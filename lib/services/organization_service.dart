import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/organization_model.dart';
import 'package:smartchama/models/role_permission_model.dart';

/// Multi-tenant organization service. Every tenant's data is isolated under
/// `organizations/{organizationId}` and its chama sub-collections, enforcing
/// tenant boundaries at the data layer.
class OrganizationService {
  static final OrganizationService _instance = OrganizationService._internal();
  factory OrganizationService() => _instance;
  OrganizationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _orgs => _firestore.collection('organizations');

  /// Creates a new tenant and assigns the creator as [OrganizationRole.owner].
  Future<Organization> createOrganization({
    required String name,
    required String ownerId,
    String? description,
    String regionCode = 'KE',
    String planId = 'free',
  }) async {
    final now = DateTime.now();
    final doc = _orgs.doc();
    final org = Organization(
      id: doc.id,
      name: name,
      description: description,
      ownerId: ownerId,
      createdAt: now,
      updatedAt: now,
      regionCode: regionCode,
      planId: planId,
      branding: BrandingConfig(appName: name),
    );
    await doc.set(org.toMap());

    // Assign owner role membership.
    await _orgs
        .doc(doc.id)
        .collection('members')
        .doc(ownerId)
        .set(MemberRole(
          id: ownerId,
          organizationId: doc.id,
          userId: ownerId,
          role: OrganizationRole.owner,
          assignedAt: now,
        ).toMap());

    return org;
  }

  Future<Organization?> getOrganization(String organizationId) async {
    final doc = await _orgs.doc(organizationId).get();
    if (!doc.exists) return null;
    return Organization.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<List<Organization>> getOrganizationsForOwner(String ownerId) async {
    final snapshot =
        await _orgs.where('ownerId', isEqualTo: ownerId).get();
    return snapshot.docs
        .map((d) => Organization.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<void> updateOrganization(Organization organization) async {
    await _orgs.doc(organization.id).update(organization.toMap());
  }

  Future<void> updateBranding(String organizationId, BrandingConfig branding) async {
    await _orgs.doc(organizationId).update({
      'branding': branding.toMap(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateWhiteLabel(
      String organizationId, WhiteLabelConfig whiteLabel) async {
    await _orgs.doc(organizationId).update({
      'whiteLabel': whiteLabel.toMap(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateSettings(
      String organizationId, OrganizationSettings settings) async {
    await _orgs.doc(organizationId).update({
      'settings': settings.toMap(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> setPlan(String organizationId, String planId) async {
    await _orgs.doc(organizationId).update({
      'planId': planId,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Independent member management scoped to the tenant.
  Future<void> addMember({
    required String organizationId,
    required String userId,
    required OrganizationRole role,
    String? memberName,
  }) async {
    await _orgs
        .doc(organizationId)
        .collection('members')
        .doc(userId)
        .set(MemberRole(
          id: userId,
          organizationId: organizationId,
          userId: userId,
          memberName: memberName,
          role: role,
          assignedAt: DateTime.now(),
        ).toMap());
    await _recomputeCounts(organizationId);
  }

  Future<void> updateMemberRole({
    required String organizationId,
    required String userId,
    required OrganizationRole role,
  }) async {
    await _orgs
        .doc(organizationId)
        .collection('members')
        .doc(userId)
        .update({'role': role.index});
  }

  Future<void> removeMember({
    required String organizationId,
    required String userId,
  }) async {
    await _orgs
        .doc(organizationId)
        .collection('members')
        .doc(userId)
        .delete();
    await _recomputeCounts(organizationId);
  }

  Future<MemberRole?> getMemberRole(
      String organizationId, String userId) async {
    final doc = await _orgs
        .doc(organizationId)
        .collection('members')
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    return MemberRole.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<List<MemberRole>> getMembers(String organizationId) async {
    final snapshot = await _orgs
        .doc(organizationId)
        .collection('members')
        .orderBy('assignedAt')
        .get();
    return snapshot.docs
        .map((d) => MemberRole.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<void> _recomputeCounts(String organizationId) async {
    final members = await getMembers(organizationId);
    final chamas = await _orgs
        .doc(organizationId)
        .collection('chamas')
        .count()
        .get();
    await _orgs.doc(organizationId).update({
      'memberCount': members.length,
      'chamaCount': chamas.count,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
