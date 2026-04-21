import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

class UserState {
  final String? chamaId;
  final String? organizationId;
  final String? name;
  final String? email;
  final String? role;
  final bool isLoading;
  final String? error;

  const UserState({
    this.chamaId,
    this.organizationId,
    this.name,
    this.email,
    this.role,
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    String? chamaId,
    String? organizationId,
    String? name,
    String? email,
    String? role,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      chamaId: chamaId ?? this.chamaId,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
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

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) =>
        results.isNotEmpty && !results.contains(ConnectivityResult.none),
    loading: () => true,
    error: (_, __) => true,
  );
});
