import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/report_model.dart';

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _reports => _firestore.collection('reports');

  Future<FinancialReport> generateMonthlySummary({
    required String chamaId,
    required String organizationId,
    required int year,
    required int month,
    required String generatedBy,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    final contributionsSnapshot = await _firestore
        .collection("organizations")
        .doc(organizationId)
        .collection("chamas")
        .doc(chamaId)
        .collection("contributions")
        .where("month", isEqualTo: month)
        .where("year", isEqualTo: year)
        .get();

    final loansSnapshot = await _firestore
        .collection("organizations")
        .doc(organizationId)
        .collection("chamas")
        .doc(chamaId)
        .collection("loans")
        .where("month", isEqualTo: month)
        .where("year", isEqualTo: year)
        .get();

    final transactionsSnapshot = await _firestore
        .collection("organizations")
        .doc(organizationId)
        .collection("chamas")
        .doc(chamaId)
        .collection("transactions")
        .get();

    double totalContributions = 0;
    double totalLoans = 0;
    int contributionCount = contributionsSnapshot.docs.length;
    int loanCount = loansSnapshot.docs.length;

    for (var doc in contributionsSnapshot.docs) {
      totalContributions += (doc["amount"] ?? 0).toDouble();
    }

    for (var doc in loansSnapshot.docs) {
      totalLoans += (doc["amount"] ?? 0).toDouble();
    }

    final data = {
      'totalContributions': totalContributions,
      'totalLoans': totalLoans,
      'contributionCount': contributionCount,
      'loanCount': loanCount,
      'netBalance': totalContributions - totalLoans,
      'contributions': contributionsSnapshot.docs.map((doc) => doc.data()).toList(),
      'loans': loansSnapshot.docs.map((doc) => doc.data()).toList(),
      'transactions': transactionsSnapshot.docs.map((doc) => doc.data()).toList(),
    };

    final doc = _reports.doc();
    final report = FinancialReport(
      id: doc.id,
      chamaId: chamaId,
      organizationId: organizationId,
      generatedBy: generatedBy,
      reportType: 'monthly_summary',
      title: 'Monthly Summary - ${_monthName(month)} $year',
      description: 'Financial summary for ${_monthName(month)} $year',
      periodStart: startDate,
      periodEnd: endDate,
      data: data,
      generatedAt: DateTime.now(),
    );

    await doc.set(report.toMap());
    return report;
  }

  Future<FinancialReport> generateAnnualSummary({
    required String chamaId,
    required String organizationId,
    required int year,
    required String generatedBy,
  }) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31, 23, 59, 59);

    final contributionsSnapshot = await _firestore
        .collection("organizations")
        .doc(organizationId)
        .collection("chamas")
        .doc(chamaId)
        .collection("contributions")
        .where("year", isEqualTo: year)
        .get();

    final loansSnapshot = await _firestore
        .collection("organizations")
        .doc(organizationId)
        .collection("chamas")
        .doc(chamaId)
        .collection("loans")
        .where("year", isEqualTo: year)
        .get();

    double totalContributions = 0;
    double totalLoans = 0;

    for (var doc in contributionsSnapshot.docs) {
      totalContributions += (doc["amount"] ?? 0).toDouble();
    }

    for (var doc in loansSnapshot.docs) {
      totalLoans += (doc["amount"] ?? 0).toDouble();
    }

    final data = {
      'totalContributions': totalContributions,
      'totalLoans': totalLoans,
      'netBalance': totalContributions - totalLoans,
      'contributions': contributionsSnapshot.docs.map((doc) => doc.data()).toList(),
      'loans': loansSnapshot.docs.map((doc) => doc.data()).toList(),
    };

    final doc = _reports.doc();
    final report = FinancialReport(
      id: doc.id,
      chamaId: chamaId,
      organizationId: organizationId,
      generatedBy: generatedBy,
      reportType: 'annual_summary',
      title: 'Annual Summary $year',
      description: 'Financial summary for year $year',
      periodStart: startDate,
      periodEnd: endDate,
      data: data,
      generatedAt: DateTime.now(),
    );

    await doc.set(report.toMap());
    return report;
  }

  Future<FinancialReport> generateLoanReport({
    required String chamaId,
    required String organizationId,
    required String generatedBy,
  }) async {
    final loansSnapshot = await _firestore
        .collection("organizations")
        .doc(organizationId)
        .collection("chamas")
        .doc(chamaId)
        .collection("loans")
        .get();

    final loans = loansSnapshot.docs.map((doc) => doc.data()).toList();
    double totalLoans = 0;
    double totalRepaid = 0;
    int pendingCount = 0;
    int approvedCount = 0;
    int rejectedCount = 0;

    for (var loan in loans) {
      final amount = (loan['amount'] ?? 0).toDouble();
      final repaid = (loan['repaidAmount'] ?? 0).toDouble();
      final status = loan['status'] ?? 'pending';

      totalLoans += amount;
      totalRepaid += repaid;

      if (status == 'pending') pendingCount++;
      else if (status == 'approved') approvedCount++;
      else if (status == 'rejected') rejectedCount++;
    }

    final data = {
      'totalLoans': totalLoans,
      'totalRepaid': totalRepaid,
      'outstanding': totalLoans - totalRepaid,
      'pendingCount': pendingCount,
      'approvedCount': approvedCount,
      'rejectedCount': rejectedCount,
      'loans': loans,
    };

    final doc = _reports.doc();
    final report = FinancialReport(
      id: doc.id,
      chamaId: chamaId,
      organizationId: organizationId,
      generatedBy: generatedBy,
      reportType: 'loan_report',
      title: 'Loan Analysis Report',
      description: 'Comprehensive loan analysis',
      periodStart: DateTime.now().subtract(const Duration(days: 365)),
      periodEnd: DateTime.now(),
      data: data,
      generatedAt: DateTime.now(),
    );

    await doc.set(report.toMap());
    return report;
  }

  Future<FinancialReport> generateContributionReport({
    required String chamaId,
    required String organizationId,
    required String generatedBy,
  }) async {
    final contributionsSnapshot = await _firestore
        .collection("organizations")
        .doc(organizationId)
        .collection("chamas")
        .doc(chamaId)
        .collection("contributions")
        .get();

    final contributions = contributionsSnapshot.docs.map((doc) => doc.data()).toList();
    double totalContributions = 0;
    Map<String, double> monthlyTotals = {};

    for (var c in contributions) {
      final amount = (c['amount'] ?? 0).toDouble();
      totalContributions += amount;

      final month = c['month'] ?? 0;
      final year = c['year'] ?? 0;
      final key = '$year-$month';
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + amount;
    }

    final data = {
      'totalContributions': totalContributions,
      'contributionCount': contributions.length,
      'averageContribution': contributions.isNotEmpty ? totalContributions / contributions.length : 0,
      'monthlyTotals': monthlyTotals,
      'contributions': contributions,
    };

    final doc = _reports.doc();
    final report = FinancialReport(
      id: doc.id,
      chamaId: chamaId,
      organizationId: organizationId,
      generatedBy: generatedBy,
      reportType: 'contribution_report',
      title: 'Contribution Analysis Report',
      description: 'Detailed contribution analysis',
      periodStart: DateTime.now().subtract(const Duration(days: 365)),
      periodEnd: DateTime.now(),
      data: data,
      generatedAt: DateTime.now(),
    );

    await doc.set(report.toMap());
    return report;
  }

  Future<List<FinancialReport>> getReportHistory(String chamaId, {int limit = 20}) async {
    final snapshot = await _reports
        .where('chamaId', isEqualTo: chamaId)
        .orderBy('generatedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => FinancialReport.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  List<ReportTemplate> getDefaultTemplates() {
    return [
      ReportTemplate(
        id: 'monthly',
        name: 'Monthly Summary',
        reportType: 'monthly_summary',
        description: 'Monthly financial overview with contributions, loans, and transactions',
        isDefault: true,
        sections: ['Summary', 'Contributions', 'Loans', 'Transactions'],
      ),
      ReportTemplate(
        id: 'annual',
        name: 'Annual Summary',
        reportType: 'annual_summary',
        description: 'Yearly financial performance analysis',
        isDefault: true,
        sections: ['Summary', 'Yearly Trends', 'Top Contributors', 'Loan Analysis'],
      ),
      ReportTemplate(
        id: 'loan',
        name: 'Loan Report',
        reportType: 'loan_report',
        description: 'Detailed loan portfolio analysis',
        isDefault: true,
        sections: ['Loan Summary', 'Outstanding Loans', 'Repayment History', 'Risk Analysis'],
      ),
      ReportTemplate(
        id: 'contribution',
        name: 'Contribution Report',
        reportType: 'contribution_report',
        description: 'Contribution patterns and member activity',
        isDefault: true,
        sections: ['Summary', 'Monthly Trends', 'Top Contributors', 'Growth Metrics'],
      ),
    ];
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
