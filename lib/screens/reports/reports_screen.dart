import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/report_model.dart';
import 'package:smartchama/services/report_service.dart';
import 'report_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const ReportsScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportService _reportService = ReportService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<FinancialReport> _reports = [];
  bool _isLoading = true;
  String _selectedReportType = 'monthly_summary';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reports = await _reportService.getReportHistory(widget.chamaId);
    if (mounted) {
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateReport(String reportType) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      FinancialReport report;

      switch (reportType) {
        case 'monthly_summary':
          report = await _reportService.generateMonthlySummary(
            chamaId: widget.chamaId,
            organizationId: widget.organizationId,
            year: now.year,
            month: now.month,
            generatedBy: user.uid,
          );
          break;
        case 'annual_summary':
          report = await _reportService.generateAnnualSummary(
            chamaId: widget.chamaId,
            organizationId: widget.organizationId,
            year: now.year,
            generatedBy: user.uid,
          );
          break;
        case 'loan_report':
          report = await _reportService.generateLoanReport(
            chamaId: widget.chamaId,
            organizationId: widget.organizationId,
            generatedBy: user.uid,
          );
          break;
        case 'contribution_report':
          report = await _reportService.generateContributionReport(
            chamaId: widget.chamaId,
            organizationId: widget.organizationId,
            generatedBy: user.uid,
          );
          break;
        default:
          throw Exception('Unknown report type');
      }

      setState(() {
        _reports.insert(0, report);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${report.title} generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final templates = _reportService.getDefaultTemplates();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Generate Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: templates.map((template) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(template.name),
                        onPressed: () {
                          setState(() => _selectedReportType = template.reportType);
                        },
                        backgroundColor: _selectedReportType == template.reportType
                            ? const Color(0xFF2E7D32)
                            : Colors.grey[200],
                        labelStyle: TextStyle(
                          color: _selectedReportType == template.reportType
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _generateReport(_selectedReportType),
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_isLoading ? 'Generating...' : 'Generate Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Report History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_reports.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No reports generated yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                )
              else
                ..._reports.map((report) => _buildReportCard(report)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(FinancialReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
          child: const Icon(Icons.picture_as_pdf, color: Color(0xFF2E7D32)),
        ),
        title: Text(
          report.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.description),
            const SizedBox(height: 4),
            Text(
              'Generated: ${DateFormat.yMMMd().add_jm().format(report.generatedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailScreen(report: report),
              ),
            );
          },
        ),
      ),
    );
  }
}
