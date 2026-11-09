import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:trip_planner/core/database/database.dart';

void main() {
  group('Schema v14 Migration Tests', () {
    test('fresh database starts at schema version 14 with chinese_name and keep_as_is', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, equals(14));

      final rawColsPlaces = await db.customSelect('PRAGMA table_info(places)').get();
      final colNamesPlaces = rawColsPlaces.map((c) => c.read<String>('name')).toSet();
      expect(colNamesPlaces.contains('chinese_name'), isTrue);

      final rawColsPhotos = await db.customSelect('PRAGMA table_info(photos)').get();
      final colNamesPhotos = rawColsPhotos.map((c) => c.read<String>('name')).toSet();
      expect(colNamesPhotos.contains('keep_as_is'), isTrue);
    });

    test('real onUpgrade from v13 database file adds chinese_name and keep_as_is and preserves existing rows', () async {
      final tempDir = await Directory.systemTemp.createTemp('tp_migration_v14_');
      final dbFile = File('${tempDir.path}/v13_test.sqlite');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // 1. Create a schema 13 database using raw SQLite DDL
      final raw = sqlite.sqlite3.open(dbFile.path);
      raw.execute('''
        PRAGMA user_version = 13;
        CREATE TABLE places (
          place_key TEXT NOT NULL PRIMARY KEY,
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

        CREATE TABLE photos (
          id TEXT NOT NULL PRIMARY KEY,
          place_key TEXT NOT NULL,
          trip_id TEXT,
          kind TEXT NOT NULL DEFAULT 'original',
          derived_from_id TEXT,
          reference_image_id TEXT,
          local_path TEXT NOT NULL,
          remote_url TEXT,
          is_shared INTEGER NOT NULL DEFAULT 0,
          taken_at INTEGER,
          created_at INTEGER NOT NULL
        );

        INSERT INTO places (place_key, name, lat, lng, created_at, updated_at)
        VALUES ('place_uji', '宇治橋', 34.89, 135.80, 1000, 1000);

        INSERT INTO photos (id, place_key, local_path, created_at)
        VALUES ('p1', 'place_uji', '/local/p1.jpg', 1000);
      ''');
      raw.dispose();

      // 2. Open with Drift AppDatabase, triggering onUpgrade from 13 to 14
      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(db.close);

      // Verify schema version bumped
      final versionResult = await db.customSelect('PRAGMA user_version').getSingle();
      expect(versionResult.read<int>('user_version'), equals(14));

      // Verify columns added
      final rawColsPlaces = await db.customSelect('PRAGMA table_info(places)').get();
      final colNamesPlaces = rawColsPlaces.map((c) => c.read<String>('name')).toSet();
      expect(colNamesPlaces.contains('chinese_name'), isTrue);

      final rawColsPhotos = await db.customSelect('PRAGMA table_info(photos)').get();
      final colNamesPhotos = rawColsPhotos.map((c) => c.read<String>('name')).toSet();
      expect(colNamesPhotos.contains('keep_as_is'), isTrue);

      // Verify existing rows preserved
      final place = await (db.select(db.places)..where((p) => p.placeKey.equals('place_uji'))).getSingle();
      expect(place.name, equals('宇治橋'));
      expect(place.chineseName, isNull);

      final photo = await (db.select(db.photos)..where((p) => p.id.equals('p1'))).getSingle();
      expect(photo.localPath, equals('/local/p1.jpg'));
      expect(photo.keepAsIs, isTrue);
    });
  });
}
