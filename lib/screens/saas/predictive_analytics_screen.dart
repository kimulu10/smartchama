import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/predictive_model.dart';
import 'package:smartchama/services/predictive_analytics_service.dart';

/// Predictive analytics: forecasts for savings growth, loan defaults, cash
/// flow, membership growth and investment returns.
class PredictiveAnalyticsScreen extends StatefulWidget {
  final String organizationId;
  const PredictiveAnalyticsScreen({super.key, required this.organizationId});

  @override
  State<PredictiveAnalyticsScreen> createState() =>
      _PredictiveAnalyticsScreenState();
}

class _PredictiveAnalyticsScreenState
    extends State<PredictiveAnalyticsScreen> {
  final PredictiveAnalyticsService _service = PredictiveAnalyticsService();
  ForecastMetric _metric = ForecastMetric.savingsGrowth;
  Forecast? _forecast;
  bool _loading = true;
  bool _computing = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _computing = true;
    });
    _forecast = await _service.forecast(
        organizationId: widget.organizationId, metric: _metric);
    setState(() {
      _loading = false;
      _computing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Predictive Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<ForecastMetric>(
                  value: _metric,
                  decoration:
                      const InputDecoration(labelText: 'Forecast metric'),
                  items: ForecastMetric.values
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text(m.displayName)))
                      .toList(),
                  onChanged: (m) {
                    _metric = m!;
                    _generate();
                  },
                ),
                const SizedBox(height: 16),
                if (_forecast != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _Kpi(
                          'Projected total',
                          _forecast!.projectedTotal
                              .toStringAsFixed(0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Kpi(
                          'Trend',
                          _forecast!.trend == null
                              ? '—'
                              : '${_forecast!.trend!.toStringAsFixed(1)}%',
                          color: (_forecast!.trend ?? 0) >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 260,
                        child: _ForecastChart(forecast: _forecast!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                      'Confidence: ${(_forecast!.confidence * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _computing ? null : _generate,
        label: const Text('Refresh Forecast'),
        icon: const Icon(Icons.refresh),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Kpi(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.black)),
          ],
        ),
      ),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  final Forecast forecast;
  const _ForecastChart({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final spots = forecast.points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= forecast.points.length) {
                  return const SizedBox();
                }
                final d = forecast.points[idx].period;
                return Text(DateFormat('MMM').format(d),
                    style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF1B5E20),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF1B5E20).withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}
