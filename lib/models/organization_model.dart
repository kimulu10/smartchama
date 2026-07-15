import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Multi-tenant organization (tenant) that owns one or more chamas.
/// All tenant data is isolated by [id] and sub-collections live under
/// `organizations/{organizationId}/...`.
class Organization {
  final String id;
  final String name;
  final String? description;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OrganizationStatus status;
  final String planId;
  final BrandingConfig branding;
  final WhiteLabelConfig whiteLabel;
  final OrganizationSettings settings;
  final String regionCode;
  final int memberCount;
  final int chamaCount;
  final int storageUsedMb;

  Organization({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.status = OrganizationStatus.active,
    this.planId = 'free',
    BrandingConfig? branding,
    WhiteLabelConfig? whiteLabel,
    OrganizationSettings? settings,
    this.regionCode = 'KE',
    this.memberCount = 0,
    this.chamaCount = 0,
    this.storageUsedMb = 0,
  })  : branding = branding ?? BrandingConfig(),
        whiteLabel = whiteLabel ?? WhiteLabelConfig(),
        settings = settings ?? OrganizationSettings();

  factory Organization.fromMap(Map<String, dynamic> map, String id) {
    return Organization(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      ownerId: map['ownerId'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : DateTime.now(),
      status: OrganizationStatus.values[map['status'] ?? 0],
      planId: map['planId'] ?? 'free',
      branding: map['branding'] != null
          ? BrandingConfig.fromMap(Map<String, dynamic>.from(map['branding']))
          : BrandingConfig(),
      whiteLabel: map['whiteLabel'] != null
          ? WhiteLabelConfig.fromMap(
              Map<String, dynamic>.from(map['whiteLabel']))
          : WhiteLabelConfig(),
      settings: map['settings'] != null
          ? OrganizationSettings.fromMap(
              Map<String, dynamic>.from(map['settings']))
          : OrganizationSettings(),
      regionCode: map['regionCode'] ?? 'KE',
      memberCount: map['memberCount'] ?? 0,
      chamaCount: map['chamaCount'] ?? 0,
      storageUsedMb: map['storageUsedMb'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'status': status.index,
      'planId': planId,
      'branding': branding.toMap(),
      'whiteLabel': whiteLabel.toMap(),
      'settings': settings.toMap(),
      'regionCode': regionCode,
      'memberCount': memberCount,
      'chamaCount': chamaCount,
      'storageUsedMb': storageUsedMb,
    };
  }

  Organization copyWith({
    String? name,
    String? description,
    String? ownerId,
    OrganizationStatus? status,
    String? planId,
    BrandingConfig? branding,
    WhiteLabelConfig? whiteLabel,
    OrganizationSettings? settings,
    String? regionCode,
    int? memberCount,
    int? chamaCount,
    int? storageUsedMb,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      status: status ?? this.status,
      planId: planId ?? this.planId,
      branding: branding ?? this.branding,
      whiteLabel: whiteLabel ?? this.whiteLabel,
      settings: settings ?? this.settings,
      regionCode: regionCode ?? this.regionCode,
      memberCount: memberCount ?? this.memberCount,
      chamaCount: chamaCount ?? this.chamaCount,
      storageUsedMb: storageUsedMb ?? this.storageUsedMb,
    );
  }
}

enum OrganizationStatus { active, trial, suspended, cancelled }

extension OrganizationStatusExtension on OrganizationStatus {
  String get displayName {
    switch (this) {
      case OrganizationStatus.active:
        return 'Active';
      case OrganizationStatus.trial:
        return 'Trial';
      case OrganizationStatus.suspended:
        return 'Suspended';
      case OrganizationStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Per-organization visual identity used for app, emails, PDFs and receipts.
class BrandingConfig {
  final String appName;
  final String? logoUrl;
  final String? faviconUrl;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String accentColorHex;
  final String? supportEmail;
  final String? supportPhone;
  final String emailTemplatePrefix;
  final String receiptFooter;
  final String pdfReportHeader;
  final String notificationTitlePrefix;

  BrandingConfig({
    this.appName = 'SmartChama',
    this.logoUrl,
    this.faviconUrl,
    this.primaryColorHex = '#1B5E20',
    this.secondaryColorHex = '#2E7D32',
    this.accentColorHex = '#FFC107',
    this.supportEmail,
    this.supportPhone,
    this.emailTemplatePrefix = 'SmartChama',
    this.receiptFooter = 'Thank you for using SmartChama.',
    this.pdfReportHeader = 'SmartChama Financial Report',
    this.notificationTitlePrefix = 'SmartChama',
  });

  factory BrandingConfig.fromMap(Map<String, dynamic> map) {
    return BrandingConfig(
      appName: map['appName'] ?? 'SmartChama',
      logoUrl: map['logoUrl'],
      faviconUrl: map['faviconUrl'],
      primaryColorHex: map['primaryColorHex'] ?? '#1B5E20',
      secondaryColorHex: map['secondaryColorHex'] ?? '#2E7D32',
      accentColorHex: map['accentColorHex'] ?? '#FFC107',
      supportEmail: map['supportEmail'],
      supportPhone: map['supportPhone'],
      emailTemplatePrefix: map['emailTemplatePrefix'] ?? 'SmartChama',
      receiptFooter: map['receiptFooter'] ?? 'Thank you for using SmartChama.',
      pdfReportHeader:
          map['pdfReportHeader'] ?? 'SmartChama Financial Report',
      notificationTitlePrefix:
          map['notificationTitlePrefix'] ?? 'SmartChama',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'logoUrl': logoUrl,
      'faviconUrl': faviconUrl,
      'primaryColorHex': primaryColorHex,
      'secondaryColorHex': secondaryColorHex,
      'accentColorHex': accentColorHex,
      'supportEmail': supportEmail,
      'supportPhone': supportPhone,
      'emailTemplatePrefix': emailTemplatePrefix,
      'receiptFooter': receiptFooter,
      'pdfReportHeader': pdfReportHeader,
      'notificationTitlePrefix': notificationTitlePrefix,
    };
  }

  Color get primaryColor => _parseColor(primaryColorHex);
  Color get secondaryColor => _parseColor(secondaryColorHex);
  Color get accentColor => _parseColor(accentColorHex);

  BrandingConfig copyWith({
    String? appName,
    String? logoUrl,
    String? faviconUrl,
    String? primaryColorHex,
    String? secondaryColorHex,
    String? accentColorHex,
    String? supportEmail,
    String? supportPhone,
    String? emailTemplatePrefix,
    String? receiptFooter,
    String? pdfReportHeader,
    String? notificationTitlePrefix,
  }) {
    return BrandingConfig(
      appName: appName ?? this.appName,
      logoUrl: logoUrl ?? this.logoUrl,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      emailTemplatePrefix:
          emailTemplatePrefix ?? this.emailTemplatePrefix,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      pdfReportHeader: pdfReportHeader ?? this.pdfReportHeader,
      notificationTitlePrefix:
          notificationTitlePrefix ?? this.notificationTitlePrefix,
    );
  }

  static Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.startsWith('#')) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF1B5E20);
    }
  }
}

/// White-label configuration allowing a tenant to present the platform as
/// their own product on a custom domain with their own name and branding.
class WhiteLabelConfig {
  final bool enabled;
  final String? customDomain;
  final String? mobileAppName;
  final String? mobilePackageId;
  final bool hideSmartChamaBadge;
  final bool useCustomColors;

  WhiteLabelConfig({
    this.enabled = false,
    this.customDomain,
    this.mobileAppName,
    this.mobilePackageId,
    this.hideSmartChamaBadge = false,
    this.useCustomColors = true,
  });

  factory WhiteLabelConfig.fromMap(Map<String, dynamic> map) {
    return WhiteLabelConfig(
      enabled: map['enabled'] ?? false,
      customDomain: map['customDomain'],
      mobileAppName: map['mobileAppName'],
      mobilePackageId: map['mobilePackageId'],
      hideSmartChamaBadge: map['hideSmartChamaBadge'] ?? false,
      useCustomColors: map['useCustomColors'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'customDomain': customDomain,
      'mobileAppName': mobileAppName,
      'mobilePackageId': mobilePackageId,
      'hideSmartChamaBadge': hideSmartChamaBadge,
      'useCustomColors': useCustomColors,
    };
  }
}

/// Tenant-level feature toggles, security policy and configurable rules.
class OrganizationSettings {
  final bool allowMemberInvites;
  final bool requireTwoFactor;
  final bool enforceLockAfterFailedLogins;
  final int maxFailedLogins;
  final bool enableAiAdvisor;
  final bool enableFraudDetection;
  final bool enablePredictiveAnalytics;
  final bool enableWhiteLabel;
  final bool enableApiAccess;
  final Map<String, dynamic> rules;

  OrganizationSettings({
    this.allowMemberInvites = true,
    this.requireTwoFactor = false,
    this.enforceLockAfterFailedLogins = true,
    this.maxFailedLogins = 5,
    this.enableAiAdvisor = true,
    this.enableFraudDetection = true,
    this.enablePredictiveAnalytics = true,
    this.enableWhiteLabel = false,
    this.enableApiAccess = false,
    this.rules = const {},
  });

  factory OrganizationSettings.fromMap(Map<String, dynamic> map) {
    return OrganizationSettings(
      allowMemberInvites: map['allowMemberInvites'] ?? true,
      requireTwoFactor: map['requireTwoFactor'] ?? false,
      enforceLockAfterFailedLogins:
          map['enforceLockAfterFailedLogins'] ?? true,
      maxFailedLogins: map['maxFailedLogins'] ?? 5,
      enableAiAdvisor: map['enableAiAdvisor'] ?? true,
      enableFraudDetection: map['enableFraudDetection'] ?? true,
      enablePredictiveAnalytics: map['enablePredictiveAnalytics'] ?? true,
      enableWhiteLabel: map['enableWhiteLabel'] ?? false,
      enableApiAccess: map['enableApiAccess'] ?? false,
      rules: Map<String, dynamic>.from(map['rules'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allowMemberInvites': allowMemberInvites,
      'requireTwoFactor': requireTwoFactor,
      'enforceLockAfterFailedLogins': enforceLockAfterFailedLogins,
      'maxFailedLogins': maxFailedLogins,
      'enableAiAdvisor': enableAiAdvisor,
      'enableFraudDetection': enableFraudDetection,
      'enablePredictiveAnalytics': enablePredictiveAnalytics,
      'enableWhiteLabel': enableWhiteLabel,
      'enableApiAccess': enableApiAccess,
      'rules': rules,
    };
  }

  OrganizationSettings copyWith({
    bool? allowMemberInvites,
    bool? requireTwoFactor,
    bool? enforceLockAfterFailedLogins,
    int? maxFailedLogins,
    bool? enableAiAdvisor,
    bool? enableFraudDetection,
    bool? enablePredictiveAnalytics,
    bool? enableWhiteLabel,
    bool? enableApiAccess,
    Map<String, dynamic>? rules,
  }) {
    return OrganizationSettings(
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
      requireTwoFactor: requireTwoFactor ?? this.requireTwoFactor,
      enforceLockAfterFailedLogins:
          enforceLockAfterFailedLogins ?? this.enforceLockAfterFailedLogins,
      maxFailedLogins: maxFailedLogins ?? this.maxFailedLogins,
      enableAiAdvisor: enableAiAdvisor ?? this.enableAiAdvisor,
      enableFraudDetection: enableFraudDetection ?? this.enableFraudDetection,
      enablePredictiveAnalytics:
          enablePredictiveAnalytics ?? this.enablePredictiveAnalytics,
      enableWhiteLabel: enableWhiteLabel ?? this.enableWhiteLabel,
      enableApiAccess: enableApiAccess ?? this.enableApiAccess,
      rules: rules ?? this.rules,
    );
  }
}
