import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:smartchama/screens/dashboard/unified_dashboard.dart';
import 'package:smartchama/models/chama_model.dart';

class CreateChamaScreen extends StatefulWidget {
  const CreateChamaScreen({super.key});

  @override
  State<CreateChamaScreen> createState() => _CreateChamaScreenState();
}

class _CreateChamaScreenState extends State<CreateChamaScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController chamaNameController = TextEditingController();
  final TextEditingController chamaDescriptionController = TextEditingController();
  
  File? selectedLogo;
  String? logoUrl;

  bool isLoading = false;

  bool loansEnabled = true;
  bool investmentsEnabled = true;
  bool dividendsEnabled = true;
  bool documentsEnabled = true;
  bool meetingsEnabled = true;
  bool votingEnabled = true;
  bool analyticsEnabled = true;
  bool attendanceEnabled = true;

  String generateInvitationCode() {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final now = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (index) {
      return chars[(now + index * 7) % chars.length];
    }).join();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        selectedLogo = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadLogo(String chamaId) async {
    if (selectedLogo == null) return null;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('organization_logos')
          .child('$chamaId.jpg');

      await storageRef.putFile(selectedLogo!);
      final url = await storageRef.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint("Logo upload error: $e");
      return null;
    }
  }

  Future<void> createChama() async {
    final user = auth.currentUser;

    if (user == null) return;

    final name = chamaNameController.text.trim();
    final description = chamaDescriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a Chama name")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final code = generateInvitationCode();
      final email = user.email ?? "";

      final orgRef = await firestore.collection("organizations").add({
        "name": "$name Organization",
        "adminId": user.uid,
        "description": description,
        "createdAt": Timestamp.now(),
      });

      final features = ChamaFeatures(
        loansEnabled: loansEnabled,
        investmentsEnabled: investmentsEnabled,
        dividendsEnabled: dividendsEnabled,
        documentsEnabled: documentsEnabled,
        meetingsEnabled: meetingsEnabled,
        votingEnabled: votingEnabled,
        analyticsEnabled: analyticsEnabled,
        attendanceEnabled: attendanceEnabled,
      );
      
      final chamaRef = await firestore
          .collection("organizations")
          .doc(orgRef.id)
          .collection("chamas")
          .add({
        "name": name,
        "adminId": user.uid,
        "inviteCode": code,
        "description": description,
        "logoUrl": null,
        "createdAt": Timestamp.now(),
        "features": features.toMap(),
      });

      if (selectedLogo != null) {
        final uploadedUrl = await _uploadLogo(chamaRef.id);
        if (uploadedUrl != null) {
          await firestore
              .collection("organizations")
              .doc(orgRef.id)
              .collection("chamas")
              .doc(chamaRef.id)
              .update({"logoUrl": uploadedUrl});
          
          await firestore
              .collection("organizations")
              .doc(orgRef.id)
              .update({"logoUrl": uploadedUrl});
        }
      }

      await firestore.collection("users").doc(user.uid).set({
        "email": email,
        "name": name,
        "chamaId": chamaRef.id,
        "organizationId": orgRef.id,
        "role": "admin",
        "status": "approved",
      });

      await firestore
          .collection("organizations")
          .doc(orgRef.id)
          .collection("chamas")
          .doc(chamaRef.id)
          .collection("members")
          .doc(user.uid)
          .set({
        "userId": user.uid,
        "email": email,
        "name": name,
        "role": "admin",
        "joinedAt": Timestamp.now(),
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Chama Created Successfully"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Share this code with members:"),
              const SizedBox(height: 10),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text("Copy Code"),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Code copied to clipboard")),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Continue"),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => UnifiedDashboard(userId: user.uid),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint("Create Chama Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    chamaNameController.dispose();
    chamaDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Chama"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Organization Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: chamaNameController,
              decoration: const InputDecoration(
                labelText: "Chama/Organization Name",
                border: OutlineInputBorder(),
                hintText: "e.g., Mwananchi Chama",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: chamaDescriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description (Optional)",
                border: OutlineInputBorder(),
                hintText: "Describe your chama's purpose and goals...",
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Organization Logo (Optional)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: selectedLogo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            selectedLogo!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text("Tap to add logo",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                ),
              ),
            ),
            if (selectedLogo != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => selectedLogo = null),
                  child: const Text("Remove Logo"),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Text(
              "Enable Features",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Select which features your chama will use",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Loans"),
                    subtitle: const Text("Allow members to request loans"),
                    value: loansEnabled,
                    onChanged: (v) => setState(() => loansEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Investments"),
                    subtitle: const Text("Track investments and returns"),
                    value: investmentsEnabled,
                    onChanged: (v) => setState(() => investmentsEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Dividends"),
                    subtitle: const Text("Distribute dividends to members"),
                    value: dividendsEnabled,
                    onChanged: (v) => setState(() => dividendsEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Documents"),
                    subtitle: const Text("Store and share files"),
                    value: documentsEnabled,
                    onChanged: (v) => setState(() => documentsEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Meetings"),
                    subtitle: const Text("Schedule and manage meetings"),
                    value: meetingsEnabled,
                    onChanged: (v) => setState(() => meetingsEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Voting"),
                    subtitle: const Text("Conduct polls and votes"),
                    value: votingEnabled,
                    onChanged: (v) => setState(() => votingEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Analytics"),
                    subtitle: const Text("View financial reports"),
                    value: analyticsEnabled,
                    onChanged: (v) => setState(() => analyticsEnabled = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Attendance"),
                    subtitle: const Text("Track member attendance"),
                    value: attendanceEnabled,
                    onChanged: (v) => setState(() => attendanceEnabled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : createChama,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Create Chama"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
