import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/services/qr_payment_service.dart';

class QRPaymentHistoryScreen extends StatefulWidget {
  final String chamaId;

  const QRPaymentHistoryScreen({
    super.key,
    required this.chamaId,
  });

  @override
  State<QRPaymentHistoryScreen> createState() => _QRPaymentHistoryScreenState();
}

class _QRPaymentHistoryScreenState extends State<QRPaymentHistoryScreen> {
  final QRPaymentService _qrService = QRPaymentService();
  List<dynamic> _payments = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final payments = await _qrService.getQRPaymentHistory(widget.chamaId);
    if (mounted) {
      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Payment History'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filterStatus = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(value: 'paid', child: Text('Paid')),
              PopupMenuItem(value: 'expired', child: Text('Expired')),
              PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No QR payments yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPayments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      return _buildPaymentCard(payment);
                    },
                  ),
                ),
    );
  }

  Widget _buildPaymentCard(dynamic payment) {
    final isActive = payment.status == 'pending';
    final isPaid = payment.status == 'paid';
    final isExpired = payment.status == 'expired';

    Color statusColor;
    if (isActive) statusColor = Colors.orange;
    else if (isPaid) statusColor = Colors.green;
    else if (isExpired) statusColor = Colors.red;
    else statusColor = Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.qr_code, color: statusColor),
        ),
        title: Text(
          'KES ${payment.amount.toInt()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payment.purpose),
            Text(
              DateFormat.yMMMd().add_jm().format(payment.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(payment.status.toUpperCase()),
          backgroundColor: statusColor.withOpacity(0.1),
          labelStyle: TextStyle(color: statusColor, fontSize: 10),
        ),
      ),
    );
  }
}
