import 'package:flutter/material.dart';
import 'package:smartchama/models/audit_log.dart';
import 'package:smartchama/services/audit_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AuditLogScreen extends StatefulWidget {
  final String chamaId;

  const AuditLogScreen({super.key, required this.chamaId});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _auditService = AuditService();
  String? _filterEntityType;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  bool _showBulkActions = false;
  final Set<String> _selectedLogIds = {};
  bool _showUserSummary = false;

  final List<String> _entityTypes = [
    'All',
    'contribution',
    'loan',
    'member',
    'meeting',
    'vote',
    'investment',
    'document',
    'settings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
            tooltip: "Search",
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) {
              setState(() {
                _filterEntityType = type == 'All' ? null : type;
              });
            },
            itemBuilder: (context) => _entityTypes
                .map((t) => PopupMenuItem(value: t, child: Text(t == 'All' ? 'All' : t.substring(0, 1).toUpperCase() + t.substring(1))))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
            tooltip: "Date Range",
          ),
          IconButton(
            icon: Icon(_showBulkActions ? Icons.done : Icons.checklist),
            onPressed: () => setState(() => _showBulkActions = !_showBulkActions),
            tooltip: "Bulk Actions",
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPdf,
            tooltip: "Export PDF",
          ),
        ],
      ),
      body: FutureBuilder<List<AuditLog>>(
        future: _auditService.getAuditLogs(
          chamaId: widget.chamaId,
          entityType: _filterEntityType,
          limit: 200,
          startDate: _startDate,
          endDate: _endDate,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var logs = snapshot.data ?? [];

          if (_searchQuery.isNotEmpty) {
            logs = logs.where((log) =>
              log.action.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              log.entityType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              log.userId.toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();
          }

          if (logs.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: Column(
              children: [
                if (_showUserSummary) _buildUserActivitySummary(logs),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isSelected = _selectedLogIds.contains(log.id);
                      return _buildLogCard(log, isSelected);
                    },
                  ),
                ),
                if (_showBulkActions)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey[100],
                    child: Row(
                      children: [
                        Text("${_selectedLogIds.length} selected"),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _selectedLogIds.isEmpty ? null : _exportSelectedToPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text("Export Selected"),
                        ),
                        TextButton.icon(
                          onPressed: _selectedLogIds.isEmpty ? null : _flagForReview,
                          icon: const Icon(Icons.flag),
                          label: const Text("Flag for Review"),
                        ),
                      ],
                    ),
                  ),
              ],
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

  Widget _buildUserActivitySummary(List<AuditLog> logs) {
    final userActivity = <String, int>{};
    final entityActivity = <String, int>{};

    for (final log in logs) {
      userActivity[log.userId] = (userActivity[log.userId] ?? 0) + 1;
      entityActivity[log.entityType] = (entityActivity[log.entityType] ?? 0) + 1;
    }

    final sortedUsers = userActivity.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sortedEntities = entityActivity.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Activity Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => setState(() => _showUserSummary = false),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("Close"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text("By User", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...sortedUsers.take(5).map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  CircleAvatar(radius: 12, backgroundColor: Colors.green.withOpacity(0.2), child: Text(entry.key.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 10))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                  Text("${entry.value} actions", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            )),
            const SizedBox(height: 12),
            const Text("By Entity", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...sortedEntities.take(5).map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 12, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                  Text("${entry.value}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(AuditLog log, bool isSelected) {
    return Card(
      margin: EdgeInsets.only(bottom: 8, right: _showBulkActions ? 0 : 16, left: _showBulkActions ? 0 : 16),
      color: isSelected ? Colors.green.withOpacity(0.1) : null,
      child: ListTile(
        leading: _showBulkActions
            ? Checkbox(value: isSelected, onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedLogIds.add(log.id);
                  } else {
                    _selectedLogIds.remove(log.id);
                  }
                });
              })
            : CircleAvatar(
                backgroundColor: _getActionColor(log.action).withOpacity(0.1),
                child: Icon(_getActionIcon(log.action), color: _getActionColor(log.action)),
              ),
        title: Text(log.action),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${log.entityType} - ${DateFormat.yMMMd().add_jm().format(log.timestamp)}'),
            if (log.previousValues != null || log.newValues != null)
              TextButton(
                onPressed: () => _showDetailView(log),
                child: const Text("View Details", style: TextStyle(fontSize: 12)),
              ),
          ],
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

  void _showDetailView(AuditLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(log.action),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Entity: ${log.entityType}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Time: ${DateFormat.yMMMd().add_jm().format(log.timestamp)}"),
              const SizedBox(height: 16),
              if (log.previousValues != null) ...[
                const Text("Previous Values", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 4),
                Text(log.previousValues.toString(), style: const TextStyle(fontSize: 12)),
              ],
              if (log.newValues != null) ...[
                const SizedBox(height: 12),
                const Text("New Values", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 4),
                Text(log.newValues.toString(), style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
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

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Search Logs"),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: "Search by action, entity, or user"),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        actions: [
          TextButton(onPressed: () {
            setState(() => _searchQuery = '');
            Navigator.pop(context);
          }, child: const Text("Clear")),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Date Range"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Start Date"),
              trailing: Text(_startDate != null ? DateFormat('MMM dd, yyyy').format(_startDate!) : 'None'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _startDate = picked);
                }
              },
            ),
            ListTile(
              title: const Text("End Date"),
              trailing: Text(_endDate != null ? DateFormat('MMM dd, yyyy').format(_endDate!) : 'None'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _endDate = picked);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () {
            setState(() {
              _startDate = null;
              _endDate = null;
            });
            Navigator.pop(context);
          }, child: const Text("Clear")),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
        ],
      ),
    );
  }

  Future<void> _exportToPdf() async {
    final logs = await _auditService.getAuditLogs(
      chamaId: widget.chamaId,
      entityType: _filterEntityType,
      limit: 100,
      startDate: _startDate,
      endDate: _endDate,
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Audit Log Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Generated: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['Time', 'Action', 'Entity', 'User'],
              data: logs.map((log) => [
                DateFormat('MMM dd, hh:mm a').format(log.timestamp),
                log.action,
                log.entityType,
                log.userId,
              ]).toList(),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/audit_log_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF exported to ${file.path}')),
      );
    }
  }

  Future<void> _exportSelectedToPdf() async {
    final logs = await _auditService.getAuditLogs(
      chamaId: widget.chamaId,
      entityType: _filterEntityType,
      limit: 200,
      startDate: _startDate,
      endDate: _endDate,
    );

    final selectedLogs = logs.where((log) => _selectedLogIds.contains(log.id)).toList();

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Selected Audit Logs', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ['Time', 'Action', 'Entity', 'User'],
              data: selectedLogs.map((log) => [
                DateFormat('MMM dd, hh:mm a').format(log.timestamp),
                log.action,
                log.entityType,
                log.userId,
              ]).toList(),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/selected_audit_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF exported to ${file.path}')),
      );
    }
  }

  void _flagForReview() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedLogIds.length} logs flagged for review')),
    );
    setState(() => _selectedLogIds.clear());
  }
}
