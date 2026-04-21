import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartchama/screens/analytics_screen.dart';
import '../transactions/transaction_history_screen.dart'; // For individual member transactions
// For admin charts

class MembersScreen extends StatefulWidget {
  final bool filterPending; // filter only pending members

  const MembersScreen({super.key, this.filterPending = false});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool isAdmin = false;
  String chamaId = "";
  bool isLoading = true;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  /// Load current user role and chama
  Future<void> loadUser() async {
    final user = auth.currentUser;
    if (user == null) return;

    final userDoc = await firestore.collection("users").doc(user.uid).get();
    final data = userDoc.data();

    setState(() {
      chamaId = data?["chamaId"] ?? "";
      isAdmin = data?["role"] == "admin";
      isLoading = false;
    });
  }

  /// Approve Member
  Future<void> approveMember(String docId, String userId) async {
    try {
      await firestore.collection("members").doc(docId).update({
        "status": "approved",
      });
      await firestore.collection("users").doc(userId).update({
        "status": "approved",
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Member approved")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error approving member: $e")));
    }
  }

  /// Reject Member
  Future<void> rejectMember(String docId, {String? userId}) async {
    try {
      await firestore.collection("members").doc(docId).delete();
      if (userId != null) {
        await firestore.collection("users").doc(userId).update({
          "status": "rejected",
        });
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Member rejected")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error rejecting member: $e")));
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "rejected":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    Query memberQuery = firestore
        .collection("members")
        .where("chamaId", isEqualTo: chamaId)
        .orderBy("joinedAt", descending: true);

    if (widget.filterPending) {
      memberQuery = memberQuery.where("status", isEqualTo: "pending");
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filterPending ? "Pending Members" : "Chama Members"),
        actions: [
          if (!widget.filterPending)
            IconButton(
                icon: const Icon(Icons.bar_chart),
                onPressed: () {
                  if (!isAdmin) return;
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AnalyticsScreen(chamaId: chamaId, organizationId: '',)));
                })
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                  hintText: "Search members...",
                  fillColor: Colors.white,
                  filled: true,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none)),
              onChanged: (val) {
                setState(() {
                  searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: chamaId.isEmpty
          ? const Center(child: Text("No Chama assigned"))
          : StreamBuilder<QuerySnapshot>(
              stream: memberQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(widget.filterPending
                        ? "No pending members"
                        : "No members yet"),
                  );
                }

                final members = snapshot.data!.docs.where((member) {
                  final name = (member["name"] ?? "").toString().toLowerCase();
                  final email = (member["email"] ?? "").toString().toLowerCase();
                  return name.contains(searchQuery) || email.contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final name = member["name"] ?? "No Name";
                    final email = member["email"] ?? "No Email";
                    final role = member["role"] ?? "member";
                    final status = member["status"] ?? "pending";
                    final userId = member["userId"];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// NAME + STATUS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Chip(
                                  label: Text(status.toUpperCase()),
                                  backgroundColor:
                                      statusColor(status).withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: statusColor(status),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),

                            /// EMAIL + ROLE
                            Text(email),
                            const SizedBox(height: 5),
                            Text("Role: $role"),
                            const SizedBox(height: 10),

                            /// 🔥 ADMIN ACTIONS
                            if (isAdmin && status == "pending")
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green),
                                      onPressed: () =>
                                          approveMember(member.id, userId),
                                      child: const Text("Approve"),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red),
                                      onPressed: () =>
                                          rejectMember(member.id, userId: userId),
                                      child: const Text("Reject"),
                                    ),
                                  ),
                                ],
                              ),

                            /// 🔹 MEMBER TRANSACTION HISTORY
                            if (!widget.filterPending)
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TransactionHistoryScreen(
                                          memberId: userId, chamaId: chamaId, organizationId: '',),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.history),
                                label: const Text("View Transactions"),
                              ),
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
}