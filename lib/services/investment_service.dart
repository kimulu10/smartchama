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

  Future<void> liquidateInvestment(
      String investmentId, double actualReturn) async {
    await _investments.doc(investmentId).update({
      'actualReturn': actualReturn,
      'status': InvestmentStatus.liquidated.index,
      'endDate': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
