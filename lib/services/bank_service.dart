import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BankIntegration {
  final String id;
  final String chamaId;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String? apiKey;
  final DateTime linkedAt;
  final BankStatus status;

  BankIntegration({
    required this.id,
    required this.chamaId,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.apiKey,
    required this.linkedAt,
    this.status = BankStatus.active,
  });

  factory BankIntegration.fromMap(Map<String, dynamic> map, String id) {
    return BankIntegration(
      id: id,
      chamaId: map['chamaId'] ?? '',
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      accountName: map['accountName'] ?? '',
      apiKey: map['apiKey'],
      linkedAt: map['linkedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['linkedAt'])
          : DateTime.now(),
      status: BankStatus.values[map['status'] ?? 0],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'apiKey': apiKey,
      'linkedAt': linkedAt.millisecondsSinceEpoch,
      'status': status.index,
    };
  }
}

class BankTransaction {
  final String id;
  final String bankIntegrationId;
  final double amount;
  final String description;
  final DateTime transactionDate;
  final String reference;
  final BankTransactionType type;
  final BankTransactionStatus status;

  BankTransaction({
    required this.id,
    required this.bankIntegrationId,
    required this.amount,
    required this.description,
    required this.transactionDate,
    required this.reference,
    required this.type,
    this.status = BankTransactionStatus.pending,
  });

  factory BankTransaction.fromMap(Map<String, dynamic> map, String id) {
    return BankTransaction(
      id: id,
      bankIntegrationId: map['bankIntegrationId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      transactionDate: map['transactionDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['transactionDate'])
          : DateTime.now(),
      reference: map['reference'] ?? '',
      type: BankTransactionType.values[map['type'] ?? 0],
      status: BankTransactionStatus.values[map['status'] ?? 0],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bankIntegrationId': bankIntegrationId,
      'amount': amount,
      'description': description,
      'transactionDate': transactionDate.millisecondsSinceEpoch,
      'reference': reference,
      'type': type.index,
      'status': status.index,
    };
  }
}

enum BankStatus {
  active,
  disconnected,
  error,
}

enum BankTransactionType {
  credit,
  debit,
}

enum BankTransactionStatus {
  pending,
  matched,
  unmatched,
}

class BankService {
  static final BankService _instance = BankService._internal();
  factory BankService() => _instance;
  BankService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  CollectionReference get _bankIntegrations =>
      _firestore.collection('bankIntegrations');
  CollectionReference get _bankTransactions =>
      _firestore.collection('bankTransactions');

  Future<String> linkBankAccount({
    required String chamaId,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? apiKey,
  }) async {
    final doc = _bankIntegrations.doc();
    await doc.set(BankIntegration(
      id: doc.id,
      chamaId: chamaId,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
      apiKey: apiKey,
      linkedAt: DateTime.now(),
    ).toMap());

    return doc.id;
  }

  Future<List<BankIntegration>> getBankAccounts(String chamaId) async {
    final snapshot = await _bankIntegrations
        .where('chamaId', isEqualTo: chamaId)
        .where('status', isEqualTo: BankStatus.active.index)
        .get();

    return snapshot.docs
        .map((doc) =>
            BankIntegration.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> unlinkBankAccount(String integrationId) async {
    await _bankIntegrations.doc(integrationId).update({
      'status': BankStatus.disconnected.index,
    });
  }

  Future<void> reconcileTransactions({
    required String chamaId,
    required String bankIntegrationId,
    List<BankTransaction>? bankTransactions,
  }) async {
    bankTransactions ??= await getBankTransactions(bankIntegrationId);

    final contributions = await _firestore
        .collection('contributions')
        .where('chamaId', isEqualTo: chamaId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final bankTx in bankTransactions) {
      if (bankTx.type != BankTransactionType.credit) continue;

      for (final contribDoc in contributions.docs) {
        final contribData = contribDoc.data();
        final contribAmount = (contribData['amount'] ?? 0).toDouble();
        const tolerance = 1.0;

        if ((bankTx.amount - contribAmount).abs() <= tolerance) {
          await _firestore
              .collection('contributions')
              .doc(contribDoc.id)
              .update({
            'status': 'matched',
            'bankReference': bankTx.reference,
            'matchedAt': DateTime.now().millisecondsSinceEpoch,
          });

          await _bankTransactions.doc(bankTx.id).update({
            'status': BankTransactionStatus.matched.index,
          });
        }
      }
    }
  }

  Future<List<BankTransaction>> getBankTransactions(
      String integrationId) async {
    final snapshot = await _bankTransactions
        .where('bankIntegrationId', isEqualTo: integrationId)
        .orderBy('transactionDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) =>
            BankTransaction.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> fetchBankTransactions({
    required String integrationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // This would typically call your backend API which interfaces with bank APIs
    // For demo purposes, we'll log the attempt
    final start =
        startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();
  }

  Future<double> getBankBalance(String integrationId) async {
    final transactions = await getBankTransactions(integrationId);
    double balance = 0;

    for (final tx in transactions) {
      if (tx.type == BankTransactionType.credit) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
    }

    return balance;
  }
}
