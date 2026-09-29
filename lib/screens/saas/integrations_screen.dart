import 'package:flutter/material.dart';
import 'package:smartchama/models/integration_model.dart';
import 'package:smartchama/services/integration_service.dart';
import 'package:smartchama/services/payment_gateway_service.dart';

/// API & third-party integrations plus payment gateway management.
class IntegrationsScreen extends StatefulWidget {
  final String organizationId;
  final int initialTab;
  const IntegrationsScreen(
      {super.key, required this.organizationId, this.initialTab = 0});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  final IntegrationService _service = IntegrationService();
  final PaymentGatewayService _payments = PaymentGatewayService();
  List<ApiIntegration> _integrations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _integrations = await _service.getIntegrations(widget.organizationId);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Integrations'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Third-Party APIs'),
              Tab(text: 'Payment Gateways'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ApiTab(
              integrations: _integrations,
              loading: _loading,
              service: _service,
              organizationId: widget.organizationId,
              onChanged: _load,
            ),
            _PaymentTab(
              organizationId: widget.organizationId,
              payments: _payments,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiTab extends StatelessWidget {
  final List<ApiIntegration> integrations;
  final bool loading;
  final IntegrationService service;
  final String organizationId;
  final VoidCallback onChanged;

  const _ApiTab({
    required this.integrations,
    required this.loading,
    required this.service,
    required this.organizationId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: () => _addIntegration(context),
          icon: const Icon(Icons.add),
          label: const Text('Connect Integration'),
        ),
        const SizedBox(height: 12),
        if (integrations.isEmpty)
          const Center(child: Text('No integrations connected.')),
        ...integrations.map((i) => Card(
              child: ListTile(
                leading: Icon(i.type.icon),
                title: Text(i.name),
                subtitle: Text(
                    '${i.type.displayName} • ${i.lastSyncAt != null ? 'Synced' : 'Not synced'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(i.status.displayName),
                      backgroundColor: i.status == IntegrationStatus.connected
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: () async {
                        await service.sync(organizationId, i.id);
                        onChanged();
                      },
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Future<void> _addIntegration(BuildContext context) async {
    IntegrationType type = IntegrationType.accounting;
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect Integration'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<IntegrationType>(
                value: type,
                items: IntegrationType.values
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t.displayName)))
                    .toList(),
                onChanged: (t) => type = t!,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: urlCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Base URL')),
              TextField(
                  controller: keyCtrl,
                  decoration:
                      const InputDecoration(labelText: 'API Key'),
                  obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await service.connect(
                organizationId: organizationId,
                type: type,
                name: nameCtrl.text.isEmpty ? type.displayName : nameCtrl.text,
                baseUrl: urlCtrl.text,
                apiKey: keyCtrl.text,
              );
              Navigator.pop(ctx, true);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    if (result == true) onChanged();
  }
}

class _PaymentTab extends StatefulWidget {
  final String organizationId;
  final PaymentGatewayService payments;
  const _PaymentTab(
      {required this.organizationId, required this.payments});

  @override
  State<_PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<_PaymentTab> {
  List<PaymentTransaction> _tx = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _tx = await widget.payments.getTransactions(widget.organizationId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...PaymentProvider.values.map((p) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.payment),
              title: Text(p.displayName),
              subtitle: const Text('Payment provider'),
              trailing: Chip(
                label: const Text('Enabled'),
                backgroundColor: Colors.green.shade100,
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _pay(context),
          icon: const Icon(Icons.send),
          label: const Text('Test Payment'),
        ),
        const SizedBox(height: 12),
        if (_tx.isNotEmpty) ...[
          const Text('Recent payments',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ..._tx.take(10).map((t) => ListTile(
                dense: true,
                title: Text(
                    '${t.provider.displayName} • ${t.amount.toStringAsFixed(0)} ${t.currency}'),
                trailing: Chip(
                  label: Text(t.status == PaymentStatus.completed
                      ? 'Paid'
                      : 'Pending'),
                  backgroundColor: t.status == PaymentStatus.completed
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                ),
              )),
        ],
      ],
    );
  }

  Future<void> _pay(BuildContext context) async {
    PaymentProvider provider = PaymentProvider.mpesa;
    final amountCtrl = TextEditingController(text: '100');
    final phoneCtrl = TextEditingController();
    final result = await showDialog<PaymentResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<PaymentProvider>(
              value: provider,
              items: PaymentProvider.values
                  .map((p) => DropdownMenuItem(
                      value: p, child: Text(p.displayName)))
                  .toList(),
              onChanged: (p) => provider = p!,
              decoration: const InputDecoration(labelText: 'Provider'),
            ),
            TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number),
            TextField(
                controller: phoneCtrl,
                decoration:
                    const InputDecoration(labelText: 'Phone (optional)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final res = await widget.payments.processPayment(
                organizationId: widget.organizationId,
                chamaId: widget.organizationId,
                userId: 'demo',
                provider: provider,
                amount: double.tryParse(amountCtrl.text) ?? 0,
                currency: 'KES',
                phoneNumber: phoneCtrl.text,
              );
              Navigator.pop(ctx, res);
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)));
      _load();
    }
  }
}
