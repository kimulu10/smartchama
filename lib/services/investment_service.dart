import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/investment_model.dart';

class InvestmentService {
  static final InvestmentService _instance = InvestmentService._internal();
  factory InvestmentService() => _instance;
  InvestmentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _investments => _firestore.collection('investments');

  Future<String> createInvestment({
    required String chamaId,
    required String name,
    String description = '',
    required double amount,
    double expectedReturn = 0,
    required DateTime startDate,
    DateTime? endDate,
    required InvestmentType type,
  }) async {
    final doc = _investments.doc();
    await doc.set(Investment(
      id: doc.id,
      chamaId: chamaId,
      name: name,
      description: description,
      amount: amount,
      expectedReturn: expectedReturn,
      startDate: startDate,
      endDate: endDate,
      type: type,
    ).toMap());
    return doc.id;
  }

  Future<void> updateInvestment({
    required String investmentId,
    String? name,
    String? description,
    String? notes,
    double? actualReturn,
    DateTime? endDate,
    InvestmentStatus? status,
    RiskLevel? riskLevel,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (notes != null) updates['notes'] = notes;
    if (actualReturn != null) updates['actualReturn'] = actualReturn;
    if (endDate != null) updates['endDate'] = endDate.millisecondsSinceEpoch;
    if (status != null) updates['status'] = status.index;
    if (riskLevel != null) updates['riskLevel'] = riskLevel.index;

    await _investments.doc(investmentId).update(updates);
  }

  Future<List<Investment>> getInvestments(String chamaId) async {
    final snapshot = await _investments
        .where('chamaId', isEqualTo: chamaId)
        .orderBy('startDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) =>
            Investment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Stream<List<Investment>> watchInvestments(String chamaId) {
    return _investments
        .where('chamaId', isEqualTo: chamaId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                Investment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<InvestmentSummary> getInvestmentSummary(String chamaId) async {
    final investments = await getInvestments(chamaId);
    final active =
        investments.where((i) => i.status == InvestmentStatus.active).toList();

    double totalInvested = 0;
    double totalExpected = 0;
    double totalActual = 0;

    for (final inv in active) {
      totalInvested += inv.amount;
      totalExpected += inv.expectedReturn;
      totalActual += inv.actualReturn;
    }

    return InvestmentSummary(
      totalInvested: totalInvested,
      totalExpectedReturn: totalExpected,
      totalActualReturn: totalActual,
      averageRoi: totalInvested > 0 ? (totalActual / totalInvested) * 100 : 0,
      activeInvestments: active.length,
    );
  }

  Future<PortfolioAnalysis> getPortfolioAnalysis(String chamaId) async {
    final investments = await getInvestments(chamaId);
    final active = investments.where((i) => i.status == InvestmentStatus.active).toList();

    double totalInvested = 0;
    for (final inv in active) {
      totalInvested += inv.amount;
    }

    final typeAllocation = <InvestmentType, double>{};
    final typeReturns = <InvestmentType, double>{};
    final typeCounts = <InvestmentType, int>{};

    for (final inv in active) {
      typeAllocation[inv.type] = (typeAllocation[inv.type] ?? 0) + inv.amount;
      typeReturns[inv.type] = (typeReturns[inv.type] ?? 0) + inv.actualReturn;
      typeCounts[inv.type] = (typeCounts[inv.type] ?? 0) + 1;
    }

    final diversificationScore = _calculateDiversificationScore(typeAllocation.length, totalInvested, typeAllocation);
    final concentrationRisk = _calculateConcentrationRisk(totalInvested, typeAllocation);

    final maturedInvestments = investments.where((i) => i.status == InvestmentStatus.matured || i.status == InvestmentStatus.liquidated).toList();
    double totalMaturedReturns = 0;
    double totalMaturedAmount = 0;
    for (final inv in maturedInvestments) {
      totalMaturedReturns += inv.actualReturn;
      totalMaturedAmount += inv.amount;
    }

    return PortfolioAnalysis(
      totalInvested: totalInvested,
      totalActive: active.length,
      totalMatured: maturedInvestments.length,
      typeAllocation: typeAllocation,
      typeReturns: typeReturns,
      typeCounts: typeCounts,
      diversificationScore: diversificationScore,
      concentrationRisk: concentrationRisk,
      historicalReturn: totalMaturedAmount > 0 ? (totalMaturedReturns / totalMaturedAmount) * 100 : 0,
    );
  }

  double _calculateDiversificationScore(int typeCount, double totalInvested, Map<InvestmentType, double> allocation) {
    if (typeCount == 0 || totalInvested == 0) return 0;
    if (typeCount == 1) return 20;
    if (typeCount == 2) return 50;
    if (typeCount >= 3) return 80;

    double maxAllocation = 0;
    for (final amount in allocation.values) {
      if (amount > maxAllocation) maxAllocation = amount;
    }
    final maxPercentage = maxAllocation / totalInvested;
    if (maxPercentage > 0.7) return 40;
    if (maxPercentage > 0.5) return 60;
    return 80;
  }

  double _calculateConcentrationRisk(double totalInvested, Map<InvestmentType, double> allocation) {
    if (totalInvested == 0) return 0;
    double maxAllocation = 0;
    for (final amount in allocation.values) {
      if (amount > maxAllocation) maxAllocation = amount;
    }
    return (maxAllocation / totalInvested) * 100;
  }

  Future<void> liquidateInvestment(
      String investmentId, double actualReturn) async {
    await _investments.doc(investmentId).update({
      'actualReturn': actualReturn,
      'status': InvestmentStatus.liquidated.index,
      'endDate': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> matureInvestment(String investmentId) async {
    await _investments.doc(investmentId).update({
      'status': InvestmentStatus.matured.index,
      'endDate': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Investment>> getInvestmentsDueForMaturity(String chamaId) async {
    final now = DateTime.now();
    final investments = await getInvestments(chamaId);
    return investments.where((i) {
      if (i.status != InvestmentStatus.active || i.endDate == null) return false;
      return i.endDate!.isBefore(now.add(const Duration(days: 7)));
    }).toList();
  }
}

class PortfolioAnalysis {
  final double totalInvested;
  final int totalActive;
  final int totalMatured;
  final Map<InvestmentType, double> typeAllocation;
  final Map<InvestmentType, double> typeReturns;
  final Map<InvestmentType, int> typeCounts;
  final double diversificationScore;
  final double concentrationRisk;
  final double historicalReturn;

  PortfolioAnalysis({
    required this.totalInvested,
    required this.totalActive,
    required this.totalMatured,
    required this.typeAllocation,
    required this.typeReturns,
    required this.typeCounts,
    required this.diversificationScore,
    required this.concentrationRisk,
    required this.historicalReturn,
  });

  String get diversificationRating {
    if (diversificationScore >= 80) return 'Excellent';
    if (diversificationScore >= 60) return 'Good';
    if (diversificationScore >= 40) return 'Fair';
    return 'Poor';
  }

  String get riskLevel {
    if (concentrationRisk > 70) return 'High';
    if (concentrationRisk > 50) return 'Medium';
    return 'Low';
  }
}
