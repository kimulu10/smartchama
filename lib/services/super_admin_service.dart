import 'package:cloud_firestore/cloud_firestore.dart';

/// Platform owner (super admin) service. Aggregates cross-tenant metrics:
/// total organizations, members, revenue, active subscriptions, support
/// requests, system status and analytics.
class SuperAdminService {
  static final SuperAdminService _instance = SuperAdminService._internal();
  factory SuperAdminService() => _instance;
  SuperAdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<PlatformMetrics> getPlatformMetrics() async {
    final orgsSnap = await _firestore.collection('organizations').get();
    final subscriptionsSnap = await _firestore.collection('subscriptions').get();
    final invoicesSnap = await _firestore.collection('invoices').get();
    final supportSnap = await _firestore
        .collection('support_requests')
        .where('status', isEqualTo: 'open')
        .get();

    int members = 0;
    for (final org in orgsSnap.docs) {
      final m = (org.data() as Map<String, dynamic>)['memberCount'] ?? 0;
      members += (m as int);
    }

    double revenue = 0;
    for (final inv in invoicesSnap.docs) {
      final data = inv.data() as Map<String, dynamic>;
      if ((data['status'] ?? 1) == 0) {
        revenue += (data['amount'] ?? 0).toDouble();
      }
    }

    int activeSubs = 0;
    for (final sub in subscriptionsSnap.docs) {
      final status = (sub.data() as Map<String, dynamic>)['status'] ?? 0;
      if (status == 0 || status == 1) activeSubs++;
    }

    return PlatformMetrics(
      totalOrganizations: orgsSnap.docs.length,
      totalMembers: members,
      totalRevenue: revenue,
      activeSubscriptions: activeSubs,
      openSupportRequests: supportSnap.docs.length,
      systemStatus: SystemStatus.operational,
      generatedAt: DateTime.now(),
    );
  }

  Future<List<Map<String, dynamic>>> getOrganizationsSummary() async {
    final snap = await _firestore
        .collection('organizations')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();
  }

  Future<void> suspendOrganization(String organizationId, bool suspended) async {
    await _firestore.collection('organizations').doc(organizationId).update({
      'status': suspended
          ? 2
          : 0,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

enum SystemStatus { operational, degraded, outage }

extension SystemStatusExtension on SystemStatus {
  String get displayName {
    switch (this) {
      case SystemStatus.operational:
        return 'Operational';
      case SystemStatus.degraded:
        return 'Degraded';
      case SystemStatus.outage:
        return 'Outage';
    }
  }
}

class PlatformMetrics {
  final int totalOrganizations;
  final int totalMembers;
  final double totalRevenue;
  final int activeSubscriptions;
  final int openSupportRequests;
  final SystemStatus systemStatus;
  final DateTime generatedAt;

  PlatformMetrics({
    required this.totalOrganizations,
    required this.totalMembers,
    required this.totalRevenue,
    required this.activeSubscriptions,
    required this.openSupportRequests,
    required this.systemStatus,
    required this.generatedAt,
  });
}
