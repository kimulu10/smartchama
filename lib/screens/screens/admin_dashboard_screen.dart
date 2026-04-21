import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool isLoading = true;
  String chamaId = "";
  String chamaName = "";
  String welcomeMessage = "";
  List<String> rules = [];
  Map<String, String> roleVotes = {}; // userId -> voted role
  Map<String, String> finalRoles = {}; // userId -> final role
  List<Map<String, dynamic>> members = [];

  TextEditingController welcomeController = TextEditingController();
  TextEditingController newRuleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAdminData();
  }

  Future<void> loadAdminData() async {
    try {
      final user = auth.currentUser;
      if (user == null) return;

      final userDoc = await firestore.collection("users").doc(user.uid).get();
      if (!userDoc.exists || userDoc["chamaId"] == null) return;

      chamaId = userDoc["chamaId"];
      final chamaDoc = await firestore.collection("chamas").doc(chamaId).get();

      chamaName = chamaDoc.data()?["name"] ?? "Your Chama";
      welcomeMessage = chamaDoc.data()?["welcomeMessage"] ?? "";
      welcomeController.text = welcomeMessage;
      rules = List<String>.from(chamaDoc.data()?["rules"] ?? []);

      // Load members
      final memberDocs = await firestore
          .collection("members")
          .where("chamaId", isEqualTo: chamaId)
          .get();
      members = memberDocs.docs
          .map((d) => {"id": d.id, "email": d["email"], "role": d["role"] ?? "member", "acknowledgedRules": d["acknowledgedRules"] ?? false})
          .toList();

      // Load role votes
      final votes = await firestore
          .collection("roleVotes")
          .where("chamaId", isEqualTo: chamaId)
          .get();
      roleVotes = {for (var d in votes.docs) d["userId"]: d["role"]};

      // Load final roles
      for (var member in members) {
        finalRoles[member["id"]] = member["role"];
      }

      setState(() => isLoading = false);
    } catch (e) {
      print("🔥 Admin Load Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> updateWelcomeMessage() async {
    await firestore.collection("chamas").doc(chamaId).update({
      "welcomeMessage": welcomeController.text.trim(),
    });
    setState(() {
      welcomeMessage = welcomeController.text.trim();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Welcome message updated")));
  }

  Future<void> addRule() async {
    if (newRuleController.text.trim().isEmpty) return;
    rules.add(newRuleController.text.trim());
    await firestore.collection("chamas").doc(chamaId).update({
      "rules": rules,
    });
    newRuleController.clear();
    setState(() {});
  }

  Future<void> removeRule(int index) async {
    rules.removeAt(index);
    await firestore.collection("chamas").doc(chamaId).update({
      "rules": rules,
    });
    setState(() {});
  }

  Future<void> finalizeRole(String userId, String role) async {
    await firestore.collection("members").doc(userId).update({
      "role": role,
    });
    finalRoles[userId] = role;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Assigned $role")));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin Dashboard - $chamaName")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// WELCOME MESSAGE
                  const Text("Welcome Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: welcomeController,
                          decoration: const InputDecoration(
                            hintText: "Set welcome message",
                          ),
                        ),
                      ),
                      IconButton(
                          onPressed: updateWelcomeMessage,
                          icon: const Icon(Icons.save, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  /// RULES MANAGEMENT
                  const Text("Chama Rules", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ...rules.asMap().entries.map((e) => ListTile(
                        title: Text(e.value),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => removeRule(e.key),
                        ),
                      )),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newRuleController,
                          decoration: const InputDecoration(hintText: "Add new rule"),
                        ),
                      ),
                      IconButton(
                        onPressed: addRule,
                        icon: const Icon(Icons.add, color: Colors.blue),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),

                  /// ROLE VOTING
                  const Text("Role Votes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ...members.map((member) => Card(
                        child: ListTile(
                          title: Text("${member["email"]} (Voted: ${roleVotes[member["id"]] ?? "-"})"),
                          subtitle: Text("Final Role: ${finalRoles[member["id"]]} | Rules Acknowledged: ${member["acknowledgedRules"]}"),
                          trailing: PopupMenuButton<String>(
                            onSelected: (role) => finalizeRole(member["id"], role),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: "chairman", child: Text("Chairman")),
                              const PopupMenuItem(value: "secretary", child: Text("Secretary")),
                              const PopupMenuItem(value: "treasurer", child: Text("Treasurer")),
                              const PopupMenuItem(value: "member", child: Text("Member")),
                            ],
                            icon: const Icon(Icons.edit),
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}