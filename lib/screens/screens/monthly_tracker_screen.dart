import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyTrackerScreen extends StatelessWidget {
  const MonthlyTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Monthly Contributions"),
      ),

      body: FutureBuilder<DocumentSnapshot>(

        future: firestore.collection("users").doc(user.uid).get(),

        builder: (context, userSnapshot) {

          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chamaId = userSnapshot.data!["chamaId"];

          return StreamBuilder<QuerySnapshot>(

            stream: firestore
                .collection("members")
                .where("chamaId", isEqualTo: chamaId)
                .snapshots(),

            builder: (context, membersSnapshot) {

              if (!membersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = membersSnapshot.data!.docs;

              return ListView.builder(

                itemCount: members.length,

                itemBuilder: (context, index) {

                  final member = members[index];

                  final userId = member["userId"];

                  return FutureBuilder<QuerySnapshot>(

                    future: firestore
                        .collection("contributions")
                        .where("userId", isEqualTo: userId)
                        .where("month", isEqualTo: now.month)
                        .where("year", isEqualTo: now.year)
                        .get(),

                    builder: (context, contributionSnapshot) {

                      if (!contributionSnapshot.hasData) {
                        return const SizedBox();
                      }

                      final hasPaid =
                          contributionSnapshot.data!.docs.isNotEmpty;

                      return FutureBuilder<DocumentSnapshot>(

                        future: firestore
                            .collection("users")
                            .doc(userId)
                            .get(),

                        builder: (context, userDoc) {

                          if (!userDoc.hasData) {
                            return const SizedBox();
                          }

                          final email = userDoc.data!["email"];

                          return Card(

                            child: ListTile(

                              leading: const Icon(Icons.person),

                              title: Text(email),

                              trailing: hasPaid
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : const Icon(Icons.cancel,
                                      color: Colors.red),

                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}