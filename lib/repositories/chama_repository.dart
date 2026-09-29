import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/core/result.dart';
import 'package:smartchama/models/chama_model.dart';
import 'package:smartchama/services/chama_service.dart';

abstract class ChamaRepository {
  Future<Result<CreatedChama>> createChama({
    required String name,
    String? description,
    String? organizationId,
    Map<String, dynamic>? features,
    Map<String, dynamic>? rules,
    String? logoUrl,
    String entityType,
  });

  Future<Result<CodeLookup>> findChamaByInviteCode(String rawCode);

  Future<Result<ChamaRef?>> resolveUserChama(String userId);

  Future<Result<JoinChamaResult>> joinChamaWithCode({
    required String inviteCode,
    String? name,
    String? email,
  });

  Future<Result<Chama?>> getChama(String organizationId, String chamaId);

  Future<Result<bool>> updateChama(
    String organizationId,
    String chamaId,
    Map<String, dynamic> data,
  );

  Future<Result<bool>> deleteChama(String organizationId, String chamaId);

  Future<Result<List<Map<String, dynamic>>>> getMembers(
    String organizationId,
    String chamaId,
  );

  Future<Result<bool>> setMemberStatus(
    String organizationId,
    String chamaId,
    String memberId,
    String status,
  );

  Future<Result<bool>> removeMember(
    String organizationId,
    String chamaId,
    String memberId,
  );

  Future<Result<bool>> updateMemberRole(
    String organizationId,
    String chamaId,
    String memberId,
    String role,
  );

  Stream<List<Chama>> streamUserChamas({
    required String organizationId,
    required String userId,
    int limit,
    DocumentSnapshot? startAfter,
  });

  Stream<Chama?> streamChama(String organizationId, String chamaId);

  Future<Result<String>> ensureOrganization({
    String? organizationId,
    String ownerName,
  });
}