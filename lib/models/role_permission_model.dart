/// Enterprise role-based access control.
///
/// Each organization assigns members a [OrganizationRole]. Feature-level
/// permissions are resolved by combining the role's default permission set
/// with any per-member custom permissions.
enum OrganizationRole {
  owner,
  chairperson,
  secretary,
  treasurer,
  auditor,
  loanOfficer,
  member,
  guest,
}

extension OrganizationRoleExtension on OrganizationRole {
  String get displayName {
    switch (this) {
      case OrganizationRole.owner:
        return 'Owner';
      case OrganizationRole.chairperson:
        return 'Chairperson';
      case OrganizationRole.secretary:
        return 'Secretary';
      case OrganizationRole.treasurer:
        return 'Treasurer';
      case OrganizationRole.auditor:
        return 'Auditor';
      case OrganizationRole.loanOfficer:
        return 'Loan Officer';
      case OrganizationRole.member:
        return 'Member';
      case OrganizationRole.guest:
        return 'Guest';
    }
  }

  int get rank {
    switch (this) {
      case OrganizationRole.owner:
        return 100;
      case OrganizationRole.chairperson:
        return 80;
      case OrganizationRole.treasurer:
        return 70;
      case OrganizationRole.secretary:
        return 60;
      case OrganizationRole.auditor:
        return 55;
      case OrganizationRole.loanOfficer:
        return 50;
      case OrganizationRole.member:
        return 20;
      case OrganizationRole.guest:
        return 10;
    }
  }
}

/// Feature-level permissions that can be toggled per role.
enum Permission {
  viewDashboard,
  manageMembers,
  manageRoles,
  approveLoans,
  rejectLoans,
  manageContributions,
  manageInvestments,
  viewFinancials,
  exportReports,
  manageBranding,
  manageBilling,
  manageIntegrations,
  manageSettings,
  viewAuditLogs,
  communicateMembers,
  manageMeetings,
  manageDocuments,
  manageVotes,
}

extension PermissionExtension on Permission {
  String get displayName {
    switch (this) {
      case Permission.viewDashboard:
        return 'View Dashboard';
      case Permission.manageMembers:
        return 'Manage Members';
      case Permission.manageRoles:
        return 'Manage Roles';
      case Permission.approveLoans:
        return 'Approve Loans';
      case Permission.rejectLoans:
        return 'Reject Loans';
      case Permission.manageContributions:
        return 'Manage Contributions';
      case Permission.manageInvestments:
        return 'Manage Investments';
      case Permission.viewFinancials:
        return 'View Financials';
      case Permission.exportReports:
        return 'Export Reports';
      case Permission.manageBranding:
        return 'Manage Branding';
      case Permission.manageBilling:
        return 'Manage Billing';
      case Permission.manageIntegrations:
        return 'Manage Integrations';
      case Permission.manageSettings:
        return 'Manage Settings';
      case Permission.viewAuditLogs:
        return 'View Audit Logs';
      case Permission.communicateMembers:
        return 'Communicate with Members';
      case Permission.manageMeetings:
        return 'Manage Meetings';
      case Permission.manageDocuments:
        return 'Manage Documents';
      case Permission.manageVotes:
        return 'Manage Votes';
    }
  }
}

const Map<OrganizationRole, Set<Permission>> _defaultPermissions = {
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
  OrganizationRole.member: {
    Permission.viewDashboard,
  },
  OrganizationRole.guest: {},
};

class RolePermissionSet {
  final OrganizationRole role;
  final Set<Permission> permissions;

  RolePermissionSet({
    required this.role,
    Set<Permission>? permissions,
  }) : permissions = permissions ?? _defaultPermissions[role] ?? {};

  factory RolePermissionSet.fromMap(Map<String, dynamic> map) {
    final role = OrganizationRole.values[map['role'] ?? 6];
    final perms = (map['permissions'] as List? ?? [])
        .map((e) => Permission.values[e as int])
        .toSet();
    return RolePermissionSet(role: role, permissions: perms);
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.index,
      'permissions': permissions.map((p) => p.index).toList(),
    };
  }

  bool has(Permission permission) => permissions.contains(permission);
}

/// A member's assignment within an organization, including any custom
/// permission overrides on top of the role defaults.
class MemberRole {
  final String id;
  final String organizationId;
  final String userId;
  final String? memberName;
  final OrganizationRole role;
  final List<Permission> granted;
  final List<Permission> revoked;
  final DateTime assignedAt;

  MemberRole({
    required this.id,
    required this.organizationId,
    required this.userId,
    this.memberName,
    required this.role,
    this.granted = const [],
    this.revoked = const [],
    required this.assignedAt,
  });

  factory MemberRole.fromMap(Map<String, dynamic> map, String id) {
    return MemberRole(
      id: id,
      organizationId: map['organizationId'] ?? '',
      userId: map['userId'] ?? '',
      memberName: map['memberName'],
      role: OrganizationRole.values[map['role'] ?? 6],
      granted: (map['granted'] as List? ?? [])
          .map((e) => Permission.values[e as int])
          .toList(),
      revoked: (map['revoked'] as List? ?? [])
          .map((e) => Permission.values[e as int])
          .toList(),
      assignedAt: map['assignedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['assignedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'userId': userId,
      'memberName': memberName,
      'role': role.index,
      'granted': granted.map((p) => p.index).toList(),
      'revoked': revoked.map((p) => p.index).toList(),
      'assignedAt': assignedAt.millisecondsSinceEpoch,
    };
  }

  Set<Permission> get effectivePermissions {
    final base = _defaultPermissions[role] ?? {};
    return base.union(granted.toSet()).difference(revoked.toSet());
  }

  bool can(Permission permission) => effectivePermissions.contains(permission);
}
