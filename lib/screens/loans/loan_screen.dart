import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoanScreen extends StatefulWidget {

  final String organizationId;
  final String chamaId;

  const LoanScreen({
    super.key,
    required this.organizationId,
    required this.chamaId,
  });

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {

  final loanController = TextEditingController();

  void requestLoan() async {

    final ref = FirebaseFirestore.instance
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("loans");

    await ref.add({
      "amount": double.parse(loanController.text),
      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Loan Requested")));
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Loans")),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: loanController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Loan Amount",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: requestLoan,
              child: const Text("Request Loan"),
            )
          ],
        ),
      ),
    );
  }
}