import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

abstract class AnitabiWebCache {
  static const String _dbName = 'anitabi_static_cache';
  static const String _storeName = 'cache_entries';
  static const int _version = 1;

  static web.IDBDatabase? _db;

  static Future<web.IDBDatabase?> _getDb() async {
    if (_db != null) return _db;
    try {
      final req = web.window.indexedDB.open(_dbName, _version);
      final completer = Completer<web.IDBDatabase?>();

      req.onupgradeneeded = ((web.IDBVersionChangeEvent e) {
        final db = req.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      }).toJS;

      req.onsuccess = ((web.Event e) {
        _db = req.result as web.IDBDatabase;
        completer.complete(_db);
      }).toJS;

      req.onerror = ((web.Event e) {
        completer.complete(null);
      }).toJS;

      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> get(String key) async {
    final db = await _getDb();
    if (db == null) return null;
    try {
      final completer = Completer<String?>();
      final tx = db.transaction(_storeName.toJS, 'readonly');
      final store = tx.objectStore(_storeName);
      final req = store.get(key.toJS);
      req.onsuccess = ((web.Event e) {
        final res = req.result;
        if (res != null && res.isA<JSObject>()) {
          final obj = res as JSObject;
          final bodyVal = obj['body'];
          if (bodyVal != null && bodyVal.isA<JSString>()) {
            completer.complete((bodyVal as JSString).toDart);
            return;
          }
        }
        completer.complete(null);
      }).toJS;
      req.onerror = ((web.Event e) {
        completer.complete(null);
      }).toJS;
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> timestamp(String key) async {
    final db = await _getDb();
    if (db == null) return null;
    try {
      final completer = Completer<DateTime?>();
      final tx = db.transaction(_storeName.toJS, 'readonly');
      final store = tx.objectStore(_storeName);
      final req = store.get(key.toJS);
      req.onsuccess = ((web.Event e) {
        final res = req.result;
        if (res != null && res.isA<JSObject>()) {
          final obj = res as JSObject;
          final atVal = obj['at'];
          if (atVal != null && atVal.isA<JSNumber>()) {
            final ms = (atVal as JSNumber).toDartInt;
            completer.complete(DateTime.fromMillisecondsSinceEpoch(ms));
            return;
          }
        }
        completer.complete(null);
      }).toJS;
      req.onerror = ((web.Event e) {
        completer.complete(null);
      }).toJS;
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  static Future<void> put(String key, String value, DateTime timestamp) async {
    final db = await _getDb();
    if (db == null) return;
    try {
      final tx = db.transaction(_storeName.toJS, 'readwrite');
      final store = tx.objectStore(_storeName);

      // Purge older versions of detail pages (e.g. $page.$oldVersion when caching $page.$newVersion)
      if (key.contains('.')) {
        final prefix = key.substring(0, key.indexOf('.') + 1);
        final cursorReq = store.openCursor();
        cursorReq.onsuccess = ((web.Event e) {
          final cursor = cursorReq.result;
          if (cursor != null && cursor.isA<web.IDBCursorWithValue>()) {
            final c = cursor as web.IDBCursorWithValue;
            final k = c.key;
            if (k.isA<JSString>()) {
              final kStr = (k as JSString).toDart;
              if (kStr.startsWith(prefix) && kStr != key) {
                c.delete();
              }
            }
            c.continue_();
          }
        }).toJS;
      }

      final entry = JSObject();
      entry['body'] = value.toJS;
      entry['at'] = timestamp.millisecondsSinceEpoch.toJS;
      store.put(entry, key.toJS);
    } catch (_) {}
  }
}
