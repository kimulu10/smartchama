import 'package:flutter/material.dart';
import 'package:smartchama/models/dividend_model.dart';
import 'package:smartchama/services/dividend_service.dart';
import 'package:intl/intl.dart';

class DividendScreen extends StatefulWidget {
  final String chamaId;

  const DividendScreen({super.key, required this.chamaId});

  @override
  State<DividendScreen> createState() => _DividendScreenState();
}

class _DividendScreenState extends State<DividendScreen> {
  final _dividendService = DividendService();
  final _currencyFormat = NumberFormat.currency(symbol: 'KES ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dividends'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Dividend>>(
        future: _dividendService.getDividends(widget.chamaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final dividends = snapshot.data ?? [];

          if (dividends.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dividends.length,
              itemBuilder: (context, index) =>
                  _buildDividendCard(dividends[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDeclareDividendDialog,
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
          Icon(Icons.payments_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No dividends declared',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Calculate and declare dividends for members',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDividendCard(Dividend dividend) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showDividendDetails(dividend),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${_getMonthName(dividend.periodMonth)} ${dividend.periodYear}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text(dividend.status.name.toUpperCase()),
                    backgroundColor: _getStatusColor(dividend.status)
                        .withOpacity(0.1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                        'Total Amount',
                        _currencyFormat.format(dividend.totalAmount),
                        Colors.green),
                  ),
                  Expanded(
                    child: _buildMetric(
                        'Per Share',
                        _currencyFormat.format(dividend.dividendPerShare),
                        Colors.blue),
                  ),
                ],
              ),
              if (dividend.paidAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Paid: ${DateFormat.yMMMd().format(dividend.paidAt!)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Color _getStatusColor(DividendStatus status) {
    switch (status) {
      case DividendStatus.distributed:
        return Colors.green;
      case DividendStatus.distributing:
        return Colors.blue;
      case DividendStatus.declared:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showDeclareDividendDialog() {
    final amountController = TextEditingController();
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Declare Dividend'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedMonth,
                decoration: const InputDecoration(labelText: 'Month'),
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(_getMonthName(m)),
                        ))
                    .toList(),
                onChanged: (v) => selectedMonth = v!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedYear,
                decoration: const InputDecoration(labelText: 'Year'),
                items: List.generate(5, (i) => DateTime.now().year - i)
                    .map((y) => DropdownMenuItem(
                          value: y,
                          child: Text(y.toString()),
                        ))
                    .toList(),
                onChanged: (v) => selectedYear = v!,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Total Dividend Amount',
                  prefixText: 'KES ',
                ),
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
              if (amount > 0) {
                await _dividendService.declareDividend(
                  chamaId: widget.chamaId,
                  periodYear: selectedYear,
                  periodMonth: selectedMonth,
                  totalAmount: amount,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Declare'),
          ),
        ],
      ),
    );
  }

  void _showDividendDetails(Dividend dividend) async {
    final memberDividends =
        await _dividendService.getMemberDividends(dividend.id);
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
              child: Text(
                'Dividend Distribution',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: memberDividends.length,
                itemBuilder: (context, index) {
                  final md = memberDividends[index];
                  return ListTile(
                    title: Text('Member ${md.memberId.substring(0, 8)}'),
                    subtitle: Text('Shares: ${md.shares.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_currencyFormat.format(md.amount)),
                        if (!md.paid)
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () async {
                              await _dividendService.markAsPaid(md.id);
                              setState(() {});
                            },
                          )
                        else
                          const Icon(Icons.check_circle,
                              color: Colors.green),
                      ],
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