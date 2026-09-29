import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/core/result.dart';
import 'package:smartchama/models/chama_model.dart';
import 'package:smartchama/repositories/chama_repository.dart';
import 'package:smartchama/services/chama_service.dart';

class FirestoreChamaRepository implements ChamaRepository {
  final FirebaseFirestore _firestore;
  final ChamaService _service;

  FirestoreChamaRepository(this._firestore)
      : _service = ChamaService(firestore: _firestore);

  @override
  Future<Result<CreatedChama>> createChama({
    required String name,
    String? description,
    String? organizationId,
    Map<String, dynamic>? features,
    Map<String, dynamic>? rules,
    String? logoUrl,
    String entityType = 'chama',
  }) async {
    try {
      final created = await _service.createChama(
        name: name,
        description: description,
        organizationId: organizationId,
        features: features,
        rules: rules,
        logoUrl: logoUrl,
        entityType: entityType,
      );
      return Success(created);
    } on ChamaException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to create chama: $e');
    }
  }

  @override
  Future<Result<CodeLookup>> findChamaByInviteCode(String rawCode) async {
    try {
      final lookup = await _service.findChamaByInviteCode(rawCode);
      return Success(lookup);
    } catch (e) {
      return Failure('Failed to lookup invite code: $e');
    }
  }

  @override
  Future<Result<ChamaRef?>> resolveUserChama(String userId) async {
    try {
      final ref = await _service.resolveUserChama(userId);
      return Success(ref);
    } catch (e) {
      return Failure('Failed to resolve user chama: $e');
    }
  }

  @override
  Future<Result<JoinChamaResult>> joinChamaWithCode({
    required String inviteCode,
    String? name,
    String? email,
  }) async {
    try {
      final result = await _service.joinChamaWithCode(
        inviteCode: inviteCode,
        name: name,
        email: email,
      );
      return Success(result);
    } on ChamaException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to join chama: $e');
    }
  }

  @override
  Future<Result<Chama?>> getChama(String organizationId, String chamaId) async {
    try {
      final chama = await _service.getChama(organizationId, chamaId);
      return Success(chama);
    } catch (e) {
      return Failure('Failed to get chama: $e');
    }
  }

  @override
  Future<Result<bool>> updateChama(
    String organizationId,
    String chamaId,
    Map<String, dynamic> data,
  ) async {
    try {
      final success = await _service.updateChama(organizationId, chamaId, data);
      return Success(success);
    } catch (e) {
      return Failure('Failed to update chama: $e');
    }
  }

  @override
  Future<Result<bool>> deleteChama(String organizationId, String chamaId) async {
    try {
      final success = await _service.deleteChama(organizationId, chamaId);
      return Success(success);
    } catch (e) {
      return Failure('Failed to delete chama: $e');
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getMembers(
    String organizationId,
    String chamaId,
  ) async {
    try {
      final members = await _service.getMembers(organizationId, chamaId);
      return Success(members);
    } catch (e) {
      return Failure('Failed to get members: $e');
    }
  }

  @override
  Future<Result<bool>> setMemberStatus(
    String organizationId,
    String chamaId,
    String memberId,
    String status,
  ) async {
    try {
      final success = await _service.setMemberStatus(
        organizationId,
        chamaId,
        memberId,
        status,
      );
      return Success(success);
    } catch (e) {
      return Failure('Failed to set member status: $e');
    }
  }

  @override
  Future<Result<bool>> removeMember(
    String organizationId,
    String chamaId,
    String memberId,
  ) async {
    try {
      final success = await _service.removeMember(
        organizationId,
        chamaId,
        memberId,
      );
      return Success(success);
    } catch (e) {
      return Failure('Failed to remove member: $e');
    }
  }

  @override
  Future<Result<bool>> updateMemberRole(
    String organizationId,
    String chamaId,
    String memberId,
    String role,
  ) async {
    try {
      final success = await _service.updateMemberRole(
        organizationId,
        chamaId,
        memberId,
        role,
      );
      return Success(success);
    } catch (e) {
      return Failure('Failed to update member role: $e');
    }
  }

  @override
  Stream<List<Chama>> streamUserChamas({
    required String organizationId,
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    var query = _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('chamas')
        .where('memberIds', arrayContains: userId)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Chama.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Stream<Chama?> streamChama(String organizationId, String chamaId) {
    return _firestore
        .collection('organizations')
        .doc(organizationId)
        .collection('chamas')
        .doc(chamaId)
        .snapshots()
        .map((doc) => doc.exists ? Chama.fromFirestore(doc) : null);
  }

  @override
  Future<Result<String>> ensureOrganization({
    String? organizationId,
    String ownerName = 'My Organization',
  }) async {
    try {
      final orgId = await _service.ensureOrganization(
        organizationId: organizationId,
        ownerName: ownerName,
      );
      return Success(orgId);
    } on ChamaException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to ensure organization: $e');
    }
  }
}