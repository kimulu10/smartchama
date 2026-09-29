import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/wallet_model.dart';
import 'package:smartchama/services/wallet_service.dart';

class WalletTransactionsScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const WalletTransactionsScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<WalletTransactionsScreen> createState() => _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  final WalletService _walletService = WalletService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _filterType = 'all';
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'KES ');

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Transactions'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filterType = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: 'deposit', child: Text('Deposits')),
              PopupMenuItem(value: 'withdrawal', child: Text('Withdrawals')),
              PopupMenuItem(value: 'transfer', child: Text('Transfers')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<WalletTransaction>>(
        future: _walletService.getTransactions(widget.chamaId, user.uid, limit: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data ?? [];
          final filtered = _filterType == 'all'
              ? transactions
              : transactions.where((t) => t.type.displayName.toLowerCase() == _filterType).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No transactions yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final tx = filtered[index];
                final isPositive = tx.type == TransactionType.deposit || tx.type == TransactionType.transfer;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getTypeColor(tx.type).withOpacity(0.1),
                      child: Icon(_getTypeIcon(tx.type), color: _getTypeColor(tx.type)),
                    ),
                    title: Text(
                      tx.type.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tx.description != null && tx.description!.isNotEmpty)
                          Text(tx.description!),
                        Text(
                          DateFormat.yMMMd().add_jm().format(tx.createdAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${isPositive ? '+' : '-'}${_currencyFormat.format(tx.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return Colors.green;
      case TransactionType.withdrawal:
        return Colors.red;
      case TransactionType.transfer:
        return Colors.blue;
      case TransactionType.payment:
        return Colors.orange;
    }
  }

  IconData _getTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.deposit:
        return Icons.arrow_downward;
      case TransactionType.withdrawal:
        return Icons.arrow_upward;
      case TransactionType.transfer:
        return Icons.swap_horiz;
      case TransactionType.payment:
        return Icons.payment;
    }
  }
}
