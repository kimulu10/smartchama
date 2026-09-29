import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    _database = await openDatabase(
      'smartchama_offline.db',
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cached_chamas (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_contributions (
        id TEXT PRIMARY KEY,
        chama_id TEXT NOT NULL,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_synchs (
        id TEXT PRIMARY KEY,
        collection TEXT NOT NULL,
        doc_id TEXT NOT NULL,
        data TEXT NOT NULL,
        operation TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> cacheChama(Map<String, dynamic> chamaData, String id) async {
    if (_database == null) return;
    await _database!.insert(
      'cached_chamas',
      {
        'id': id,
        'data': jsonEncode(chamaData),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedChamas() async {
    if (_database == null) return [];
    final results = await _database!.query('cached_chamas');
    return results.map((row) {
      return jsonDecode(row['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  Future<void> cacheContributions(
    List<Map<String, dynamic>> contributions,
    String chamaId,
  ) async {
    if (_database == null) return;
    final batch = _database!;
    for (final contribution in contributions) {
      await batch.insert(
        'cached_contributions',
        {
          'id': contribution['id'],
          'chama_id': chamaId,
          'data': jsonEncode(contribution),
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCachedContributions(
    String chamaId,
  ) async {
    if (_database == null) return [];
    final results = await _database!.query(
      'cached_contributions',
      where: 'chama_id = ?',
      whereArgs: [chamaId],
    );
    return results.map((row) {
      return jsonDecode(row['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  Future<void> queueForSync({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    required String operation,
  }) async {
    if (_database == null) return;
    await _database!.insert(
      'pending_synchs',
      {
        'id': '${collection}_${docId}_${DateTime.now().millisecondsSinceEpoch}',
        'collection': collection,
        'doc_id': docId,
        'data': jsonEncode(data),
        'operation': operation,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> syncPendingChanges() async {
    if (_database == null || !_isOnline) return;

    final pending = await _database!.query('pending_synchs');
    for (final item in pending) {
      try {
        final collection = item['collection'] as String;
        final docId = item['doc_id'] as String;
        final operation = item['operation'] as String;
        final data = jsonDecode(item['data'] as String);

        switch (operation) {
          case 'create':
            await _firestore.collection(collection).doc(docId).set(data);
            break;
          case 'update':
            await _firestore.collection(collection).doc(docId).update(data);
            break;
          case 'delete':
            await _firestore.collection(collection).doc(docId).delete();
            break;
        }

        await _database!.delete(
          'pending_synchs',
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      } catch (e) {
        // Will retry on next sync
      }
    }
  }

  Future<void> setOnlineStatus(bool online) async {
    _isOnline = online;
    if (online) {
      await syncPendingChanges();
    }
  }

  Future<void> clearCache() async {
    if (_database == null) return;
    await _database!.delete('cached_chamas');
    await _database!.delete('cached_contributions');
  }
}