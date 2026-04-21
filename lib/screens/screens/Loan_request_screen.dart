import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoanRequestScreen extends StatefulWidget {
  const LoanRequestScreen({super.key});

  @override
  State<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool isLoading = false;

  Future<void> requestLoan() async {
    if (amountController.text.isEmpty || reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter all details")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = auth.currentUser;
      if (user == null) return;

      final userDoc = await firestore.collection("users").doc(user.uid).get();
      final chamaId = userDoc["chamaId"];

      await firestore.collection("loans").add({
        "userId": user.uid,
        "chamaId": chamaId,
        "amount": double.parse(amountController.text),
        "reason": reasonController.text,
        "status": "Pending",
        "repaidAmount": 0.0,
        "date": Timestamp.now(),
        "month": DateTime.now().month,
        "year": DateTime.now().year,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Loan request submitted")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Request Loan")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount (KES)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: "Reason",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: requestLoan,
                      child: const Text("Submit Loan Request"),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}