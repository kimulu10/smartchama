import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const AnalyticsScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  int selectedYear = DateTime.now().year;
  String chamaName = "Analytics";
  String _dateFilter = 'year';
  DateTime? customStart;
  DateTime? customEnd;
  bool _comparisonMode = false;
  int? compareYear;
  DateTime? compareStart;
  DateTime? compareEnd;
  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadChamaName();
  }

  Future<void> _loadChamaName() async {
    final chamaDoc = await FirebaseFirestore.instance
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();
    if (chamaDoc.exists && mounted) {
      setState(() {
        chamaName = chamaDoc.data()?["name"] ?? "Analytics";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$chamaName - Analytics'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            onSelected: (value) {
              setState(() {
                _dateFilter = value;
                if (value != 'custom') {
                  customStart = null;
                  customEnd = null;
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'month', child: Text("This Month")),
              const PopupMenuItem(value: 'quarter', child: Text("This Quarter")),
              const PopupMenuItem(value: 'year', child: Text("This Year")),
              const PopupMenuItem(value: 'custom', child: Text("Custom Range")),
            ],
          ),
          IconButton(
            icon: Icon(_comparisonMode ? Icons.compare : Icons.compare_arrows),
            onPressed: () => setState(() => _comparisonMode = !_comparisonMode),
            tooltip: "Comparison Mode",
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportChart,
            tooltip: "Export",
          ),
        ],
      ),
      body: _buildAnalytics(),
    );
  }

  Widget _buildAnalytics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("transactions")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data!.docs;

        final now = DateTime.now();
        DateTime filterStart;
        DateTime filterEnd = now;

        if (_dateFilter == 'month') {
          filterStart = DateTime(now.year, now.month, 1);
        } else if (_dateFilter == 'quarter') {
          final quarter = ((now.month - 1) ~/ 3) + 1;
          filterStart = DateTime(now.year, (quarter - 1) * 3 + 1, 1);
        } else if (_dateFilter == 'custom' && customStart != null && customEnd != null) {
          filterStart = customStart!;
          filterEnd = customEnd!;
        } else {
          filterStart = DateTime(now.year, 1, 1);
        }

        final filtered = transactions.where((doc) {
          final timestamp = (doc["timestamp"] as Timestamp?)?.toDate();
          if (timestamp == null) return false;
          return timestamp.isAfter(filterStart.subtract(const Duration(days: 1))) && timestamp.isBefore(filterEnd.add(const Duration(days: 1)));
        }).toList();

        final compareTransactions = _comparisonMode ? transactions.where((doc) {
          final timestamp = (doc["timestamp"] as Timestamp?)?.toDate();
          if (timestamp == null) return false;
          DateTime cStart, cEnd;
          if (_dateFilter == 'month') {
            final prev = DateTime(now.year, now.month - 1, 1);
            cStart = prev;
            cEnd = DateTime(now.year, now.month, 1);
          } else if (_dateFilter == 'quarter') {
            final quarter = ((now.month - 1) ~/ 3);
            if (quarter == 0) {
              cStart = DateTime(now.year - 1, 10, 1);
              cEnd = DateTime(now.year, 1, 1);
            } else {
              cStart = DateTime(now.year, (quarter - 1) * 3 + 1, 1);
              cEnd = DateTime(now.year, quarter * 3 + 1, 1);
            }
          } else {
            cStart = DateTime(now.year - 1, 1, 1);
            cEnd = DateTime(now.year, 1, 1);
          }
          return timestamp.isAfter(cStart.subtract(const Duration(days: 1))) && timestamp.isBefore(cEnd.add(const Duration(days: 1)));
        }).toList() : [];

        double totalContributions = 0;
        double totalLoans = 0;
        double totalRepayments = 0;
        int pendingCount = 0;
        int successCount = 0;
        int failedCount = 0;
        Map<String, double> memberContributions = {};
        Map<String, double> monthlyData = {};

        for (var doc in filtered) {
          final type = doc["type"] ?? "";
          final status = (doc["status"] ?? "").toString();
          final amount = (doc["amount"] ?? 0).toDouble();
          final timestamp = (doc["timestamp"] as Timestamp?)?.toDate();
          final month = timestamp != null ? DateFormat('MMM').format(timestamp) : 'Unknown';
          final memberId = doc["memberId"] ?? doc["userId"] ?? 'Unknown';
          final memberName = doc["memberName"] ?? memberId;

          if (timestamp != null && timestamp.year == selectedYear || _dateFilter != 'year') {
            if (type == "contribution") {
              totalContributions += amount;
              monthlyData[month] = (monthlyData[month] ?? 0) + amount;
              memberContributions[memberName] = (memberContributions[memberName] ?? 0) + amount;
            }
            if (type == "loan_request" && status == "approved") {
              totalLoans += amount;
            }
            if (type == "loan_repayment" && (status == "completed" || status == "success")) {
              totalRepayments += amount;
            }

            if (status == "pending") pendingCount++;
            if (status == "success" || status == "approved") successCount++;
            if (status == "failed" || status == "rejected") failedCount++;
          }
        }

        final compareContributions = _comparisonMode ? compareTransactions.fold<double>(0.0, (sum, doc) {
          if (doc["type"] == "contribution") return sum + (doc["amount"] ?? 0).toDouble();
          return sum;
        }) : 0.0;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_comparisonMode) _buildComparisonCard(filtered.length, compareContributions),
                _buildSummaryCards(
                  totalContributions,
                  totalLoans,
                  totalRepayments,
                  pendingCount,
                  successCount,
                  failedCount,
                ),
                const SizedBox(height: 24),
                _buildHealthScoreCard(totalContributions, totalLoans, totalRepayments, pendingCount, failedCount),
                const SizedBox(height: 24),
                _buildRiskIndicators(totalLoans, totalRepayments, failedCount),
                const SizedBox(height: 24),
                RepaintBoundary(
                  key: _chartKey,
                  child: _buildMonthlyBarChart(monthlyData),
                ),
                const SizedBox(height: 24),
                _buildMemberRanking(memberContributions),
                const SizedBox(height: 24),
                _buildTransactionStats(
                  pendingCount,
                  successCount,
                  failedCount,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparisonCard(int currentCount, double compareContributions) {
    return Card(
      elevation: 4,
      color: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.compare, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Comparison Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Comparing with previous period", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Text("Prev: KES ${_formatNumber(compareContributions)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(double contributions, double loans, double repayments, int pending, int success, int failed) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Contributions',
                'KES ${_formatNumber(contributions)}',
                Icons.arrow_downward,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Total Loans',
                'KES ${_formatNumber(loans)}',
                Icons.money,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Repayments',
                'KES ${_formatNumber(repayments)}',
                Icons.check_circle,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Net Balance',
                'KES ${_formatNumber(contributions + repayments - loans)}',
                Icons.account_balance_wallet,
                const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScoreCard(double contributions, double loans, double repayments, int pending, int failed) {
    final total = contributions + loans + repayments;
    final healthScore = total > 0 ? ((repayments / (loans > 0 ? loans : 1) * 100).clamp(0, 100)).toInt() : 50;
    final scoreColor = healthScore >= 80 ? Colors.green : healthScore >= 50 ? Colors.orange : Colors.red;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Health Score',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 0,
                                centerSpaceRadius: 50,
                                sections: [
                                  PieChartSectionData(
                                    value: healthScore.toDouble(),
                                    color: scoreColor,
                                    radius: 50,
                                  ),
                                  PieChartSectionData(
                                    value: (100 - healthScore).toDouble(),
                                    color: Colors.grey[300]!,
                                    radius: 50,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text('$healthScore', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: scoreColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _healthMetric('Contributions', contributions, Colors.green),
                      _healthMetric('Loans', loans, Colors.orange),
                      _healthMetric('Repayments', repayments, Colors.blue),
                      _healthMetric('Pending', pending.toDouble(), Colors.purple),
                      _healthMetric('Failed', failed.toDouble(), Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthMetric(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(_formatNumber(value), style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRiskIndicators(double totalLoans, double totalRepayments, int failedCount) {
    final defaultRate = totalLoans > 0 ? (failedCount / totalLoans * 100).clamp(0, 100) : 0.0;
    final riskColor = defaultRate > 20 ? Colors.red : defaultRate > 10 ? Colors.orange : Colors.green;
    final riskLevel = defaultRate > 20 ? 'High' : defaultRate > 10 ? 'Medium' : 'Low';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loan Default Risk',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.warning, color: riskColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Risk Level: $riskLevel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: riskColor)),
                      const SizedBox(height: 4),
                      Text('Default Rate: ${defaultRate.toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(riskLevel, style: TextStyle(color: riskColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: defaultRate / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(riskColor),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(double contributions, double loans, double repayments) {
    final total = contributions + loans + repayments;
    if (total == 0) {
      return _buildEmptyChart('No transaction data available');
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: contributions,
                      title: 'Contrib',
                      color: Colors.green,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: loans,
                      title: 'Loans',
                      color: Colors.orange,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: repayments,
                      title: 'Repay',
                      color: Colors.blue,
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Contributions', Colors.green),
                _buildLegendItem('Loans', Colors.orange),
                _buildLegendItem('Repayments', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMonthlyBarChart(Map<String, double> monthlyData) {
    if (monthlyData.isEmpty) {
      return _buildEmptyChart('No monthly data available');
    }

    final sortedMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final maxValue = monthlyData.values.isEmpty
        ? 100.0
        : monthlyData.values.reduce((a, b) => a > b ? a : b) * 1.2;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Contributions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          'KES ${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < sortedMonths.length) {
                            return Text(
                              sortedMonths[value.toInt()],
                              style: const TextStyle(fontSize: 10),
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
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatNumber(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxValue / 4,
                  ),
                  barGroups: sortedMonths.asMap().entries.map((entry) {
                    final month = entry.value;
                    final amount = monthlyData[month] ?? 0;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: amount,
                          color: const Color(0xFF2E7D32),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionStats(int pending, int success, int failed) {
    final total = pending + success + failed;
    final successRate = total > 0 ? (success / total * 100) : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusItem('Pending', pending, Colors.orange),
                _buildStatusItem('Success', success, Colors.green),
                _buildStatusItem('Failed', failed, Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Success Rate: ${successRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: successRate / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2E7D32),
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.circle, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChart(String message) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRanking(Map<String, double> memberContributions) {
    final sorted = memberContributions.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    if (top.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Contributors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...top.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value.key;
              final amount = entry.value.value;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: index == 0 ? Colors.amber : index == 1 ? Colors.grey : index == 2 ? Colors.brown : Colors.green,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(member, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text('KES ${_formatNumber(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _exportChart() async {
    try {
      final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chart not ready')));
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/chart_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chart exported to ${file.path}')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}
