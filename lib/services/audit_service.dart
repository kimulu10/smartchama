import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/audit_log.dart';

class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _auditLogs => _firestore.collection('auditLogs');

  Future<void> logAction({
    required String chamaId,
    required String userId,
    required AuditAction action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
  }) async {
    final doc = _auditLogs.doc();
    await doc.set(AuditLog(
      id: doc.id,
      chamaId: chamaId,
      userId: userId,
      action: action.displayName,
      entityType: entityType,
      entityId: entityId,
      previousValues: previousValues,
      newValues: newValues,
      timestamp: DateTime.now(),
    ).toMap());
  }

  Future<List<AuditLog>> getAuditLogs({
    required String chamaId,
    String? entityType,
    String? entityId,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _auditLogs.where('chamaId', isEqualTo: chamaId);

    if (entityType != null) {
      query = query.where('entityType', isEqualTo: entityType);
    }
    if (entityId != null) {
      query = query.where('entityId', isEqualTo: entityId);
    }

    final snapshot =
        await query.orderBy('timestamp', descending: true).limit(limit).get();

    return snapshot.docs
        .map((doc) =>
            AuditLog.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<List<AuditLog>> getUserActivity({
    required String chamaId,
    required String userId,
    int limit = 20,
  }) async {
    final snapshot = await _auditLogs
        .where('chamaId', isEqualTo: chamaId)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) =>
            AuditLog.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}
