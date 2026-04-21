class Dividend {
  final String id;
  final String chamaId;
  final int periodYear;
  final int periodMonth;
  final double totalAmount;
  final double totalShares;
  final DateTime declaredAt;
  final DateTime? paidAt;
  final DividendStatus status;

  Dividend({
    required this.id,
    required this.chamaId,
    required this.periodYear,
    required this.periodMonth,
    required this.totalAmount,
    required this.totalShares,
    required this.declaredAt,
    this.paidAt,
    this.status = DividendStatus.declared,
  });

  factory Dividend.fromMap(Map<String, dynamic> map, String id) {
    return Dividend(
      id: id,
      chamaId: map['chamaId'] ?? '',
      periodYear: map['periodYear'] ?? 0,
      periodMonth: map['periodMonth'] ?? 0,
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      totalShares: (map['totalShares'] ?? 0).toDouble(),
      declaredAt: map['declaredAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['declaredAt'])
          : DateTime.now(),
      paidAt: map['paidAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['paidAt'])
          : null,
      status: DividendStatus.values[map['status'] ?? 0],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      'periodYear': periodYear,
      'periodMonth': periodMonth,
      'totalAmount': totalAmount,
      'totalShares': totalShares,
      'declaredAt': declaredAt.millisecondsSinceEpoch,
      'paidAt': paidAt?.millisecondsSinceEpoch,
      'status': status.index,
    };
  }

  double get dividendPerShare => totalShares > 0 ? totalAmount / totalShares : 0;
}

class MemberDividend {
  final String id;
  final String dividendId;
  final String memberId;
  final double shares;
  final double amount;
  final bool paid;
  final DateTime? paidAt;

  MemberDividend({
    required this.id,
    required this.dividendId,
    required this.memberId,
    required this.shares,
    required this.amount,
    this.paid = false,
    this.paidAt,
  });

  factory MemberDividend.fromMap(Map<String, dynamic> map, String id) {
    return MemberDividend(
      id: id,
      dividendId: map['dividendId'] ?? '',
      memberId: map['memberId'] ?? '',
      shares: (map['shares'] ?? 0).toDouble(),
      amount: (map['amount'] ?? 0).toDouble(),
      paid: map['paid'] ?? false,
      paidAt: map['paidAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['paidAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dividendId': dividendId,
      'memberId': memberId,
      'shares': shares,
      'amount': amount,
      'paid': paid,
      'paidAt': paidAt?.millisecondsSinceEpoch,
    };
  }
}

enum DividendStatus {
  declared,
  approved,
  distributing,
  distributed,
  cancelled,
}