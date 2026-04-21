import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/mpesa_service.dart';

class LoanRepaymentScreen extends StatefulWidget {
  final String loanId;
  final double totalAmount;
  final String organizationId;
  final String chamaId;

  const LoanRepaymentScreen({
    super.key,
    required this.loanId,
    required this.totalAmount,
    required this.organizationId,
    required this.chamaId,
  });

  @override
  State<LoanRepaymentScreen> createState() =>
      _LoanRepaymentScreenState();
}

class _LoanRepaymentScreenState
    extends State<LoanRepaymentScreen> {

  final TextEditingController amountController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  double totalPaid = 0;
  bool isLoading = false;

  /// =========================
  /// LOAD PAYMENTS
  /// =========================
  Future<void> loadPayments() async {
    final payments = await firestore
        .collection("loan_payments")
        .where("loanId", isEqualTo: widget.loanId)
        .get();

    double sum = 0;

    for (var doc in payments.docs) {
      sum += (doc["amount"] ?? 0).toDouble();
    }

    setState(() {
      totalPaid = sum;
    });
  }

  /// =========================
  /// MANUAL PAYMENT (CASH)
  /// =========================
  Future<void> makeManualPayment() async {
    if (amountController.text.isEmpty) return;

    double? amount = double.tryParse(amountController.text);

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid amount")),
      );
      return;
    }

    setState(() => isLoading = true);

    await firestore.collection("loan_payments").add({
      "loanId": widget.loanId,
      "amount": amount,
      "date": Timestamp.now(),
      "method": "cash",
    });

    final loansRef = firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("loans");
    
    final loanDoc = await loansRef.doc(widget.loanId).get();
    final currentRepaid = (loanDoc.data()?["repaidAmount"] ?? 0).toDouble();

    await loansRef.doc(widget.loanId).set({
      "repaidAmount": currentRepaid + amount,
    }, SetOptions(merge: true));

    if (currentRepaid + amount >= (loanDoc.data()?["amount"] ?? 0).toDouble()) {
      await loansRef.doc(widget.loanId).update({
        "status": "repaid",
      });
    }

    final loanData = loanDoc.data() ?? {};

    await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("transactions")
          .add({
      "userId": loanData["userId"],
      "chamaId": loanData["chamaId"],
      "loanId": widget.loanId,
      "amount": amount,
      "type": "loan_repayment",
      "status": "success",
      "source": "cash",
      "paymentMethod": "cash",
      "description": "Cash loan repayment recorded",
      "timestamp": Timestamp.now(),
    });

    double newTotal = totalPaid + amount;

    if (newTotal >= widget.totalAmount) {
      await firestore.collection("loans").doc(widget.loanId).update({
        "status": "repaid"
      });
    }

    amountController.clear();
    await loadPayments();

    setState(() => isLoading = false);
  }

  /// =========================
  /// MPESA PAYMENT
  /// =========================
  Future<void> payWithMpesa() async {

    if (amountController.text.isEmpty || phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter amount and phone")),
      );
      return;
    }

    double? amount = double.tryParse(amountController.text);

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid amount")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() => isLoading = true);

    final userDoc = await firestore
        .collection("users")
        .doc(user.uid)
        .get();

    final chamaId = userDoc["chamaId"];
    final organizationId = userDoc["organizationId"] ?? '';

    final result = await MpesaService.payLoan(
      phone: phoneController.text,
      amount: amount,
      userId: user.uid,
      organizationId: organizationId,
      chamaId: chamaId,
      loanId: widget.loanId,
    );

    if (result['success'] != true) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${result['error']}")),
      );
      return;
    }

    final checkoutRequestID = result['checkoutRequestID'];

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text("M-Pesa Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Please check your phone and enter your M-Pesa PIN."),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text("Waiting for payment..."),
          ],
        ),
      ),
    );

    final status = await MpesaService.waitForTransactionCompletion(checkoutRequestID);

    if (!mounted) return;
    Navigator.pop(context);

    if (status == 'success') {
      final loansRef = firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("loans");
      
      final loanDoc = await loansRef.doc(widget.loanId).get();
      final currentRepaid = (loanDoc.data()?["repaidAmount"] ?? 0).toDouble();

      await loansRef.doc(widget.loanId).set({
        "repaidAmount": currentRepaid + amount,
      }, SetOptions(merge: true));

      await firestore.collection("loan_payments").add({
        "loanId": widget.loanId,
        "amount": amount,
        "date": Timestamp.now(),
        "method": "mpesa",
        "checkoutRequestID": checkoutRequestID,
      });

      if (currentRepaid + amount >= widget.totalAmount) {
        await loansRef.doc(widget.loanId).update({
          "status": "repaid",
        });
      }

      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("transactions")
          .add({
        "userId": user.uid,
        "chamaId": widget.chamaId,
        "loanId": widget.loanId,
        "amount": amount,
        "type": "loan_repayment",
        "status": "success",
        "source": "mpesa",
        "paymentMethod": "mpesa",
        "description": "M-Pesa loan repayment",
        "timestamp": Timestamp.now(),
      });

      await loadPayments();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment successful!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment failed or timed out"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    loadPayments();
  }

  @override
  Widget build(BuildContext context) {

    double balance = widget.totalAmount - totalPaid;

    return Scaffold(
      appBar: AppBar(title: const Text("Loan Repayment")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              /// SUMMARY CARD
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(
                        "Total Loan: KES ${widget.totalAmount}",
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "Paid: KES $totalPaid",
                        style: const TextStyle(color: Colors.green),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "Balance: KES $balance",
                        style: const TextStyle(color: Colors.red),
                      ),

                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              /// AMOUNT
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Repayment Amount",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              /// PHONE
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone (07XXXXXXXX)",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              /// BUTTONS
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [

                        /// MPESA BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.phone_android),
                            label: const Text("Pay via MPESA"),
                            onPressed: payWithMpesa,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// MANUAL BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: makeManualPayment,
                            child: const Text("Record Cash Payment"),
                          ),
                        ),

                      ],
                    ),

            ],
          ),
        ),
      ),
    );
  }
}