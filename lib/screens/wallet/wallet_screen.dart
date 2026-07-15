import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/wallet_model.dart';
import 'package:smartchama/services/wallet_service.dart';
import 'wallet_transactions_screen.dart';

class WalletScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const WalletScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'KES ');

  Wallet? _wallet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final wallet = await _walletService.getWallet(widget.chamaId, user.uid);
    if (mounted) {
      setState(() {
        _wallet = wallet;
        _isLoading = false;
      });
    }
  }

  Future<void> _showDepositDialog() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deposit Funds'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (KES)',
                  prefixText: 'KES ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                final user = _auth.currentUser;
                if (user != null) {
                  await _walletService.deposit(
                    widget.chamaId,
                    user.uid,
                    amount,
                    description: descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : null,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deposit successful'), backgroundColor: Colors.green),
                    );
                    _loadWallet();
                  }
                }
              }
            },
            child: const Text('Deposit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWithdrawDialog() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Funds'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (KES)',
                  prefixText: 'KES ',
                  border: const OutlineInputBorder(),
                  helperText: 'Available: ${_currencyFormat.format(_wallet?.balance ?? 0)}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                final user = _auth.currentUser;
                if (user != null) {
                  try {
                    await _walletService.withdraw(
                      widget.chamaId,
                      user.uid,
                      amount,
                      description: descriptionController.text.isNotEmpty
                          ? descriptionController.text
                          : null,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Withdrawal successful'), backgroundColor: Colors.green),
                      );
                      _loadWallet();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              }
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTransferDialog() async {
    final amountController = TextEditingController();
    String? selectedChamaId;
    String? selectedUserId;
    List<Map<String, dynamic>> chamas = [];
    List<Map<String, dynamic>> members = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Transfer Funds'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (KES)',
                    prefixText: 'KES ',
                    border: const OutlineInputBorder(),
                    helperText: 'Available: ${_currencyFormat.format(_wallet?.balance ?? 0)}',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'To Chama', border: OutlineInputBorder()),
                  hint: const Text('Select Chama'),
                  value: selectedChamaId,
                  items: const [],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedChamaId = value;
                      selectedUserId = null;
                      members = [];
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'To Member', border: OutlineInputBorder()),
                  hint: const Text('Select Member'),
                  value: selectedUserId,
                  items: members.map((m) {
                    return DropdownMenuItem(value: m['id'] as String?, child: Text(m['name'] ?? m['email']));
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedUserId = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0 && selectedChamaId != null && selectedUserId != null) {
                  final user = _auth.currentUser;
                  if (user != null) {
                    try {
                      await _walletService.transfer(
                        fromChamaId: widget.chamaId,
                        fromUserId: user.uid,
                        toChamaId: selectedChamaId!,
                        toUserId: selectedUserId!,
                        amount: amount,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transfer successful'), backgroundColor: Colors.green),
                        );
                        _loadWallet();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                }
              },
              child: const Text('Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_wallet == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Digital Wallet'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('No wallet found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final user = _auth.currentUser;
                  if (user != null) {
                    await _walletService.getOrCreateWallet(widget.chamaId, user.uid);
                    _loadWallet();
                  }
                },
                child: const Text('Create Wallet'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Wallet'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WalletTransactionsScreen(
                  chamaId: widget.chamaId,
                  organizationId: widget.organizationId,
                ),
              ),
            );
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWallet,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 20),
              _buildActionButtons(),
              const SizedBox(height: 20),
              const Text(
                'Wallet Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildSummaryRow('Total Deposits', _wallet!.totalDeposits, Colors.green),
              _buildSummaryRow('Total Withdrawals', _wallet!.totalWithdrawals, Colors.red),
              _buildSummaryRow('Total Transfers', _wallet!.totalTransfers, Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              _currencyFormat.format(_wallet!.balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Currency: ${_wallet!.currency}',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showDepositDialog,
            icon: const Icon(Icons.add_circle, size: 20),
            label: const Text('Deposit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showWithdrawDialog,
            icon: const Icon(Icons.remove_circle, size: 20),
            label: const Text('Withdraw'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showTransferDialog,
            icon: const Icon(Icons.swap_horiz, size: 20),
            label: const Text('Transfer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        trailing: Text(
          _currencyFormat.format(value),
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
        ),
      ),
    );
  }
}
