import 'package:flutter/material.dart';
import 'package:smartchama/models/audit_log.dart';
import 'package:smartchama/services/audit_service.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatefulWidget {
  final String chamaId;

  const AuditLogScreen({super.key, required this.chamaId});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _auditService = AuditService();
  String? _filterEntityType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) => setState(() => _filterEntityType = type),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All')),
              const PopupMenuItem(value: 'contribution', child: Text('Contributions')),
              const PopupMenuItem(value: 'loan', child: Text('Loans')),
              const PopupMenuItem(value: 'member', child: Text('Members')),
              const PopupMenuItem(value: 'meeting', child: Text('Meetings')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<AuditLog>>(
        future: _auditService.getAuditLogs(
          chamaId: widget.chamaId,
          entityType: _filterEntityType,
          limit: 100,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) => _buildLogCard(logs[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(AuditLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getActionColor(log.action).withOpacity(0.1),
          child: Icon(_getActionIcon(log.action), color: _getActionColor(log.action)),
        ),
        title: Text(log.action),
        subtitle: Text(
          '${log.entityType} - ${DateFormat.yMMMd().add_jm().format(log.timestamp)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[300],
          child: Text(
            log.userId.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('Created') || action.contains('Approved')) {
      return Colors.green;
    }
    if (action.contains('Deleted') || action.contains('Rejected')) {
      return Colors.red;
    }
    if (action.contains('Updated')) {
      return Colors.blue;
    }
    return Colors.orange;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('Contribution')) return Icons.arrow_downward;
    if (action.contains('Loan')) return Icons.money;
    if (action.contains('Member')) return Icons.person;
    if (action.contains('Meeting')) return Icons.event;
    if (action.contains('Vote')) return Icons.how_to_vote;
    if (action.contains('login')) return Icons.login;
    return Icons.history;
  }
}