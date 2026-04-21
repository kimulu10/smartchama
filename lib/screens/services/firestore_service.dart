import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================= USERS =================
  Future<DocumentSnapshot?> getUser(String userId) async {
    final doc = await _firestore.collection("users").doc(userId).get();
    return doc.exists ? doc : null;
  }

  Future<void> updateUserRole(String userId, String role) async {
    await _firestore.collection("users").doc(userId).update({
      "role": role,
    });
  }

  // ================= CHAMAS =================
  Future<DocumentSnapshot?> getChama(String chamaId) async {
    final doc = await _firestore.collection("chamas").doc(chamaId).get();
    return doc.exists ? doc : null;
  }

  // ================= CONTRIBUTIONS =================
  Future<double> getUserBalance(String userId, String chamaId) async {
    final query = await _firestore
        .collection("contributions")
        .where("userId", isEqualTo: userId)
        .where("chamaId", isEqualTo: chamaId)
        .get();

    double balance = 0;
    for (var doc in query.docs) {
      balance += (doc["amount"] ?? 0).toDouble();
    }

    return balance;
  }

  Future<void> addContribution(String userId, String chamaId, double amount, String mpesaCode) async {
    await _firestore.collection("contributions").add({
      "userId": userId,
      "chamaId": chamaId,
      "amount": amount,
      "date": DateTime.now(),
      "paymentMethod": "mpesa",
      "mpesaCode": mpesaCode,
    });
  }

  // ================= LOANS =================
  Future<int> getUserActiveLoans(String userId, String chamaId) async {
    final query = await _firestore
        .collection("loans")
        .where("userId", isEqualTo: userId)
        .where("chamaId", isEqualTo: chamaId)
        .where("status", isEqualTo: "approved")
        .get();

    return query.docs.length;
  }

  Future<void> addLoan(String userId, String chamaId, double amount) async {
    await _firestore.collection("loans").add({
      "userId": userId,
      "chamaId": chamaId,
      "amount": amount,
      "status": "pending",
      "repaidAmount": 0,
      "createdAt": DateTime.now(),
    });
  }

  // ================= LEADER SUGGESTIONS =================
  Stream<QuerySnapshot> suggestionsStream(String chamaId) {
    return _firestore
        .collection("leader_suggestions")
        .where("chamaId", isEqualTo: chamaId)
        .snapshots();
  }

  Future<void> vote(String userId, String suggestionId, String candidate) async {
    // Prevent duplicate votes
    final existing = await _firestore
        .collection("votes")
        .where("userId", isEqualTo: userId)
        .where("suggestionId", isEqualTo: suggestionId)
        .get();

    if (existing.docs.isEmpty) {
      await _firestore.collection("votes").add({
        "userId": userId,
        "suggestionId": suggestionId,
        "vote": candidate,
      });
    }
  }

  Future<Map<String, int>> getVoteResults(String suggestionId) async {
    final votes = await _firestore
        .collection("votes")
        .where("suggestionId", isEqualTo: suggestionId)
        .get();

    final results = <String, int>{};

    for (var doc in votes.docs) {
      final v = doc["vote"];
      results[v] = (results[v] ?? 0) + 1;
    }

    return results;
  }

  Future<void> assignLeaderRole(String userId, String role) async {
    await updateUserRole(userId, role);
  }

  // ================= MEMBERS =================
  Stream<QuerySnapshot> pendingMembersStream(String chamaId) {
    return _firestore
        .collection("members")
        .where("chamaId", isEqualTo: chamaId)
        .where("status", isEqualTo: "pending")
        .snapshots();
  }

  Future<void> approveMember(String memberId) async {
    await _firestore.collection("members").doc(memberId).update({
      "status": "approved",
      "role": "member",
    });

    await _firestore.collection("users").doc(memberId).update({
      "status": "approved",
      "role": "member",
    });
  }

  Future<void> rejectMember(String memberId) async {
    await _firestore.collection("members").doc(memberId).delete();
  }

  // ================= LOAN PAYMENTS (MPESA CALLBACK) =================
  Future<void> updateLoanPayment(String loanId, double amount, String mpesaCode) async {
    final loanRef = _firestore.collection("loans").doc(loanId);
    final loanDoc = await loanRef.get();

    final currentPaid = loanDoc.data()?["repaidAmount"] ?? 0;
    final totalAmount = loanDoc.data()?["amount"] ?? 0;

    final newPaid = currentPaid + amount;

    await loanRef.update({
      "repaidAmount": newPaid,
      "status": newPaid >= totalAmount ? "repaid" : loanDoc.data()?["status"]
    });

    await _firestore.collection("loan_payments").add({
      "loanId": loanId,
      "amount": amount,
      "paymentMethod": "mpesa",
      "mpesaCode": mpesaCode,
      "date": DateTime.now(),
    });
  }
}