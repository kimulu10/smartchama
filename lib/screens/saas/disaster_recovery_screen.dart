import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/services/disaster_recovery_service.dart';

/// Disaster recovery & enterprise security: automatic backups, encryption
/// status, two-factor authentication, secure restore and monitoring.
class DisasterRecoveryScreen extends StatefulWidget {
  final String organizationId;
  const DisasterRecoveryScreen({super.key, required this.organizationId});

  @override
  State<DisasterRecoveryScreen> createState() =>
      _DisasterRecoveryScreenState();
}

class _DisasterRecoveryScreenState extends State<DisasterRecoveryScreen> {
  final DisasterRecoveryService _service = DisasterRecoveryService();
  List<BackupManifest> _backups = [];
  SecuritySummary? _summary;
  bool _loading = true;
  bool _twoFactor = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _backups = await _service.getBackups(widget.organizationId);
    _summary =
        await _service.getSecuritySummary(widget.organizationId);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _summary == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Disaster Recovery & Security')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Disaster Recovery & Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _summary!.encryptionEnabled
                ? Colors.green.shade50
                : Colors.orange.shade50,
            child: ListTile(
              leading: Icon(
                  _summary!.encryptionEnabled
                      ? Icons.lock
                      : Icons.lock_open,
                  color: _summary!.encryptionEnabled
                      ? Colors.green
                      : Colors.orange),
              title: const Text('Data Encryption'),
              subtitle: Text(_summary!.encryptionEnabled
                  ? 'All tenant data is encrypted at rest'
                  : 'Encryption not active'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_heart),
              title: const Text('Security Monitoring'),
              subtitle: Text(
                  '${_summary!.openSecurityEvents} open security event(s)'),
              trailing: Chip(
                label: Text('${_summary!.backupsCount} backups'),
                backgroundColor: Colors.grey.shade100,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Two-Factor Authentication'),
            subtitle: const Text('Require 2FA for privileged actions'),
            value: _twoFactor,
            onChanged: (v) async {
              setState(() => _twoFactor = v);
              await _service.enrollTwoFactor('current-user');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(v ? '2FA enabled' : '2FA disabled')));
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _service.createBackup(widget.organizationId);
                    _load();
                  },
                  icon: const Icon(Icons.backup),
                  label: const Text('Create Backup'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Backup History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_backups.isEmpty)
            const Text('No backups yet.')
          else
            ..._backups.map((b) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.archive),
                    title: Text(
                        'Backup ${DateFormat('dd MMM yyyy HH:mm').format(b.createdAt)}'),
                    subtitle: Text(b.encrypted
                        ? 'Encrypted • ${b.sizeMb} MB'
                        : 'Not encrypted'),
                    trailing: TextButton(
                      onPressed: () async {
                        await _service
                            .restore(widget.organizationId, b.id);
                        _load();
                      },
                      child: const Text('Restore'),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
