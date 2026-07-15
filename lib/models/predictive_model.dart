enum ForecastMetric {
  savingsGrowth,
  loanDefaults,
  cashFlow,
  membershipGrowth,
  investmentReturns,
}

extension ForecastMetricExtension on ForecastMetric {
  String get displayName {
    switch (this) {
      case ForecastMetric.savingsGrowth:
        return 'Savings Growth';
      case ForecastMetric.loanDefaults:
        return 'Loan Defaults';
      case ForecastMetric.cashFlow:
        return 'Cash Flow';
      case ForecastMetric.membershipGrowth:
        return 'Membership Growth';
      case ForecastMetric.investmentReturns:
        return 'Investment Returns';
    }
  }
}

class ForecastPoint {
  final DateTime period;
  final double value;
  final double lowerBound;
  final double upperBound;

  ForecastPoint({
    required this.period,
    required this.value,
    this.lowerBound = 0,
    this.upperBound = 0,
  });

  factory ForecastPoint.fromMap(Map<String, dynamic> map) {
    return ForecastPoint(
      period: map['period'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['period'])
          : DateTime.now(),
      value: (map['value'] ?? 0).toDouble(),
      lowerBound: (map['lowerBound'] ?? 0).toDouble(),
      upperBound: (map['upperBound'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'period': period.millisecondsSinceEpoch,
      'value': value,
      'lowerBound': lowerBound,
      'upperBound': upperBound,
    };
  }
}

class Forecast {
  final String id;
  final String organizationId;
  final String? chamaId;
  final ForecastMetric metric;
  final List<ForecastPoint> points;
  final double confidence;
  final DateTime generatedAt;
  final String currency;

  Forecast({
    required this.id,
    required this.organizationId,
    this.chamaId,
    required this.metric,
    required this.points,
    this.confidence = 0.8,
    required this.generatedAt,
    this.currency = 'KES',
  });

  factory Forecast.fromMap(Map<String, dynamic> map, String id) {
    return Forecast(
      id: id,
      organizationId: map['organizationId'] ?? '',
      chamaId: map['chamaId'],
      metric: ForecastMetric.values[map['metric'] ?? 0],
      points: (map['points'] as List? ?? [])
          .map((e) => ForecastPoint.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      confidence: (map['confidence'] ?? 0.8).toDouble(),
      generatedAt: map['generatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['generatedAt'])
          : DateTime.now(),
      currency: map['currency'] ?? 'KES',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'chamaId': chamaId,
      'metric': metric.index,
      'points': points.map((p) => p.toMap()).toList(),
      'confidence': confidence,
      'generatedAt': generatedAt.millisecondsSinceEpoch,
      'currency': currency,
    };
  }

  double get projectedTotal =>
      points.fold(0, (sum, p) => sum + p.value);

  double? get trend {
    if (points.length < 2) return null;
    final first = points.first.value;
    final last = points.last.value;
    if (first == 0) return null;
    return ((last - first) / first) * 100;
  }
}
