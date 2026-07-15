import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/role_permission_model.dart';

/// Role-based permission service. Resolves feature-level permissions for a
/// member based on their role plus per-member granted/revoked overrides.
class RolePermissionService {
  static final RolePermissionService _instance =
      RolePermissionService._internal();
  factory RolePermissionService() => _instance;
  RolePermissionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _members(String orgId) => _firestore
      .collection('organizations')
      .doc(orgId)
      .collection('members');

  /// Returns the effective permissions for a member, or an empty set if the
  /// member is not part of the organization.
  Future<Set<Permission>> getPermissions(
      String organizationId, String userId) async {
    final doc = await _members(organizationId).doc(userId).get();
    if (!doc.exists) return {};
    final role = MemberRole.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    return role.effectivePermissions;
  }

  Future<bool> can(
      String organizationId, String userId, Permission permission) async {
    final perms = await getPermissions(organizationId, userId);
    return perms.contains(permission);
  }

  /// Assigns or updates a member's role. [granted]/[revoked] provide custom
  /// overrides on top of the role defaults.
  Future<void> assignRole({
    required String organizationId,
    required String userId,
    required OrganizationRole role,
    List<Permission> granted = const [],
    List<Permission> revoked = const [],
    String? memberName,
  }) async {
    final existing = await _members(organizationId).doc(userId).get();
    final member = MemberRole(
      id: userId,
      organizationId: organizationId,
      userId: userId,
      memberName: memberName,
      role: role,
      granted: granted,
      revoked: revoked,
      assignedAt: existing.exists
          ? (existing.data() as Map<String, dynamic>)['assignedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  (existing.data() as Map<String, dynamic>)['assignedAt'])
              : DateTime.now()
          : DateTime.now(),
    );
    await _members(organizationId).doc(userId).set(member.toMap());
  }

  Future<void> grantPermission({
    required String organizationId,
    required String userId,
    required Permission permission,
  }) async {
    final member = await _read(organizationId, userId);
    if (member == null) return;
    final granted = {...member.granted, permission}.toList();
    final revoked = member.revoked.where((p) => p != permission).toList();
    await _members(organizationId).doc(userId).update({
      'granted': granted.map((p) => p.index).toList(),
      'revoked': revoked.map((p) => p.index).toList(),
    });
  }

  Future<void> revokePermission({
    required String organizationId,
    required String userId,
    required Permission permission,
  }) async {
    final member = await _read(organizationId, userId);
    if (member == null) return;
    final revoked = {...member.revoked, permission}.toList();
    final granted = member.granted.where((p) => p != permission).toList();
    await _members(organizationId).doc(userId).update({
      'revoked': revoked.map((p) => p.index).toList(),
      'granted': granted.map((p) => p.index).toList(),
    });
  }

  Future<MemberRole?> _read(String organizationId, String userId) async {
    final doc = await _members(organizationId).doc(userId).get();
    if (!doc.exists) return null;
    return MemberRole.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Default permission template for UI display.
  Set<Permission> defaultPermissionsFor(OrganizationRole role) {
    const map = defaultPermissionTemplate;
    return map[role] ?? {};
  }
}

const Map<OrganizationRole, Set<Permission>> defaultPermissionTemplate = {
  OrganizationRole.owner: {
    Permission.viewDashboard,
    Permission.manageMembers,
    Permission.manageRoles,
    Permission.approveLoans,
    Permission.rejectLoans,
    Permission.manageContributions,
    Permission.manageInvestments,
    Permission.viewFinancials,
    Permission.exportReports,
    Permission.manageBranding,
    Permission.manageBilling,
    Permission.manageIntegrations,
    Permission.manageSettings,
    Permission.viewAuditLogs,
    Permission.communicateMembers,
    Permission.manageMeetings,
    Permission.manageDocuments,
    Permission.manageVotes,
  },
  OrganizationRole.chairperson: {
    Permission.viewDashboard,
    Permission.manageMembers,
    Permission.approveLoans,
    Permission.rejectLoans,
    Permission.viewFinancials,
    Permission.exportReports,
    Permission.viewAuditLogs,
    Permission.communicateMembers,
    Permission.manageMeetings,
    Permission.manageVotes,
  },
  OrganizationRole.treasurer: {
    Permission.viewDashboard,
    Permission.manageContributions,
    Permission.manageInvestments,
    Permission.viewFinancials,
    Permission.exportReports,
    Permission.viewAuditLogs,
  },
  OrganizationRole.secretary: {
    Permission.viewDashboard,
    Permission.manageMembers,
    Permission.communicateMembers,
    Permission.manageMeetings,
    Permission.manageDocuments,
    Permission.manageVotes,
  },
  OrganizationRole.auditor: {
    Permission.viewDashboard,
    Permission.viewFinancials,
    Permission.exportReports,
    Permission.viewAuditLogs,
  },
  OrganizationRole.loanOfficer: {
    Permission.viewDashboard,
    Permission.approveLoans,
    Permission.rejectLoans,
    Permission.viewFinancials,
  },
  OrganizationRole.member: {Permission.viewDashboard},
  OrganizationRole.guest: {},
};
