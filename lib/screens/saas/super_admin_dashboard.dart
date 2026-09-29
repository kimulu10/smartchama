import 'package:flutter/material.dart';
import 'package:smartchama/services/super_admin_service.dart';
import 'package:intl/intl.dart';

/// Platform owner dashboard with cross-tenant metrics and controls.
class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final SuperAdminService _service = SuperAdminService();
  late Future<PlatformMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _service.getPlatformMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Super Admin')),
      body: FutureBuilder<PlatformMetrics>(
        future: _metricsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final m = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: m.systemStatus == SystemStatus.operational
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: ListTile(
                  leading: Icon(
                    m.systemStatus == SystemStatus.operational
                        ? Icons.check_circle
                        : Icons.warning,
                    color: m.systemStatus == SystemStatus.operational
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: const Text('System Status'),
                  subtitle: Text(m.systemStatus.displayName),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount:
                    MediaQuery.of(context).size.width > 700 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _StatCard('Organizations', '${m.totalOrganizations}',
                      Icons.apartment, Colors.green),
                  _StatCard('Members', '${m.totalMembers}', Icons.people,
                      Colors.blue),
                  _StatCard('Revenue',
                      'KSh ${NumberFormat.decimalPattern().format(m.totalRevenue)}',
                      Icons.money, Colors.teal),
                  _StatCard('Active Subs', '${m.activeSubscriptions}',
                      Icons.verified, Colors.purple),
                  _StatCard('Open Support', '${m.openSupportRequests}',
                      Icons.support_agent, Colors.orange),
                  _StatCard(
                      'Generated',
                      DateFormat('HH:mm').format(m.generatedAt),
                      Icons.schedule,
                      Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Recent Organizations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _service.getOrganizationsSummary(),
                builder: (context, orgSnap) {
                  if (!orgSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final orgs = orgSnap.data!;
                  if (orgs.isEmpty) {
                    return const Text('No organizations yet.');
                  }
                  return Column(
                    children: orgs.take(10).map((org) {
                      final status = org['status'] ?? 0;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.business),
                          title: Text(org['name'] ?? 'Unnamed'),
                          subtitle: Text(
                              'Plan: ${org['planId'] ?? 'free'} • Members: ${org['memberCount'] ?? 0}'),
                          trailing: Chip(
                            label: Text(status == 2 ? 'Suspended' : 'Active'),
                            backgroundColor: status == 2
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
