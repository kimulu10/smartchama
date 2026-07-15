class AuditLog {
  final String id;
  final String chamaId;
  final String userId;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, dynamic>? previousValues;
  final Map<String, dynamic>? newValues;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.chamaId,
    required this.userId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.previousValues,
    this.newValues,
    required this.timestamp,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map, String id) {
    return AuditLog(
      id: id,
      chamaId: map['chamaId'] ?? '',
      userId: map['userId'] ?? '',
      action: map['action'] ?? '',
      entityType: map['entityType'] ?? '',
      entityId: map['entityId'] ?? '',
      previousValues: map['previousValues'],
      newValues: map['newValues'],
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chamaId': chamaId,
      'userId': userId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'previousValues': previousValues,
      'newValues': newValues,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

enum AuditAction {
  created,
  updated,
  deleted,
  login,
  logout,
  approval,
  payment,
  roleChange,
  contributionAdded,
  loanApproved,
  loanRejected,
  loanRepaid,
  memberAdded,
  memberRemoved,
  meetingScheduled,
  voteCast,
  documentUploaded,
  brandingUpdated,
  integrationConnected,
  fraudAlertResolved,
  subscriptionChanged,
  exportGenerated,
}

extension AuditActionExtension on AuditAction {
  String get displayName {
    switch (this) {
      case AuditAction.created:
        return 'Created';
      case AuditAction.updated:
        return 'Updated';
      case AuditAction.deleted:
        return 'Deleted';
      case AuditAction.login:
        return 'Logged in';
      case AuditAction.logout:
        return 'Logged out';
      case AuditAction.contributionAdded:
        return 'Contribution added';
      case AuditAction.loanApproved:
        return 'Loan approved';
      case AuditAction.loanRejected:
        return 'Loan rejected';
      case AuditAction.loanRepaid:
        return 'Loan repaid';
      case AuditAction.memberAdded:
        return 'Member added';
      case AuditAction.memberRemoved:
        return 'Member removed';
      case AuditAction.meetingScheduled:
        return 'Meeting scheduled';
      case AuditAction.voteCast:
        return 'Vote cast';
      case AuditAction.documentUploaded:
        return 'Document uploaded';
      case AuditAction.approval:
        return 'Approval';
      case AuditAction.payment:
        return 'Payment';
      case AuditAction.roleChange:
        return 'Role changed';
      case AuditAction.brandingUpdated:
        return 'Branding updated';
      case AuditAction.integrationConnected:
        return 'Integration connected';
      case AuditAction.fraudAlertResolved:
        return 'Fraud alert resolved';
      case AuditAction.subscriptionChanged:
        return 'Subscription changed';
      case AuditAction.exportGenerated:
        return 'Report exported';
    }
  }
}