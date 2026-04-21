import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const String userBox = 'user_box';
  static const String chamaBox = 'chama_box';
  static const String contributionBox = 'contribution_box';
  static const String loanBox = 'loan_box';
  static const String cacheBox = 'cache_box';
}

class OfflineStorageService {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(HiveBoxes.userBox);
    await Hive.openBox(HiveBoxes.chamaBox);
    await Hive.openBox(HiveBoxes.contributionBox);
    await Hive.openBox(HiveBoxes.loanBox);
    await Hive.openBox(HiveBoxes.cacheBox);
  }

  static Box get userBox => Hive.box(HiveBoxes.userBox);
  static Box get chamaBox => Hive.box(HiveBoxes.chamaBox);
  static Box get contributionBox => Hive.box(HiveBoxes.contributionBox);
  static Box get loanBox => Hive.box(HiveBoxes.loanBox);
  static Box get cacheBox => Hive.box(HiveBoxes.cacheBox);

  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await userBox.put('current_user', userData);
  }

  static Map<String, dynamic>? getUserData() {
    final data = userBox.get('current_user');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> saveChamaData(
      String chamaId, Map<String, dynamic> data) async {
    await chamaBox.put(chamaId, data);
  }

  static Map<String, dynamic>? getChamaData(String chamaId) {
    final data = chamaBox.get(chamaId);
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  static Future<void> saveContributions(
      String chamaId, List<Map<String, dynamic>> contributions) async {
    await contributionBox.put(chamaId, contributions);
  }

  static List<Map<String, dynamic>> getContributions(String chamaId) {
    final data = contributionBox.get(chamaId);
    if (data != null) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<void> saveLoans(
      String chamaId, List<Map<String, dynamic>> loans) async {
    await loanBox.put(chamaId, loans);
  }

  static List<Map<String, dynamic>> getLoans(String chamaId) {
    final data = loanBox.get(chamaId);
    if (data != null) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<void> cacheData(String key, dynamic data,
      {Duration? expiry}) async {
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': expiry?.inMilliseconds,
    };
    await cacheBox.put(key, cacheData);
  }

  static dynamic getCachedData(String key) {
    final cacheData = cacheBox.get(key);
    if (cacheData != null) {
      final timestamp = cacheData['timestamp'] as int;
      final expiry = cacheData['expiry'] as int?;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (expiry == null || now - timestamp < expiry) {
        return cacheData['data'];
      }
    }
    return null;
  }

  static Future<void> clearAll() async {
    await userBox.clear();
    await chamaBox.clear();
    await contributionBox.clear();
    await loanBox.clear();
    await cacheBox.clear();
  }

  static Future<void> clearUserData() async {
    await userBox.clear();
  }
}
