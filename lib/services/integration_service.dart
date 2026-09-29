import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/integration_model.dart';

/// Manages third-party integrations (accounting, payroll, banking, government,
/// CRM) for a tenant, including connection status and sync metadata.
class IntegrationService {
  static final IntegrationService _instance = IntegrationService._internal();
  factory IntegrationService() => _instance;
  IntegrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _integrations(String orgId) => _firestore
      .collection('organizations')
      .doc(orgId)
      .collection('integrations');

  Future<ApiIntegration> connect({
    required String organizationId,
    required IntegrationType type,
    required String name,
    String? baseUrl,
    String? apiKey,
    Map<String, dynamic> config = const {},
  }) async {
    final doc = _integrations(organizationId).doc();
    final masked = apiKey != null && apiKey.isNotEmpty
        ? '****${apiKey.substring(apiKey.length - 4)}'
        : null;
    final integration = ApiIntegration(
      id: doc.id,
      organizationId: organizationId,
      type: type,
      name: name,
      baseUrl: baseUrl,
      maskedApiKey: masked,
      status: IntegrationStatus.connected,
      config: config,
      createdAt: DateTime.now(),
      lastSyncAt: DateTime.now(),
    );
    await doc.set(integration.toMap());
    return integration;
  }

  Future<void> updateStatus(
    String organizationId,
    String integrationId, {
    required IntegrationStatus status,
    String? error,
  }) async {
    await _integrations(organizationId).doc(integrationId).update({
      'status': status.index,
      'lastSyncAt': DateTime.now().millisecondsSinceEpoch,
      'lastSyncError': error,
    });
  }

  Future<void> disconnect(String organizationId, String integrationId) async {
    await _integrations(organizationId).doc(integrationId).update({
      'status': IntegrationStatus.disconnected.index,
    });
  }

  Future<List<ApiIntegration>> getIntegrations(String organizationId) async {
    final snapshot = await _integrations(organizationId).get();
    return snapshot.docs
        .map((d) =>
            ApiIntegration.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  /// Simulates a sync run for an integration and returns a result summary.
  Future<Map<String, dynamic>> sync(String organizationId, String integrationId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      await updateStatus(organizationId, integrationId,
          status: IntegrationStatus.connected);
      return {'success': true, 'records': 10};
    } catch (e) {
      await updateStatus(organizationId, integrationId,
          status: IntegrationStatus.error, error: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }
}
