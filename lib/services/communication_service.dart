import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/communication_model.dart';

/// Communication Center. Centralises announcements, push, SMS, email,
/// in-app chat and meeting invitations across a tenant.
class CommunicationService {
  static final CommunicationService _instance =
      CommunicationService._internal();
  factory CommunicationService() => _instance;
  CommunicationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _messages(String orgId) => _firestore
      .collection('organizations')
      .doc(orgId)
      .collection('communications');

  Future<CommunicationMessage> send({
    required String organizationId,
    required MessageChannel channel,
    required String subject,
    required String body,
    required List<String> recipientIds,
    String? chamaId,
    String? createdBy,
  }) async {
    final now = DateTime.now();
    final doc = _messages(organizationId).doc();
    final message = CommunicationMessage(
      id: doc.id,
      organizationId: organizationId,
      chamaId: chamaId,
      channel: channel,
      subject: subject,
      body: body,
      recipientIds: recipientIds,
      recipientCount: recipientIds.length,
      status: MessageStatus.sent,
      createdAt: now,
      sentAt: now,
      createdBy: createdBy,
    );
    await doc.set(message.toMap());
    return message;
  }

  Future<CommunicationMessage> schedule({
    required String organizationId,
    required MessageChannel channel,
    required String subject,
    required String body,
    required List<String> recipientIds,
    required DateTime scheduledAt,
    String? createdBy,
  }) async {
    final doc = _messages(organizationId).doc();
    final message = CommunicationMessage(
      id: doc.id,
      organizationId: organizationId,
      channel: channel,
      subject: subject,
      body: body,
      recipientIds: recipientIds,
      recipientCount: recipientIds.length,
      status: MessageStatus.scheduled,
      createdAt: DateTime.now(),
      scheduledAt: scheduledAt,
      createdBy: createdBy,
    );
    await doc.set(message.toMap());
    return message;
  }

  Future<List<CommunicationMessage>> getMessages(String organizationId,
      {int limit = 50}) async {
    final snapshot = await _messages(organizationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((d) => CommunicationMessage.fromMap(
            d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  /// Returns tenant members that can be messaged (recipient directory).
  Future<List<Map<String, dynamic>>> getRecipients(String organizationId) async {
    final snapshot = await _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('members')
        .get();
    return snapshot.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList();
  }
}
