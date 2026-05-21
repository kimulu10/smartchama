import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class RateLimiter {
  final Map<String, List<int>> _attempts = {};
  final int maxAttempts;
  final int windowMs;

  RateLimiter({
    this.maxAttempts = 5,
    this.windowMs = 60000,
  });

  int _recentCount(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attempts = _attempts[key] ?? [];
    return attempts.where((t) => now - t < windowMs).length;
  }

  bool isBlocked(String key) => _recentCount(key) >= maxAttempts;

  void recordAttempt(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attempts = _attempts[key] ?? [];
    final recent = attempts.where((t) => now - t < windowMs).toList();
    _attempts[key] = [...recent, now];
  }

  int getRemainingAttempts(String key) {
    return (maxAttempts - _recentCount(key)).clamp(0, maxAttempts);
  }

  void reset(String key) {
    _attempts.remove(key);
  }

  void resetAll() {
    _attempts.clear();
  }
}

class AuthRateLimiter extends RateLimiter {
  AuthRateLimiter() : super(maxAttempts: 5, windowMs: 60000);
}

class SessionManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _sessionKey = 'session_token';
  static const _expiryKey = 'session_expiry';
  static const _userIdKey = 'session_user_id';

  static Future<void> createSession({
    required String userId,
    Duration duration = const Duration(days: 7),
  }) async {
    final now = DateTime.now();
    final expiry = now.add(duration);
    final token = '${userId}_${now.millisecondsSinceEpoch}';

    await _storage.write(key: _sessionKey, value: token);
    await _storage.write(
      key: _expiryKey,
      value: expiry.millisecondsSinceEpoch.toString(),
    );
    await _storage.write(key: _userIdKey, value: userId);
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

  static Future<void> refreshSession({
    Duration extendBy = const Duration(days: 7),
  }) async {
    if (!await isSessionValid()) return;

    final newExpiry = DateTime.now().add(extendBy);
    await _storage.write(
      key: _expiryKey,
      value: newExpiry.millisecondsSinceEpoch.toString(),
    );
  }

  static Future<void> endSession() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _expiryKey);
    await _storage.delete(key: _userIdKey);
  }

  static Future<bool> hasActiveSession() => isSessionValid();

  static Future<String?> getSessionUserId() async {
    if (!await isSessionValid()) return null;
    return _storage.read(key: _userIdKey);
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

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: 'user_id', value: userId);
  }

  static Future<String?> getUserId() async {
    return _storage.read(key: 'user_id');
  }

  static Future<void> saveEmail(String email) async {
    await _storage.write(key: 'user_email', value: email);
  }

  static Future<String?> getStoredEmail() async {
    return _storage.read(key: 'user_email');
  }

  static Future<void> saveBiometricEnabled(bool enabled) async {
    await _storage.write(key: 'biometric_enabled', value: enabled.toString());
  }

  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: 'biometric_enabled');
    return value == 'true';
  }

  /// Clears session and user prefs. Does not sign out of Firebase — call
  /// FirebaseAuth.signOut separately.
  static Future<void> clearAll() async {
    await SessionManager.endSession();
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'user_email');
    await _storage.delete(key: 'biometric_enabled');
    await _clearLegacyCredentials();
  }

  static Future<void> _clearLegacyCredentials() async {
    await _storage.delete(key: 'user_password');
    await _storage.delete(key: 'auth_token');
  }

  @Deprecated('Passwords must not be stored on device')
  static Future<void> saveCredentials(String email, String password) async {
    await saveEmail(email);
    await _clearLegacyCredentials();
  }

  @Deprecated('Use getStoredEmail and Firebase session instead')
  static Future<Map<String, String>?> getCredentials() async {
    await _clearLegacyCredentials();
    return null;
  }
}
