import 'package:flutter/material.dart';

enum IntegrationType {
  accounting,
  payroll,
  banking,
  government,
  crm,
  custom,
}

extension IntegrationTypeExtension on IntegrationType {
  String get displayName {
    switch (this) {
      case IntegrationType.accounting:
        return 'Accounting';
      case IntegrationType.payroll:
        return 'Payroll';
      case IntegrationType.banking:
        return 'Banking API';
      case IntegrationType.government:
        return 'Government System';
      case IntegrationType.crm:
        return 'CRM';
      case IntegrationType.custom:
        return 'Custom API';
    }
  }

  IconData get icon {
    switch (this) {
      case IntegrationType.accounting:
        return Icons.account_balance_wallet;
      case IntegrationType.payroll:
        return Icons.payments;
      case IntegrationType.banking:
        return Icons.account_balance;
      case IntegrationType.government:
        return Icons.gavel;
      case IntegrationType.crm:
        return Icons.people_alt;
      case IntegrationType.custom:
        return Icons.api;
    }
  }
}

enum IntegrationStatus { connected, disconnected, error, pending }

extension IntegrationStatusExtension on IntegrationStatus {
  String get displayName {
    switch (this) {
      case IntegrationStatus.connected:
        return 'Connected';
      case IntegrationStatus.disconnected:
        return 'Disconnected';
      case IntegrationStatus.error:
        return 'Error';
      case IntegrationStatus.pending:
        return 'Pending';
    }
  }
}

class ApiIntegration {
  final String id;
  final String organizationId;
  final IntegrationType type;
  final String name;
  final String? baseUrl;
  final String? maskedApiKey;
  final IntegrationStatus status;
  final Map<String, dynamic> config;
  final DateTime createdAt;
  final DateTime? lastSyncAt;
  final String? lastSyncError;

  ApiIntegration({
    required this.id,
    required this.organizationId,
    required this.type,
    required this.name,
    this.baseUrl,
    this.maskedApiKey,
    this.status = IntegrationStatus.disconnected,
    this.config = const {},
    required this.createdAt,
    this.lastSyncAt,
    this.lastSyncError,
  });

  factory ApiIntegration.fromMap(Map<String, dynamic> map, String id) {
    return ApiIntegration(
      id: id,
      organizationId: map['organizationId'] ?? '',
      type: IntegrationType.values[map['type'] ?? 0],
      name: map['name'] ?? '',
      baseUrl: map['baseUrl'],
      maskedApiKey: map['maskedApiKey'],
      status: IntegrationStatus.values[map['status'] ?? 1],
      config: Map<String, dynamic>.from(map['config'] ?? {}),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      lastSyncAt: map['lastSyncAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSyncAt'])
          : null,
      lastSyncError: map['lastSyncError'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'type': type.index,
      'name': name,
      'baseUrl': baseUrl,
      'maskedApiKey': maskedApiKey,
      'status': status.index,
      'config': config,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastSyncAt': lastSyncAt?.millisecondsSinceEpoch,
      'lastSyncError': lastSyncError,
    };
  }
}
