import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsScreen extends StatelessWidget {
  final String chamaId;
  final String organizationId;

  const AnalyticsScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection("transactions")
            .where("chamaId", isEqualTo: chamaId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          double contributions = 0;
          double loanRequests = 0;
          double repayments = 0;
          int pending = 0;
          int successOrApproved = 0;
          int failedOrRejected = 0;

          for (var doc in snapshot.data!.docs) {
            final type = doc["type"];
            final status = (doc["status"] ?? "").toString();
            final amount = (doc["amount"] ?? 0).toDouble();

            switch (type) {
              case "contribution":
                contributions += amount;
                break;
              case "loan_request":
                loanRequests += amount;
                break;
              case "loan_repayment":
                repayments += amount;
                break;
            }

            if (status == "pending") pending++;
            if (status == "success" || status == "approved") successOrApproved++;
            if (status == "failed" || status == "rejected") failedOrRejected++;
          }

          return Column(
            children: [
              const SizedBox(height: 20),
              const Text("Financial Overview",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Pending: $pending  •  Success/Approved: $successOrApproved  •  Failed/Rejected: $failedOrRejected"),

              SizedBox(
                height: 300,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                          value: contributions,
                          title: "Contrib",
                          radius: 60),
                      PieChartSectionData(
                          value: loanRequests, title: "Loans", radius: 60),
                      PieChartSectionData(
                          value: repayments,
                          title: "Repay",
                          radius: 60),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}