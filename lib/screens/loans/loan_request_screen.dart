import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoanRequestScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const LoanRequestScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  String chamaName = "Request Loan";

  @override
  void initState() {
    super.initState();
    _loadChamaName();
  }

  Future<void> _loadChamaName() async {
    final chamaDoc = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();
    if (chamaDoc.exists && mounted) {
      setState(() {
        chamaName = chamaDoc.data()?["name"] ?? "Request Loan";
      });
    }
  }

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

      final amount = double.parse(amountController.text);
      final loanRef = await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("loans")
          .add({
        "userId": user.uid,
        "chamaId": widget.chamaId,
        "amount": amount,
        "reason": reasonController.text,
        "status": "pending",
        "repaidAmount": 0.0,
        "date": Timestamp.now(),
        "createdAt": Timestamp.now(),
        "month": DateTime.now().month,
        "year": DateTime.now().year,
      });

      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("transactions")
          .add({
        "userId": user.uid,
        "chamaId": widget.chamaId,
        "loanId": loanRef.id,
        "amount": amount,
        "type": "loan_request",
        "status": "pending",
        "source": "system",
        "description": "Loan request submitted",
        "timestamp": Timestamp.now(),
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
      appBar: AppBar(
        title: Text("$chamaName - Request Loan"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
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