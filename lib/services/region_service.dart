import 'package:smartchama/models/region_model.dart';

/// Regional expansion helper. Resolves the active region for a tenant and
/// exposes currency formatting, supported payment methods and compliance
/// settings for cross-country operation.
class RegionService {
  static final RegionService _instance = RegionService._internal();
  factory RegionService() => _instance;
  RegionService._internal();

  Region getRegion(String code) => Region.getByCode(code);

  List<Region> get supportedRegions => Region.all;

  CurrencyFormatter formatterFor(String code) {
    final region = getRegion(code);
    return CurrencyFormatter(region.currencyCode, region.currencySymbol);
  }

  String format(String code, double amount) =>
      formatterFor(code).format(amount);

  /// Validates that an organization's configured rules are consistent with
  /// the active region (e.g. supported language/payment method).
  List<String> validate(Region region, Map<String, dynamic> rules) {
    final issues = <String>[];
    final language = rules['language'] as String?;
    if (language != null && !region.supportedLanguages.contains(language)) {
      issues.add(
          'Language "$language" is not supported in ${region.name}.');
    }
    final method = rules['paymentMethod'] as String?;
    if (method != null && !region.paymentMethods.contains(method)) {
      issues.add(
          'Payment method "$method" is not available in ${region.name}.');
    }
    return issues;
  }

  Region copyWithOverrides(Region region, Map<String, dynamic> overrides) {
    return region.copyWith(
      defaultLanguage: overrides['defaultLanguage'] ?? region.defaultLanguage,
      paymentMethods: overrides['paymentMethods'] != null
          ? List<String>.from(overrides['paymentMethods'])
          : region.paymentMethods,
      defaultTaxRate: overrides['defaultTaxRate'] ?? region.defaultTaxRate,
    );
  }
}
