 import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
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
  int touchedIndex = -1;

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
          final bestPerforming = active.isEmpty
              ? null
              : active.reduce((a, b) => a.roi > b.roi ? a : b);

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(totalInvested, totalReturn, avgRoi, active.length, bestPerforming),
                const SizedBox(height: 16),
                _buildAllocationPieChart(active),
                const SizedBox(height: 16),
                _buildPerformanceChart(active),
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

  Widget _buildSummaryCard(double totalInvested, double totalReturn, double roi, int activeCount, Investment? best) {
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
            if (best != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Best: ${best.name} (${best.roi.toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildAllocationPieChart(List<Investment> investments) {
    if (investments.isEmpty) return const SizedBox.shrink();

    Map<InvestmentType, double> allocation = {};
    for (final inv in investments) {
      allocation[inv.type] = (allocation[inv.type] ?? 0) + inv.amount;
    }

    final total = allocation.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portfolio Allocation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection == null) {
                                touchedIndex = -1;
                                return;
                              }
                              touchedIndex = response.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sections: allocation.entries.toList().asMap().entries.map((entry) {
                          final index = entry.key;
                          final type = entry.value.key;
                          final amount = entry.value.value;
                          final isTouched = index == touchedIndex;
                          final color = colors[index % colors.length];
                          return PieChartSectionData(
                            value: amount,
                            title: isTouched ? '${(amount / total * 100).toStringAsFixed(0)}%' : type.displayName.substring(0, 3),
                            color: color,
                            radius: isTouched ? 70 : 60,
                            titleStyle: TextStyle(
                              fontSize: isTouched ? 14 : 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: allocation.entries.toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final type = entry.value.key;
                        final amount = entry.value.value;
                        final color = colors[index % colors.length];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                              const SizedBox(width: 8),
                              Expanded(child: Text(type.displayName, style: const TextStyle(fontSize: 12))),
                              Text('${(amount / total * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceChart(List<Investment> investments) {
    if (investments.isEmpty) return const SizedBox.shrink();

    final sorted = List<Investment>.from(investments)..sort((a, b) => a.startDate.compareTo(b.startDate));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Timeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final label = index < sorted.length ? sorted[index].name : '';
                          return LineTooltipItem(
                            '$label\nKES ${spot.y.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: sorted.map((e) => e.actualReturn).reduce((a, b) => a > b ? a : b) / 4,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sorted.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(sorted[index].name, style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) => Text(_currencyFormat.format(value), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sorted.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.actualReturn)).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.2)),
                    ),
                    LineChartBarData(
                      spots: sorted.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.expectedReturn)).toList(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      dashArray: [5, 5],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem('Actual', Colors.green),
                const SizedBox(width: 16),
                _legendItem('Expected', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
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
            if (investment.notes.isNotEmpty)
              Text('Notes: ${investment.notes.substring(0, investment.notes.length > 30 ? 30 : investment.notes.length)}...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
    final notesController = TextEditingController();
    InvestmentType selectedType = InvestmentType.treasuryBills;
    RiskLevel selectedRisk = RiskLevel.medium;

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
                onChanged: (v) => setState(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RiskLevel>(
                value: selectedRisk,
                decoration: const InputDecoration(labelText: 'Risk Level'),
                items: RiskLevel.values
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.displayName),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedRisk = v!),
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
                    labelText: 'Expected Return Rate (%)', suffixText: '%'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
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
              final expectedReturnRate = double.tryParse(returnController.text) ?? 0;
              final expectedReturn = amount * (expectedReturnRate / 100);
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
    final nameController = TextEditingController(text: investment.name);
    final notesController = TextEditingController(text: investment.notes);
    final returnController = TextEditingController(text: investment.actualReturn.toString());
    bool isEditing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEditing ? 'Edit Investment' : investment.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () {
                        setSheetState(() => isEditing = !isEditing);
                      },
                      icon: Icon(isEditing ? Icons.close : Icons.edit),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isEditing) ...[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: returnController,
                    decoration: const InputDecoration(labelText: 'Actual Return (KES)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await _investmentService.updateInvestment(
                        investmentId: investment.id,
                        name: nameController.text,
                        actualReturn: double.tryParse(returnController.text),
                        notes: notesController.text,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Investment updated')),
                        );
                      }
                    },
                    child: const Text('Save Changes'),
                  ),
                ] else ...[
                  _detailRow('Type', investment.type.displayName),
                  _detailRow('Amount', _currencyFormat.format(investment.amount)),
                  _detailRow('Expected Return', _currencyFormat.format(investment.expectedReturn)),
                  _detailRow('Actual Return', _currencyFormat.format(investment.actualReturn)),
                  _detailRow('ROI', '${investment.roi.toStringAsFixed(1)}%'),
                  _detailRow('Risk Level', investment.riskLevel.displayName),
                  _detailRow('Status', investment.status.name),
                  if (investment.notes.isNotEmpty) _detailRow('Notes', investment.notes),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
