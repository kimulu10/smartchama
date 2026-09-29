import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/qr_payment_model.dart';

class QRPaymentService {
  static final QRPaymentService _instance = QRPaymentService._internal();
  factory QRPaymentService() => _instance;
  QRPaymentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _qrPayments => _firestore.collection('qr_payments');

  Future<String> createQRPayment({
    required String chamaId,
    required String organizationId,
    required String createdBy,
    required double amount,
    required String purpose,
    Duration expiryDuration = const Duration(hours: 24),
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(expiryDuration);

    final payload = {
      'chamaId': chamaId,
      'organizationId': organizationId,
      'createdBy': createdBy,
      'amount': amount,
      'purpose': purpose,
      'timestamp': now.millisecondsSinceEpoch,
      'signature': _generateSignature(chamaId, amount, now),
    };

    final qrData = jsonEncode(payload);
    final doc = _qrPayments.doc();

    await doc.set(QRPayment(
      id: doc.id,
      chamaId: chamaId,
      organizationId: organizationId,
      createdBy: createdBy,
      amount: amount,
      purpose: purpose,
      qrData: qrData,
      expiresAt: expiresAt,
      createdAt: now,
    ).toMap());

    return doc.id;
  }

  Future<void> scanQRPayment(String qrData, String scannedByUserId) async {
    try {
      final payload = jsonDecode(qrData) as Map<String, dynamic>;
      final chamaId = payload['chamaId'] as String?;
      final amount = (payload['amount'] ?? 0).toDouble();

      if (chamaId == null) return;

      final snapshot = await _qrPayments
          .where('chamaId', isEqualTo: chamaId)
          .where('amount', isEqualTo: amount)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in snapshot.docs) {
        final payment = QRPayment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (payment.isExpired) {
          await doc.reference.update({'status': 'expired'});
          continue;
        }

        await doc.reference.update({
          'status': 'scanned',
          'scannedBy': scannedByUserId,
        });
        break;
      }
    } catch (e) {
      print('Error scanning QR: $e');
    }
  }

  Future<void> completeQRPayment(String qrId) async {
    await _qrPayments.doc(qrId).update({
      'status': 'paid',
      'paidAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<QRPayment>> getActiveQRPayments(String chamaId) async {
    final snapshot = await _qrPayments
        .where('chamaId', isEqualTo: chamaId)
        .where('status', isEqualTo: 'pending')
        .get();

    final payments = snapshot.docs
        .map((doc) => QRPayment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    for (var payment in payments) {
      if (payment.isExpired) {
        await _qrPayments.doc(payment.id).update({'status': 'expired'});
      }
    }

    return payments.where((p) => !p.isExpired).toList();
  }

  Future<List<QRPayment>> getQRPaymentHistory(String chamaId) async {
    final snapshot = await _qrPayments
        .where('chamaId', isEqualTo: chamaId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => QRPayment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> cancelQRPayment(String qrId) async {
    await _qrPayments.doc(qrId).update({'status': 'cancelled'});
  }

  String _generateSignature(String chamaId, double amount, DateTime timestamp) {
    final input = '$chamaId:$amount:${timestamp.millisecondsSinceEpoch}';
    return input.hashCode.toString();
  }
}
