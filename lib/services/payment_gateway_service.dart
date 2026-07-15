import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified payment gateway abstraction supporting M-Pesa, Airtel Money,
/// bank transfers, card payments and international providers. The base
/// implementation records payments locally; gateway-specific backends
/// (e.g. Daraja for M-Pesa) plug in via [processPayment].
class PaymentGatewayService {
  static final PaymentGatewayService _instance =
      PaymentGatewayService._internal();
  factory PaymentGatewayService() => _instance;
  PaymentGatewayService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _payments =>
      _firestore.collection('payment_transactions');

  Future<PaymentResult> processPayment({
    required String organizationId,
    required String chamaId,
    required String userId,
    required PaymentProvider provider,
    required double amount,
    required String currency,
    String? phoneNumber,
    String? reference,
  }) async {
    final now = DateTime.now();
    final doc = _payments.doc();
    final tx = PaymentTransaction(
      id: doc.id,
      organizationId: organizationId,
      chamaId: chamaId,
      userId: userId,
      provider: provider,
      amount: amount,
      currency: currency,
      status: PaymentStatus.pending,
      phoneNumber: phoneNumber,
      reference: reference ?? doc.id,
      createdAt: now,
    );
    await doc.set(tx.toMap());

    // Gateway-specific hooks would go here. For now we simulate success and
    // mark the transaction completed, mirroring the existing M-Pesa flow.
    final ok = await _dispatchToProvider(tx);
    await _payments.doc(doc.id).update({
      'status': ok ? PaymentStatus.completed.index : PaymentStatus.failed.index,
      'processedAt': DateTime.now().millisecondsSinceEpoch,
    });

    return PaymentResult(
      success: ok,
      transactionId: doc.id,
      message: ok ? 'Payment processed via ${provider.displayName}' : 'Payment failed',
    );
  }

  Future<bool> _dispatchToProvider(PaymentTransaction tx) async {
    switch (tx.provider) {
      case PaymentProvider.mpesa:
      case PaymentProvider.airtelMoney:
      case PaymentProvider.bankTransfer:
      case PaymentProvider.card:
      case PaymentProvider.international:
        // Integrate with the relevant provider SDK/backend here.
        return true;
    }
  }

  Future<List<PaymentTransaction>> getTransactions(String organizationId,
      {int limit = 50}) async {
    final snapshot = await _payments
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((d) =>
            PaymentTransaction.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }
}

enum PaymentProvider {
  mpesa,
  airtelMoney,
  bankTransfer,
  card,
  international,
}

extension PaymentProviderExtension on PaymentProvider {
  String get displayName {
    switch (this) {
      case PaymentProvider.mpesa:
        return 'M-Pesa';
      case PaymentProvider.airtelMoney:
        return 'Airtel Money';
      case PaymentProvider.bankTransfer:
        return 'Bank Transfer';
      case PaymentProvider.card:
        return 'Card Payment';
      case PaymentProvider.international:
        return 'International';
    }
  }
}

enum PaymentStatus { pending, completed, failed, refunded }

class PaymentTransaction {
  final String id;
  final String organizationId;
  final String chamaId;
  final String userId;
  final PaymentProvider provider;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String? phoneNumber;
  final String reference;
  final DateTime createdAt;
  final DateTime? processedAt;

  PaymentTransaction({
    required this.id,
    required this.organizationId,
    required this.chamaId,
    required this.userId,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.status,
    this.phoneNumber,
    required this.reference,
    required this.createdAt,
    this.processedAt,
  });

  factory PaymentTransaction.fromMap(Map<String, dynamic> map, String id) {
    return PaymentTransaction(
      id: id,
      organizationId: map['organizationId'] ?? '',
      chamaId: map['chamaId'] ?? '',
      userId: map['userId'] ?? '',
      provider: PaymentProvider.values[map['provider'] ?? 0],
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'KES',
      status: PaymentStatus.values[map['status'] ?? 0],
      phoneNumber: map['phoneNumber'],
      reference: map['reference'] ?? id,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      processedAt: map['processedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['processedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'chamaId': chamaId,
      'userId': userId,
      'provider': provider.index,
      'amount': amount,
      'currency': currency,
      'status': status.index,
      'phoneNumber': phoneNumber,
      'reference': reference,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'processedAt': processedAt?.millisecondsSinceEpoch,
    };
  }
}

class PaymentResult {
  final bool success;
  final String transactionId;
  final String message;

  PaymentResult({
    required this.success,
    required this.transactionId,
    required this.message,
  });
}
