import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/screens/dashboard/unified_dashboard.dart';

class JoinChamaScreen extends StatefulWidget {
  const JoinChamaScreen({super.key});

  @override
  State<JoinChamaScreen> createState() => _JoinChamaScreenState();
}

class _JoinChamaScreenState extends State<JoinChamaScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController codeController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  Future<void> joinChama() async {
    final code = codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => errorMessage = "Please enter invite code");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = auth.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
          errorMessage = "Please login first";
        });
        return;
      }

      // Search all organizations for the chama with this invite code
      String? chamaId;
      String? organizationId;
      String? chamaName;

      final orgs = await firestore.collection("organizations").get();
      
      for (var orgDoc in orgs.docs) {
        final chamas = await firestore
            .collection("organizations")
            .doc(orgDoc.id)
            .collection("chamas")
            .where("inviteCode", isEqualTo: code)
            .get();
        
        if (chamas.docs.isNotEmpty) {
          final chama = chamas.docs.first;
          chamaId = chama.id;
          organizationId = orgDoc.id;
          chamaName = chama.data()["name"];
          break;
        }
      }

      if (chamaId == null || organizationId == null) {
        setState(() {
          isLoading = false;
          errorMessage = "Invalid invite code. Please check and try again.";
        });
        return;
      }

      // Get user name from user doc
      final userDoc = await firestore.collection("users").doc(user.uid).get();
      final userName = userDoc.data()?["name"] ?? user.email ?? "Member";

      // Add member to the chama
      await firestore
          .collection("organizations")
          .doc(organizationId)
          .collection("chamas")
          .doc(chamaId)
          .collection("members")
          .doc(user.uid)
          .set({
        "userId": user.uid,
        "email": user.email,
        "name": userName,
        "role": "member",
        "status": "pending",
        "joinedAt": Timestamp.now(),
      });

      // Update user with chamaId and organizationId
      await firestore.collection("users").doc(user.uid).set({
        "chamaId": chamaId,
        "organizationId": organizationId,
        "role": "member",
        "status": "pending",
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Joined $chamaName! Pending approval.")),
      );

      // Navigate to dashboard
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => UnifiedDashboard(userId: user.uid),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join Chama"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "Invite Code",
                border: OutlineInputBorder(),
                hintText: "Enter 6-character code",
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : joinChama,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Join Chama"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}