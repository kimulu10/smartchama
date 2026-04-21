import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class RateLimiter {
  final Map<String, List<int>> _attempts = {};
  final int maxAttempts;
  final int windowMs;
  final int lockoutMs;

  RateLimiter({
    this.maxAttempts = 5,
    this.windowMs = 60000,
    this.lockoutMs = 300000,
  });

  bool isAllowed(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attempts = _attempts[key] ?? [];

    final recentAttempts = attempts.where((t) => now - t < windowMs).toList();

    if (recentAttempts.length >= maxAttempts) {
      _attempts[key] = recentAttempts;
      return false;
    }

    _attempts[key] = [...recentAttempts, now];
    return true;
  }

  int getRemainingAttempts(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attempts = _attempts[key] ?? [];
    final recentAttempts = attempts.where((t) => now - t < windowMs).length;
    return (maxAttempts - recentAttempts).clamp(0, maxAttempts);
  }

  bool isLockedOut(String key) {
    return !isAllowed(key);
  }

  void reset(String key) {
    _attempts.remove(key);
  }

  void resetAll() {
    _attempts.clear();
  }
}

class AuthRateLimiter extends RateLimiter {
  AuthRateLimiter() : super(maxAttempts: 5, windowMs: 60000, lockoutMs: 300000);
}

class SessionManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _sessionKey = 'session_token';
  static const _expiryKey = 'session_expiry';
  static const _refreshKey = 'session_refresh';

  static Future<void> createSession({
    required String userId,
    Duration duration = const Duration(days: 7),
  }) async {
    final now = DateTime.now();
    final expiry = now.add(duration);
    final token = '${userId}_${now.millisecondsSinceEpoch}';

    await _storage.write(key: _sessionKey, value: token);
    await _storage.write(
        key: _expiryKey, value: expiry.millisecondsSinceEpoch.toString());
    await _storage.write(
        key: _refreshKey, value: now.millisecondsSinceEpoch.toString());
  }

  static Future<bool> isSessionValid() async {
    try {
      final expiryStr = await _storage.read(key: _expiryKey);
      if (expiryStr == null) return false;

      final expiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
      return DateTime.now().isBefore(expiry);
    } catch (e) {
      return false;
    }
  }

  static Future<void> refreshSession(
      {Duration extendBy = const Duration(days: 7)}) async {
    final isValid = await isSessionValid();
    if (!isValid) return;

    final newExpiry = DateTime.now().add(extendBy);
    await _storage.write(
        key: _expiryKey, value: newExpiry.millisecondsSinceEpoch.toString());
  }

  static Future<void> endSession() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _expiryKey);
    await _storage.delete(key: _refreshKey);
  }

  static Future<bool> hasActiveSession() async {
    return await isSessionValid();
  }

  static Future<String?> getSessionToken() async {
    final isValid = await isSessionValid();
    if (!isValid) return null;
    return await _storage.read(key: _sessionKey);
  }
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  static Future<bool> authenticate({
    String reason = 'Authenticate to access SmartChama',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometricsOnly({
    String reason = 'Use biometric to authenticate',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: 'user_id', value: userId);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  static Future<void> saveBiometricEnabled(bool enabled) async {
    await _storage.write(key: 'biometric_enabled', value: enabled.toString());
  }

  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: 'biometric_enabled');
    return value == 'true';
  }

  static Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: 'user_email', value: email);
    await _storage.write(key: 'user_password', value: password);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final email = await _storage.read(key: 'user_email');
    final password = await _storage.read(key: 'user_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: 'user_email');
    await _storage.delete(key: 'user_password');
  }
}
