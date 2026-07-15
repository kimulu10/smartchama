import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/subscription_model.dart';
import 'package:smartchama/services/subscription_service.dart';
import 'package:smartchama/services/organization_service.dart';

/// Subscription & billing: plan selection, monthly/annual billing, automatic
/// renewal management and invoice history for the tenant.
class SubscriptionBillingScreen extends StatefulWidget {
  final String organizationId;
  const SubscriptionBillingScreen({super.key, required this.organizationId});

  @override
  State<SubscriptionBillingScreen> createState() =>
      _SubscriptionBillingScreenState();
}

class _SubscriptionBillingScreenState
    extends State<SubscriptionBillingScreen> {
  final SubscriptionService _service = SubscriptionService();
  final OrganizationService _orgService = OrganizationService();
  BillingCycle _cycle = BillingCycle.monthly;
  Subscription? _current;
  String _currentPlanId = 'free';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sub = await _service.getActiveSubscription(widget.organizationId);
    final org = await _orgService.getOrganization(widget.organizationId);
    setState(() {
      _current = sub;
      _currentPlanId = org?.planId ?? 'free';
      _loading = false;
    });
  }

  Future<void> _subscribe(SubscriptionPlan plan) async {
    setState(() => _loading = true);
    await _service.subscribe(
      organizationId: widget.organizationId,
      planId: plan.id,
      cycle: _cycle,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: const Text('Subscriptions & Billing')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions & Billing')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_current != null) _currentBanner(),
          const SizedBox(height: 12),
          SegmentedButton<BillingCycle>(
            segments: const [
              ButtonSegment(value: BillingCycle.monthly, label: Text('Monthly')),
              ButtonSegment(value: BillingCycle.annual, label: Text('Annual')),
            ],
            selected: {_cycle},
            onSelectionChanged: (s) => setState(() => _cycle = s.first),
          ),
          const SizedBox(height: 12),
          ...SubscriptionPlan.defaults.map((plan) => _planCard(plan)),
          const SizedBox(height: 16),
          const Text('Invoice History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _invoiceList(),
        ],
      ),
    );
  }

  Widget _currentBanner() {
    final plan = SubscriptionPlan.getById(_currentPlanId);
    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        leading: const Icon(Icons.verified, color: Colors.green),
        title: Text('Current plan: ${plan.name}'),
        subtitle: Text(
            'Renews in ${_current!.daysRemaining} days • ${_current!.billingCycle.displayName} • ${_current!.willRenew ? 'Auto-renew ON' : 'Auto-renew OFF'}'),
        trailing: _current!.isActive
            ? null
            : TextButton(
                onPressed: () => _subscribe(plan),
                child: const Text('Reactivate')),
      ),
    );
  }

  Widget _planCard(SubscriptionPlan plan) {
    final isCurrent = plan.id == _currentPlanId && _current?.isActive == true;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: plan.id == 'enterprise'
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.amber, width: 2),
              borderRadius: BorderRadius.circular(12))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(plan.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (isCurrent)
                  Chip(
                      label: const Text('Current'),
                      backgroundColor: Colors.green.shade100),
              ],
            ),
            const SizedBox(height: 4),
            Text(plan.description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              plan.priceMonthly == 0
                  ? 'Free'
                  : _cycle == BillingCycle.monthly
                      ? 'KSh ${NumberFormat.decimalPattern().format(plan.priceMonthly)} / mo'
                      : 'KSh ${NumberFormat.decimalPattern().format(plan.priceAnnual)} / yr',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_cycle == BillingCycle.annual && plan.annualSavings > 0)
              Text(
                  'Save KSh ${NumberFormat.decimalPattern().format(plan.annualSavings)}/yr',
                  style: const TextStyle(color: Colors.green, fontSize: 12)),
            const SizedBox(height: 8),
            ...plan.features.map((f) => Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
                  ],
                )),
            const SizedBox(height: 12),
            if (!isCurrent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _subscribe(plan),
                  child: Text(plan.priceMonthly == 0
                      ? 'Downgrade'
                      : 'Choose ${plan.name}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _invoiceList() {
    return FutureBuilder<List<Invoice>>(
      future: _service.getInvoices(widget.organizationId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final invoices = snap.data!;
        if (invoices.isEmpty) {
          return const Text('No invoices yet.');
        }
        return Column(
          children: invoices.map((inv) {
            final paid = inv.status == InvoiceStatus.paid;
            return Card(
              child: ListTile(
                leading: Icon(
                    paid ? Icons.receipt_long : Icons.pending_actions,
                    color: paid ? Colors.green : Colors.orange),
                title: Text(
                    'KSh ${NumberFormat.decimalPattern().format(inv.amount)}'),
                subtitle: Text(DateFormat('dd MMM yyyy')
                    .format(inv.issuedAt)),
                trailing: Chip(
                  label: Text(inv.status.displayName),
                  backgroundColor:
                      paid ? Colors.green.shade100 : Colors.orange.shade100,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
