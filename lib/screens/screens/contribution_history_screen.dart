import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ContributionHistoryScreen extends StatelessWidget {
  const ContributionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final FirebaseAuth auth = FirebaseAuth.instance;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Contribution History"),
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: firestore.collection("users").doc(user.uid).get(),
        builder: (context, userSnapshot) {

          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data!;
          final chamaId = userData["chamaId"];

          return StreamBuilder<QuerySnapshot>(

            stream: firestore
                .collection("contributions")
                .where("chamaId", isEqualTo: chamaId)
                .orderBy("date", descending: true)
                .snapshots(),

            builder: (context, snapshot) {

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final contributions = snapshot.data!.docs;

              if (contributions.isEmpty) {
                return const Center(
                  child: Text("No contributions yet"),
                );
              }

              return ListView.builder(

                itemCount: contributions.length,

                itemBuilder: (context, index) {

                  final data = contributions[index];

                  final amount = data["amount"];
                  final date = (data["date"] as Timestamp).toDate();

                  return FutureBuilder<DocumentSnapshot>(
                    future: firestore
                        .collection("users")
                        .doc(data["userId"])
                        .get(),

                    builder: (context, userDoc) {

                      if (!userDoc.hasData) {
                        return const SizedBox();
                      }

                      final userData = userDoc.data!;

                      return Card(
                        child: ListTile(

                          leading: const Icon(Icons.payments),

                          title: Text(
                            "KES $amount",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          subtitle: Text(
                              "${userData["email"]} • ${DateFormat.yMMMd().format(date)}"),

                        ),
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