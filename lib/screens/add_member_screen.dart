import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddMemberScreen extends StatefulWidget {
  final String organizationId;
  final String chamaId;

  const AddMemberScreen({
    super.key,
    required this.organizationId,
    required this.chamaId,
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {

  final emailController = TextEditingController();

  void addMember() async {

    final membersRef = FirebaseFirestore.instance
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("members");

    await membersRef.add({
      "email": emailController.text.trim(),
      "joinedAt": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Member Added")));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Member")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Member Email",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: addMember,
              child: const Text("Add Member"),
            )
          ],
        ),
      ),
    );
  }
}