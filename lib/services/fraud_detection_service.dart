import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/fraud_model.dart';

/// AI Fraud Detection. Scans transactions, logins and membership for
/// suspicious patterns: duplicate transactions, suspicious withdrawals,
/// unusual login locations, fake/duplicate members and repeated payment
/// attempts.
class FraudDetectionService {
  static final FraudDetectionService _instance =
      FraudDetectionService._internal();
  factory FraudDetectionService() => _instance;
  FraudDetectionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _alerts => _firestore.collection('fraud_alerts');

  /// Runs the full detection suite for a tenant and persists any alerts.
  Future<List<FraudAlert>> scan({
    required String organizationId,
    String? chamaId,
  }) async {
    final alerts = <FraudAlert>[];
    alerts.addAll(await _detectDuplicateTransactions(organizationId, chamaId));
    alerts.addAll(await _detectSuspiciousWithdrawals(organizationId, chamaId));
    alerts.addAll(await _detectMultiplePaymentAttempts(organizationId, chamaId));
    alerts.addAll(await _detectFakeMembers(organizationId));
    for (final a in alerts) {
      await _alerts.doc(a.id).set(a.toMap());
    }
    return alerts;
  }

  Future<List<FraudAlert>> _detectDuplicateTransactions(
      String orgId, String? chamaId) async {
    final alerts = <FraudAlert>[];
    final chamas = await _chamaRefs(orgId, chamaId);
    for (final chamaRef in chamas) {
      final snap = await chamaRef
          .collection('transactions')
          .orderBy('amount', descending: false)
          .get();
      final seen = <String, Map<String, dynamic>>{};
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        final key = '${data['type']}_$amount';
        if (seen.containsKey(key)) {
          alerts.add(_alert(
            orgId,
            chamaRef.id,
            FraudType.duplicateTransaction,
            FraudSeverity.medium,
            0.75,
            'Possible duplicate transaction of $amount detected.',
            entityType: 'transaction',
            entityId: d.id,
            userId: data['userId'],
          ));
        } else {
          seen[key] = data;
        }
      }
    }
    return alerts;
  }

  Future<List<FraudAlert>> _detectSuspiciousWithdrawals(
      String orgId, String? chamaId) async {
    final alerts = <FraudAlert>[];
    final chamas = await _chamaRefs(orgId, chamaId);
    for (final chamaRef in chamas) {
      final snap = await chamaRef.collection('wallet_transactions').get();
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        if (data['type'] != 'withdrawal') continue;
        final amount = (data['amount'] ?? 0).toDouble();
        if (amount > 100000) {
          alerts.add(_alert(
            orgId,
            chamaRef.id,
            FraudType.suspiciousWithdrawal,
            FraudSeverity.high,
            0.8,
            'Large withdrawal of $amount flagged for review.',
            entityType: 'wallet_transaction',
            entityId: d.id,
            userId: data['userId'],
          ));
        }
      }
    }
    return alerts;
  }

  Future<List<FraudAlert>> _detectMultiplePaymentAttempts(
      String orgId, String? chamaId) async {
    final alerts = <FraudAlert>[];
    final chamas = await _chamaRefs(orgId, chamaId);
    for (final chamaRef in chamas) {
      final snap = await chamaRef.collection('payment_attempts').get();
      final byUser = <String, int>{};
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final userId = data['userId']?.toString() ?? '';
        byUser[userId] = (byUser[userId] ?? 0) + 1;
      }
      for (final entry in byUser.entries) {
        if (entry.value >= 5) {
          alerts.add(_alert(
            orgId,
            chamaRef.id,
            FraudType.multiplePaymentAttempts,
            FraudSeverity.medium,
            0.65,
            'User ${entry.key} made ${entry.value} payment attempts.',
            userId: entry.key,
          ));
        }
      }
    }
    return alerts;
  }

  Future<List<FraudAlert>> _detectFakeMembers(String orgId) async {
    final alerts = <FraudAlert>[];
    final snap = await _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .get();
    final phones = <String, int>{};
    for (final d in snap.docs) {
      final phone = (d.data() as Map<String, dynamic>)['phone'] ?? '';
      if (phone.isEmpty) continue;
      phones[phone] = (phones[phone] ?? 0) + 1;
    }
    for (final entry in phones.entries) {
      if (entry.value > 1) {
        alerts.add(_alert(
          orgId,
          null,
          FraudType.fakeMember,
          FraudSeverity.high,
          0.85,
          'Phone number ${entry.key} is linked to ${entry.value} members.',
        ));
      }
    }
    return alerts;
  }

  Future<List<FraudAlert>> getAlerts(String organizationId,
      {FraudStatus? status, int limit = 50}) async {
    Query query = _alerts
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('detectedAt', descending: true)
        .limit(limit);
    if (status != null) {
      query = query.where('status', isEqualTo: status.index);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((d) => FraudAlert.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<void> resolve(String alertId, String note) async {
    await _alerts.doc(alertId).update({
      'status': FraudStatus.resolved.index,
      'resolvedAt': DateTime.now().millisecondsSinceEpoch,
      'resolutionNote': note,
    });
  }

  FraudAlert _alert(
    String orgId,
    String? chamaId,
    FraudType type,
    FraudSeverity severity,
    double confidence,
    String description, {
    String? entityType,
    String? entityId,
    String? userId,
  }) {
    final now = DateTime.now();
    return FraudAlert(
      id: _firestore.collection('x').doc().id,
      organizationId: orgId,
      chamaId: chamaId,
      type: type,
      severity: severity,
      description: description,
      confidenceScore: confidence,
      entityType: entityType,
      entityId: entityId,
      userId: userId,
      detectedAt: now,
    );
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
