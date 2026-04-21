class LoanModel {
  final String id;
  final String userId;
  final String chamaId;
  final String? userName;
  final double amount;
  final double repaidAmount;
  final String status;
  final String? reason;
  final DateTime date;
  final DateTime createdAt;
  final int month;
  final int year;
  final double interestRate;

  LoanModel({
    required this.id,
    required this.userId,
    required this.chamaId,
    this.userName,
    required this.amount,
    this.repaidAmount = 0,
    this.status = 'pending',
    this.reason,
    required this.date,
    required this.createdAt,
    required this.month,
    required this.year,
    this.interestRate = 0,
  });

  factory LoanModel.fromMap(Map<String, dynamic> map, String id) {
    return LoanModel(
      id: id,
      userId: map['userId'] ?? '',
      chamaId: map['chamaId'] ?? '',
      userName: map['userName'],
      amount: (map['amount'] ?? 0).toDouble(),
      repaidAmount: (map['repaidAmount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      reason: map['reason'],
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'])
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      month: map['month'] ?? DateTime.now().month,
      year: map['year'] ?? DateTime.now().year,
      interestRate: (map['interestRate'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'chamaId': chamaId,
      'userName': userName,
      'amount': amount,
      'repaidAmount': repaidAmount,
      'status': status,
      'reason': reason,
      'date': date.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'month': month,
      'year': year,
      'interestRate': interestRate,
    };
  }

  double get outstandingAmount => amount - repaidAmount;

  double get repaymentProgress =>
      amount > 0 ? (repaidAmount / amount) * 100 : 0;

  bool get isFullyRepaid => repaidAmount >= amount;

  bool get isPending => status == 'pending';

  bool get isApproved => status == 'approved';

  bool get isRejected => status == 'rejected';

  bool get isOverdue =>
      isApproved && DateTime.now().isAfter(date.add(const Duration(days: 30)));

  LoanModel copyWith({
    String? id,
    String? userId,
    String? chamaId,
    String? userName,
    double? amount,
    double? repaidAmount,
    String? status,
    String? reason,
    DateTime? date,
    DateTime? createdAt,
    int? month,
    int? year,
    double? interestRate,
  }) {
    return LoanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      chamaId: chamaId ?? this.chamaId,
      userName: userName ?? this.userName,
      amount: amount ?? this.amount,
      repaidAmount: repaidAmount ?? this.repaidAmount,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      month: month ?? this.month,
      year: year ?? this.year,
      interestRate: interestRate ?? this.interestRate,
    );
  }
}

class LoanPaymentModel {
  final String id;
  final String loanId;
  final double amount;
  final DateTime date;
  final String method;

  LoanPaymentModel({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.date,
    required this.method,
  });

  factory LoanPaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return LoanPaymentModel(
      id: id,
      loanId: map['loanId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'])
          : DateTime.now(),
      method: map['method'] ?? 'cash',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loanId': loanId,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'method': method,
    };
  }
}