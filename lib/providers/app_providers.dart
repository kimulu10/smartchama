import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smartchama/services/security_service.dart';
import 'package:smartchama/services/branding_service.dart';
import 'package:smartchama/repositories/chama_repository.dart';
import 'package:smartchama/repositories/firestore_chama_repository.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  return SecureStorageService.isBiometricEnabled();
});

final coldStartAuthProvider = FutureProvider<(bool, String?)>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return (false, null);
  final valid = await SessionManager.isSessionValid();
  if (!valid) return (false, null);
  final doc = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .get();
  final status = doc.data()?["status"] as String? ?? "active";
  return (true, status);
});

final brandingThemeProvider = FutureProvider<ThemeData>((ref) async {
  final authAsync = ref.watch(authStateProvider);
  final user = authAsync.valueOrNull;
  if (user == null) return ThemeData(primarySwatch: Colors.green);
  final userState = ref.watch(userProvider);
  final orgId = userState.organizationId;
  if (orgId == null) return ThemeData(primarySwatch: Colors.green);
  final service = BrandingService();
  final branding = await service.getBranding(orgId);
  return service.buildTheme(branding);
});

class UserState {
  final String? chamaId;
  final String? organizationId;
  final String? name;
  final String? email;
  final String? role;
  final String? platformRole;
  final bool isLoading;
  final String? error;

  const UserState({
    this.chamaId,
    this.organizationId,
    this.name,
    this.email,
    this.role,
    this.platformRole,
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    String? chamaId,
    String? organizationId,
    String? name,
    String? email,
    String? role,
    String? platformRole,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      chamaId: chamaId ?? this.chamaId,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      platformRole: platformRole ?? this.platformRole,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UserNotifier extends StateNotifier<UserState> {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserNotifier(this._firestore, this._auth) : super(const UserState());

  Future<void> loadUserData() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection("users").doc(user.uid).get();
        final data = userDoc.data();
        if (data != null) {
          state = state.copyWith(
            chamaId: data["chamaId"],
            organizationId: data["organizationId"],
            name: data["name"],
            email: data["email"],
            role: data["role"],
            platformRole: data["platformRole"],
            isLoading: false,
          );
        } else {
          state = state.copyWith(isLoading: false);
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const UserState();
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(
      ref.watch(firebaseFirestoreProvider), ref.watch(firebaseAuthProvider));
});

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// App-wide theme mode (light/dark) for the Mobile & Web Experience feature.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) =>
        results.isNotEmpty && !results.contains(ConnectivityResult.none),
    loading: () => true,
    error: (_, __) => true,
  );
});

final chamaRepositoryProvider = Provider<ChamaRepository>((ref) {
  return FirestoreChamaRepository(ref.watch(firebaseFirestoreProvider));
});
