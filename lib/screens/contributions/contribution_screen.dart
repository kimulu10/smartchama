import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartchama/widgets/common_widgets.dart';
import 'package:smartchama/services/notification_service.dart';
import 'package:smartchama/models/chama_model.dart';

class ContributionScreen extends StatefulWidget {
  final String organizationId;
  final String chamaId;

  const ContributionScreen({
    super.key,
    required this.organizationId,
    required this.chamaId,
  });

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  final amountController = TextEditingController();
  final FirebaseAuth auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String chamaName = "";
  ChamaRules chamaRules = ChamaRules();

  @override
  void initState() {
    super.initState();
    _loadChamaInfo();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _loadChamaInfo() async {
    final chamaDoc = await FirebaseFirestore.instance
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();

    if (chamaDoc.exists) {
      final data = chamaDoc.data();
      if (mounted) {
        setState(() {
          chamaName = data?["name"] ?? "";
          if (data?["rules"] != null) {
            chamaRules = ChamaRules.fromMap(Map<String, dynamic>.from(data!["rules"]));
          }
        });
      }
    }
  }

  Future<void> _scheduleContributionReminder() async {
    final user = auth.currentUser;
    if (user == null) return;

    await NotificationService().scheduleContributionReminder(
      chamaId: widget.chamaId,
      chamaName: chamaName,
      deadline: chamaRules.contributionDeadline,
      amount: chamaRules.contributionAmount,
    );
  }

  void addContribution() async {
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = auth.currentUser;
      final ref = FirebaseFirestore.instance
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("contributions");

      await ref.add({
        "userId": user?.uid,
        "amount": double.parse(amountController.text),
        "createdAt": FieldValue.serverTimestamp(),
        "month": DateTime.now().month,
        "year": DateTime.now().year,
        "paymentMethod": "manual",
        "status": "completed",
      });

      await FirebaseFirestore.instance
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("transactions")
          .add({
        "userId": user?.uid,
        "chamaId": widget.chamaId,
        "amount": double.parse(amountController.text),
        "type": "contribution",
        "timestamp": FieldValue.serverTimestamp(),
        "status": "completed",
        "paymentMethod": "manual",
      });

      amountController.clear();

      await _scheduleContributionReminder();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contribution Added")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final contributionsRef = FirebaseFirestore.instance
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("contributions");

    return Scaffold(
      appBar: AppBar(
        title: Text(chamaName.isEmpty ? "Contributions" : "$chamaName - Contributions"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF2E7D32)),
                          SizedBox(width: 8),
                          Text(
                            "Contribution Details",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Expected Amount: KES ${chamaRules.contributionAmount.toStringAsFixed(0)}"),
                      Text("Deadline: ${chamaRules.contributionDeadline.day}/${chamaRules.contributionDeadline.month}/${chamaRules.contributionDeadline.year}"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Add New Contribution",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Amount (KES)",
                          prefixText: "KES ",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : addContribution,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Add Contribution"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Recent Contributions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: contributionsRef
                    .orderBy("createdAt", descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingShimmer(height: 100);
                  }

                  if (snapshot.hasError) {
                    return ErrorDisplay(
                      message: "Failed to load contributions",
                      onRetry: () => setState(() {}),
                    );
                  }

                  final contributions = snapshot.data?.docs ?? [];

                  if (contributions.isEmpty) {
                    return const EmptyStateDisplay(
                      title: "No contributions yet",
                      subtitle: "Be the first to contribute!",
                      icon: Icons.payments_outlined,
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: contributions.length,
                    itemBuilder: (context, index) {
                      final data = contributions[index];
                      final amount = (data["amount"] ?? 0).toDouble();
                      final timestamp =
                          (data["createdAt"] as Timestamp?)?.toDate();
                      final status = data["status"] ?? "completed";

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: status == "completed"
                                ? const Color(0xFF1B5E20)
                                : Colors.orange,
                            child: Icon(
                              status == "completed"
                                  ? Icons.attach_money
                                  : Icons.pending,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            "KES ${amount.toStringAsFixed(0)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            timestamp != null
                                ? "${timestamp.day}/${timestamp.month}/${timestamp.year}"
                                : "Unknown date",
                          ),
                          trailing: Icon(
                            status == "completed"
                                ? Icons.check_circle
                                : Icons.pending,
                            color: status == "completed"
                                ? Colors.green
                                : Colors.orange,
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
}
