import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'offline_storage_service.dart';

class OfflineSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Connectivity _connectivity = Connectivity();

  static StreamSubscription? _connectivitySubscription;
  static bool _isOnline = true;
  static bool _isSyncing = false;

  static Future<void> init() async {
    _isOnline = await _checkConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  static Future<bool> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  static void _handleConnectivityChange(List<ConnectivityResult> result) {
    final wasOnline = _isOnline;
    _isOnline = !result.contains(ConnectivityResult.none);

    if (!wasOnline && _isOnline) {
      syncPendingChanges();
    }
  }

  static bool get isOnline => _isOnline;
  static bool get isSyncing => _isSyncing;

  static Future<void> syncPendingChanges() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    try {
      await _syncUserData();
      await _syncContributions();
      await _syncLoans();
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _syncUserData() async {
    final pendingChanges =
        OfflineStorageService.getCachedData('pending_user_changes');
    if (pendingChanges == null) return;

    final userData = OfflineStorageService.getUserData();
    if (userData != null) {
      final userId = userData['userId'];
      if (userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .set(userData, SetOptions(merge: true));
      }
    }
  }

  static Future<void> _syncContributions() async {
    final pendingChanges =
        OfflineStorageService.getCachedData('pending_contributions');
    if (pendingChanges == null) return;

    for (final contribution in pendingChanges) {
      await _firestore.collection('contributions').add(contribution);
    }
    await OfflineStorageService.cacheData('pending_contributions', null);
  }

  static Future<void> _syncLoans() async {
    final pendingChanges = OfflineStorageService.getCachedData('pending_loans');
    if (pendingChanges == null) return;

    for (final loan in pendingChanges) {
      await _firestore.collection('loans').add(loan);
    }
    await OfflineStorageService.cacheData('pending_loans', null);
  }

  static Future<void> cacheChamaData(String chamaId) async {
    if (_isOnline) {
      try {
        final doc = await _firestore.collection('chamas').doc(chamaId).get();
        if (doc.exists) {
          await OfflineStorageService.saveChamaData(chamaId, doc.data()!);
        }
      } catch (e) {
        // Use cached data on error
      }
    }
  }

  static Map<String, dynamic>? getOfflineChamaData(String chamaId) {
    if (_isOnline) {
      return null;
    }
    return OfflineStorageService.getChamaData(chamaId);
  }

  static Future<void> saveContributionOffline(
      Map<String, dynamic> contribution) async {
    if (_isOnline) {
      await _firestore.collection('contributions').add(contribution);
    } else {
      final pending =
          OfflineStorageService.getCachedData('pending_contributions') ?? [];
      pending.add(contribution);
      await OfflineStorageService.cacheData('pending_contributions', pending);
    }
  }

  static Future<void> saveLoanOffline(Map<String, dynamic> loan) async {
    if (_isOnline) {
      await _firestore.collection('loans').add(loan);
    } else {
      final pending =
          OfflineStorageService.getCachedData('pending_loans') ?? [];
      pending.add(loan);
      await OfflineStorageService.cacheData('pending_loans', pending);
    }
  }

  static void dispose() {
    _connectivitySubscription?.cancel();
  }
}
