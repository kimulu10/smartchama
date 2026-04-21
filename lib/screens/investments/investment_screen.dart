import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/investment_model.dart';
import 'package:smartchama/services/investment_service.dart';

class InvestmentScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const InvestmentScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  final _investmentService = InvestmentService();
  final _currencyFormat = NumberFormat.currency(symbol: 'KES ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment Tracking'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('investments')
            .where('chamaId', isEqualTo: widget.chamaId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final investments = snapshot.data!.docs
              .map((doc) => Investment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          if (investments.isEmpty) {
            return _buildEmptyState();
          }

          final active = investments.where((i) => i.status == InvestmentStatus.active).toList();
          final totalInvested = active.fold(0.0, (sum, i) => sum + i.amount);
          final totalReturn = active.fold(0.0, (sum, i) => sum + i.actualReturn);
          final avgRoi = active.isNotEmpty ? totalReturn / totalInvested * 100 : 0.0;

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(totalInvested, totalReturn, avgRoi, active.length),
                const SizedBox(height: 16),
                const Text('Active Investments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...investments.map((inv) => _buildInvestmentCard(inv)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddInvestmentDialog,
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No investments yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first investment',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      double totalInvested, double totalReturn, double roi, int activeCount) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Portfolio Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                      'Total Invested', _currencyFormat.format(totalInvested), Colors.blue),
                ),
                Expanded(
                  child: _buildMetric(
                      'Returns', _currencyFormat.format(totalReturn), Colors.green),
                ),
                Expanded(
                  child: _buildMetric('ROI', '${roi.toStringAsFixed(1)}%', Colors.orange),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildInvestmentCard(Investment investment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(investment.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(investment.type.displayName),
            Text('ROI: ${investment.roi.toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.green)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_currencyFormat.format(investment.amount),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Icon(
              investment.status == InvestmentStatus.active
                  ? Icons.check_circle
                  : Icons.done_all,
              color: investment.status == InvestmentStatus.active
                  ? Colors.green
                  : Colors.grey,
            ),
          ],
        ),
        onTap: () => _showInvestmentDetails(investment),
      ),
    );
  }

  void _showAddInvestmentDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final returnController = TextEditingController();
    InvestmentType selectedType = InvestmentType.treasuryBills;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Investment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Investment Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<InvestmentType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: InvestmentType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName),
                        ))
                    .toList(),
                onChanged: (v) => selectedType = v!,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                    labelText: 'Amount', prefixText: 'KES '),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: returnController,
                decoration: const InputDecoration(
                    labelText: 'Expected Return', prefixText: 'KES '),
                keyboardType: TextInputType.number,
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
              final amount = double.tryParse(amountController.text) ?? 0;
              final expectedReturn = double.tryParse(returnController.text) ?? 0;
              if (nameController.text.isNotEmpty && amount > 0) {
                await _investmentService.createInvestment(
                  chamaId: widget.chamaId,
                  name: nameController.text,
                  amount: amount,
                  expectedReturn: expectedReturn,
                  startDate: DateTime.now(),
                  type: selectedType,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showInvestmentDetails(Investment investment) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(investment.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Type: ${investment.type.displayName}'),
            Text('Amount: ${_currencyFormat.format(investment.amount)}'),
            Text('Expected Return: ${_currencyFormat.format(investment.expectedReturn)}'),
            Text('Actual Return: ${_currencyFormat.format(investment.actualReturn)}'),
            Text('ROI: ${investment.roi.toStringAsFixed(1)}%'),
            Text('Status: ${investment.status.name}'),
            const SizedBox(height: 16),
            if (investment.status == InvestmentStatus.active)
              ElevatedButton(
                onPressed: () async {
                  await _investmentService.liquidateInvestment(investment.id, investment.expectedReturn);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Liquidate'),
              ),
          ],
        ),
      ),
    );
  }
}