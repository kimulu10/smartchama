import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;
  final String? memberId; // null = all members (admin)

  const TransactionHistoryScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
    this.memberId,
  });

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String filterType = "all"; // all, contribution, loan_request, loan_repayment
  String filterStatus = "all"; // all, pending, success, failed, approved, rejected
  final ScrollController _scrollController = ScrollController();
  String chamaName = "Transactions";

  @override
  void initState() {
    super.initState();
    _loadChamaName();
  }

  Future<void> _loadChamaName() async {
    final chamaDoc = await FirebaseFirestore.instance
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();
    if (chamaDoc.exists && mounted) {
      setState(() {
        chamaName = chamaDoc.data()?["name"] ?? "Transactions";
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {}); // Trigger rebuild and re-fetch
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    Query transactionQuery = FirebaseFirestore.instance
        .collection("transactions")
        .where("chamaId", isEqualTo: widget.chamaId)
        .orderBy("timestamp", descending: true);

    // Filter for member only if memberId is passed
    if (widget.memberId != null) {
      transactionQuery = transactionQuery.where("userId", isEqualTo: widget.memberId);
    }

    // Filter by type
    if (filterType != "all") {
      transactionQuery = transactionQuery.where("type", isEqualTo: filterType);
    }

    // Filter by status
    if (filterStatus != "all") {
      transactionQuery = transactionQuery.where("status", isEqualTo: filterStatus);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("$chamaName - Transactions"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.rule),
            onSelected: (value) {
              setState(() {
                filterStatus = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "all", child: Text("All Statuses")),
              PopupMenuItem(value: "pending", child: Text("Pending")),
              PopupMenuItem(value: "success", child: Text("Success")),
              PopupMenuItem(value: "failed", child: Text("Failed")),
              PopupMenuItem(value: "approved", child: Text("Approved")),
              PopupMenuItem(value: "rejected", child: Text("Rejected")),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                filterType = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "all", child: Text("All")),
              PopupMenuItem(value: "contribution", child: Text("Contributions")),
              PopupMenuItem(value: "loan_request", child: Text("Loan Requests")),
              PopupMenuItem(value: "loan_repayment", child: Text("Loan Repayments")),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          child: Column(
            children: [
              // Admin Analytics Chart
              if (widget.memberId == null) _analyticsChart(),

              StreamBuilder<QuerySnapshot>(
                stream: transactionQuery.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final transactions = snapshot.data!.docs;

                  if (transactions.isEmpty) {
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          "No transactions found",
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final data = transactions[index];
                      final timestamp = (data["timestamp"] as Timestamp?)?.toDate();
                      final formattedTime = timestamp != null
                          ? DateFormat.yMMMd().add_jm().format(timestamp)
                          : "Unknown";

                      final type = data["type"] ?? "info";
                      final status = (data["status"] ?? "unknown").toString();
                      final amount = (data["amount"] ?? 0).toDouble();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _iconColor(type).withOpacity(0.2),
                            child: Icon(_icon(type), color: _iconColor(type)),
                          ),
                          title: Text(
                            "KES ${amount.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _iconColor(type),
                            ),
                          ),
                          subtitle: Text("${data["description"] ?? ""}\n$formattedTime"),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Chip(
                                label: Text(type.toUpperCase()),
                                backgroundColor: _iconColor(type).withOpacity(0.15),
                              ),
                              const SizedBox(height: 4),
                              Chip(
                                label: Text(status.toUpperCase()),
                                backgroundColor: _statusColor(status).withOpacity(0.15),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Analytics Chart for Admin
  Widget _analyticsChart() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("transactions")
          .where("chamaId", isEqualTo: widget.chamaId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(
            height: 150,
            child: Center(child: Text("No data for analytics")),
          );
        }

        final transactions = snapshot.data!.docs;

        double totalContributions = 0;
        double totalLoans = 0;
        double totalRepayments = 0;

        for (var doc in transactions) {
          final type = doc["type"] ?? "";
          final amount = (doc["amount"] ?? 0).toDouble();
          if (type == "contribution") totalContributions += amount;
          if (type == "loan_request") totalLoans += amount;
          if (type == "loan_repayment") totalRepayments += amount;
        }

        return SizedBox(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: [
                      totalContributions,
                      totalLoans,
                      totalRepayments
                    ].reduce((a, b) => a > b ? a : b) *
                    1.2,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text("Contrib");
                          case 1:
                            return const Text("Loans");
                          case 2:
                            return const Text("Repay");
                          default:
                            return const Text("");
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(toY: totalContributions, color: Colors.green)
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [BarChartRodData(toY: totalLoans, color: Colors.red)],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [BarChartRodData(toY: totalRepayments, color: Colors.blue)],
                  ),
                ],
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case "contribution":
        return Icons.arrow_downward;
      case "loan":
      case "loan_request":
        return Icons.money;
      case "loan_repayment":
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case "contribution":
        return Colors.green;
      case "loan":
      case "loan_request":
        return Colors.red;
      case "loan_repayment":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "success":
      case "approved":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "failed":
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}