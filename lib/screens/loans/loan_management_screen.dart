import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartchama/services/notification_service.dart';
import 'package:smartchama/models/chama_model.dart';

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
  ChamaRules chamaRules = ChamaRules();
  String _errorMessage = "";
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    loadUserData();
    _loadChamaName();
    _loadChamaRules();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChamaName() async {
    try {
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
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Failed to load chama name");
    }
  }

  Future<void> _loadChamaRules() async {
    try {
      final chamaDoc = await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .get();
      if (chamaDoc.exists) {
        final data = chamaDoc.data();
        if (data?["rules"] != null) {
          setState(() {
            chamaRules = ChamaRules.fromMap(Map<String, dynamic>.from(data!["rules"]));
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Failed to load chama rules");
    }
  }

  Future<void> loadUserData() async {
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => currentUserId = user.uid);

    try {
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
        _errorMessage = "";
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        _errorMessage = "Failed to load user role";
      });
    }
  }

  Future<void> updateLoanStatus(String loanId, String status) async {
    try {
      final loanDoc = await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("loans")
          .doc(loanId)
          .get();

      final loanData = loanDoc.data() ?? {};
      final userId = loanData["userId"];
      final amount = (loanData["amount"] ?? 0).toDouble();

      final updates = <String, dynamic>{
        "status": status,
        "processedAt": Timestamp.now(),
        "processedBy": currentUserId,
      };

      if (status == "approved") {
        updates["deadline"] = Timestamp.fromDate(
          DateTime.now().add(Duration(days: chamaRules.loanRepaymentDays)),
        );
      }

      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("loans")
          .doc(loanId)
          .update(updates);

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
        "amount": amount,
        "type": "loan_request",
        "status": status,
        "description": "Loan request $status",
        "timestamp": Timestamp.now(),
      });

      await NotificationService().notifyLoanStatus(
        chamaId: widget.chamaId,
        status: status,
        amount: amount,
      );

      if (status == "approved") {
        final deadline = DateTime.now().add(Duration(days: chamaRules.loanRepaymentDays));
        await NotificationService().scheduleLoanDeadlineReminder(
          chamaId: widget.chamaId,
          loanId: loanId,
          deadline: deadline,
          outstandingAmount: amount,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Loan $status successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update loan: $e")),
        );
      }
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
      case 'overdue':
        return Colors.deepOrange;
      default:
        return Colors.orange;
    }
  }

  bool _isOverdue(dynamic deadline) {
    if (deadline == null) return false;
    final deadlineDate = (deadline as Timestamp).toDate();
    return deadlineDate.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text("$chamaName - Loans"),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(_errorMessage, style: TextStyle(fontSize: 16, color: Colors.red[700])),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => loadUserData()),
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (role != "admin" && role != "treasurer" && role != "chairman") {
      return Scaffold(
        appBar: AppBar(
          title: Text("$chamaName - Loans"),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text("Access denied - Admin/Treasurer only")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$chamaName - Loan Requests"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: "Refresh",
          ),
        ],
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

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text("Error loading loans: ${snapshot.error}", style: TextStyle(color: Colors.red[700])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final loans = snapshot.data!.docs;

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: loans.length,
              itemBuilder: (context, index) {
                final loan = loans[index];
                final amount = (loan["amount"] ?? 0).toDouble();
                final repaid = (loan["repaidAmount"] ?? 0).toDouble();
                final status = loan["status"] ?? "pending";
                final outstanding = amount - repaid;
                final deadline = loan["deadline"];
                final isOverdue = status == "approved" && _isOverdue(deadline);
                final progress = amount > 0 ? (repaid / amount) : 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isOverdue ? Colors.deepOrange : _getStatusColor(status).withOpacity(0.3),
                      width: isOverdue ? 2 : 1,
                    ),
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
                                color: (isOverdue ? Colors.deepOrange : _getStatusColor(status)).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isOverdue ? "OVERDUE" : status.toUpperCase(),
                                style: TextStyle(
                                  color: isOverdue ? Colors.deepOrange : _getStatusColor(status),
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
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isOverdue ? Colors.deepOrange : _getStatusColor(status),
                            ),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${(progress * 100).toStringAsFixed(1)}% repaid",
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                        if (status == "approved" && deadline != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                isOverdue ? Icons.warning : Icons.calendar_today,
                                size: 14,
                                color: isOverdue ? Colors.red : Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Due: ${_formatDate((deadline as Timestamp).toDate())}",
                                style: TextStyle(
                                  color: isOverdue ? Colors.red : Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (isOverdue) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    "OVERDUE",
                                    style: TextStyle(
                                      color: Colors.deepOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              "Requested: ${_formatDate((loan["date"] as Timestamp?)?.toDate())}",
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
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
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
          ),
        ),
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