import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/wallet_model.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _wallets => _firestore.collection('wallets');
  CollectionReference get _walletTransactions =>
      _firestore.collection('wallet_transactions');

  Future<String> createWallet({
    required String chamaId,
    required String userId,
    String memberName = '',
  }) async {
    final doc = _wallets.doc();
    final now = DateTime.now();
    await doc.set(Wallet(
      id: doc.id,
      chamaId: chamaId,
      userId: userId,
      memberName: memberName,
      createdAt: now,
      updatedAt: now,
    ).toMap());
    return doc.id;
  }

  Future<Wallet?> getWallet(String chamaId, String userId) async {
    final snapshot = await _wallets
        .where('chamaId', isEqualTo: chamaId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Wallet.fromMap(snapshot.docs.first.data() as Map<String, dynamic>, snapshot.docs.first.id);
  }

  Future<String> getOrCreateWallet(String chamaId, String userId, {String memberName = ''}) async {
    final existing = await getWallet(chamaId, userId);
    if (existing != null) return existing.id;
    return createWallet(chamaId: chamaId, userId: userId, memberName: memberName);
  }

  Future<double> getWalletBalance(String chamaId, String userId) async {
    final wallet = await getWallet(chamaId, userId);
    return wallet?.balance ?? 0;
  }

  Future<void> deposit(String chamaId, String userId, double amount, {String? description}) async {
    if (amount <= 0) return;

    final walletId = await getOrCreateWallet(chamaId, userId);
    final wallet = await _wallets.doc(walletId).get();
    if (!wallet.exists) return;

    final data = wallet.data() as Map<String, dynamic>;
    final currentBalance = (data['balance'] ?? 0).toDouble();
    final currentDeposits = (data['totalDeposits'] ?? 0).toDouble();
    final now = DateTime.now();

    await _wallets.doc(walletId).update({
      'balance': currentBalance + amount,
      'totalDeposits': currentDeposits + amount,
      'lastTransactionAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    final txDoc = _walletTransactions.doc();
    await txDoc.set(WalletTransaction(
      id: txDoc.id,
      walletId: walletId,
      chamaId: chamaId,
      userId: userId,
      type: TransactionType.deposit,
      status: WalletTransactionStatus.completed,
      amount: amount,
      description: description,
      createdAt: now,
      updatedAt: now,
    ).toMap());
  }

  Future<void> withdraw(String chamaId, String userId, double amount, {String? description}) async {
    if (amount <= 0) return;

    final wallet = await getWallet(chamaId, userId);
    if (wallet == null || wallet.balance < amount) {
      throw Exception('Insufficient wallet balance');
    }

    final walletId = wallet.id;
    final currentWithdrawals = wallet.totalWithdrawals;
    final now = DateTime.now();

    await _wallets.doc(walletId).update({
      'balance': wallet.balance - amount,
      'totalWithdrawals': currentWithdrawals + amount,
      'lastTransactionAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    final txDoc = _walletTransactions.doc();
    await txDoc.set(WalletTransaction(
      id: txDoc.id,
      walletId: walletId,
      chamaId: chamaId,
      userId: userId,
      type: TransactionType.withdrawal,
      status: WalletTransactionStatus.completed,
      amount: amount,
      description: description,
      createdAt: now,
      updatedAt: now,
    ).toMap());
  }

  Future<void> transfer({
    required String fromChamaId,
    required String fromUserId,
    required String toChamaId,
    required String toUserId,
    required double amount,
  }) async {
    if (amount <= 0) return;

    final fromWallet = await getWallet(fromChamaId, fromUserId);
    if (fromWallet == null || fromWallet.balance < amount) {
      throw Exception('Insufficient wallet balance for transfer');
    }

    final toWalletId = await getOrCreateWallet(toChamaId, toUserId);
    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final fromRef = _wallets.doc(fromWallet.id);
      final toRef = _wallets.doc(toWalletId);

      final fromSnap = await transaction.get(fromRef);
      final toSnap = await transaction.get(toRef);

      final fromData = fromSnap.data() as Map<String, dynamic>;
      final toData = toSnap.data() as Map<String, dynamic>;

      final fromBalance = (fromData['balance'] ?? 0).toDouble();
      final toBalance = (toData['balance'] ?? 0).toDouble();
      final fromTransfers = (fromData['totalTransfers'] ?? 0).toDouble();
      final toTransfers = (toData['totalTransfers'] ?? 0).toDouble();

      transaction.update(fromRef, {
        'balance': fromBalance - amount,
        'totalTransfers': fromTransfers + amount,
        'lastTransactionAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      transaction.update(toRef, {
        'balance': toBalance + amount,
        'totalTransfers': toTransfers + amount,
        'lastTransactionAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      final txDoc = _walletTransactions.doc();
      transaction.set(txDoc, WalletTransaction(
        id: txDoc.id,
        walletId: fromWallet.id,
        chamaId: fromChamaId,
        userId: fromUserId,
        type: TransactionType.transfer,
        status: WalletTransactionStatus.completed,
        amount: amount,
        recipientWalletId: toWalletId,
        createdAt: now,
        updatedAt: now,
      ).toMap());
    });
  }

  Future<List<WalletTransaction>> getTransactions(String chamaId, String userId, {int limit = 50}) async {
    final wallet = await getWallet(chamaId, userId);
    if (wallet == null) return [];

    final snapshot = await _walletTransactions
        .where('walletId', isEqualTo: wallet.id)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => WalletTransaction.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}
