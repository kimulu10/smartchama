class QRPayment {
  final String id;
  final String chamaId;
  final String organizationId;
  final String createdBy;
  final double amount;
  final String currency;
  final String purpose;
  final String qrData;
  final String status;
  final String? scannedBy;
  final DateTime? paidAt;
  final DateTime expiresAt;
  final DateTime createdAt;

  QRPayment({
    required this.id,
    required this.chamaId,
    required this.organizationId,
    required this.createdBy,
    required this.amount,
    this.currency = 'KES',
    required this.purpose,
    required this.qrData,
    this.status = 'pending',
    this.scannedBy,
    this.paidAt,
    required this.expiresAt,
    required this.createdAt,
  });

  factory QRPayment.fromMap(Map<String, dynamic> map, String id) {
    return QRPayment(
      id: id,
      chamaId: map['chamaId'] ?? '',
      organizationId: map['organizationId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'KES',
      purpose: map['purpose'] ?? '',
      qrData: map['qrData'] ?? '',
      status: map['status'] ?? 'pending',
      scannedBy: map['scannedBy'] as String?,
      paidAt: map['paidAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['paidAt'])
          : null,
      expiresAt: map['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiresAt'])
          : DateTime.now().add(const Duration(hours: 24)),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      'organizationId': organizationId,
      'createdBy': createdBy,
      'amount': amount,
      'currency': currency,
      'purpose': purpose,
      'qrData': qrData,
      'status': status,
      if (scannedBy != null) 'scannedBy': scannedBy,
      if (paidAt != null) 'paidAt': paidAt!.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

enum QRPaymentStatus { pending, scanned, paid, expired, cancelled }
