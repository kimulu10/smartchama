import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class AdminDashboardScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const AdminDashboardScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  bool isLoading = true;
  String chamaName = "";
  String inviteCode = "";
  String welcomeMessage = "";
  String? logoUrl;
  String organizationDescription = "";
  List<Map<String, dynamic>> membersList = [];
  List<String> chamaRules = [];

  final welcomeController = TextEditingController();
  final newRuleController = TextEditingController();
  final descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAdminData();
  }

  Future<void> loadAdminData() async {
    try {
      final chamaDoc = await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .get();

      if (chamaDoc.exists) {
        chamaName = chamaDoc.data()?["name"] ?? "Your Chama";
        welcomeMessage = chamaDoc.data()?["welcomeMessage"] ?? "";
        inviteCode = chamaDoc.data()?["inviteCode"] ?? "";
        logoUrl = chamaDoc.data()?["logoUrl"];
        organizationDescription = chamaDoc.data()?["description"] ?? "";
        welcomeController.text = welcomeMessage;
        descriptionController.text = organizationDescription;
        chamaRules = List<String>.from(chamaDoc.data()?["rules"] ?? []);
      }

      final memberDocs = await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("members")
          .get();

      membersList = memberDocs.docs
          .map((d) => {
                "id": d.id,
                "name": d["name"] ?? d["email"] ?? "Unknown",
                "email": d["email"] ?? "",
                "role": d["role"] ?? "member",
                "status": d["status"] ?? "active",
                "profileImageUrl": d["profileImageUrl"],
                "joinedAt": d["joinedAt"],
              })
          .toList();

      setState(() => isLoading = false);
    } catch (e) {
      print("Error loading admin data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> pickLogo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null) {
        final File file = File(image.path);
        final String fileName = "logo_${widget.chamaId}_${DateTime.now().millisecondsSinceEpoch}";
        
        final ref = firebase_storage.FirebaseStorage.instance
            .ref()
            .child("chama_logos")
            .child(fileName);
            
        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        await firestore
            .collection("organizations")
            .doc(widget.organizationId)
            .collection("chamas")
            .doc(widget.chamaId)
            .update({"logoUrl": downloadUrl});

        setState(() => logoUrl = downloadUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logo updated!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> updateChamaDescription() async {
    try {
      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .update({"description": descriptionController.text.trim()});

      setState(() => organizationDescription = descriptionController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Description updated!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> removeMember(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Member"),
        content: const Text("Are you sure you want to remove this member? They will need to rejoin to access the chama."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Get member userId before deleting
        final memberDoc = await firestore
            .collection("organizations")
            .doc(widget.organizationId)
            .collection("chamas")
            .doc(widget.chamaId)
            .collection("members")
            .doc(memberId)
            .get();
        
        final userId = memberDoc.data()?["userId"];
        
        // Delete from members collection
        await firestore
            .collection("organizations")
            .doc(widget.organizationId)
            .collection("chamas")
            .doc(widget.chamaId)
            .collection("members")
            .doc(memberId)
            .delete();

        // Clear user's chama reference
        if (userId != null) {
          await firestore.collection("users").doc(userId).update({
            "chamaId": FieldValue.delete(),
            "organizationId": FieldValue.delete(),
          });
        }

        membersList.removeWhere((m) => m["id"] == memberId);
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Member removed")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> updateWelcomeMessage() async {
    await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .update({"welcomeMessage": welcomeController.text.trim()});

    setState(() => welcomeMessage = welcomeController.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Welcome message updated")),
    );
  }

  Future<void> addRule() async {
    if (newRuleController.text.trim().isEmpty) return;

    chamaRules.add(newRuleController.text.trim());

    await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .update({"rules": chamaRules});

    newRuleController.clear();
    setState(() {});
  }

  Future<void> removeRule(int index) async {
    chamaRules.removeAt(index);

    await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .update({"rules": chamaRules});

    setState(() {});
  }

  Future<void> assignRole(String memberId, String role) async {
    await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("members")
        .doc(memberId)
        .update({"role": role});

    final index = membersList.indexWhere((m) => m["id"] == memberId);
    if (index != -1) {
      membersList[index]["role"] = role;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Assigned $role role")),
    );

    setState(() {});
  }

  Color getRoleColor(String role) {
    switch (role) {
      case 'chairman':
        return Colors.purple;
      case 'secretary':
        return Colors.blue;
      case 'treasurer':
        return Colors.orange;
      case 'admin':
        return Colors.red;
      case 'member':
      default:
        return Colors.green;
    }
  }

  IconData getRoleIcon(String role) {
    switch (role) {
      case 'chairman':
        return Icons.emoji_events;
      case 'secretary':
        return Icons.edit_document;
      case 'treasurer':
        return Icons.account_balance;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'member':
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Panel - $chamaName"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: loadAdminData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoAndDescriptionCard(),
              const SizedBox(height: 24),
              _buildInviteCard(),
              const SizedBox(height: 24),
              _buildWelcomeMessageCard(),
              const SizedBox(height: 24),
              _buildRulesCard(),
              const SizedBox(height: 24),
              _buildMembersCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoAndDescriptionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Logo
            GestureDetector(
              onTap: pickLogo,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                    backgroundImage: logoUrl != null ? NetworkImage(logoUrl!) : null,
                    child: logoUrl == null
                        ? const Icon(Icons.business, size: 50, color: Color(0xFF2E7D32))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap to change logo",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 20),
            
            // Description
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Chama Description",
                hintText: "Describe your chama...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: updateChamaDescription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Save Description"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.group_add, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  "Invite New Members",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Invitation Code",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          inviteCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Code copied!")),
                      );
                    },
                    icon: const Icon(Icons.copy, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeMessageCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.waving_hand, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  "Welcome Message",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: welcomeController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Set a welcome message for new members",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: updateWelcomeMessage,
                icon: const Icon(Icons.save),
                label: const Text("Update Message"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Text(
                  "Chama Rules & Notes",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (chamaRules.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "No rules added yet. Add important rules and notes for your members.",
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...chamaRules.asMap().entries.map((entry) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFF2E7D32), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.value)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 18),
                          onPressed: () => removeRule(entry.key),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newRuleController,
                    decoration: InputDecoration(
                      hintText: "Add a new rule or note...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: addRule,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersCard() {
    int adminCount = 0, secretaryCount = 0, treasurerCount = 0, memberCount = 0;

    for (var m in membersList) {
      final role = m["role"];
      if (role == "admin" || role == "chairman") adminCount++;
      if (role == "secretary") secretaryCount++;
      if (role == "treasurer") treasurerCount++;
      if (role == "member") memberCount++;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.people, color: Color(0xFF2E7D32)),
                    SizedBox(width: 8),
                    Text(
                      "Member Roles",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  "${membersList.length} total",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRoleStat("Chairmen", adminCount, Icons.emoji_events, Colors.purple),
                _buildRoleStat("Secretaries", secretaryCount, Icons.edit_document, Colors.blue),
                _buildRoleStat("Treasurers", treasurerCount, Icons.account_balance, Colors.orange),
                _buildRoleStat("Members", memberCount, Icons.person, Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text("Assign Roles", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...membersList.map((member) => _buildMemberTile(member)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleStat(String label, int count, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final role = member["role"] ?? "member";
    final roleColor = getRoleColor(role);
    final roleIcon = getRoleIcon(role);
    final memberStatus = member["status"] ?? "active";
    final isActive = memberStatus == "active";
    final profileImageUrl = member["profileImageUrl"];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: isActive ? Colors.grey.shade200 : Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
        color: isActive ? null : Colors.red.shade50,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.1),
          backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
          child: profileImageUrl == null ? Icon(roleIcon, color: roleColor, size: 20) : null,
        ),
        title: Row(
          children: [
            Text(member["name"] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.w600)),
            if (!isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text("DISABLED", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: Text(member["email"] ?? "", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Role dropdown
            PopupMenuButton<String>(
              initialValue: role,
              onSelected: (newRole) => assignRole(member["id"], newRole),
              itemBuilder: (context) => const [
                PopupMenuItem(value: "chairman", child: Text("Chairman")),
                PopupMenuItem(value: "secretary", child: Text("Secretary")),
                PopupMenuItem(value: "treasurer", child: Text("Treasurer")),
                PopupMenuItem(value: "admin", child: Text("Admin")),
                PopupMenuItem(value: "member", child: Text("Member")),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(role.toUpperCase(), style: TextStyle(color: roleColor, fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: roleColor, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Enable/Disable button
            IconButton(
              icon: Icon(
                isActive ? Icons.block : Icons.check_circle,
                color: isActive ? Colors.red : Colors.green,
                size: 20,
              ),
              onPressed: () => toggleMemberStatus(member["id"], isActive ? "disabled" : "active"),
              tooltip: isActive ? "Disable member" : "Enable member",
            ),
            // Remove button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () => removeMember(member["id"]),
              tooltip: "Remove member",
            ),
          ],
        ),
      ),
    );
  }

  Future<void> toggleMemberStatus(String memberId, String status) async {
    try {
      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("members")
          .doc(memberId)
          .update({"status": status});

      final index = membersList.indexWhere((m) => m["id"] == memberId);
      if (index != -1) {
        membersList[index]["status"] = status;
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == "disabled" ? "Member disabled" : "Member enabled")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    welcomeController.dispose();
    newRuleController.dispose();
    super.dispose();
  }
}