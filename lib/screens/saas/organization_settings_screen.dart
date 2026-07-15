import 'package:flutter/material.dart';
import 'package:smartchama/models/organization_model.dart';
import 'package:smartchama/models/region_model.dart';
import 'package:smartchama/models/role_permission_model.dart';
import 'package:smartchama/services/organization_service.dart';

/// Organization settings: branding, white-label configuration, member
/// management, region and configurable rules.
class OrganizationSettingsScreen extends StatefulWidget {
  final String organizationId;
  final String userId;
  final int initialTab;
  const OrganizationSettingsScreen({
    super.key,
    required this.organizationId,
    required this.userId,
    this.initialTab = 0,
  });

  @override
  State<OrganizationSettingsScreen> createState() =>
      _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState
    extends State<OrganizationSettingsScreen> {
  final OrganizationService _orgService = OrganizationService();
  Organization? _org;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final org = await _orgService.getOrganization(widget.organizationId);
    setState(() => _org = org);
  }

  @override
  Widget build(BuildContext context) {
    if (_org == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Organization Settings')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return DefaultTabController(
      length: 5,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_org!.name),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'General'),
              Tab(text: 'Branding'),
              Tab(text: 'White-Label'),
              Tab(text: 'Members'),
              Tab(text: 'Rules'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GeneralTab(org: _org!, onSaved: _load),
            _BrandingTab(org: _org!, onSaved: _load),
            _WhiteLabelTab(org: _org!, onSaved: _load),
            _MembersTab(organizationId: widget.organizationId),
            _RulesTab(org: _org!, onSaved: _load),
          ],
        ),
      ),
    );
  }
}

class _GeneralTab extends StatefulWidget {
  final Organization org;
  final VoidCallback onSaved;
  const _GeneralTab({required this.org, required this.onSaved});

  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
  late TextEditingController _name;
  late TextEditingController _desc;
  late String _regionCode;
  final OrganizationService _service = OrganizationService();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.org.name);
    _desc = TextEditingController(text: widget.org.description ?? '');
    _regionCode = widget.org.regionCode;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Organization name')),
        const SizedBox(height: 12),
        TextField(
            controller: _desc,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _regionCode,
          decoration: const InputDecoration(labelText: 'Region / Country'),
          items: Region.all
              .map((r) => DropdownMenuItem(value: r.code, child: Text(r.name)))
              .toList(),
          onChanged: (v) => setState(() => _regionCode = v!),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            final updated = widget.org.copyWith(
              name: _name.text,
              description: _desc.text,
              regionCode: _regionCode,
            );
            await _service.updateOrganization(updated);
            widget.onSaved();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved')));
            }
          },
          child: const Text('Save General Settings'),
        ),
      ],
    );
  }
}

class _BrandingTab extends StatefulWidget {
  final Organization org;
  final VoidCallback onSaved;
  const _BrandingTab({required this.org, required this.onSaved});

  @override
  State<_BrandingTab> createState() => _BrandingTabState();
}

class _BrandingTabState extends State<_BrandingTab> {
  late TextEditingController _appName;
  late TextEditingController _primary;
  late TextEditingController _secondary;
  late TextEditingController _accent;
  late TextEditingController _receiptFooter;
  final OrganizationService _service = OrganizationService();

  @override
  void initState() {
    super.initState();
    final b = widget.org.branding;
    _appName = TextEditingController(text: b.appName);
    _primary = TextEditingController(text: b.primaryColorHex);
    _secondary = TextEditingController(text: b.secondaryColorHex);
    _accent = TextEditingController(text: b.accentColorHex);
    _receiptFooter = TextEditingController(text: b.receiptFooter);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.org.branding;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: b.primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.groups,
                    color: b.primaryColor, size: 28),
              ),
              const SizedBox(width: 12),
              Text(b.appName,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
            controller: _appName,
            decoration: const InputDecoration(labelText: 'App name')),
        const SizedBox(height: 12),
        _colorField('Primary color', _primary),
        _colorField('Secondary color', _secondary),
        _colorField('Accent color', _accent),
        const SizedBox(height: 12),
        TextField(
            controller: _receiptFooter,
            decoration: const InputDecoration(labelText: 'Receipt footer')),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            final branding = widget.org.branding.copyWith(
              appName: _appName.text,
              primaryColorHex: _primary.text,
              secondaryColorHex: _secondary.text,
              accentColorHex: _accent.text,
              receiptFooter: _receiptFooter.text,
            );
            await _service
                .updateBranding(widget.org.id, branding);
            widget.onSaved();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Branding saved')));
            }
          },
          child: const Text('Save Branding'),
        ),
      ],
    );
  }

  Widget _colorField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: TextField(controller: ctrl, decoration: InputDecoration(labelText: label))),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _parse(ctrl.text),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Color _parse(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'ff'), radix: 16));
    } catch (_) {
      return const Color(0xFF1B5E20);
    }
  }
}

class _WhiteLabelTab extends StatefulWidget {
  final Organization org;
  final VoidCallback onSaved;
  const _WhiteLabelTab({required this.org, required this.onSaved});

  @override
  State<_WhiteLabelTab> createState() => _WhiteLabelTabState();
}

class _WhiteLabelTabState extends State<_WhiteLabelTab> {
  late bool _enabled;
  late TextEditingController _domain;
  late TextEditingController _mobileName;
  final OrganizationService _service = OrganizationService();

  @override
  void initState() {
    super.initState();
    final w = widget.org.whiteLabel;
    _enabled = w.enabled;
    _domain = TextEditingController(text: w.customDomain ?? '');
    _mobileName = TextEditingController(text: w.mobileAppName ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Enable white-label'),
          subtitle:
              const Text('Present the platform under your own brand.'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        TextField(
            controller: _domain,
            decoration: const InputDecoration(
                labelText: 'Custom domain (e.g. app.yourco.com)')),
        const SizedBox(height: 12),
        TextField(
            controller: _mobileName,
            decoration: const InputDecoration(
                labelText: 'Mobile app name')),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            final wl = WhiteLabelConfig(
              enabled: _enabled,
              customDomain: _domain.text.isEmpty ? null : _domain.text,
              mobileAppName: _mobileName.text.isEmpty ? null : _mobileName.text,
            );
            await _service.updateWhiteLabel(widget.org.id, wl);
            widget.onSaved();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('White-label saved')));
            }
          },
          child: const Text('Save White-Label'),
        ),
      ],
    );
  }
}

class _MembersTab extends StatefulWidget {
  final String organizationId;
  const _MembersTab({required this.organizationId});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  final OrganizationService _service = OrganizationService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MemberRole>>(
      future: _service.getMembers(widget.organizationId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = snap.data!;
        if (members.isEmpty) {
          return const Center(child: Text('No members yet.'));
        }
        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (_, i) {
            final m = members[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(m.memberName ?? m.userId),
              subtitle: Text(m.role.displayName),
              trailing: DropdownButton<OrganizationRole>(
                value: m.role,
                underline: const SizedBox(),
                items: OrganizationRole.values
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text(r.displayName)))
                    .toList(),
                onChanged: (r) async {
                  await _service.updateMemberRole(
                      organizationId: widget.organizationId,
                      userId: m.userId,
                      role: r!);
                  setState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _RulesTab extends StatefulWidget {
  final Organization org;
  final VoidCallback onSaved;
  const _RulesTab({required this.org, required this.onSaved});

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  final OrganizationService _service = OrganizationService();
  late bool _twoFactor;
  late bool _memberInvites;
  late bool _fraudDetection;
  late bool _apiAccess;

  @override
  void initState() {
    super.initState();
    final s = widget.org.settings;
    _twoFactor = s.requireTwoFactor;
    _memberInvites = s.allowMemberInvites;
    _fraudDetection = s.enableFraudDetection;
    _apiAccess = s.enableApiAccess;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Require two-factor authentication'),
          value: _twoFactor,
          onChanged: (v) => setState(() => _twoFactor = v),
        ),
        SwitchListTile(
          title: const Text('Allow member invites'),
          value: _memberInvites,
          onChanged: (v) => setState(() => _memberInvites = v),
        ),
        SwitchListTile(
          title: const Text('Enable AI fraud detection'),
          value: _fraudDetection,
          onChanged: (v) => setState(() => _fraudDetection = v),
        ),
        SwitchListTile(
          title: const Text('Enable API access'),
          value: _apiAccess,
          onChanged: (v) => setState(() => _apiAccess = v),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            final settings = widget.org.settings.copyWith(
              requireTwoFactor: _twoFactor,
              allowMemberInvites: _memberInvites,
              enableFraudDetection: _fraudDetection,
              enableApiAccess: _apiAccess,
            );
            await _service.updateSettings(widget.org.id, settings);
            widget.onSaved();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rules saved')));
            }
          },
          child: const Text('Save Rules'),
        ),
      ],
    );
  }
}
