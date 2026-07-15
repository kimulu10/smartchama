enum FraudType {
  duplicateTransaction,
  suspiciousWithdrawal,
  unusualLoginLocation,
  fakeMember,
  multiplePaymentAttempts,
  velocityAnomaly,
}

extension FraudTypeExtension on FraudType {
  String get displayName {
    switch (this) {
      case FraudType.duplicateTransaction:
        return 'Duplicate Transaction';
      case FraudType.suspiciousWithdrawal:
        return 'Suspicious Withdrawal';
      case FraudType.unusualLoginLocation:
        return 'Unusual Login Location';
      case FraudType.fakeMember:
        return 'Fake / Duplicate Member';
      case FraudType.multiplePaymentAttempts:
        return 'Multiple Payment Attempts';
      case FraudType.velocityAnomaly:
        return 'Transaction Velocity Anomaly';
    }
  }
}

enum FraudSeverity { low, medium, high, critical }

extension FraudSeverityExtension on FraudSeverity {
  String get displayName {
    switch (this) {
      case FraudSeverity.low:
        return 'Low';
      case FraudSeverity.medium:
        return 'Medium';
      case FraudSeverity.high:
        return 'High';
      case FraudSeverity.critical:
        return 'Critical';
    }
  }
}

enum FraudStatus { open, investigating, resolved, falsePositive }

extension FraudStatusExtension on FraudStatus {
  String get displayName {
    switch (this) {
      case FraudStatus.open:
        return 'Open';
      case FraudStatus.investigating:
        return 'Investigating';
      case FraudStatus.resolved:
        return 'Resolved';
      case FraudStatus.falsePositive:
        return 'False Positive';
    }
  }
}

class FraudAlert {
  final String id;
  final String organizationId;
  final String? chamaId;
  final FraudType type;
  final FraudSeverity severity;
  final FraudStatus status;
  final String description;
  final double confidenceScore;
  final String? entityType;
  final String? entityId;
  final String? userId;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final String? resolutionNote;

  FraudAlert({
    required this.id,
    required this.organizationId,
    this.chamaId,
    required this.type,
    required this.severity,
    this.status = FraudStatus.open,
    required this.description,
    this.confidenceScore = 0.5,
    this.entityType,
    this.entityId,
    this.userId,
    required this.detectedAt,
    this.resolvedAt,
    this.resolutionNote,
  });

  factory FraudAlert.fromMap(Map<String, dynamic> map, String id) {
    return FraudAlert(
      id: id,
      organizationId: map['organizationId'] ?? '',
      chamaId: map['chamaId'],
      type: FraudType.values[map['type'] ?? 0],
      severity: FraudSeverity.values[map['severity'] ?? 1],
      status: FraudStatus.values[map['status'] ?? 0],
      description: map['description'] ?? '',
      confidenceScore: (map['confidenceScore'] ?? 0.5).toDouble(),
      entityType: map['entityType'],
      entityId: map['entityId'],
      userId: map['userId'],
      detectedAt: map['detectedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['detectedAt'])
          : DateTime.now(),
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['resolvedAt'])
          : null,
      resolutionNote: map['resolutionNote'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'chamaId': chamaId,
      'type': type.index,
      'severity': severity.index,
      'status': status.index,
      'description': description,
      'confidenceScore': confidenceScore,
      'entityType': entityType,
      'entityId': entityId,
      'userId': userId,
      'detectedAt': detectedAt.millisecondsSinceEpoch,
      'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
      'resolutionNote': resolutionNote,
    };
  }
}

class FraudRule {
  final String id;
  final FraudType type;
  final bool enabled;
  final double threshold;
  final String description;

  FraudRule({
    required this.id,
    required this.type,
    this.enabled = true,
    this.threshold = 0.7,
    required this.description,
  });

  factory FraudRule.fromMap(Map<String, dynamic> map, String id) {
    return FraudRule(
      id: id,
      type: FraudType.values[map['type'] ?? 0],
      enabled: map['enabled'] ?? true,
      threshold: (map['threshold'] ?? 0.7).toDouble(),
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'enabled': enabled,
      'threshold': threshold,
      'description': description,
    };
  }
}
