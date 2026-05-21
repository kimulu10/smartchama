import 'package:flutter/material.dart';
import '../loans/loan_management_screen.dart';

class DashboardLoanManagementScreen extends StatelessWidget {
  final String chamaId;
  final String organizationId;

  const DashboardLoanManagementScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  Widget build(BuildContext context) {
    return LoanManagementScreen(
      chamaId: chamaId,
      organizationId: organizationId,
    );
  }
}
