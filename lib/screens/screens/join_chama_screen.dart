import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import your UnifiedDashboard
import '../dashboard/unified_dashboard.dart';

class JoinChamaScreen extends StatefulWidget {
  const JoinChamaScreen({super.key});

  @override
  State<JoinChamaScreen> createState() => _JoinChamaScreenState();
}

class _JoinChamaScreenState extends State<JoinChamaScreen> {
  final TextEditingController codeController = TextEditingController();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  bool isLoading = false;

  Future<void> joinChama() async {
    final code = codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter invite code")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = auth.currentUser;
      if (user == null) return;

      /// 🔍 GET USER DATA
      final userDoc = await firestore.collection("users").doc(user.uid).get();
      final userData = userDoc.data();
      final name = userData?["name"] ?? "No Name";
      final email = user.email;

      /// 🔍 FIND CHAMA BY CODE
      final query = await firestore
          .collection("chamas")
          .where("inviteCode", isEqualTo: code)
          .get();

      if (query.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid invite code")),
        );
        setState(() => isLoading = false);
        return;
      }

      final chama = query.docs.first;
      final chamaId = chama.id;

      /// 🚫 CHECK IF ALREADY MEMBER
      final existingMember = await firestore
          .collection("members")
          .where("userId", isEqualTo: user.uid)
          .where("chamaId", isEqualTo: chamaId)
          .get();

      if (existingMember.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You already requested/joined")),
        );
        setState(() => isLoading = false);
        return;
      }

      /// 🔥 ADD MEMBER WITH PENDING STATUS
      await firestore.collection("members").add({
        "userId": user.uid,
        "name": name,
        "email": email,
        "chamaId": chamaId,
        "role": "member",
        "status": "pending",
        "joinedAt": Timestamp.now(),
      });

      /// 🔥 UPDATE USER PROFILE MERGE
      await firestore.collection("users").doc(user.uid).set({
        "chamaId": chamaId,
        "role": "member",
        "status": "pending",
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request sent! Await admin approval")),
      );

      /// ✅ NAVIGATE TO DASHBOARD
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => UnifiedDashboard(userId: user.uid),
        ),
        (route) => false,
      );
    } catch (e) {
      print("🔥 Join Error: $e");
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
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join Chama"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Enter Invitation Code",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: "Invite Code",
                hintText: "e.g. ABC123",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: joinChama,
                      child: const Text(
                        "Request to Join",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
} 