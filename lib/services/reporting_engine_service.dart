import 'package:cloud_firestore/cloud_firestore.dart';

/// Advanced reporting engine. Builds enterprise reports from tenant chama
/// data: income statements, balance sheets, cash flow, member statements,
/// audit reports, tax summaries and loan reports.
class ReportingEngineService {
  static final ReportingEngineService _instance =
      ReportingEngineService._internal();
  factory ReportingEngineService() => _instance;
  ReportingEngineService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ReportTable> buildIncomeStatement({
    required String organizationId,
    required String chamaId,
    required int year,
    required int month,
  }) async {
    final contributions = await _sum(
        organizationId, chamaId, 'contributions', year, month);
    final loansRepaid = await _sum(organizationId, chamaId, 'loans', year, month,
        field: 'repaidAmount');
    final interest = contributions * 0.05;
    final expenses = loansRepaid * 0.0;

    return ReportTable(
      title: 'Income Statement',
      subtitle: '${_monthName(month)} $year',
      headers: ['Item', 'Amount'],
      rows: [
        ['Contributions', contributions.toStringAsFixed(2)],
        ['Loan Repayments', loansRepaid.toStringAsFixed(2)],
        ['Interest Income', interest.toStringAsFixed(2)],
        ['Expenses', expenses.toStringAsFixed(2)],
        [
          'Net Income',
          (contributions + loansRepaid + interest - expenses)
              .toStringAsFixed(2)
        ],
      ],
    );
  }

  Future<ReportTable> buildBalanceSheet({
    required String organizationId,
    required String chamaId,
  }) async {
    final contributions = await _total(organizationId, chamaId, 'contributions');
    final loans = await _total(organizationId, chamaId, 'loans');
    final loansRepaid = await _totalField(
        organizationId, chamaId, 'loans', 'repaidAmount');
    final investments = await _total(organizationId, chamaId, 'investments');

    return ReportTable(
      title: 'Balance Sheet',
      subtitle: 'As of ${DateTime.now().toLocal().toString().split(' ').first}',
      headers: ['Account', 'Amount'],
      rows: [
        ['Cash / Contributions', contributions.toStringAsFixed(2)],
        ['Investments', investments.toStringAsFixed(2)],
        ['Loans Outstanding', (loans - loansRepaid).toStringAsFixed(2)],
        ['Total Assets', (contributions + investments + (loans - loansRepaid)).toStringAsFixed(2)],
      ],
    );
  }

  Future<ReportTable> buildCashFlow({
    required String organizationId,
    required String chamaId,
    required int year,
  }) async {
    final contributions = await _sumYear(
        organizationId, chamaId, 'contributions', year);
    final loansOut = await _sumYear(organizationId, chamaId, 'loans', year);
    final loansIn = await _sumYearField(
        organizationId, chamaId, 'loans', 'repaidAmount', year);

    return ReportTable(
      title: 'Cash Flow Report',
      subtitle: 'Year $year',
      headers: ['Activity', 'Amount'],
      rows: [
        ['Inflows (Contributions)', contributions.toStringAsFixed(2)],
        ['Inflows (Loan Repayments)', loansIn.toStringAsFixed(2)],
        ['Outflows (Loans Issued)', loansOut.toStringAsFixed(2)],
        [
          'Net Cash Flow',
          (contributions + loansIn - loansOut).toStringAsFixed(2)
        ],
      ],
    );
  }

  Future<ReportTable> buildLoanReport({
    required String organizationId,
    required String chamaId,
  }) async {
    final snap = await _chama(organizationId, chamaId)
        .collection('loans')
        .get();
    final rows = <List<String>>[];
    double total = 0, repaid = 0;
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0).toDouble();
      final r = (data['repaidAmount'] ?? 0).toDouble();
      total += amount;
      repaid += r;
      rows.add([
        data['memberName']?.toString() ??
            data['userId']?.toString() ??
            'Member',
        amount.toStringAsFixed(2),
        r.toStringAsFixed(2),
        (amount - r).toStringAsFixed(2),
        data['status']?.toString() ?? 'pending',
      ]);
    }
    rows.add([
      'TOTAL',
      total.toStringAsFixed(2),
      repaid.toStringAsFixed(2),
      (total - repaid).toStringAsFixed(2),
      '',
    ]);
    return ReportTable(
      title: 'Loan Report',
      subtitle: 'All loans',
      headers: ['Member', 'Principal', 'Repaid', 'Outstanding', 'Status'],
      rows: rows,
    );
  }

  Future<ReportTable> buildMemberStatement({
    required String organizationId,
    required String chamaId,
    required String userId,
  }) async {
    final cSnap = await _chama(organizationId, chamaId)
        .collection('contributions')
        .where('userId', isEqualTo: userId)
        .get();
    final rows = <List<String>>[];
    double total = 0;
    for (final d in cSnap.docs) {
      final data = d.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0).toDouble();
      total += amount;
      rows.add([
        data['date']?.toString() ?? '',
        'Contribution',
        amount.toStringAsFixed(2),
      ]);
    }
    rows.add(['', 'Total', total.toStringAsFixed(2)]);
    return ReportTable(
      title: 'Member Statement',
      subtitle: 'User $userId',
      headers: ['Date', 'Type', 'Amount'],
      rows: rows,
    );
  }

  Future<ReportTable> buildAuditReport({
    required String organizationId,
    required String chamaId,
  }) async {
    final snap = await _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('chamas')
        .doc(chamaId)
        .collection('auditLogs')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();
    final rows = snap.docs.map<List<String>>((d) {
      final data = d.data() as Map<String, dynamic>;
      return [
        DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0)
            .toString()
            .split('.')
            .first,
        data['action']?.toString() ?? '',
        data['entityType']?.toString() ?? '',
        data['userId']?.toString() ?? '',
      ];
    }).toList();
    return ReportTable(
      title: 'Audit Report',
      subtitle: 'Recent activity',
      headers: ['Timestamp', 'Action', 'Entity', 'User'],
      rows: rows,
    );
  }

  Future<ReportTable> buildTaxSummary({
    required String organizationId,
    required String chamaId,
    required double taxRate,
  }) async {
    final contributions = await _total(organizationId, chamaId, 'contributions');
    final tax = contributions * taxRate;
    return ReportTable(
      title: 'Tax Summary',
      subtitle: 'Rate ${taxRate * 100}%',
      headers: ['Item', 'Amount'],
      rows: [
        ['Gross Contributions', contributions.toStringAsFixed(2)],
        ['Tax Rate', '${(taxRate * 100).toStringAsFixed(1)}%'],
        ['Tax Due', tax.toStringAsFixed(2)],
      ],
    );
  }

  DocumentReference _chama(String orgId, String chamaId) =>
      _firestore.collection('organizations').doc(orgId).collection('chamas').doc(chamaId);

  Future<double> _sum(String orgId, String chamaId, String coll, int year,
      int month, {String? field}) async {
    final snap = await _chama(orgId, chamaId)
        .collection(coll)
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .get();
    return _sumDocs(snap.docs, field);
  }

  Future<double> _sumYear(String orgId, String chamaId, String coll, int year,
      {String? field}) async {
    final snap = await _chama(orgId, chamaId)
        .collection(coll)
        .where('year', isEqualTo: year)
        .get();
    return _sumDocs(snap.docs, field);
  }

  Future<double> _sumYearField(String orgId, String chamaId, String coll,
      String field, int year) async {
    final snap = await _chama(orgId, chamaId)
        .collection(coll)
        .where('year', isEqualTo: year)
        .get();
    return _sumDocs(snap.docs, field);
  }

  Future<double> _total(String orgId, String chamaId, String coll) async {
    final snap = await _chama(orgId, chamaId).collection(coll).get();
    return _sumDocs(snap.docs, null);
  }

  Future<double> _totalField(
      String orgId, String chamaId, String coll, String field) async {
    final snap = await _chama(orgId, chamaId).collection(coll).get();
    return _sumDocs(snap.docs, field);
  }

  double _sumDocs(List<QueryDocumentSnapshot> docs, String? field) {
    double total = 0;
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      total += ((field != null ? data[field] : data['amount']) ?? 0).toDouble();
    }
    return total;
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

class ReportTable {
  final String title;
  final String subtitle;
  final List<String> headers;
  final List<List<String>> rows;

  ReportTable({
    required this.title,
    required this.subtitle,
    required this.headers,
    required this.rows,
  });
}
