import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/loan_scoring_model.dart';
import 'package:smartchama/models/loan_model.dart';

class LoanScoringService {
  static final LoanScoringService _instance = LoanScoringService._internal();
  factory LoanScoringService() => _instance;
  LoanScoringService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _loanScores => _firestore.collection('loan_scores');

  Future<LoanScore> calculateLoanScore({
    required String chamaId,
    required String userId,
    required double requestedAmount,
    String? loanId,
  }) async {
    final now = DateTime.now();
    final factors = <String, dynamic>{};
    int totalScore = 0;

    final contributionsSnapshot = await _firestore
        .collection("organizations")
        .doc(chamaId)
        .collection("chamas")
        .doc(chamaId)
        .collection("contributions")
        .where("userId", isEqualTo: userId)
        .get();

    final contributions = contributionsSnapshot.docs;
    double totalContributions = 0;
    for (var doc in contributions) {
      totalContributions += (doc["amount"] ?? 0).toDouble();
    }

    int contributionScore = 0;
    if (totalContributions >= 50000) contributionScore = 100;
    else if (totalContributions >= 20000) contributionScore = 80;
    else if (totalContributions >= 10000) contributionScore = 60;
    else if (totalContributions >= 5000) contributionScore = 40;
    else if (totalContributions > 0) contributionScore = 20;

    factors['contributionHistory'] = {
      'name': 'Contribution History',
      'weight': 0.30,
      'score': contributionScore,
      'description': 'Total contributions: KES ${totalContributions.toInt()}',
    };
    totalScore += (contributionScore * 0.30).round();

    final loansSnapshot = await _firestore
        .collection("organizations")
        .doc(chamaId)
        .collection("chamas")
        .doc(chamaId)
        .collection("loans")
        .where("userId", isEqualTo: userId)
        .get();

    final loans = loansSnapshot.docs;
    double totalLoans = 0;
    double totalRepaid = 0;
    for (var doc in loans) {
      final amount = (doc["amount"] ?? 0).toDouble();
      final repaid = (doc["repaidAmount"] ?? 0).toDouble();
      totalLoans += amount;
      totalRepaid += repaid;
    }

    double repaymentRate = totalLoans > 0 ? (totalRepaid / totalLoans) * 100 : 100;
    int repaymentScore = 0;
    if (repaymentRate >= 90) repaymentScore = 100;
    else if (repaymentRate >= 70) repaymentScore = 80;
    else if (repaymentRate >= 50) repaymentScore = 60;
    else if (repaymentRate >= 30) repaymentScore = 40;
    else if (repaymentRate > 0) repaymentScore = 20;

    factors['repaymentHistory'] = {
      'name': 'Repayment History',
      'weight': 0.25,
      'score': repaymentScore,
      'description': 'Repayment rate: ${repaymentRate.toStringAsFixed(1)}%',
    };
    totalScore += (repaymentScore * 0.25).round();

    final userDoc = await _firestore.collection("users").doc(userId).get();
    final createdAt = userDoc.data()?["createdAt"];
    int membershipMonths = 0;
    if (createdAt != null) {
      final createdDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
      membershipMonths = ((now.difference(createdDate).inDays) / 30).floor();
    }

    int membershipScore = 0;
    if (membershipMonths >= 24) membershipScore = 100;
    else if (membershipMonths >= 12) membershipScore = 80;
    else if (membershipMonths >= 6) membershipScore = 60;
    else if (membershipMonths >= 3) membershipScore = 40;
    else if (membershipMonths > 0) membershipScore = 20;

    factors['membershipDuration'] = {
      'name': 'Membership Duration',
      'weight': 0.20,
      'score': membershipScore,
      'description': 'Member for $membershipMonths months',
    };
    totalScore += (membershipScore * 0.20).round();

    double loanToContributionRatio = totalContributions > 0 ? requestedAmount / totalContributions : 1.0;
    int ratioScore = 0;
    if (loanToContributionRatio <= 0.5) ratioScore = 100;
    else if (loanToContributionRatio <= 1.0) ratioScore = 80;
    else if (loanToContributionRatio <= 2.0) ratioScore = 60;
    else if (loanToContributionRatio <= 3.0) ratioScore = 40;
    else ratioScore = 20;

    factors['loanToContributionRatio'] = {
      'name': 'Loan-to-Contribution Ratio',
      'weight': 0.15,
      'score': ratioScore,
      'description': 'Ratio: ${loanToContributionRatio.toStringAsFixed(2)}',
    };
    totalScore += (ratioScore * 0.15).round();

    final votesSnapshot = await _firestore
        .collection("organizations")
        .doc(chamaId)
        .collection("chamas")
        .doc(chamaId)
        .collection("votes")
        .get();

    int activityScore = 50;
    factors['chamaActivity'] = {
      'name': 'Chama Activity',
      'weight': 0.10,
      'score': activityScore,
      'description': 'Active member',
    };
    totalScore += (activityScore * 0.10).round();

    String riskLevel;
    if (totalScore >= 70) riskLevel = RiskLevel.low.name;
    else if (totalScore >= 40) riskLevel = RiskLevel.medium.name;
    else riskLevel = RiskLevel.high.name;

    String recommendation;
    if (totalScore >= 70) recommendation = 'approve';
    else if (totalScore >= 40) recommendation = 'review';
    else recommendation = 'reject';

    final score = LoanScore(
      id: loanId ?? '',
      loanId: loanId ?? '',
      chamaId: chamaId,
      userId: userId,
      score: totalScore.clamp(0, 100),
      riskLevel: riskLevel,
      recommendation: recommendation,
      factors: factors,
      memberContributionHistory: totalContributions,
      memberLoanHistory: totalLoans,
      repaymentRate: repaymentRate,
      chamaMembershipDuration: membershipMonths,
      calculatedAt: now,
    );

    if (loanId != null) {
      final scoreDoc = _loanScores.doc();
      await scoreDoc.set(score.toMap());
    }

    return score;
  }

  Future<void> saveScore(LoanScore score) async {
    final doc = _loanScores.doc(score.id.isEmpty ? null : score.id);
    if (score.id.isEmpty) {
      final newDoc = _loanScores.doc();
      await newDoc.set(score.toMap());
    } else {
      await doc.set(score.toMap());
    }
  }

  Future<LoanScore?> getScoreForLoan(String loanId) async {
    final snapshot = await _loanScores
        .where('loanId', isEqualTo: loanId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return LoanScore.fromMap(snapshot.docs.first.data() as Map<String, dynamic>, snapshot.docs.first.id);
  }

  Future<List<LoanScore>> getMemberScoreHistory(String chamaId, String userId) async {
    final snapshot = await _loanScores
        .where('chamaId', isEqualTo: chamaId)
        .where('userId', isEqualTo: userId)
        .orderBy('calculatedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => LoanScore.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> approveLoanWithScore(String loanId, String scoreId) async {
    await _firestore
        .collection("organizations")
        .doc(scoreId)
        .collection("chamas")
        .doc(scoreId)
        .collection("loans")
        .doc(loanId)
        .update({"status": "approved"});
  }
}
