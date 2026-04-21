import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;

class AttendanceHistoryPage extends StatefulWidget {
  final String chamaId;

  const AttendanceHistoryPage({super.key, required this.chamaId});

  @override
  State<AttendanceHistoryPage> createState() =>
      _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  int selectedMonth = DateTime.now().month;
  
  get Printing => null;

  String formatDate(int timestamp) {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${d.day}/${d.month}/${d.year}";
  }

  // ==========================
  // 📥 EXPORT PDF
  // ==========================
  Future<void> exportToPDF(List<QueryDocumentSnapshot> meetings) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Attendance Report",
                style: const pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 10),
            ...meetings.map((m) {
              final data = m.data() as Map<String, dynamic>;
              return pw.Text(
                  "${data["meetingName"]} - ${formatDate(data["timestamp"])}");
            })
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ==========================
  // 📊 CALCULATE %
  // ==========================
  Future<Map<String, double>> calculateAttendanceStats(
      List<QueryDocumentSnapshot> meetings) async {
    Map<String, int> presentCount = {};
    Map<String, int> totalCount = {};

    for (var meeting in meetings) {
      final membersSnapshot = await firestore
          .collection("attendance")
          .doc(meeting.id)
          .collection("members")
          .get();

      for (var m in membersSnapshot.docs) {
        final email = m["email"];
        final present = m["present"] == true;

        totalCount[email] = (totalCount[email] ?? 0) + 1;
        if (present) {
          presentCount[email] = (presentCount[email] ?? 0) + 1;
        }
      }
    }

    Map<String, double> percentage = {};

    for (var email in totalCount.keys) {
      percentage[email] =
          (presentCount[email] ?? 0) / totalCount[email]! * 100;
    }

    return percentage;
  }

  // ==========================
  // 👑 APPROVE MEETING
  // ==========================
  Future<void> approveMeeting(String meetingId) async {
    await firestore
        .collection("attendance")
        .doc(meetingId)
        .update({"approved": true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance History"),
        actions: [
          IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                final snapshot =
                    await firestore.collection("attendance").get();
                exportToPDF(snapshot.docs);
              })
        ],
      ),
      body: Column(
        children: [
          // ==========================
          // 📅 MONTH FILTER
          // ==========================
          Padding(
            padding: const EdgeInsets.all(10),
            child: DropdownButton<int>(
              value: selectedMonth,
              isExpanded: true,
              items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text("Month ${index + 1}"))),
              onChanged: (val) {
                setState(() => selectedMonth = val!);
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection("attendance")
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final meetings = snapshot.data!.docs.where((m) {
                  final data = m.data() as Map<String, dynamic>;
                  final date = DateTime.fromMillisecondsSinceEpoch(
                      data["timestamp"]);
                  return date.month == selectedMonth;
                }).toList();

                if (meetings.isEmpty) {
                  return const Center(child: Text("No records"));
                }

                return FutureBuilder<Map<String, double>>(
                  future: calculateAttendanceStats(meetings),
                  builder: (context, statsSnapshot) {
                    final stats = statsSnapshot.data ?? {};

                    return ListView(
                      children: [
                        // ==========================
                        // 📊 ANALYTICS CARD
                        // ==========================
                        Card(
                          margin: const EdgeInsets.all(10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text("Attendance Analytics",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                                ...stats.entries.map((e) => Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 3),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(e.key),
                                          Text(
                                              "${e.value.toStringAsFixed(1)}%"),
                                        ],
                                      ),
                                    ))
                              ],
                            ),
                          ),
                        ),

                        // ==========================
                        // MEETINGS LIST
                        // ==========================
                        ...meetings.map((meeting) {
                          final data =
                              meeting.data() as Map<String, dynamic>;
                          final meetingId = meeting.id;

                          return Card(
                            margin: const EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            child: ExpansionTile(
                              title: Text(data["meetingName"]),
                              subtitle: Text(
                                  formatDate(data["timestamp"])),
                              trailing: data["approved"] == true
                                  ? const Icon(Icons.verified,
                                      color: Colors.green)
                                  : IconButton(
                                      icon: const Icon(Icons.check),
                                      onPressed: () =>
                                          approveMeeting(meetingId),
                                    ),
                              children: [
                                FutureBuilder<QuerySnapshot>(
                                  future: firestore
                                      .collection("attendance")
                                      .doc(meetingId)
                                      .collection("members")
                                      .get(),
                                  builder: (context, memberSnapshot) {
                                    if (!memberSnapshot.hasData) {
                                      return const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    final members =
                                        memberSnapshot.data!.docs;

                                    return Column(
                                      children: members.map((m) {
                                        final isPresent =
                                            m["present"] == true;

                                        return Card(
                                          margin:
                                              const EdgeInsets.all(5),
                                          child: ListTile(
                                            leading: Icon(
                                              isPresent
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              color: isPresent
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            title: Text(m["email"]),
                                            trailing: Text(
                                              isPresent
                                                  ? "Present"
                                                  : "Absent",
                                              style: TextStyle(
                                                  color: isPresent
                                                      ? Colors.green
                                                      : Colors.red),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                )
                              ],
                            ),
                          );
                        })
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}