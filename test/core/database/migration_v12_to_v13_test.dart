import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:trip_planner/core/database/database.dart';

const _v10TableNames = [
  'places',
  'labels',
  'place_labels',
  'photos',
  'place_visits',
  'v10_reference_images',
  'trips',
  'trip_days',
  'stops',
  'stop_labels',
  'schedule_items',
];

const _legacyTableNames = [
  'rois',
  'pois',
  'animes',
  'tags',
  'poi_animes',
  'poi_tags',
  'time_chunks',
  'reference_images',
  'media_assets',
];

void _createLegacyTables(sqlite.Database raw) {
  raw.execute('''
    CREATE TABLE IF NOT EXISTS rois (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      author_id TEXT NOT NULL,
      is_shared INTEGER DEFAULT 0,
      is_offline_cached INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT 0,
      cloud_version INTEGER DEFAULT 0,
      sync_lock_expires_at INTEGER
    );
    CREATE TABLE IF NOT EXISTS animes (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      bangumi_id TEXT,
      author_id TEXT NOT NULL,
      is_shared INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS tags (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      author_id TEXT NOT NULL,
      is_shared INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS pois (
      id TEXT PRIMARY KEY,
      roi_id TEXT,
      name TEXT NOT NULL,
      description TEXT,
      address TEXT,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      business_hours TEXT,
      contact_info TEXT,
      local_cover_image_path TEXT,
      remote_cover_image_url TEXT,
      sort_order INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT 0,
      sync_status INTEGER DEFAULT 0,
      is_deleted INTEGER DEFAULT 0,
      has_ever_synced INTEGER DEFAULT 0,
      last_modified_at INTEGER,
      author_id TEXT NOT NULL,
      is_shared INTEGER DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS poi_animes (
      poi_id TEXT,
      anime_id TEXT,
      PRIMARY KEY (poi_id, anime_id)
    );
    CREATE TABLE IF NOT EXISTS poi_tags (
      poi_id TEXT,
      tag_id TEXT,
      PRIMARY KEY (poi_id, tag_id)
    );
    CREATE TABLE IF NOT EXISTS reference_images (
      id TEXT PRIMARY KEY,
      poi_id TEXT,
      author_id TEXT NOT NULL,
      local_path TEXT,
      remote_url TEXT,
      metadata TEXT,
      created_at INTEGER DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS media_assets (
      id TEXT PRIMARY KEY,
      poi_id TEXT NOT NULL,
      author_id TEXT NOT NULL,
      type TEXT NOT NULL,
      local_path TEXT,
      remote_url TEXT,
      metadata TEXT,
      reference_image_id TEXT,
      created_at INTEGER DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS time_chunks (
      id TEXT PRIMARY KEY,
      poi_id TEXT,
      date TEXT,
      start_time TEXT,
      end_time TEXT,
      status TEXT,
      sort_order INTEGER,
      duration INTEGER,
      transit_duration INTEGER,
      is_fixed_time INTEGER,
      author_id TEXT NOT NULL,
      is_shared INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT 0,
      sync_status INTEGER DEFAULT 0,
      is_deleted INTEGER DEFAULT 0,
      has_ever_synced INTEGER DEFAULT 0,
      last_modified_at INTEGER
    );
  ''');
}

void main() {
  group('Schema v13 Migration & Cutover Tests', () {
    test('fresh database starts at schema version 13 with only v10 tables and zero legacy tables', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, equals(13));

      final rows = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get();
      final tableNames = rows.map((r) => r.read<String>('name')).toSet();

      for (final v10Table in _v10TableNames) {
        expect(tableNames.contains(v10Table), isTrue, reason: 'v10 table $v10Table must exist');
      }

      for (final legacyTable in _legacyTableNames) {
        expect(tableNames.contains(legacyTable), isFalse, reason: 'legacy table $legacyTable must not exist');
      }
    });

    test('real upgrade from v12 file drops legacy tables and brings over rows written after v10 exactly once', () async {
      final tempDir = await Directory.systemTemp.createTemp('db_v12_v13_test_');
      final dbFile = File('${tempDir.path}/app_v12.db');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      // 1. Build a real v12 database using sqlite3
      final raw = sqlite.sqlite3.open(dbFile.path);

      // Create v10 tables at v12 schema (including stops.area and stops.note)
      raw.execute('''
        CREATE TABLE places (
          place_key TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          lat REAL NOT NULL,
          lng REAL NOT NULL,
          description TEXT,
          address TEXT,
          business_hours TEXT,
          contact_info TEXT,
          access_tips TEXT,
          links TEXT,
          cover_local_path TEXT,
          cover_remote_url TEXT,
          source TEXT,
          source_url TEXT,
          private_note TEXT,
          visibility TEXT NOT NULL DEFAULT 'saved',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE labels (
          id TEXT PRIMARY KEY,
          kind TEXT NOT NULL,
          name TEXT NOT NULL,
          bangumi_id TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE place_labels (
          place_key TEXT NOT NULL,
          label_id TEXT NOT NULL,
          PRIMARY KEY (place_key, label_id)
        );
        CREATE TABLE photos (
          id TEXT PRIMARY KEY,
          place_key TEXT NOT NULL,
          kind TEXT NOT NULL DEFAULT 'original',
          reference_image_id TEXT,
          derived_from_id TEXT,
          trip_id TEXT,
          local_path TEXT NOT NULL,
          remote_url TEXT,
          is_shared INTEGER NOT NULL DEFAULT 0,
          taken_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE place_visits (
          id TEXT PRIMARY KEY,
          place_key TEXT NOT NULL,
          visited_at INTEGER NOT NULL,
          trip_id TEXT,
          stop_id TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE v10_reference_images (
          id TEXT PRIMARY KEY,
          place_key TEXT,
          local_path TEXT,
          remote_url TEXT,
          episode TEXT,
          timestamp_s INTEGER,
          source TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE trips (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          owner_id TEXT NOT NULL,
          sharing TEXT NOT NULL DEFAULT 'private',
          start_date TEXT,
          day_count INTEGER NOT NULL DEFAULT 1,
          sync_status INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE trip_days (
          id TEXT PRIMARY KEY,
          trip_id TEXT NOT NULL,
          sort_key TEXT NOT NULL,
          pinned_date TEXT,
          title TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE stops (
          id TEXT PRIMARY KEY,
          trip_id TEXT NOT NULL,
          place_key TEXT NOT NULL,
          name TEXT NOT NULL,
          lat REAL NOT NULL,
          lng REAL NOT NULL,
          area TEXT,
          note TEXT,
          added_by TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE stop_labels (
          stop_id TEXT NOT NULL,
          label_id TEXT NOT NULL,
          PRIMARY KEY (stop_id, label_id)
        );
        CREATE TABLE schedule_items (
          id TEXT PRIMARY KEY,
          trip_id TEXT NOT NULL,
          stop_id TEXT NOT NULL,
          day_id TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          start_time TEXT,
          duration_minutes INTEGER,
          transit_minutes INTEGER,
          is_fixed_time INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'scheduled',
          sync_status INTEGER NOT NULL DEFAULT 0,
          updated_by TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      // Create legacy tables that still existed in v12
      _createLegacyTables(raw);

      // Pre-existing v10 rows created before cutover
      final nowSec = DateTime.utc(2026, 10, 1).millisecondsSinceEpoch ~/ 1000;
      raw.execute('''
        INSERT INTO places (place_key, name, lat, lng, created_at, updated_at)
        VALUES ('existing_v10_place', 'Already in V10', 35.0, 135.0, $nowSec, $nowSec);
      ''');

      // Legacy rows written to old tables in the past
      final legacyMs = DateTime.utc(2026, 10, 20).millisecondsSinceEpoch;
      raw.execute('''
        INSERT INTO pois (id, roi_id, name, lat, lng, author_id, created_at, local_cover_image_path)
        VALUES ('poi_legacy_only', 'roi_transition', 'Old Spot', 34.48, 135.79, 'u1', $legacyMs, '/img/cover.jpg');

        INSERT INTO time_chunks (id, poi_id, author_id)
        VALUES ('chunk_deprecated', 'poi_legacy_only', 'u1');

        INSERT INTO media_assets (id, poi_id, author_id, type, local_path)
        VALUES ('ticket_deprecated', 'poi_legacy_only', 'u1', 'ticket_qr', '/tickets/qr.png');
      ''');

      raw.execute('PRAGMA user_version = 12;');
      raw.dispose();

      // 2. Open with AppDatabase to trigger onUpgrade(12 -> 13)
      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(db.close);

      expect(db.schemaVersion, equals(13));

      // 3. Verify all 9 legacy tables are dropped
      final tableRows = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get();
      final tableNames = tableRows.map((r) => r.read<String>('name')).toSet();

      for (final legacyTable in _legacyTableNames) {
        expect(tableNames.contains(legacyTable), isFalse, reason: 'legacy table $legacyTable must be dropped');
      }

      // 4. Verify existing v10 rows were preserved untouched
      final existingPlace = await (db.select(db.places)..where((p) => p.placeKey.equals('existing_v10_place'))).getSingleOrNull();
      expect(existingPlace, isNotNull);
      expect(existingPlace!.name, equals('Already in V10'));

      // 5. Verify migrateData() was NOT re-run (avoiding overwrites / resurrections on dev phones)
      final unmigratedPlace = await (db.select(db.places)..where((p) => p.placeKey.equals('poi_legacy_only'))).getSingleOrNull();
      expect(unmigratedPlace, isNull, reason: 'legacy rows must not be re-migrated when upgrading from v12');
    });

    test('real upgrade directly from v9 file creates v10 tables, migrates data, and drops legacy tables', () async {
      final tempDir = await Directory.systemTemp.createTemp('db_v9_v13_test_');
      final dbFile = File('${tempDir.path}/app_v9.db');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      // 1. Build a pure v9 database file (no v10 tables exist)
      final raw = sqlite.sqlite3.open(dbFile.path);
      _createLegacyTables(raw);

      final nowMs = DateTime.utc(2026, 5, 20).millisecondsSinceEpoch;
      raw.execute('''
        INSERT INTO rois (id, name, author_id, created_at)
        VALUES ('roi_kyoto', 'Kyoto City', 'u1', $nowMs);

        INSERT INTO animes (id, name, bangumi_id, author_id, created_at)
        VALUES ('anime_k_on', 'K-ON!', '1424', 'u1', $nowMs);

        INSERT INTO pois (id, roi_id, name, lat, lng, author_id, created_at)
        VALUES ('poi_active', 'roi_kyoto', 'Kamo River Delta', 35.03, 135.77, 'u1', $nowMs);

        INSERT INTO pois (id, roi_id, name, lat, lng, author_id, is_deleted, has_ever_synced)
        VALUES ('poi_tombstone', 'roi_kyoto', 'Old Deleted Spot', 0, 0, 'u1', 1, 1);

        INSERT INTO poi_animes (poi_id, anime_id)
        VALUES ('poi_active', 'anime_k_on');

        INSERT INTO media_assets (id, poi_id, author_id, type, local_path, created_at)
        VALUES ('photo_delta', 'poi_active', 'u1', 'user_photo', '/photos/delta.jpg', $nowMs);
      ''');

      raw.execute('PRAGMA user_version = 9;');
      raw.dispose();

      // 2. Open with AppDatabase to trigger onUpgrade(9 -> 13)
      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(db.close);

      expect(db.schemaVersion, equals(13));

      // 3. Verify all 11 v10 tables exist and all 9 legacy tables are dropped
      final tableRows = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get();
      final tableNames = tableRows.map((r) => r.read<String>('name')).toSet();

      for (final v10Table in _v10TableNames) {
        expect(tableNames.contains(v10Table), isTrue, reason: 'v10 table $v10Table must exist');
      }

      for (final legacyTable in _legacyTableNames) {
        expect(tableNames.contains(legacyTable), isFalse, reason: 'legacy table $legacyTable must be dropped');
      }

      // 4. Verify data: active spot migrated, tombstone spot skipped
      final activePlace = await (db.select(db.places)..where((p) => p.placeKey.equals('poi_active'))).getSingleOrNull();
      expect(activePlace, isNotNull);
      expect(activePlace!.name, equals('Kamo River Delta'));
      expect(activePlace.visibility, equals('saved'));

      final tombstonePlace = await (db.select(db.places)..where((p) => p.placeKey.equals('poi_tombstone'))).getSingleOrNull();
      expect(tombstonePlace, isNull, reason: 'tombstone POIs must not be migrated as saved places');

      final photo = await (db.select(db.photos)..where((p) => p.id.equals('photo_delta'))).getSingleOrNull();
      expect(photo, isNotNull);
      expect(photo!.localPath, equals('/photos/delta.jpg'));

      final labels = await db.select(db.labels).get();
      expect(labels.any((l) => l.kind == 'region' && l.name == 'Kyoto City'), isTrue);
      expect(labels.any((l) => l.kind == 'anime' && l.name == 'K-ON!' && l.bangumiId == '1424'), isTrue);
    });
  });
}
