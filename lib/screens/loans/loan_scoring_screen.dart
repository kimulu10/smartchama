import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/loan_scoring_model.dart';
import 'package:smartchama/services/loan_scoring_service.dart';

class LoanScoringScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const LoanScoringScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<LoanScoringScreen> createState() => _LoanScoringScreenState();
}

class _LoanScoringScreenState extends State<LoanScoringScreen> {
  final LoanScoringService _scoringService = LoanScoringService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingLoans = [];

  @override
  void initState() {
    super.initState();
    _loadPendingLoans();
  }

  Future<void> _loadPendingLoans() async {
    final snapshot = await _firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .collection("loans")
        .where("status", isEqualTo: "pending")
        .orderBy("date", descending: true)
        .get();

    setState(() {
      _pendingLoans = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      _isLoading = false;
    });
  }

  Future<void> _calculateAndApprove(String loanId, String userId, double amount) async {
    setState(() => _isLoading = true);
    try {
      final score = await _scoringService.calculateLoanScore(
        chamaId: widget.chamaId,
        userId: userId,
        requestedAmount: amount,
        loanId: loanId,
      );

      if (score.recommendation == 'approve') {
        await _firestore
            .collection("organizations")
            .doc(widget.organizationId)
            .collection("chamas")
            .doc(widget.chamaId)
            .collection("loans")
            .doc(loanId)
            .update({
          "status": "approved",
          "scoreId": score.id,
          "riskLevel": score.riskLevel,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loan approved (Score: ${score.score})'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (score.recommendation == 'reject') {
        await _firestore
            .collection("organizations")
            .doc(widget.organizationId)
            .collection("chamas")
            .doc(widget.chamaId)
            .collection("loans")
            .doc(loanId)
            .update({
          "status": "rejected",
          "scoreId": score.id,
          "riskLevel": score.riskLevel,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loan rejected (Score: ${score.score})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Review Required (Score: ${score.score})'),
              content: Text('This loan requires manual review. Score breakdown:\n'
                  '${score.factors.values.map((f) => '- ${f['name']}: ${f['score']}').join('\n')}'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            ),
          );
        }
      }

      _loadPendingLoans();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Loan Scoring'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: _pendingLoans.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No pending loans', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPendingLoans,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pendingLoans.length,
                itemBuilder: (context, index) {
                  final loan = _pendingLoans[index];
                  return _buildLoanCard(loan);
                },
              ),
            ),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    final amount = (loan['amount'] ?? 0).toDouble();
    final userId = loan['userId'] ?? '';
    final reason = loan['reason'] ?? 'No reason provided';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KES ${amount.toInt()}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(reason, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _calculateAndApprove(loan['id'], userId, amount),
                icon: const Icon(Icons.auto_graph, size: 18),
                label: const Text('Calculate Score & Decide'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
