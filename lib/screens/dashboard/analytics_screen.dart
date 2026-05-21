import 'package:flutter/material.dart';
import '../analytics/analytics_screen.dart';

class DashboardAnalyticsScreen extends StatelessWidget {
  final String chamaId;
  final String organizationId;

  const DashboardAnalyticsScreen({
    super.key,
    required this.chamaId,
    required this.organizationId,
  });

  @override
  Widget build(BuildContext context) {
    return AnalyticsScreen(
      chamaId: chamaId,
      organizationId: organizationId,
    );
  }
}
