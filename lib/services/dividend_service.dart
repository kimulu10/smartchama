import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/dividend_model.dart';
import 'package:smartchama/models/contribution_model.dart';

class DividendService {
  static final DividendService _instance = DividendService._internal();
  factory DividendService() => _instance;
  DividendService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _dividends => _firestore.collection('dividends');
  CollectionReference get _memberDividends =>
      _firestore.collection('memberDividends');

  Future<String> declareDividend({
    required String chamaId,
    required int periodYear,
    required int periodMonth,
    required double totalAmount,
  }) async {
    final doc = _dividends.doc();
    final members = await _getMemberShares(chamaId);
    final totalShares = members.values.fold(0.0, (sum, shares) => sum + shares);

    await doc.set(Dividend(
      id: doc.id,
      chamaId: chamaId,
      periodYear: periodYear,
      periodMonth: periodMonth,
      totalAmount: totalAmount,
      totalShares: totalShares,
      declaredAt: DateTime.now(),
    ).toMap());

    for (final entry in members.entries) {
      final memberDoc = _memberDividends.doc();
      final memberDividend =
          totalShares > 0 ? (totalAmount * entry.value / totalShares) : 0.0;
      await memberDoc.set(MemberDividend(
        id: memberDoc.id,
        dividendId: doc.id,
        memberId: entry.key,
        shares: entry.value,
        amount: memberDividend,
      ).toMap());
    }

    return doc.id;
  }

  Future<Map<String, double>> _getMemberShares(String chamaId) async {
    final snapshot = await _firestore
        .collection('contributions')
        .where('chamaId', isEqualTo: chamaId)
        .get();

    final memberShares = <String, double>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final memberId = data['memberId'] as String?;
      final amount = (data['amount'] ?? 0).toDouble();
      if (memberId != null) {
        memberShares[memberId] = (memberShares[memberId] ?? 0) + amount;
      }
    }
    return memberShares;
  }

  Future<List<Dividend>> getDividends(String chamaId) async {
    final snapshot = await _dividends
        .where('chamaId', isEqualTo: chamaId)
        .orderBy('declaredAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) =>
            Dividend.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<List<MemberDividend>> getMemberDividends(String dividendId) async {
    final snapshot =
        await _memberDividends.where('dividendId', isEqualTo: dividendId).get();

    return snapshot.docs
        .map((doc) =>
            MemberDividend.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> markAsPaid(String memberDividendId) async {
    await _memberDividends.doc(memberDividendId).update({
      'paid': true,
      'paidAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<double> calculateProjectedDividend({
    required String chamaId,
    required int periodYear,
    required int periodMonth,
  }) async {
    final members = await _getMemberShares(chamaId);
    final totalShares = members.values.fold(0.0, (sum, shares) => sum + shares);
    return totalShares;
  }
}
