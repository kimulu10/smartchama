import 'package:flutter/material.dart';
import 'package:smartchama/models/fraud_model.dart';
import 'package:smartchama/services/fraud_detection_service.dart';

/// AI Fraud Detection dashboard. Scans for duplicate transactions, suspicious
/// withdrawals, unusual logins, fake members and repeated payment attempts.
class FraudDetectionScreen extends StatefulWidget {
  final String organizationId;
  const FraudDetectionScreen({super.key, required this.organizationId});

  @override
  State<FraudDetectionScreen> createState() => _FraudDetectionScreenState();
}

class _FraudDetectionScreenState extends State<FraudDetectionScreen> {
  final FraudDetectionService _service = FraudDetectionService();
  List<FraudAlert> _alerts = [];
  bool _loading = true;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _alerts = await _service.getAlerts(widget.organizationId);
    setState(() => _loading = false);
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    await _service.scan(organizationId: widget.organizationId);
    await _load();
    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final open = _alerts.where((a) => a.status == FraudStatus.open).length;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Fraud Detection')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _scan,
        label: _scanning ? const Text('Scanning...') : const Text('Run Scan'),
        icon: const Icon(Icons.security),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: open > 0 ? Colors.red.shade50 : Colors.green.shade50,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(open > 0 ? Icons.warning : Icons.verified,
                          color: open > 0 ? Colors.red : Colors.green),
                      const SizedBox(width: 12),
                      Text(
                        open > 0
                            ? '$open open fraud alert(s) detected'
                            : 'No active fraud alerts',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _alerts.isEmpty
                      ? const Center(
                          child: Text('No alerts. Run a scan to analyze.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _alerts.length,
                          itemBuilder: (_, i) => _AlertCard(
                            _alerts[i],
                            onResolve: () async {
                              await _service.resolve(
                                  _alerts[i].id, 'Resolved by admin.');
                              _load();
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final FraudAlert alert;
  final VoidCallback onResolve;
  const _AlertCard(this.alert, {required this.onResolve});

  Color get _color {
    switch (alert.severity) {
      case FraudSeverity.low:
        return Colors.blue;
      case FraudSeverity.medium:
        return Colors.orange;
      case FraudSeverity.high:
        return Colors.deepOrange;
      case FraudSeverity.critical:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _color.withOpacity(0.15),
          child: Icon(Icons.security, color: _color),
        ),
        title: Text(alert.type.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(alert.description),
        ),
        trailing: alert.status == FraudStatus.open
            ? TextButton(onPressed: onResolve, child: const Text('Resolve'))
            : Chip(
                label: Text(alert.status.displayName),
                backgroundColor: Colors.green.shade100),
      ),
    );
  }
}
