import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartchama/models/chama_model.dart';

class ChamaService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<Chama?> getChama(String chamaId) async {
    try {
      final doc = await firestore.collection("chamas").doc(chamaId).get();
      if (doc.exists) {
        return Chama.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Chama>> getOrganizationChamas(String organizationId) async {
    try {
      final snapshot = await firestore
          .collection("organizations")
          .doc(organizationId)
          .collection("chamas")
          .get();
      return snapshot.docs.map((doc) => Chama.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> createChama({
    required String chamaName,
    String? description,
    String? organizationId,
  }) async {
    try {
      final user = auth.currentUser;
      if (user == null) return null;

      DocumentReference chamaRef;
      
      if (organizationId != null) {
        chamaRef = await firestore
            .collection("organizations")
            .doc(organizationId)
            .collection("chamas")
            .add({
          "name": chamaName,
          "description": description ?? "",
          "createdBy": user.uid,
          "createdAt": Timestamp.now(),
          "inviteCode": _generateInviteCode(),
          "status": "active",
        });
      } else {
        chamaRef = await firestore.collection("chamas").add({
          "name": chamaName,
          "description": description ?? "",
          "createdBy": user.uid,
          "createdAt": Timestamp.now(),
          "inviteCode": _generateInviteCode(),
          "status": "active",
        });
      }

      await firestore.collection("members").add({
        "userId": user.uid,
        "chamaId": chamaRef.id,
        "role": "admin",
        "status": "active",
        "joinedAt": Timestamp.now(),
      });

      await firestore.collection("users").doc(user.uid).set({
        "email": user.email,
        "chamaId": chamaRef.id,
        "role": "admin",
        "status": "active",
        "createdAt": Timestamp.now(),
      }, SetOptions(merge: true));

      return chamaRef.id;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateChama(String chamaId, Map<String, dynamic> data) async {
    try {
      await firestore.collection("chamas").doc(chamaId).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteChama(String chamaId) async {
    try {
      await firestore.collection("chamas").doc(chamaId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMembers(String chamaId) async {
    try {
      final snapshot = await firestore
          .collection("members")
          .where("chamaId", isEqualTo: chamaId)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> joinChama({
    required String inviteCode,
    String? organizationId,
    String? userId,
    String? name,
    String? email,
  }) async {
    try {
      final currentUser = auth.currentUser;
      final uid = userId ?? currentUser?.uid;
      if (uid == null) return false;

      QuerySnapshot chamaQuery;
      
      if (organizationId != null) {
        chamaQuery = await firestore
            .collection("organizations")
            .doc(organizationId)
            .collection("chamas")
            .where("inviteCode", isEqualTo: inviteCode)
            .get();
      } else {
        chamaQuery = await firestore
            .collection("chamas")
            .where("inviteCode", isEqualTo: inviteCode)
            .get();
      }

      if (chamaQuery.docs.isEmpty) return false;

      final chamaDoc = chamaQuery.docs.first;
      final chamaId = chamaDoc.id;

      final memberExists = await firestore
          .collection("members")
          .where("chamaId", isEqualTo: chamaId)
          .where("userId", isEqualTo: uid)
          .get();

      if (memberExists.docs.isNotEmpty) return false;

      await firestore.collection("members").add({
        "userId": uid,
        "chamaId": chamaId,
        "role": "member",
        "status": "pending",
        "joinedAt": Timestamp.now(),
      });

      await firestore.collection("users").doc(uid).set({
        "chamaId": chamaId,
        "role": "member",
        "status": "pending",
        "updatedAt": Timestamp.now(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveMember(String memberId) async {
    try {
      await firestore.collection("members").doc(memberId).update({
        "status": "active",
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeMember(String memberId) async {
    try {
      await firestore.collection("members").doc(memberId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateMemberRole(String memberId, String role) async {
    try {
      await firestore.collection("members").doc(memberId).update({
        "role": role,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (index) => chars[(random + index * 7) % chars.length]).join();
  }

  Stream<List<Chama>> streamOrganizationChamas(String organizationId) {
    return firestore
        .collection("organizations")
        .doc(organizationId)
        .collection("chamas")
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map<Chama>((doc) => Chama.fromFirestore(doc)).toList();
        });
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await firestore.collection("users").doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }
}