// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:indexed_db' as idb;

abstract class AnitabiWebCache {
  static const String _dbName = 'anitabi_static_cache';
  static const String _storeName = 'cache_entries';
  static const int _version = 1;

  static idb.Database? _db;

  static Future<idb.Database?> _getDb() async {
    if (_db != null) return _db;
    if (!idb.IdbFactory.supported) return null;
    final idbFactory = html.window.indexedDB;
    if (idbFactory == null) return null;
    try {
      _db = await idbFactory.open(
        _dbName,
        version: _version,
        onUpgradeNeeded: (event) {
          final db = (event.target as idb.Request).result as idb.Database;
          if (db.objectStoreNames == null || !db.objectStoreNames!.contains(_storeName)) {
            db.createObjectStore(_storeName);
          }
        },
      );
      return _db;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> get(String key) async {
    final db = await _getDb();
    if (db == null) return null;
    try {
      final txn = db.transaction(_storeName, 'readonly');
      final store = txn.objectStore(_storeName);
      final entry = await store.getObject(key);
      if (entry is Map && entry['body'] is String) {
        return entry['body'] as String;
      }
    } catch (_) {}
    return null;
  }

  static Future<DateTime?> timestamp(String key) async {
    final db = await _getDb();
    if (db == null) return null;
    try {
      final txn = db.transaction(_storeName, 'readonly');
      final store = txn.objectStore(_storeName);
      final entry = await store.getObject(key);
      if (entry is Map && entry['at'] is int) {
        return DateTime.fromMillisecondsSinceEpoch(entry['at'] as int);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> put(String key, String value, DateTime timestamp) async {
    final db = await _getDb();
    if (db == null) return;
    try {
      final txn = db.transaction(_storeName, 'readwrite');
      final store = txn.objectStore(_storeName);
      await store.put({
        'body': value,
        'at': timestamp.millisecondsSinceEpoch,
      }, key);
    } catch (_) {}
  }
}
