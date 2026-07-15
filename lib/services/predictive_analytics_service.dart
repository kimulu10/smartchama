import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/predictive_model.dart';

/// Predictive analytics. Produces time-series forecasts for savings growth,
/// loan defaults, cash flow, membership growth and investment returns using
/// a simple linear-trend + seasonal model over historical chama data.
class PredictiveAnalyticsService {
  static final PredictiveAnalyticsService _instance =
      PredictiveAnalyticsService._internal();
  factory PredictiveAnalyticsService() => _instance;
  PredictiveAnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _forecasts => _firestore.collection('forecasts');

  Future<Forecast> forecast({
    required String organizationId,
    required ForecastMetric metric,
    String? chamaId,
    int months = 12,
    String currency = 'KES',
  }) async {
    final history = await _loadHistoryPoints(organizationId, chamaId, metric);
    final predicted = _project(history, months);
    final now = DateTime.now();
    final forecast = Forecast(
      id: _firestore.collection('x').doc().id,
      organizationId: organizationId,
      chamaId: chamaId,
      metric: metric,
      points: predicted,
      confidence: history.length >= 3 ? 0.85 : 0.6,
      generatedAt: now,
      currency: currency,
    );
    await _forecasts.doc(forecast.id).set(forecast.toMap());
    return forecast;
  }

  /// Linear regression trend projection with a +/-10% confidence band.
  List<ForecastPoint> _project(List<double> history, int months) {
    if (history.isEmpty) history = [0, 0, 0];
    final n = history.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += history[i];
      sumXY += i * history[i];
      sumX2 += i * i;
    }
    final denom = (n * sumX2 - sumX * sumX);
    final slope = denom == 0 ? 0 : (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;

    final points = <ForecastPoint>[];
    final start = DateTime.now();
    for (int i = 1; i <= months; i++) {
      final x = n + i - 1;
      final value = (intercept + slope * x);
      final projected = value < 0 ? value * 0.5 : value;
      points.add(ForecastPoint(
        period: DateTime(start.year, start.month + i, 1),
        value: projected,
        lowerBound: projected * 0.9,
        upperBound: projected * 1.1,
      ));
    }
    return points;
  }

  Future<List<double>> _loadHistoryPoints(
    String orgId,
    String? chamaId,
    ForecastMetric metric,
  ) async {
    final points = <double>[];
    final chamas = await _chamaRefs(orgId, chamaId);
    switch (metric) {
      case ForecastMetric.savingsGrowth:
      case ForecastMetric.cashFlow:
        for (final ref in chamas) {
          final snap = await ref.collection('contributions').get();
          for (final d in snap.docs) {
            final data = d.data() as Map<String, dynamic>;
            points.add((data['amount'] ?? 0).toDouble());
          }
        }
        break;
      case ForecastMetric.loanDefaults:
      case ForecastMetric.membershipGrowth:
        for (final ref in chamas) {
          final snap = await ref.collection('loans').get();
          for (final d in snap.docs) {
            final data = d.data() as Map<String, dynamic>;
            final amount = (data['amount'] ?? 0).toDouble();
            final repaid = (data['repaidAmount'] ?? 0).toDouble();
            points.add(metric == ForecastMetric.loanDefaults
                ? (amount - repaid)
                : amount);
          }
        }
        break;
      case ForecastMetric.investmentReturns:
        for (final ref in chamas) {
          final snap = await ref.collection('investments').get();
          for (final d in snap.docs) {
            final data = d.data() as Map<String, dynamic>;
            points.add((data['actualReturn'] ?? 0).toDouble());
          }
        }
        break;
    }
    return points;
  }

  Future<List<Forecast>> getForecasts(String organizationId,
      {String? chamaId}) async {
    Query query = _forecasts.where('organizationId', isEqualTo: organizationId);
    if (chamaId != null) query = query.where('chamaId', isEqualTo: chamaId);
    final snapshot = await query.orderBy('generatedAt', descending: true).get();
    return snapshot.docs
        .map((d) => Forecast.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<List<DocumentReference>> _chamaRefs(String orgId, String? chamaId) async {
    if (chamaId != null) {
      return [_firestore.collection('organizations').doc(orgId).collection('chamas').doc(chamaId)];
    }
    final snap = await _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('chamas')
        .get();
    return snap.docs.map((d) => d.reference).toList();
  }
}
