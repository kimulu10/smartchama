import 'package:flutter/material.dart';

/// A supported region/country configuration for cross-border expansion.
class Region {
  final String code;
  final String name;
  final String currencyCode;
  final String currencySymbol;
  final String defaultLanguage;
  final List<String> supportedLanguages;
  final List<String> paymentMethods;
  final double defaultTaxRate;
  final Map<String, dynamic> compliance;

  const Region({
    required this.code,
    required this.name,
    required this.currencyCode,
    required this.currencySymbol,
    required this.defaultLanguage,
    required this.supportedLanguages,
    required this.paymentMethods,
    this.defaultTaxRate = 0,
    this.compliance = const {},
  });

  static const kenya = Region(
    code: 'KE',
    name: 'Kenya',
    currencyCode: 'KES',
    currencySymbol: 'KSh',
    defaultLanguage: 'en',
    supportedLanguages: ['en', 'sw'],
    paymentMethods: ['M-Pesa', 'Airtel Money', 'Bank Transfer', 'Card'],
    defaultTaxRate: 0,
    compliance: {'vatRegistered': false},
  );

  static const uganda = Region(
    code: 'UG',
    name: 'Uganda',
    currencyCode: 'UGX',
    currencySymbol: 'USh',
    defaultLanguage: 'en',
    supportedLanguages: ['en', 'lg'],
    paymentMethods: ['MTN Mobile Money', 'Airtel Money', 'Bank Transfer'],
    defaultTaxRate: 0,
    compliance: {'vatRegistered': false},
  );

  static const tanzania = Region(
    code: 'TZ',
    name: 'Tanzania',
    currencyCode: 'TZS',
    currencySymbol: 'TSh',
    defaultLanguage: 'en',
    supportedLanguages: ['en', 'sw'],
    paymentMethods: ['M-Pesa', 'Tigo Pesa', 'Airtel Money', 'Bank Transfer'],
    defaultTaxRate: 0,
    compliance: {'vatRegistered': false},
  );

  static const southAfrica = Region(
    code: 'ZA',
    name: 'South Africa',
    currencyCode: 'ZAR',
    currencySymbol: 'R',
    defaultLanguage: 'en',
    supportedLanguages: ['en', 'af', 'zu'],
    paymentMethods: ['EFT', 'Card', 'SnapScan', 'Bank Transfer'],
    defaultTaxRate: 15,
    compliance: {'vatRegistered': true},
  );

  static const nigeria = Region(
    code: 'NG',
    name: 'Nigeria',
    currencyCode: 'NGN',
    currencySymbol: '₦',
    defaultLanguage: 'en',
    supportedLanguages: ['en', 'yo', 'ig', 'ha'],
    paymentMethods: ['Flutterwave', 'Paystack', 'Bank Transfer', 'Card'],
    defaultTaxRate: 7.5,
    compliance: {'vatRegistered': true},
  );

  static const List<Region> all = [
    kenya,
    uganda,
    tanzania,
    southAfrica,
    nigeria,
  ];

  static Region getByCode(String code) =>
      all.firstWhere((r) => r.code == code, orElse: () => kenya);

  Region copyWith({
    String? code,
    String? name,
    String? currencyCode,
    String? currencySymbol,
    String? defaultLanguage,
    List<String>? supportedLanguages,
    List<String>? paymentMethods,
    double? defaultTaxRate,
    Map<String, dynamic>? compliance,
  }) {
    return Region(
      code: code ?? this.code,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      compliance: compliance ?? this.compliance,
    );
  }
}

/// A configurable, tenant-specific business rule.
class OrganizationRule {
  final String key;
  final String label;
  final RuleType type;
  final dynamic value;
  final String description;

  const OrganizationRule({
    required this.key,
    required this.label,
    required this.type,
    required this.value,
    required this.description,
  });
}

enum RuleType { boolean, number, text, choice }

extension RuleTypeExtension on RuleType {
  String get displayName {
    switch (this) {
      case RuleType.boolean:
        return 'Toggle';
      case RuleType.number:
        return 'Number';
      case RuleType.text:
        return 'Text';
      case RuleType.choice:
        return 'Choice';
    }
  }
}

class CurrencyFormatter {
  final String code;
  final String symbol;

  const CurrencyFormatter(this.code, this.symbol);

  String format(double amount) {
    final abs = amount.abs();
    final formatted = abs
        .toStringAsFixed(2)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},');
    final sign = amount < 0 ? '-' : '';
    return '$sign$symbol $formatted';
  }
}
