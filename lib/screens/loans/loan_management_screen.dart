import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'loan_repayment_screen.dart';

class LoanManagementScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const LoanManagementScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<LoanManagementScreen> createState() => _LoanManagementScreenState();
}

class _LoanManagementScreenState extends State<LoanManagementScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  String? currentUserId;
  String? role;
  bool isLoading = true;
  String chamaName = "Loans";

  @override
  void initState() {
    super.initState();
    loadUserData();
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
        chamaName = chamaDoc.data()?["name"] ?? "Loans";
      });
    }
  }

  Future<void> loadUserData() async {
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => currentUserId = user.uid);

    final memberDoc = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("members")
        .doc(user.uid)
        .get();

    setState(() {
      role = memberDoc.data()?["role"];
      isLoading = false;
    });
  }

  Future<void> updateLoanStatus(String loanId, String status) async {
    try {
      // Get user details for the transaction
      final memberDoc = await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("loans")
          .doc(loanId)
          .get();
      
      final loanData = memberDoc.data() ?? {};
      final userId = loanData["userId"];

      // Update loan status
      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("loans")
          .doc(loanId)
          .update({"status": status});

      // Add transaction record
      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("transactions")
          .add({
        "userId": userId,
        "chamaId": widget.chamaId,
        "organizationId": widget.organizationId,
        "loanId": loanId,
        "amount": (loanData["amount"] ?? 0).toDouble(),
        "type": "loan_request",
        "status": status,
        "description": "Loan request $status",
        "timestamp": Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Loan $status successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update loan: $e")),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'repaid':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (role != "admin" && role != "treasurer" && role != "chairman") {
      return Scaffold(
        appBar: AppBar(
          title: Text("$chamaName - Loans"),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text("Access denied - Admin only")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$chamaName - Loan Requests"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection("organizations")
            .doc(widget.organizationId)
            .collection("chamas")
            .doc(widget.chamaId)
            .collection("loans")
            .orderBy("date", descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.money_off, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No loan requests",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Members haven't requested any loans yet",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final loans = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: loans.length,
            itemBuilder: (context, index) {
              final loan = loans[index];
              final amount = (loan["amount"] ?? 0).toDouble();
              final repaid = (loan["repaidAmount"] ?? 0).toDouble();
              final status = loan["status"] ?? "pending";
              final outstanding = amount - repaid;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            "KES ${amount.toInt()}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loan["reason"] ?? "No reason provided",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildInfoChip("Repaid", "KES ${repaid.toInt()}"),
                          const SizedBox(width: 12),
                          _buildInfoChip("Outstanding", "KES ${outstanding.toInt()}"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate((loan["date"] as Timestamp?)?.toDate()),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                      
                      if (status == "pending") ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => updateLoanStatus(loan.id, "approved"),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text("Approve"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => updateLoanStatus(loan.id, "rejected"),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text("Reject"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      if (status == "approved" && outstanding > 0) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LoanRepaymentScreen(
                                    loanId: loan.id,
                                    totalAmount: amount,
                                    organizationId: widget.organizationId,
                                    chamaId: widget.chamaId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.payment),
                            label: const Text("Record Payment"),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Unknown";
    return "${date.day}/${date.month}/${date.year}";
  }
}