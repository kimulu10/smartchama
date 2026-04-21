import 'package:flutter/material.dart';
import '../loans/loan_request_screen.dart';

class DashboardLoanRequestScreen extends StatelessWidget {
  final String chamaId;
  final String organizationId;

  const DashboardLoanRequestScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  Widget build(BuildContext context) {
    return LoanRequestScreen(
      chamaId: chamaId,
      organizationId: organizationId,
    );
  }
}