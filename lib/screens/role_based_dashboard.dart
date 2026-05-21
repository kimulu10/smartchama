import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin/admin_dashboard_screen.dart';
import 'dashboard/unified_dashboard.dart';
import 'leaders/leader_dashboard.dart';

/// Routes the user to the appropriate dashboard based on their chama role.
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
        final role = ctx['role'] ?? 'member';
        final organizationId = ctx['organizationId'] ?? '';
        final chamaId = ctx['chamaId'] ?? '';

        if (organizationId.isEmpty || chamaId.isEmpty) {
          return UnifiedDashboard(userId: userId);
        }

        switch (role) {
          case 'admin':
          case 'chairman':
            return AdminDashboardScreen(
              organizationId: organizationId,
              chamaId: chamaId,
            );
          case 'treasurer':
          case 'secretary':
            return LeaderDashboard(
              organizationId: organizationId,
              chamaId: chamaId,
              userId: userId,
              role: role,
            );
          default:
            return UnifiedDashboard(userId: userId);
        }
      },
    );
  }
}
