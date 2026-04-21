class Investment {
  final String id;
  final String chamaId;
  final String name;
  final String description;
  final double amount;
  final double expectedReturn;
  final double actualReturn;
  final DateTime startDate;
  final DateTime? endDate;
  final InvestmentType type;
  final InvestmentStatus status;

  Investment({
    required this.id,
    required this.chamaId,
    required this.name,
    this.description = '',
    required this.amount,
    this.expectedReturn = 0,
    this.actualReturn = 0,
    required this.startDate,
    this.endDate,
    required this.type,
    this.status = InvestmentStatus.active,
  });

  factory Investment.fromMap(Map<String, dynamic> map, String id) {
    return Investment(
      id: id,
      chamaId: map['chamaId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      expectedReturn: (map['expectedReturn'] ?? 0).toDouble(),
      actualReturn: (map['actualReturn'] ?? 0).toDouble(),
      startDate: map['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startDate'])
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'])
          : null,
      type: InvestmentType.values[map['type'] ?? 0],
      status: InvestmentStatus.values[map['status'] ?? 0],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      'name': name,
      'description': description,
      'amount': amount,
      'expectedReturn': expectedReturn,
      'actualReturn': actualReturn,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'type': type.index,
      'status': status.index,
    };
  }

  double get roi => amount > 0 ? (actualReturn / amount) * 100 : 0;
  double get projectedRoi => amount > 0 ? (expectedReturn / amount) * 100 : 0;
}

enum InvestmentType {
  treasuryBills,
  bonds,
  moneyMarket,
  fixedDeposit,
  saccoShares,
  realEstate,
  other,
}

enum InvestmentStatus {
  active,
  matured,
  liquidated,
}

extension InvestmentTypeExtension on InvestmentType {
  String get displayName {
    switch (this) {
      case InvestmentType.treasuryBills:
        return 'Treasury Bills';
      case InvestmentType.bonds:
        return 'Bonds';
      case InvestmentType.moneyMarket:
        return 'Money Market';
      case InvestmentType.fixedDeposit:
        return 'Fixed Deposit';
      case InvestmentType.saccoShares:
        return 'Sacco Shares';
      case InvestmentType.realEstate:
        return 'Real Estate';
      case InvestmentType.other:
        return 'Other';
    }
  }
}

class InvestmentSummary {
  final double totalInvested;
  final double totalExpectedReturn;
  final double totalActualReturn;
  final double averageRoi;
  final int activeInvestments;

  InvestmentSummary({
    required this.totalInvested,
    required this.totalExpectedReturn,
    required this.totalActualReturn,
    required this.averageRoi,
    required this.activeInvestments,
  });
}