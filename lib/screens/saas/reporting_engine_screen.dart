import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/services/report_export_service.dart';
import 'package:smartchama/services/reporting_engine_service.dart';

enum ReportKind {
  income,
  balance,
  cashflow,
  loans,
  member,
  audit,
  tax,
}

extension ReportKindExtension on ReportKind {
  String get displayName {
    switch (this) {
      case ReportKind.income:
        return 'Income Statement';
      case ReportKind.balance:
        return 'Balance Sheet';
      case ReportKind.cashflow:
        return 'Cash Flow';
      case ReportKind.loans:
        return 'Loan Report';
      case ReportKind.member:
        return 'Member Statement';
      case ReportKind.audit:
        return 'Audit Report';
      case ReportKind.tax:
        return 'Tax Summary';
    }
  }
}

/// Advanced reporting engine. Generates enterprise reports and exports them
/// to PDF, Excel and CSV.
class ReportingEngineScreen extends StatefulWidget {
  final String organizationId;
  final ReportKind initialReport;
  const ReportingEngineScreen(
      {super.key,
      required this.organizationId,
      this.initialReport = ReportKind.income});

  @override
  State<ReportingEngineScreen> createState() =>
      _ReportingEngineScreenState();
}

class _ReportingEngineScreenState extends State<ReportingEngineScreen> {
  final ReportingEngineService _engine = ReportingEngineService();
  final ReportExportService _export = ReportExportService();
  ReportKind _kind = ReportKind.income;
  String? _chamaId;
  ReportTable? _report;
  bool _loading = false;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialReport;
    _resolveChama();
  }

  Future<void> _resolveChama() async {
    final snap = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('chamas')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      _chamaId = snap.docs.first.id;
    }
    _generate();
  }

  Future<void> _generate() async {
    if (_chamaId == null) {
      setState(() => _report = null);
      return;
    }
    setState(() => _loading = true);
    switch (_kind) {
      case ReportKind.income:
        _report = await _engine.buildIncomeStatement(
            organizationId: widget.organizationId,
            chamaId: _chamaId!,
            year: _year,
            month: _month);
        break;
      case ReportKind.balance:
        _report = await _engine.buildBalanceSheet(
            organizationId: widget.organizationId, chamaId: _chamaId!);
        break;
      case ReportKind.cashflow:
        _report = await _engine.buildCashFlow(
            organizationId: widget.organizationId,
            chamaId: _chamaId!,
            year: _year);
        break;
      case ReportKind.loans:
        _report = await _engine.buildLoanReport(
            organizationId: widget.organizationId, chamaId: _chamaId!);
        break;
      case ReportKind.member:
        _report = await _engine.buildMemberStatement(
            organizationId: widget.organizationId,
            chamaId: _chamaId!,
            userId: 'demo');
        break;
      case ReportKind.audit:
        _report = await _engine.buildAuditReport(
            organizationId: widget.organizationId, chamaId: _chamaId!);
        break;
      case ReportKind.tax:
        const regionRate = 0.0;
        _report = await _engine.buildTaxSummary(
            organizationId: widget.organizationId,
            chamaId: _chamaId!,
            taxRate: regionRate);
        break;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reporting Engine')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<ReportKind>(
                  value: _kind,
                  decoration:
                      const InputDecoration(labelText: 'Report type'),
                  items: ReportKind.values
                      .map((k) => DropdownMenuItem(
                          value: k, child: Text(k.displayName)))
                      .toList(),
                  onChanged: (k) {
                    _kind = k!;
                    _generate();
                  },
                ),
                const SizedBox(height: 12),
                if (_chamaId == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'No chama found in this organization yet. Create a chama to generate reports.'),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _month,
                          decoration:
                              const InputDecoration(labelText: 'Month'),
                          items: List.generate(12, (i) => i + 1)
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(DateFormat('MMMM')
                                        .format(DateTime(2020, m))),
                                  ))
                              .toList(),
                          onChanged: (m) {
                            _month = m!;
                            _generate();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _year,
                          decoration:
                              const InputDecoration(labelText: 'Year'),
                          items: [DateTime.now().year, DateTime.now().year - 1]
                              .map((y) => DropdownMenuItem(
                                    value: y,
                                    child: Text('$y'),
                                  ))
                              .toList(),
                          onChanged: (y) {
                            _year = y!;
                            _generate();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_report != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_report!.title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text(_report!.subtitle,
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: _report!.headers
                                    .map((h) => DataColumn(
                                        label: Text(h,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold))))
                                    .toList(),
                                rows: _report!.rows
                                    .map((r) => DataRow(
                                        cells: r
                                            .map((c) => DataCell(Text(c)))
                                            .toList()))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _doExport('pdf'),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _doExport('excel'),
                          icon: const Icon(Icons.table_chart),
                          label: const Text('Excel'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _doExport('csv'),
                          icon: const Icon(Icons.file_download),
                          label: const Text('CSV'),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  Future<void> _doExport(String format) async {
    if (_report == null) return;
    String? path;
    if (format == 'pdf') {
      final bytes = await _export.exportPdf(
        title: _report!.title,
        subtitle: _report!.subtitle,
        headers: _report!.headers,
        rows: _report!.rows,
      );
      path = await _export.saveToFile(
          '${_report!.title.replaceAll(' ', '_')}.pdf', bytes);
    } else if (format == 'excel') {
      final content = _export.exportExcel(
        title: _report!.title,
        headers: _report!.headers,
        rows: _report!.rows,
      );
      path = await _export.saveToFile(
          '${_report!.title.replaceAll(' ', '_')}.xls', content.codeUnits);
    } else {
      final content = _export.exportCsv(
        headers: _report!.headers,
        rows: _report!.rows,
      );
      path = await _export.saveToFile(
          '${_report!.title.replaceAll(' ', '_')}.csv', content.codeUnits);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to $path')));
    }
  }
}
