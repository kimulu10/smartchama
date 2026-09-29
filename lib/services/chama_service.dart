import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:smartchama/models/chama_model.dart';
import 'package:smartchama/services/notification_service.dart';

/// Error thrown for any recoverable chama flow problem so the UI can show a
/// readable message instead of a generic failure.
class ChamaException implements Exception {
  final String message;

  ChamaException(this.message);

  @override
  String toString() => message;
}

/// Points at a single chama stored under `organizations/{organizationId}/chamas`.
class ChamaRef {
  final String organizationId;
  final String chamaId;

  const ChamaRef({required this.organizationId, required this.chamaId});

  @override
  bool operator ==(Object other) =>
      other is ChamaRef &&
      other.organizationId == organizationId &&
      other.chamaId == chamaId;

  @override
  int get hashCode => Object.hash(organizationId, chamaId);

  @override
  String toString() => '$organizationId/$chamaId';
}

class CreatedChama {
  final ChamaRef ref;
  final String inviteCode;
  final String name;

  const CreatedChama({
    required this.ref,
    required this.inviteCode,
    required this.name,
  });
}

enum JoinChamaStatus { joined, alreadyMember, invalidCode, notAuthenticated }
class JoinChamaResult {
  final JoinChamaStatus status;
  final ChamaRef? ref;
  final String? chamaName;
  final String? message;

  const JoinChamaResult._(this.status, {this.ref, this.chamaName, this.message});

  const JoinChamaResult.joined({required ChamaRef ref, required String chamaName})
      : this._(JoinChamaStatus.joined, ref: ref, chamaName: chamaName);

  const JoinChamaResult.alreadyMember({required ChamaRef ref, required String chamaName})
      : this._(JoinChamaStatus.alreadyMember, ref: ref, chamaName: chamaName);

  const JoinChamaResult.invalidCode([String? message])
      : this._(JoinChamaStatus.invalidCode, message: message);

  const JoinChamaResult.notAuthenticated()
      : this._(JoinChamaStatus.notAuthenticated,
            message: "Please sign in before joining a chama.");

  bool get isSuccess =>
      status == JoinChamaStatus.joined || status == JoinChamaStatus.alreadyMember;
}

/// Outcome of an invite code lookup. [error] carries the real reason a lookup
/// failed so the UI never shows a misleading "invalid code".
class CodeLookup {
  final ChamaRef? ref;
  final String? error;

  const CodeLookup._({this.ref, this.error});

  const CodeLookup.found(ChamaRef ref) : this._(ref: ref);

  const CodeLookup.notFound()
      : this._(
          error:
              "Invalid invite code. Please check the code and try again.",
        );

  const CodeLookup.failed(String reason) : this._(error: reason);

  bool get isSuccess => ref != null;
}

/// Single source of truth for chama creation / lookup / membership.
///
/// Every document lives at `organizations/{organizationId}/chamas/{chamaId}`
/// because that is the path the rest of the app reads from. An organization is
/// created automatically for the creator when one does not exist yet.
/// The signed in user details the service operates on. Wrapped in a class so the
/// flow can be exercised in tests without a real Firebase Auth session.
class ChamaSession {
  final String uid;
  final String? email;
  final String? displayName;

  const ChamaSession({required this.uid, this.email, this.displayName});
}

class ChamaService {
  static const String _organizations = 'organizations';
  static const String _chamas = 'chamas';
  static const String _members = 'members';
  static const String _users = 'users';
  static const String _inviteCodes = 'invite_codes';
  static const int _codeLength = 6;
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore firestore;
  final FirebaseAuth? _auth;
  final Random _random;
  final ChamaSession? Function()? _sessionProvider;

  ChamaService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Random? random,
    ChamaSession? Function()? sessionProvider,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _random = random ?? Random.secure(),
        _sessionProvider = sessionProvider;

  ChamaSession? _session() {
    final provider = _sessionProvider;
    if (provider != null) return provider();

    final user = _auth?.currentUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return ChamaSession(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }

  // ---------------------------------------------------------------- paths

  DocumentReference<Map<String, dynamic>> _organizationRef(
          String organizationId) =>
      firestore.collection(_organizations).doc(organizationId);

  CollectionReference<Map<String, dynamic>> _chamasRef(String organizationId) =>
      _organizationRef(organizationId).collection(_chamas);

  DocumentReference<Map<String, dynamic>> _chamaRef(
          String organizationId, String chamaId) =>
      _chamasRef(organizationId).doc(chamaId);

  DocumentReference<Map<String, dynamic>> _memberRef(
          String organizationId, String chamaId, String uid) =>
      _chamaRef(organizationId, chamaId).collection(_members).doc(uid);

  DocumentReference<Map<String, dynamic>> _inviteCodeRef(String code) =>
      firestore.collection(_inviteCodes).doc(code);

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      firestore.collection(_users).doc(userId);

  // ------------------------------------------------------------- creation

  /// Creates the chama, the creator's membership, the invite code index and the
  /// user link in one atomic batch. Throws [ChamaException] with a readable
  /// message when anything goes wrong.
  Future<CreatedChama> createChama({
    required String name,
    String? description,
    String? organizationId,
    Map<String, dynamic>? features,
    Map<String, dynamic>? rules,
    String? logoUrl,
    String entityType = 'chama',
  }) async {
    final session = _session();
    if (session == null) {
      throw ChamaException("You need to be signed in to create a chama.");
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ChamaException("Please enter a chama name.");
    }

    try {
      final userDoc = await _userRef(session.uid).get();
      final userData = userDoc.data();
      final ownerName = (userData?['name'] ??
              session.displayName ??
              session.email ??
              'Owner')
          .toString();

      final orgId = await ensureOrganization(
        organizationId: organizationId,
        ownerName: ownerName,
      );

      final inviteCode = await _reserveInviteCode();
      final chamaRef = _chamasRef(orgId).doc();
      final now = Timestamp.now();
      final mergedRules = {..._defaultRules(), ...?rules};

      final batch = firestore.batch();

      batch.set(chamaRef, {
        'name': trimmedName,
        'description': description?.trim() ?? '',
        'organizationId': orgId,
        'createdBy': session.uid,
        'adminId': session.uid,
        'inviteCode': inviteCode,
        'logoUrl': logoUrl,
        'entityType': entityType,
        'createdAt': now,
        'updatedAt': now,
        'status': 'active',
        'memberIds': [session.uid],
        'features': features ?? _defaultFeatures(),
        'rules': mergedRules,
      });

      batch.set(
        _memberRef(orgId, chamaRef.id, session.uid),
        {
          'userId': session.uid,
          'name': ownerName,
          'email': session.email ?? '',
          'role': 'admin',
          'status': 'active',
          'joinedAt': now,
        },
      );

      batch.set(
        _userRef(session.uid),
        {
          'chamaId': chamaRef.id,
          'organizationId': orgId,
          'role': 'admin',
          'status': 'active',
          'chamaIds': FieldValue.arrayUnion([chamaRef.id]),
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      batch.set(
        _inviteCodeRef(inviteCode),
        {
          'chamaId': chamaRef.id,
          'organizationId': orgId,
          'chamaName': trimmedName,
          'active': true,
          'createdAt': now,
        },
      );

      await batch.commit();

      return CreatedChama(
        ref: ChamaRef(organizationId: orgId, chamaId: chamaRef.id),
        inviteCode: inviteCode,
        name: trimmedName,
      );
    } on ChamaException {
      rethrow;
    } catch (e) {
      throw ChamaException(_describeError(e));
    }
  }

  /// Returns the organization to create the chama under, creating one when the
  /// user has none yet.
  Future<String> ensureOrganization({
    String? organizationId,
    String ownerName = 'My Organization',
  }) async {
    final session = _session();
    if (session == null) {
      throw ChamaException("You need to be signed in to create a chama.");
    }

    try {
      String? targetId = organizationId?.trim();
      if (targetId == null || targetId.isEmpty) {
        final userDoc = await _userRef(session.uid).get();
        final stored = userDoc.data()?['organizationId'];
        if (stored is String && stored.isNotEmpty) {
          targetId = stored;
        }
      }

      if (targetId != null && targetId.isNotEmpty) {
        final ref = _organizationRef(targetId);
        if (!(await ref.get()).exists) {
          await ref.set({
            'name': '$ownerName Organization',
            'adminId': session.uid,
            'createdBy': session.uid,
            'createdAt': Timestamp.now(),
          });
        }
        return ref.id;
      }

      final userDoc = await _userRef(session.uid).get();
      final stored = userDoc.data()?['organizationId'];
      if (stored is String && stored.isNotEmpty) {
        final ref = _organizationRef(stored);
        if (!(await ref.get()).exists) {
          await ref.set({
            'name': '$ownerName Organization',
            'adminId': session.uid,
            'createdBy': session.uid,
            'createdAt': Timestamp.now(),
          });
        }
        return ref.id;
      }

      final ref = firestore.collection(_organizations).doc();
      await ref.set({
        'name': '$ownerName Organization',
        'adminId': session.uid,
        'createdBy': session.uid,
        'createdAt': Timestamp.now(),
      });

      await _userRef(session.uid).set(
        {'organizationId': ref.id, 'updatedAt': Timestamp.now()},
        SetOptions(merge: true),
      );

      return ref.id;
    } catch (e) {
      throw ChamaException(_describeError(e));
    }
  }

  // ------------------------------------------------------------- lookup

  /// Resolves an invite code to a chama without requiring membership.
  /// Checks the code index first, then falls back to the legacy top level
  /// `chamas` collection so chamas created before the index existed still work.
  Future<CodeLookup> findChamaByInviteCode(String rawCode) async {
    final code = normalizeCode(rawCode);
    if (code.isEmpty) return const CodeLookup.notFound();

    try {
      final indexed = await _lookupByCodeIndex(code);
      if (indexed != null) return CodeLookup.found(indexed);

      final legacyId = await _lookupLegacyChamaId(code);
      if (legacyId == null) return const CodeLookup.notFound();

      final migrated = await _migrateLegacyChama(legacyId);
      if (migrated != null) return CodeLookup.found(migrated);

      return const CodeLookup.failed(
        "This invite code belongs to a chama created before the upgrade. "
        "Ask the chama admin to open the app once so the code can be refreshed.",
      );
    } catch (e) {
      return CodeLookup.failed(_describeError(e));
    }
  }

  Future<ChamaRef?> _lookupByCodeIndex(String code) async {
    try {
      final doc = await _inviteCodeRef(code).get();
      if (!doc.exists) {
        debugPrintError('ChamaService: no invite_codes entry for $code');
        return null;
      }
      final data = doc.data();
      final organizationId = data?['organizationId'] as String?;
      final chamaId = data?['chamaId'] as String?;
      if (organizationId == null ||
          organizationId.isEmpty ||
          chamaId == null ||
          chamaId.isEmpty) {
        debugPrintError('ChamaService: invite code $code is incomplete');
        return null;
      }
      // The target chama document is not read here: a user redeeming a code is
      // not a member yet, so the security rules deny that read.
      return ChamaRef(organizationId: organizationId, chamaId: chamaId);
    } catch (e) {
      debugPrintError('ChamaService: invite code lookup failed: $e');
      rethrow;
    }
  }

  /// Looks the code up in the legacy top level `chamas` collection. Only the
  /// creator/admin of such a chama passes the security rules, so this returns a
  /// document id, null when the code is unknown, and rethrows real failures.
  Future<String?> _lookupLegacyChamaId(String code) async {
    try {
      final snapshot = await firestore
          .collection(_chamas)
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } on FirebaseException catch (e) {
      // A non admin cannot read legacy chamas; that simply means this code has
      // not been indexed yet.
      if (e.code == 'permission-denied') {
        debugPrintError('ChamaService: legacy code $code is not readable yet');
        return null;
      }
      rethrow;
    }
  }

  /// Moves a chama created under the old top level `chamas` collection into the
  /// organization scoped layout so the dashboard and all feature screens can
  /// read it again.
  Future<ChamaRef?> _migrateLegacyChama(String legacyChamaId) async {
    final session = _session();
    if (session == null) return null;

    try {
      final legacyDoc =
          await firestore.collection(_chamas).doc(legacyChamaId).get();
      if (!legacyDoc.exists) return null;
      final data = Map<String, dynamic>.from(legacyDoc.data() ?? const {});

      final userDoc = await _userRef(session.uid).get();
      final ownerName =
          (userDoc.data()?['name'] ?? session.displayName ?? 'Owner').toString();
      final orgId = await ensureOrganization(ownerName: ownerName);
      final code = (data['inviteCode'] ?? '').toString();

      final target = _chamaRef(orgId, legacyChamaId);
      await target.set({
        ...data,
        'organizationId': orgId,
        'adminId': session.uid,
        'originalAdminId': data['adminId'],
        'updatedAt': Timestamp.now(),
        'memberIds': _asStringList(data['memberIds']),
      });

      final legacyMembers =
          await legacyDoc.reference.collection(_members).get();
      for (final member in legacyMembers.docs) {
        await target
            .collection(_members)
            .doc(member.id)
            .set(member.data(), SetOptions(merge: true));
      }

      if (code.isNotEmpty) {
        await _writeCodeIndex(
          code,
          orgId,
          legacyChamaId,
          chamaName: (data['name'] ?? '').toString(),
        );
      }

      // Persist the repaired link so the dashboard resolves without migrating
      // on every load.
      await _userRef(session.uid).set(
        {
          'chamaId': legacyChamaId,
          'organizationId': orgId,
          'status': 'active',
          'chamaIds': FieldValue.arrayUnion([legacyChamaId]),
          'updatedAt': Timestamp.now(),
        },
        SetOptions(merge: true),
      );

      return ChamaRef(organizationId: orgId, chamaId: legacyChamaId);
    } catch (e) {
      debugPrintError('ChamaService: legacy migration failed: $e');
      return null;
    }
  }

  Future<void> _writeCodeIndex(
    String code,
    String organizationId,
    String chamaId, {
    String? chamaName,
  }) async {
    try {
      await _inviteCodeRef(code).set({
        'chamaId': chamaId,
        'organizationId': organizationId,
        'chamaName': chamaName,
        'active': true,
        'createdAt': Timestamp.now(),
      });
    } catch (_) {
      // The index is an optimisation; lookups can still fall back to a scan.
    }
  }

  /// Finds the chama a user belongs to and repairs the link when it still points
  /// at the legacy top level `chamas` collection.
  Future<ChamaRef?> resolveUserChama(String userId) async {
    try {
      final userDoc = await _userRef(userId).get();
      final userData = userDoc.data();
      final chamaId = userData?['chamaId'] as String? ?? '';

      if (chamaId.isEmpty) {
        return _repairFromMembership(userId);
      }

      final organizationId = userData?['organizationId'] as String? ?? '';
      if (organizationId.isNotEmpty) {
        final exists =
            await _chamaRef(organizationId, chamaId).get().then((s) => s.exists);
        if (exists) {
          return ChamaRef(organizationId: organizationId, chamaId: chamaId);
        }
      }

      // Fall back to the legacy location and move it into an organization.
      final legacyDoc = await firestore.collection(_chamas).doc(chamaId).get();
      if (legacyDoc.exists) {
        return _migrateLegacyChama(chamaId);
      }

      return _repairFromMembership(userId);
    } catch (e) {
      debugPrintError('ChamaService: could not resolve the user chama: $e');
      return null;
    }
  }

  /// Recovers the chama link from the membership record when the user document
  /// is missing or out of date, for example after a partially completed join.
  Future<ChamaRef?> _repairFromMembership(String userId) async {
    try {
      final snapshot = await firestore
          .collectionGroup(_members)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;

      final path = snapshot.docs.first.reference.path;

      // Membership still under the legacy top level collection: migrate it.
      final legacyChamaId = _legacyChamaIdFromMemberPath(path);
      if (legacyChamaId != null) {
        return _migrateLegacyChama(legacyChamaId);
      }

      final ref = _chamaRefFromMemberPath(path);
      if (ref == null) return null;

      final member = snapshot.docs.first.data();
      await _userRef(userId).set({
        'chamaId': ref.chamaId,
        'organizationId': ref.organizationId,
        'chamaIds': FieldValue.arrayUnion([ref.chamaId]),
        'status': (member['status'] ?? 'active').toString(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      return ref;
    } catch (e) {
      debugPrintError('ChamaService: membership repair failed: $e');
      return null;
    }
  }

  /// Parses `organizations/{organizationId}/chamas/{chamaId}/members/{userId}`.
  ChamaRef? _chamaRefFromMemberPath(String path) {
    final segments = path.split('/');
    if (segments.length == 6 &&
        segments[0] == _organizations &&
        segments[2] == _chamas &&
        segments[4] == _members) {
      return ChamaRef(organizationId: segments[1], chamaId: segments[3]);
    }
    return null;
  }

  /// Parses the legacy `chamas/{chamaId}/members/{userId}` path.
  String? _legacyChamaIdFromMemberPath(String path) {
    final segments = path.split('/');
    if (segments.length == 4 &&
        segments[0] == _chamas &&
        segments[2] == _members) {
      return segments[1];
    }
    return null;
  }

  Future<Chama?> getChama(String organizationId, String chamaId) async {
    try {
      final doc = await _chamaRef(organizationId, chamaId).get();
      if (!doc.exists) return null;
      return Chama.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------- joining

  /// Joins the user to the chama identified by [inviteCode] and links their user
  /// document so the dashboard resolves straight to that chama.
  Future<JoinChamaResult> joinChamaWithCode({
    required String inviteCode,
    String? name,
    String? email,
  }) async {
    final session = _session();
    if (session == null) {
      return const JoinChamaResult.notAuthenticated();
    }

    final lookup = await findChamaByInviteCode(inviteCode);
    if (!lookup.isSuccess) {
      return JoinChamaResult.invalidCode(lookup.error);
    }

    final ref = lookup.ref!;

    try {
      final memberRef = _memberRef(ref.organizationId, ref.chamaId, session.uid);
      // A user redeeming a code is not a member yet, so this read is denied by
      // the security rules. A denial simply means "not a member yet".
      Map<String, dynamic>? existingMember;
      try {
        existingMember = (await memberRef.get()).data();
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        existingMember = null;
      }

      final userDoc = await _userRef(session.uid).get();
      final userData = userDoc.data();
      final displayName = (name ??
              userData?['name'] ??
              session.displayName ??
              session.email ??
              'Member')
          .toString();
      final displayEmail =
          (email ?? session.email ?? userData?['email'] ?? '').toString();

      final batch = firestore.batch();
      batch.set(
        memberRef,
        {
          'userId': session.uid,
          'name': displayName,
          'email': displayEmail,
          'role': existingMember?['role'] ?? 'member',
          'status': 'active',
          'joinedAt': existingMember?['joinedAt'] ?? Timestamp.now(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      // Now a member, the chama document and its members can be read.
      final wasAlreadyMember = existingMember != null;
      final memberDoc = await memberRef.get();
      final memberData = memberDoc.data();
      final role = memberData?['role']?.toString() ?? 'member';

      // Written after the membership record exists so the chama document is
      // writable by the new member.
      final linkBatch = firestore.batch();
      linkBatch.set(
        _chamaRef(ref.organizationId, ref.chamaId),
        {
          'memberIds': FieldValue.arrayUnion([session.uid]),
          'updatedAt': Timestamp.now(),
        },
        SetOptions(merge: true),
      );

      linkBatch.set(
        _userRef(session.uid),
        {
          'chamaId': ref.chamaId,
          'organizationId': ref.organizationId,
          'role': role,
          'status': 'active',
          'chamaIds': FieldValue.arrayUnion([ref.chamaId]),
          'updatedAt': Timestamp.now(),
        },
        SetOptions(merge: true),
      );

      await linkBatch.commit();

      final chamaName = (await _chamaRef(ref.organizationId, ref.chamaId)
              .get())
          .data()?['name']
          ?.toString() ??
          'Chama';

      try {
        await NotificationService().notifyNewMember(
          chamaId: ref.chamaId,
          memberName: displayName,
          chamaName: chamaName,
        );
      } catch (_) {}

      if (wasAlreadyMember) {
        return JoinChamaResult.alreadyMember(
          ref: ref,
          chamaName: chamaName,
        );
      }

      return JoinChamaResult.joined(ref: ref, chamaName: chamaName);
    } catch (e) {
      throw ChamaException(_describeError(e));
    }
  }

  // ------------------------------------------------------------- mutation

  Future<bool> updateChama(
    String organizationId,
    String chamaId,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updatedAt'] = Timestamp.now();
      await _chamaRef(organizationId, chamaId).update(data);
      return true;
    } catch (e) {
      debugPrintError('updateChama failed: $e');
      return false;
    }
  }

  Future<bool> deleteChama(String organizationId, String chamaId) async {
    try {
      final doc = await _chamaRef(organizationId, chamaId).get();
      final code = doc.data()?['inviteCode']?.toString() ?? '';
      await _chamaRef(organizationId, chamaId).delete();
      if (code.isNotEmpty) {
        await _inviteCodeRef(code).delete();
      }
      return true;
    } catch (e) {
      debugPrintError('deleteChama failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMembers(
    String organizationId,
    String chamaId,
  ) async {
    try {
      final snapshot =
          await _chamaRef(organizationId, chamaId).collection(_members).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> setMemberStatus(
    String organizationId,
    String chamaId,
    String memberId,
    String status,
  ) async {
    try {
      await _memberRef(organizationId, chamaId, memberId)
          .update({'status': status});
      if (status == 'active') {
        await _userRef(memberId).set(
          {'status': 'active', 'updatedAt': Timestamp.now()},
          SetOptions(merge: true),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeMember(
    String organizationId,
    String chamaId,
    String memberId,
  ) async {
    try {
      await _memberRef(organizationId, chamaId, memberId).delete();
      await _chamaRef(organizationId, chamaId).set(
        {'memberIds': FieldValue.arrayRemove([memberId])},
        SetOptions(merge: true),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateMemberRole(
    String organizationId,
    String chamaId,
    String memberId,
    String role,
  ) async {
    try {
      await _memberRef(organizationId, chamaId, memberId).update({'role': role});
      await _userRef(memberId).set(
        {'role': role, 'updatedAt': Timestamp.now()},
        SetOptions(merge: true),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------- streams

  Stream<List<Chama>> streamUserChamas({
    required String organizationId,
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    var query = _chamasRef(organizationId)
        .where('memberIds', arrayContains: userId)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map<Chama>((doc) => Chama.fromFirestore(doc))
        .toList());
  }

  Stream<Chama?> streamChama(String organizationId, String chamaId) {
    return _chamaRef(organizationId, chamaId).snapshots().map(
          (doc) => doc.exists ? Chama.fromFirestore(doc) : null,
        );
  }

  // -------------------------------------------------------------- helpers

  static String normalizeCode(String code) =>
      code.trim().replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  Future<String> _reserveInviteCode() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = _generateCode();
      final snapshot = await _inviteCodeRef(code).get();
      if (!snapshot.exists) return code;
    }
    throw ChamaException(
      "Could not generate a unique invite code. Please try again.",
    );
  }

  String _generateCode() => List<String>.generate(
        _codeLength,
        (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
      ).join();

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Map<String, dynamic> _defaultFeatures() {
    return {
      'loansEnabled': true,
      'investmentsEnabled': true,
      'dividendsEnabled': true,
      'documentsEnabled': true,
      'meetingsEnabled': true,
      'votingEnabled': true,
      'analyticsEnabled': true,
      'attendanceEnabled': true,
      'leaderPrivateChatEnabled': true,
      'contributionRemindersEnabled': true,
    };
  }

  Map<String, dynamic> _defaultRules() {
    return {
      'contributionAmount': 1000,
      'contributionDeadline': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30))),
      'loanRepaymentDays': 30,
      'loanInterestRate': 5.0,
      'maxLoanAmount': 50000,
      'loansOptional': false,
    };
  }

  String _describeError(Object error) {
    final text = error.toString();
    if (text.contains('permission-denied') ||
        text.contains('PERMISSION_DENIED')) {
      return 'Database permission denied. Deploy the updated firestore.rules '
          'and try again.';
    }
    if (text.contains('unavailable') || text.contains('UNAVAILABLE')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (text.contains('deadline-exceeded')) {
      return 'The request timed out. Please try again.';
    }
    return 'Could not complete the request: $text';
  }
}

void debugPrintError(String message) {
  // ignore: avoid_print
  print(message);
}
