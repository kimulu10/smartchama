import 'package:flutter/material.dart';
import '../loans/loan_management_screen.dart';

class DashboardLoanManagementScreen extends StatelessWidget {
  final String chamaId;

  const DashboardLoanManagementScreen({super.key, required this.chamaId});

  @override
  Widget build(BuildContext context) {
    return LoanManagementScreen(chamaId: chamaId, organizationId: '',);
  }
}