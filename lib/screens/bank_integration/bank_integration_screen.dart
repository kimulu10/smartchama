import 'package:flutter/material.dart';
import 'package:smartchama/services/bank_service.dart';
import 'package:intl/intl.dart';

class BankIntegrationScreen extends StatefulWidget {
  final String chamaId;

  const BankIntegrationScreen({super.key, required this.chamaId});

  @override
  State<BankIntegrationScreen> createState() => _BankIntegrationScreenState();
}

class _BankIntegrationScreenState extends State<BankIntegrationScreen> {
  final _bankService = BankService();
  final _currencyFormat = NumberFormat.currency(symbol: 'KES ');
  List<BankIntegration> _accounts = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Integration'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<BankIntegration>>(
        future: _bankService.getBankAccounts(widget.chamaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          _accounts = snapshot.data ?? [];

          if (_accounts.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _accounts.length,
              itemBuilder: (context, index) =>
                  _buildAccountCard(_accounts[index]),
            ),
          );
        },
      ),
      floatingActionButton: _accounts.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _showLinkAccountDialog,
              backgroundColor: const Color(0xFF2E7D32),
              icon: const Icon(Icons.add),
              label: const Text('Link Account'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No bank account linked',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Link your bank account for automatic reconciliation',
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showLinkAccountDialog,
            icon: const Icon(Icons.add),
            label: const Text('Link Account'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BankIntegration account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Text(account.bankName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Chip(
                  label: Text(account.status.name),
                  backgroundColor: account.status == BankStatus.active
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Account: ${account.accountNumber}'),
            Text('Name: ${account.accountName}'),
            const SizedBox(height: 8),
            Text('Linked: ${DateFormat.yMMMd().format(account.linkedAt)}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reconcileTransactions(account.id),
                    icon: const Icon(Icons.sync),
                    label: const Text('Reconcile'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewTransactions(account.id),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Transactions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkAccountDialog() {
    final bankController = TextEditingController();
    final accountNumberController = TextEditingController();
    final accountNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Bank Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankController,
                decoration: const InputDecoration(labelText: 'Bank Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNumberController,
                decoration: const InputDecoration(labelText: 'Account Number'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (bankController.text.isNotEmpty &&
                  accountNumberController.text.isNotEmpty) {
                await _bankService.linkBankAccount(
                  chamaId: widget.chamaId,
                  bankName: bankController.text,
                  accountNumber: accountNumberController.text,
                  accountName: accountNameController.text,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Link'),
          ),
        ],
      ),
    );
  }

  void _reconcileTransactions(String integrationId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Reconciling transactions...'),
          ],
        ),
      ),
    );

    await _bankService.reconcileTransactions(
      chamaId: widget.chamaId,
      bankIntegrationId: integrationId,
    );

    if (mounted) Navigator.pop(context);
  }

  void _viewTransactions(String integrationId) async {
    final transactions = await _bankService.getBankTransactions(integrationId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bank Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return ListTile(
                    title: Text(tx.description),
                    subtitle: Text(DateFormat.yMMMd().format(tx.transactionDate)),
                    trailing: Text(
                      _currencyFormat.format(tx.amount),
                      style: TextStyle(
                        color: tx.type == BankTransactionType.credit
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}