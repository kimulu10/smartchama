import 'package:flutter/material.dart';
import 'package:smartchama/models/organization_model.dart';
import 'package:smartchama/models/region_model.dart';
import 'package:smartchama/services/organization_service.dart';
import 'package:smartchama/services/region_service.dart';

/// Regional expansion: multiple currencies, languages, country-specific
/// payment methods, local tax/compliance and configurable org rules.
class RegionalSettingsScreen extends StatefulWidget {
  final String organizationId;
  const RegionalSettingsScreen({super.key, required this.organizationId});

  @override
  State<RegionalSettingsScreen> createState() =>
      _RegionalSettingsScreenState();
}

class _RegionalSettingsScreenState extends State<RegionalSettingsScreen> {
  final OrganizationService _orgService = OrganizationService();
  final RegionService _regionService = RegionService();
  Organization? _org;
  Region? _region;
  Map<String, dynamic> _rules = {};
  List<String> _issues = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final org = await _orgService.getOrganization(widget.organizationId);
    setState(() {
      _org = org;
      _region = _regionService.getRegion(org?.regionCode ?? 'KE');
      _rules = Map<String, dynamic>.from(org?.settings.rules ?? {});
      _issues = [];
    });
  }

  void _validate() {
    setState(() {
      _issues = _regionService.validate(_region!, _rules);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_org == null || _region == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Regional Settings')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Regional Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _region!.code,
            decoration: const InputDecoration(labelText: 'Country / Region'),
            items: Region.all
                .map((r) => DropdownMenuItem(value: r.code, child: Text(r.name)))
                .toList(),
            onChanged: (code) async {
              await _orgService.updateOrganization(
                  _org!.copyWith(regionCode: code));
              _load();
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Locale',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _infoRow('Currency',
                      '${_region!.currencyCode} (${_region!.currencySymbol})'),
                  _infoRow('Default language', _region!.defaultLanguage),
                  _infoRow('Languages',
                      _region!.supportedLanguages.join(', ')),
                  _infoRow('Tax rate', '${(_region!.defaultTaxRate * 100).toStringAsFixed(1)}%'),
                  _infoRow('Payment methods',
                      _region!.paymentMethods.join(', ')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Organization Rules',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: (_rules['language'] as String?) ??
                        _region!.defaultLanguage,
                    decoration:
                        const InputDecoration(labelText: 'Preferred language'),
                    items: _region!.supportedLanguages
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) {
                      _rules['language'] = v;
                      _validate();
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: (_rules['paymentMethod'] as String?) ??
                        _region!.paymentMethods.first,
                    decoration:
                        const InputDecoration(labelText: 'Default payment method'),
                    items: _region!.paymentMethods
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      _rules['paymentMethod'] = v;
                      _validate();
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final settings =
                          _org!.settings.copyWith(rules: _rules);
                      await _orgService.updateSettings(_org!.id, settings);
                      _validate();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Rules saved')));
                      }
                    },
                    child: const Text('Save Rules'),
                  ),
                ],
              ),
            ),
          ),
          if (_issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._issues.map((i) => ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: Text(i),
                )),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
