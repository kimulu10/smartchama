import 'package:flutter/material.dart';
import '../analytics/analytics_screen.dart';

class DashboardAnalyticsScreen extends StatelessWidget {
  final String chamaId;

  const DashboardAnalyticsScreen({super.key, required this.chamaId});

  @override
  Widget build(BuildContext context) {
    return AnalyticsScreen(chamaId: chamaId, organizationId: '',);
  }
}