import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceAnalyticsDashboard extends StatefulWidget {
  final String chamaId;

  const AttendanceAnalyticsDashboard({super.key, required this.chamaId});

  @override
  State<AttendanceAnalyticsDashboard> createState() =>
      _AttendanceAnalyticsDashboardState();
}

class _AttendanceAnalyticsDashboardState
    extends State<AttendanceAnalyticsDashboard> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, double> attendanceStats = {};
  Map<String, int> attendanceCount = {};
  Map<String, int> totalMeetings = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  // ==========================
  // LOAD ANALYTICS
  // ==========================
  Future<void> loadAnalytics() async {
    final meetingsSnapshot = await firestore
        .collection("attendance")
        .where("chamaId", isEqualTo: widget.chamaId)
        .get();

    for (var meeting in meetingsSnapshot.docs) {
      final membersSnapshot = await firestore
          .collection("attendance")
          .doc(meeting.id)
          .collection("members")
          .get();

      for (var m in membersSnapshot.docs) {
        final email = m["email"];
        final present = m["present"] == true;

        totalMeetings[email] = (totalMeetings[email] ?? 0) + 1;

        if (present) {
          attendanceCount[email] = (attendanceCount[email] ?? 0) + 1;
        }
      }
    }

    attendanceStats = {
      for (var email in totalMeetings.keys)
        email: ((attendanceCount[email] ?? 0) /
                totalMeetings[email]!) *
            100
    };

    setState(() => isLoading = false);
  }

  // ==========================
  // MEMBER RANKING
  // ==========================
  List<MapEntry<String, double>> getRankedMembers() {
    final list = attendanceStats.entries.toList();
    list.sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  // ==========================
  // ALERTS
  // ==========================
  List<String> getLowAttendanceMembers() {
    return attendanceStats.entries
        .where((e) => e.value < 50)
        .map((e) => e.key)
        .toList();
  }

  // ==========================
  // LOAN ELIGIBILITY
  // ==========================
  bool isEligibleForLoan(String email) {
    return (attendanceStats[email] ?? 0) >= 60;
  }

  // ==========================
  // UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    final ranked = getRankedMembers();
    final lowAttendance = getLowAttendanceMembers();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics Dashboard"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(15),
                children: [
                  // ==========================
                  // 📊 ATTENDANCE OVERVIEW
                  // ==========================
                  const Text("Attendance Overview",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 10),

                  ...attendanceStats.entries.map((entry) {
                    return Card(
                      child: ListTile(
                        title: Text(entry.key),
                        subtitle: LinearProgressIndicator(
                          value: entry.value / 100,
                          minHeight: 8,
                        ),
                        trailing:
                            Text("${entry.value.toStringAsFixed(1)}%"),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // ==========================
                  // 🏆 TOP MEMBERS
                  // ==========================
                  const Text("Top Performers",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                  ...ranked.take(5).map((e) {
                    return Card(
                      color: Colors.green.withOpacity(0.1),
                      child: ListTile(
                        leading: const Icon(Icons.star, color: Colors.green),
                        title: Text(e.key),
                        trailing:
                            Text("${e.value.toStringAsFixed(1)}%"),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // ==========================
                  // ⚠️ LOW ATTENDANCE ALERTS
                  // ==========================
                  const Text("Absentee Alerts",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                  if (lowAttendance.isEmpty)
                    const Text("No issues detected ✅")
                  else
                    ...lowAttendance.map((email) {
                      return Card(
                        color: Colors.red.withOpacity(0.1),
                        child: ListTile(
                          leading:
                              const Icon(Icons.warning, color: Colors.red),
                          title: Text(email),
                          subtitle: const Text("Low attendance"),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // ==========================
                  // 💰 LOAN ELIGIBILITY
                  // ==========================
                  const Text("Loan Eligibility",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                  ...attendanceStats.entries.map((e) {
                    final eligible = isEligibleForLoan(e.key);

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          eligible
                              ? Icons.check_circle
                              : Icons.cancel,
                          color:
                              eligible ? Colors.green : Colors.red,
                        ),
                        title: Text(e.key),
                        subtitle: Text(
                            eligible ? "Eligible for loan" : "Not eligible"),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // ==========================
                  // 🧠 SMART INSIGHTS
                  // ==========================
                  const Text("Smart Insights",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                              "• ${lowAttendance.length} members have attendance below 50%"),
                          Text(
                              "• Best performer: ${ranked.isNotEmpty ? ranked.first.key : "-"}"),
                          const Text(
                              "• Encourage inactive members to attend meetings"),
                          const Text(
                              "• Consider penalties for absenteeism"),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}