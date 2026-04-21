import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyTrackerScreen extends StatefulWidget {
  final String organizationId;
  final String chamaId;

  const MonthlyTrackerScreen({
    super.key,
    required this.organizationId,
    required this.chamaId,
  });

  @override
  State<MonthlyTrackerScreen> createState() => _MonthlyTrackerScreenState();
}

class _MonthlyTrackerScreenState extends State<MonthlyTrackerScreen> {
  DateTime _selectedMonth = DateTime.now();
  String chamaName = "Monthly Tracker";

  @override
  void initState() {
    super.initState();
    _loadChamaName();
  }

  Future<void> _loadChamaName() async {
    final chamaDoc = await FirebaseFirestore.instance
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();
    if (chamaDoc.exists && mounted) {
      setState(() {
        chamaName = chamaDoc.data()?["name"] ?? "Monthly Tracker";
      });
    }
  }

  String _getMonthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _formatMonth(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$chamaName - Monthly Tracker'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildContributionSummary(),
          Expanded(child: _buildContributionList()),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1B5E20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: _previousMonth,
          ),
          Text(
            _formatMonth(_selectedMonth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildContributionSummary() {
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("contributions")
          .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where("createdAt", isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          );
        }

        final contributions = snapshot.data!.docs;
        final totalAmount = contributions.fold<double>(
          0,
          (sum, doc) => sum + (doc['amount'] as num? ?? 0),
        );
        final count = contributions.length;
        final average = count > 0 ? totalAmount / count : 0.0;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Monthly Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Total', 'KSh ${totalAmount.toStringAsFixed(0)}'),
                  _buildSummaryItem('Contributions', count.toString()),
                  _buildSummaryItem('Average', 'KSh ${average.toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildContributionList() {
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("contributions")
          .where("createdAt", isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where("createdAt", isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final contributions = snapshot.data!.docs;

        if (contributions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No contributions for this month',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: contributions.length,
          itemBuilder: (context, index) {
            final doc = contributions[index];
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?) ?? 0;
            final createdAt = data['createdAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF2E7D32),
                  child: Icon(
                    Icons.attach_money,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  'KSh ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  createdAt != null
                      ? _formatDate(createdAt.toDate())
                      : 'Unknown date',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}