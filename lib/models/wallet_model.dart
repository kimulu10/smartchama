import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { deposit, withdrawal, transfer, payment }

enum WalletTransactionStatus { pending, completed, failed, reversed }

extension TransactionTypeExtension on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.payment:
        return 'Payment';
    }
  }
}

extension WalletTransactionStatusExtension on WalletTransactionStatus {
  String get displayName {
    switch (this) {
      case WalletTransactionStatus.pending:
        return 'Pending';
      case WalletTransactionStatus.completed:
        return 'Completed';
      case WalletTransactionStatus.failed:
        return 'Failed';
      case WalletTransactionStatus.reversed:
        return 'Reversed';
    }
  }
}

class Wallet {
  final String id;
  final String chamaId;
  final String userId;
  final String memberName;
  final double balance;
  final double totalDeposits;
  final double totalWithdrawals;
  final double totalTransfers;
  final String currency;
  final bool isActive;
  final DateTime? lastTransactionAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Wallet({
    required this.id,
    required this.chamaId,
    required this.userId,
    this.memberName = '',
    this.balance = 0,
    this.totalDeposits = 0,
    this.totalWithdrawals = 0,
    this.totalTransfers = 0,
    this.currency = 'KES',
    this.isActive = true,
    this.lastTransactionAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wallet.fromMap(Map<String, dynamic> map, String id) {
    return Wallet(
      id: id,
      chamaId: map['chamaId'] ?? '',
      userId: map['userId'] ?? '',
      memberName: map['memberName'] ?? '',
      balance: (map['balance'] ?? 0).toDouble(),
      totalDeposits: (map['totalDeposits'] ?? 0).toDouble(),
      totalWithdrawals: (map['totalWithdrawals'] ?? 0).toDouble(),
      totalTransfers: (map['totalTransfers'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'KES',
      isActive: map['isActive'] ?? true,
      lastTransactionAt: map['lastTransactionAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastTransactionAt'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      'userId': userId,
      'memberName': memberName,
      'balance': balance,
      'totalDeposits': totalDeposits,
      'totalWithdrawals': totalWithdrawals,
      'totalTransfers': totalTransfers,
      'currency': currency,
      'isActive': isActive,
      if (lastTransactionAt != null)
        'lastTransactionAt': lastTransactionAt!.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Wallet copyWith({
    String? id,
    String? chamaId,
    String? userId,
    String? memberName,
    double? balance,
    double? totalDeposits,
    double? totalWithdrawals,
    double? totalTransfers,
    String? currency,
    bool? isActive,
    DateTime? lastTransactionAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      chamaId: chamaId ?? this.chamaId,
      userId: userId ?? this.userId,
      memberName: memberName ?? this.memberName,
      balance: balance ?? this.balance,
      totalDeposits: totalDeposits ?? this.totalDeposits,
      totalWithdrawals: totalWithdrawals ?? this.totalWithdrawals,
      totalTransfers: totalTransfers ?? this.totalTransfers,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      lastTransactionAt: lastTransactionAt ?? this.lastTransactionAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WalletTransaction {
  final String id;
  final String walletId;
  final String chamaId;
  final String userId;
  final TransactionType type;
  final WalletTransactionStatus status;
  final double amount;
  final String? description;
  final String? referenceId;
  final String? recipientWalletId;
  final DateTime createdAt;
  final DateTime updatedAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.chamaId,
    required this.userId,
    required this.type,
    required this.status,
    required this.amount,
    this.description,
    this.referenceId,
    this.recipientWalletId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransaction(
      id: id,
      walletId: map['walletId'] ?? '',
      chamaId: map['chamaId'] ?? '',
      userId: map['userId'] ?? '',
      type: TransactionType.values[map['type'] ?? 0],
      status: WalletTransactionStatus.values[map['status'] ?? 0],
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] as String?,
      referenceId: map['referenceId'] as String?,
      recipientWalletId: map['recipientWalletId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'walletId': walletId,
      'chamaId': chamaId,
      'userId': userId,
      'type': type.index,
      'status': status.index,
      'amount': amount,
      if (description != null) 'description': description,
      if (referenceId != null) 'referenceId': referenceId,
      if (recipientWalletId != null) 'recipientWalletId': recipientWalletId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
}
