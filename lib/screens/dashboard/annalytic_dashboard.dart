import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsDashboard extends StatefulWidget {
  final String chamaId;

  const AnalyticsDashboard({super.key, required this.chamaId});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  final firestore = FirebaseFirestore.instance;

  Map<String, double> memberStats = {};

  Future<void> loadStats() async {
    final attendance = await firestore.collection("attendance").get();

    Map<String, int> present = {};
    Map<String, int> total = {};

    for (var meeting in attendance.docs) {
      final members = await firestore
          .collection("attendance")
          .doc(meeting.id)
          .collection("members")
          .get();

      for (var m in members.docs) {
        final email = m["email"] ?? m.id;
        final isPresent = m["present"] == true;

        total[email] = (total[email] ?? 0) + 1;
        if (isPresent) present[email] = (present[email] ?? 0) + 1;
      }
    }

    memberStats = {};
    total.forEach((k, v) {
      memberStats[k] = ((present[k] ?? 0) / v) * 100;
    });

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analytics Dashboard")),
      body: memberStats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 20),

                // BAR CHART
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      barGroups: memberStats.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((e) {
                        return BarChartGroupData(x: e.key, barRods: [
                          BarChartRodData(toY: e.value.value)
                        ]);
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // MEMBER RANKING
                Expanded(
                  child: ListView(
                    children: memberStats.entries.map((e) {
                      return ListTile(
                        title: Text(e.key),
                        trailing:
                            Text("${e.value.toStringAsFixed(1)}%"),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
    );
  }
}