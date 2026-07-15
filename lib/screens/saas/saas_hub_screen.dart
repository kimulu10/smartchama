import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/services/organization_service.dart';

import 'super_admin_dashboard.dart';
import 'subscription_billing_screen.dart';
import 'organization_settings_screen.dart';
import 'roles_permissions_screen.dart';
import 'ai_advisor_screen.dart';
import 'fraud_detection_screen.dart';
import 'predictive_analytics_screen.dart';
import 'communication_center_screen.dart';
import 'integrations_screen.dart';
import 'regional_settings_screen.dart';
import 'reporting_engine_screen.dart';
import 'disaster_recovery_screen.dart';
import 'experience_screen.dart';

/// Phase 4 – Enterprise SaaS command center. Entry point for all 20
/// enterprise features, gated by the current user's tenant.
class SaasHubScreen extends StatefulWidget {
  const SaasHubScreen({super.key});

  @override
  State<SaasHubScreen> createState() => _SaasHubScreenState();
}

class _SaasHubScreenState extends State<SaasHubScreen> {
  String? _organizationId;
  String? _userId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    setState(() {
      _userId = user.uid;
      _organizationId = data?['organizationId'] as String?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_organizationId == null || _organizationId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Enterprise SaaS')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business_center, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No organization linked to your account.',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showCreateOrg(context),
                child: const Text('Create your organization'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise SaaS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Super Admin',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SuperAdminDashboard()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Platform & Tenancy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _grid([
            _Feature('Multi-Tenant Organizations', Icons.apartment,
                () => _open(OrganizationSettingsScreen(
                    organizationId: _organizationId!,
                    userId: _userId!))),
            _Feature('Subscriptions & Billing', Icons.payment,
                () => _open(SubscriptionBillingScreen(
                    organizationId: _organizationId!))),
            _Feature('Organization Branding', Icons.palette,
                () => _open(OrganizationSettingsScreen(
                    organizationId: _organizationId!,
                    userId: _userId!,
                    initialTab: 1))),
            _Feature('White-Label Platform', Icons.label,
                () => _open(OrganizationSettingsScreen(
                    organizationId: _organizationId!,
                    userId: _userId!,
                    initialTab: 2))),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Security, Roles & AI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _grid([
            _Feature('Role-Based Permissions', Icons.shield,
                () => _open(RolesPermissionsScreen(
                    organizationId: _organizationId!))),
            _Feature('Enterprise Audit Logs', Icons.history,
                () => _open(ReportingEngineScreen(
                    organizationId: _organizationId!,
                    initialReport: ReportKind.audit))),
            _Feature('AI Financial Advisor', Icons.psychology,
                () => _open(AiAdvisorScreen(
                    organizationId: _organizationId!))),
            _Feature('AI Fraud Detection', Icons.security,
                () => _open(FraudDetectionScreen(
                    organizationId: _organizationId!))),
            _Feature('Predictive Analytics', Icons.insights,
                () => _open(PredictiveAnalyticsScreen(
                    organizationId: _organizationId!))),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Money, Comms & Reports',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _grid([
            _Feature('Investment Management', Icons.trending_up,
                () => _open(ReportingEngineScreen(
                    organizationId: _organizationId!,
                    initialReport: ReportKind.loans))),
            _Feature('Digital Wallet', Icons.account_balance_wallet,
                () => _open(ReportingEngineScreen(
                    organizationId: _organizationId!,
                    initialReport: ReportKind.balance))),
            _Feature('Payment Gateways', Icons.credit_card,
                () => _open(IntegrationsScreen(
                    organizationId: _organizationId!,
                    initialTab: 1))),
            _Feature('API & Integrations', Icons.hub,
                () => _open(IntegrationsScreen(
                    organizationId: _organizationId!))),
            _Feature('Reporting Engine', Icons.assessment,
                () => _open(ReportingEngineScreen(
                    organizationId: _organizationId!))),
            _Feature('Communication Center', Icons.campaign,
                () => _open(CommunicationCenterScreen(
                    organizationId: _organizationId!))),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Resilience & Global',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _grid([
            _Feature('Disaster Recovery', Icons.backup,
                () => _open(DisasterRecoveryScreen(
                    organizationId: _organizationId!))),
            _Feature('Regional Expansion', Icons.public,
                () => _open(RegionalSettingsScreen(
                    organizationId: _organizationId!))),
            _Feature('Mobile & Web Experience', Icons.phone_android,
                () => _open(const ExperienceScreen())),
          ]),
        ],
      ),
    );
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _showCreateOrg(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Organization'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Organization name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (result == null || result.isEmpty || _userId == null) return;
    final org = await OrganizationService().createOrganization(
      name: result,
      ownerId: _userId!,
    );
    if (mounted) {
      setState(() => _organizationId = org.id);
    }
  }

  Widget _grid(List<_Feature> features) {
    return GridView.count(
      crossAxisCount:
          MediaQuery.of(context).size.width > 700 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: features.map((f) => _FeatureCard(f)).toList(),
    );
  }
}

class _Feature {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  _Feature(this.title, this.icon, this.onTap);
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard(this.feature);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(feature.icon, size: 36, color: const Color(0xFF1B5E20)),
              const SizedBox(height: 10),
              Text(
                feature.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
