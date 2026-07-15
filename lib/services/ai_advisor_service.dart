import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/ai_advisor_model.dart';

/// Enterprise AI Financial Advisor. Generates financial insights, loan
/// recommendations, savings advice, investment suggestions and cash-flow
/// forecasts from the tenant's chama data.
class AiAdvisorService {
  static final AiAdvisorService _instance = AiAdvisorService._internal();
  factory AiAdvisorService() => _instance;
  AiAdvisorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _insights =>
      _firestore.collection('advisor_insights');

  Future<List<AdvisorInsight>> generateInsights({
    required String organizationId,
    String? chamaId,
  }) async {
    final contributions = await _sumContributions(organizationId, chamaId);
    final loans = await _sumLoans(organizationId, chamaId);
    final investments = await _sumInvestments(organizationId, chamaId);
    final now = DateTime.now();

    final insights = <AdvisorInsight>[];

    // Savings advice.
    if (contributions > 0) {
      insights.add(AdvisorInsight(
        id: _firestore.collection('x').doc().id,
        organizationId: organizationId,
        chamaId: chamaId,
        category: AdvisorCategory.savingsAdvice,
        severity: contributions > 50000
            ? AdvisorSeverity.positive
            : AdvisorSeverity.info,
        title: 'Savings discipline is ${contributions > 50000 ? "strong" : "building"}',
        detail:
            'Total contributions reached ${contributions.toStringAsFixed(0)}. '
            'Consider automating monthly contributions and increasing by 10-20% '
            'to accelerate group wealth.',
        score: (contributions / 100000).clamp(0, 1),
        createdAt: now,
      ));
    }

    // Loan recommendation.
    final outstanding = loans['outstanding'] ?? 0;
    insights.add(AdvisorInsight(
      id: _firestore.collection('x').doc().id,
      organizationId: organizationId,
      chamaId: chamaId,
      category: AdvisorCategory.loanRecommendation,
      severity: outstanding > loans['total']! * 0.6
          ? AdvisorSeverity.warning
          : AdvisorSeverity.positive,
      title: outstanding > 0
          ? 'Outstanding loans at ${outstanding.toStringAsFixed(0)}'
          : 'Healthy loan book',
      detail: outstanding > 0
          ? 'Outstanding loans are high. Prioritise repayments and keep the '
              'loan-to-contribution ratio below 60% to protect liquidity.'
          : 'No outstanding loans. The group has strong liquidity for new, '
              'income-generating lending.',
      score: loans['total']! > 0 ? (1 - outstanding / loans['total']!) : 1,
      createdAt: now,
    ));

    // Investment suggestion.
    if (investments > 0) {
      insights.add(AdvisorInsight(
        id: _firestore.collection('x').doc().id,
        organizationId: organizationId,
        chamaId: chamaId,
        category: AdvisorCategory.investmentSuggestion,
        severity: AdvisorSeverity.info,
        title: 'Diversify the ${investments.toStringAsFixed(0)} investment pool',
        detail: 'Spread exposure across Treasury Bills, Money Market Funds and '
            'real estate to balance risk and return. Keep 20% in liquid assets.',
        createdAt: now,
      ));
    }

    // Cash flow forecast.
    final projectedCashFlow = contributions - outstanding;
    insights.add(AdvisorInsight(
      id: _firestore.collection('x').doc().id,
      organizationId: organizationId,
      chamaId: chamaId,
      category: AdvisorCategory.cashFlowForecast,
      severity: projectedCashFlow < 0 ? AdvisorSeverity.warning : AdvisorSeverity.positive,
      title: 'Projected net cash flow',
      detail: 'Net position is ${projectedCashFlow.toStringAsFixed(0)} based on '
          'contributions minus outstanding loans. Maintain a 3-month reserve.',
      score: projectedCashFlow > 0 ? 0.8 : 0.3,
      createdAt: now,
    ));

    for (final insight in insights) {
      await _insights.doc(insight.id).set(insight.toMap());
    }
    return insights;
  }

  Future<List<AdvisorInsight>> getInsights(
    String organizationId, {
    String? chamaId,
    int limit = 30,
  }) async {
    Query query = _insights
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (chamaId != null) {
      query = query.where('chamaId', isEqualTo: chamaId);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((d) =>
            AdvisorInsight.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<double> _sumContributions(String orgId, String? chamaId) async {
    double total = 0;
    final chamas = await _chamaRefs(orgId, chamaId);
    for (final chamaRef in chamas) {
      final snap = await chamaRef.collection('contributions').get();
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        total += (data['amount'] ?? 0).toDouble();
      }
    }
    return total;
  }

  Future<Map<String, double>> _sumLoans(String orgId, String? chamaId) async {
    double total = 0;
    double outstanding = 0;
    final chamas = await _chamaRefs(orgId, chamaId);
    for (final chamaRef in chamas) {
      final snap = await chamaRef.collection('loans').get();
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        final repaid = (data['repaidAmount'] ?? 0).toDouble();
        total += amount;
        outstanding += (amount - repaid);
      }
    }
    return {'total': total, 'outstanding': outstanding};
  }

  Future<double> _sumInvestments(String orgId, String? chamaId) async {
    double total = 0;
    final chamas = await _chamaRefs(orgId, chamaId);
    for (final chamaRef in chamas) {
      final snap = await chamaRef.collection('investments').get();
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        total += (data['amount'] ?? 0).toDouble();
      }
    }
    return total;
  }

  Future<List<DocumentReference>> _chamaRefs(String orgId, String? chamaId) async {
    if (chamaId != null) {
      return [_firestore.collection('organizations').doc(orgId).collection('chamas').doc(chamaId)];
    }
    final snap = await _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('chamas')
        .get();
    return snap.docs.map((d) => d.reference).toList();
  }
}
