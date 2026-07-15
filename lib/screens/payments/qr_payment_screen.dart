import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smartchama/models/qr_payment_model.dart';
import 'package:smartchama/services/qr_payment_service.dart';

class QRPaymentScreen extends StatefulWidget {
  final String chamaId;
  final String organizationId;

  const QRPaymentScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  State<QRPaymentScreen> createState() => _QRPaymentScreenState();
}

class _QRPaymentScreenState extends State<QRPaymentScreen> with SingleTickerProviderStateMixin {
  final QRPaymentService _qrService = QRPaymentService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _qrDataController = TextEditingController();

  late TabController _tabController;
  String _selectedPurpose = 'Contribution';
  List<QRPayment> _activePayments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActivePayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _qrDataController.dispose();
    super.dispose();
  }

  Future<void> _loadActivePayments() async {
    final payments = await _qrService.getActiveQRPayments(widget.chamaId);
    if (mounted) {
      setState(() {
        _activePayments = payments;
        _isLoading = false;
      });
    }
  }

  Future<void> _createQRPayment() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
      );
      return;
    }

    final qrId = await _qrService.createQRPayment(
      chamaId: widget.chamaId,
      organizationId: widget.organizationId,
      createdBy: user.uid,
      amount: amount,
      purpose: _selectedPurpose,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code created successfully'), backgroundColor: Colors.green),
      );
      _amountController.clear();
      _loadActivePayments();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('QR Payment Created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Center(
                  child: Icon(Icons.qr_code_2, size: 150, color: Colors.grey[800]),
                ),
              ),
              const SizedBox(height: 16),
              Text('Amount: KES ${amount.toInt()}'),
              Text('Purpose: $_selectedPurpose'),
              Text('ID: $qrId'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    }
  }

  Future<void> _scanQRPayment() async {
    final qrData = _qrDataController.text.trim();
    if (qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter QR data'), backgroundColor: Colors.red),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    await _qrService.scanQRPayment(qrData, user.uid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code scanned successfully'), backgroundColor: Colors.green),
      );
      _qrDataController.clear();
      _loadActivePayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Payments'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Create QR'),
            Tab(text: 'Scan QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateQRTab(),
          _buildScanQRTab(),
        ],
      ),
    );
  }

  Widget _buildCreateQRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create QR Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (KES)',
                      prefixText: 'KES ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedPurpose,
                    decoration: const InputDecoration(
                      labelText: 'Purpose',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Contribution', child: Text('Contribution')),
                      DropdownMenuItem(value: 'Loan Repayment', child: Text('Loan Repayment')),
                      DropdownMenuItem(value: 'Meeting Fee', child: Text('Meeting Fee')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPurpose = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _createQRPayment,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Generate QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Active QR Payments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_activePayments.isEmpty)
            Center(
              child: Text('No active QR payments', style: TextStyle(color: Colors.grey[600])),
            )
          else
            ..._activePayments.map((payment) => _buildActivePaymentCard(payment)),
        ],
      ),
    );
  }

  Widget _buildScanQRTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scan QR Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _qrDataController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'QR Code Data',
                      hintText: 'Paste QR code data here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _scanQRPayment,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Verify & Pay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePaymentCard(QRPayment payment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.1),
          child: const Icon(Icons.qr_code, color: Colors.orange),
        ),
        title: Text('KES ${payment.amount.toInt()} - ${payment.purpose}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expires: ${DateFormat.jm().format(payment.expiresAt)}'),
            Text('ID: ${payment.id.substring(0, 8)}...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        trailing: Chip(
          label: Text(payment.status.toUpperCase()),
          backgroundColor: Colors.orange.withOpacity(0.1),
        ),
      ),
    );
  }
}
