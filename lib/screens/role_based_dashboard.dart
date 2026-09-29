import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard/unified_dashboard.dart';
import 'platform/super_admin_dashboard.dart';

/// Routes the user to the appropriate dashboard based on their role.
///
/// Super admins get the platform-level dashboard. Everyone else — admins,
/// chairmen, treasurers, secretaries, and members — lands on the unified
/// dashboard which adapts its content based on the user's role.
class RoleBasedDashboard extends StatelessWidget {
  final String userId;

  const RoleBasedDashboard({super.key, required this.userId});

  Future<Map<String, String>> _loadContext() async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};
    return {
      'role': (data['role'] as String?) ?? 'member',
      'organizationId': (data['organizationId'] as String?) ?? '',
      'chamaId': (data['chamaId'] as String?) ?? '',
      'platformRole': (data['platformRole'] as String?) ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _loadContext(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final ctx = snapshot.data ?? {};
        final platformRole = ctx['platformRole'] ?? '';
        final organizationId = ctx['organizationId'] ?? '';
        final chamaId = ctx['chamaId'] ?? '';

        if (platformRole == 'super_admin') {
          return const SuperAdminDashboard();
        }

        return UnifiedDashboard(
          userId: userId,
          organizationId: organizationId.isNotEmpty ? organizationId : null,
          chamaId: chamaId.isNotEmpty ? chamaId : null,
        );
      },
    );
  }
}
