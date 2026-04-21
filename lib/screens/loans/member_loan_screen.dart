import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemberLoanScreen extends StatefulWidget {
  final String organizationId;
  final String chamaId;

  const MemberLoanScreen({
    super.key,
    required this.organizationId,
    required this.chamaId,
  });

  @override
  State<MemberLoanScreen> createState() => _MemberLoanScreenState();
}

class _MemberLoanScreenState extends State<MemberLoanScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  String? currentUserId;
  bool isLoading = true;
  List<Map<String, dynamic>> myLoans = [];
  String chamaName = "My Loans";

  @override
  void initState() {
    super.initState();
    currentUserId = auth.currentUser?.uid;
    loadMyLoans();
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
        chamaName = chamaDoc.data()?["name"] ?? "My Loans";
      });
    }
  }

  Future<void> loadMyLoans() async {
    if (currentUserId == null) return;

    try {
      final loans = await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("loans")
          .where("userId", isEqualTo: currentUserId)
          .where("userId", isEqualTo: currentUserId)
          .orderBy("date", descending: true)
          .get();

      myLoans = loans.docs
          .map((d) => {
                "id": d.id,
                "amount": d["amount"] ?? 0,
                "repaidAmount": d["repaidAmount"] ?? 0,
                "status": d["status"] ?? "pending",
                "reason": d["reason"] ?? "",
                "date": d["date"],
              })
          .toList();

      setState(() => isLoading = false);
    } catch (e) {
      print("Error loading loans: $e");
      setState(() => isLoading = false);
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'repaid':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$chamaName - My Loans"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadMyLoans,
              child: myLoans.isEmpty
                  ? _buildEmptyState()
                  : _buildLoansList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestLoanDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Request Loan"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.money_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No loans yet",
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "Request a loan if you need funds",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myLoans.length,
      itemBuilder: (context, index) {
        final loan = myLoans[index];
        final amount = (loan["amount"] as num).toDouble();
        final repaid = (loan["repaidAmount"] as num).toDouble();
        final status = loan["status"] ?? "pending";
        final balance = amount - repaid;
        final progress = amount > 0 ? (repaid / amount * 100) : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  getStatusColor(status).withOpacity(0.05),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "KES ${amount.toInt()}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: getStatusColor(status),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (loan["reason"] != null && loan["reason"].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    loan["reason"],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Repaid", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        Text("KES ${repaid.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Balance", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        Text(
                          "KES ${balance.toInt()}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: balance > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(getStatusColor(status)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${progress.toStringAsFixed(1)}% repaid",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (status == "approved" && balance > 0) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRepayDialog(loan["id"], balance),
                      icon: const Icon(Icons.payment),
                      label: const Text("Make Payment"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRequestLoanDialog() {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Request Loan"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount (KES)",
                  prefixText: "KES ",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Reason",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (amountController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter amount")),
                );
                return;
              }

              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid amount")),
                );
                return;
              }

              await firestore
                  .collection("organizations")
                  .doc(widget.organizationId)
                  .collection("chamas")
                  .doc(widget.chamaId)
                  .collection("loans")
                  .add({
                "userId": currentUserId,
                "chamaId": widget.chamaId,
                "amount": amount,
                "reason": reasonController.text.trim(),
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
                "userId": currentUserId,
                "chamaId": widget.chamaId,
                "amount": amount,
                "type": "loan_request",
                "status": "pending",
                "description": "Loan request: ${reasonController.text.trim()}",
                "timestamp": Timestamp.now(),
              });

              Navigator.pop(context);
              loadMyLoans();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Loan request submitted")),
              );
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  void _showRepayDialog(String loanId, double balance) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Make Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Remaining balance: KES ${balance.toInt()}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Payment Amount",
                prefixText: "KES ",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid amount")),
                );
                return;
              }

              final loansRef = firestore
                  .collection("organizations")
                  .doc(widget.organizationId)
                  .collection("chamas")
                  .doc(widget.chamaId)
                  .collection("loans");

              final loanDoc = await loansRef.doc(loanId).get();
              final currentRepaid = (loanDoc.data()?["repaidAmount"] ?? 0).toDouble();

              await loansRef.doc(loanId).set({
                "repaidAmount": currentRepaid + amount,
              }, SetOptions(merge: true));

              if (currentRepaid + amount >= (loanDoc.data()?["amount"] ?? 0).toDouble()) {
                await loansRef.doc(loanId).update({
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
                "userId": currentUserId,
                "chamaId": widget.chamaId,
                "loanId": loanId,
                "amount": amount,
                "type": "loan_repayment",
                "status": "success",
                "description": "Loan repayment",
                "timestamp": Timestamp.now(),
              });

              Navigator.pop(context);
              loadMyLoans();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Payment recorded")),
              );
            },
            child: const Text("Pay"),
          ),
        ],
      ),
    );
  }
}