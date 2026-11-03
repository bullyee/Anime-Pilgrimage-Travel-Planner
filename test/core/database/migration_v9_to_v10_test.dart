
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/database/migrations/migration_v9_to_v10.dart';

Future<void> createLegacyV9Tables(AppDatabase db) async {
  await db.customStatement('''
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
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS animes (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      bangumi_id TEXT,
      author_id TEXT NOT NULL,
      is_shared INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT 0
    );
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS tags (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      author_id TEXT NOT NULL,
      is_shared INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT 0
    );
  ''');
  await db.customStatement('''
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
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS poi_animes (
      poi_id TEXT,
      anime_id TEXT,
      PRIMARY KEY (poi_id, anime_id)
    );
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS poi_tags (
      poi_id TEXT,
      tag_id TEXT,
      PRIMARY KEY (poi_id, tag_id)
    );
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS reference_images (
      id TEXT PRIMARY KEY,
      poi_id TEXT,
      author_id TEXT,
      local_path TEXT,
      remote_url TEXT,
      metadata TEXT,
      created_at INTEGER
    );
  ''');
  await db.customStatement('''
    CREATE TABLE IF NOT EXISTS media_assets (
      id TEXT PRIMARY KEY,
      poi_id TEXT,
      author_id TEXT,
      type TEXT,
      local_path TEXT,
      remote_url TEXT,
      metadata TEXT,
      reference_image_id TEXT,
      created_at INTEGER
    );
  ''');
  await db.customStatement('''
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
      author_id TEXT,
      is_shared INTEGER,
      created_at INTEGER,
      sync_status INTEGER,
      is_deleted INTEGER,
      has_ever_synced INTEGER,
      last_modified_at INTEGER
    );
  ''');
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('MigrationV9ToV10 Tests', () {
    test('metadata parser parses JSON and plain strings correctly', () {
      final jsonMeta = parseLegacyMetadata('{"source": "anitabi", "ep": 2, "s": 145}');
      expect(jsonMeta.episode, equals('2'));
      expect(jsonMeta.timestampS, equals(145));
      expect(jsonMeta.source, equals('anitabi'));

      final textMeta = parseLegacyMetadata('EP 03');
      expect(textMeta.episode, equals('EP 03'));
      expect(textMeta.timestampS, isNull);

      final emptyMeta = parseLegacyMetadata(null);
      expect(emptyMeta.episode, isNull);
      expect(emptyMeta.timestampS, isNull);
    });

    test('migrates v9 database to v10 preserving places, photos, labels, and ref images', () async {
      final nowMs = DateTime.utc(2026, 10, 15).millisecondsSinceEpoch;

      // 1. Create and seed v9 legacy tables
      await createLegacyV9Tables(db);

      await db.customStatement(
        'INSERT INTO rois (id, name, author_id, created_at) VALUES (?, ?, ?, ?);',
        ['roi_kyoto', 'Kyoto Prefecture', 'user_test', nowMs],
      );

      await db.customStatement(
        'INSERT INTO animes (id, name, bangumi_id, author_id, created_at) VALUES (?, ?, ?, ?, ?);',
        ['anime_euphonium', 'Hibike! Euphonium', '105151', 'user_test', nowMs],
      );

      await db.customStatement(
        'INSERT INTO tags (id, name, author_id, created_at) VALUES (?, ?, ?, ?);',
        ['tag_bench', 'Bench', 'user_test', nowMs],
      );

      await db.customStatement(
        '''INSERT INTO pois (
             id, roi_id, name, lat, lng, description, address,
             local_cover_image_path, author_id, created_at, last_modified_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);''',
        [
          'anitabi:uji_spot_1',
          'roi_kyoto',
          'Kumiko Bench',
          34.89,
          135.81,
          'Iconic river bench scene',
          'Uji, Kyoto',
          '/images/cover.jpg',
          'user_test',
          nowMs,
          DateTime.utc(2026, 10, 20).millisecondsSinceEpoch ~/ 1000,
        ],
      );

      await db.customStatement(
        'INSERT INTO poi_animes (poi_id, anime_id) VALUES (?, ?);',
        ['anitabi:uji_spot_1', 'anime_euphonium'],
      );

      await db.customStatement(
        'INSERT INTO poi_tags (poi_id, tag_id) VALUES (?, ?);',
        ['anitabi:uji_spot_1', 'tag_bench'],
      );

      // Reference image with JSON metadata
      await db.customStatement(
        '''INSERT INTO reference_images (
             id, poi_id, author_id, local_path, remote_url, metadata, created_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?);''',
        [
          'ref_img_1',
          'anitabi:uji_spot_1',
          'user_test',
          '/ref/shot.jpg',
          'https://cdn.anitabi.cn/shot.jpg',
          '{"source": "anitabi", "ep": 1, "s": 450}',
          nowMs,
        ],
      );

      // Media assets: user_photo, reference_frame, and ticket_qr
      await db.customStatement(
        '''INSERT INTO media_assets (
             id, poi_id, author_id, type, local_path, reference_image_id, created_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?);''',
        [
          'photo_1',
          'anitabi:uji_spot_1',
          'user_test',
          'user_photo',
          '/photos/my_trip.jpg',
          'ref_img_1',
          nowMs,
        ],
      );

      await db.customStatement(
        '''INSERT INTO media_assets (
             id, poi_id, author_id, type, local_path, metadata, created_at
           ) VALUES (?, ?, ?, ?, ?, ?, ?);''',
        [
          'ref_frame_2',
          'anitabi:uji_spot_1',
          'user_test',
          'reference_frame',
          '/ref/frame2.jpg',
          '{"source": "anitabi", "ep": "2", "s": 720}',
          nowMs,
        ],
      );

      await db.customStatement(
        '''INSERT INTO media_assets (
             id, poi_id, author_id, type, local_path, created_at
           ) VALUES (?, ?, ?, ?, ?, ?);''',
        [
          'ticket_qr_1',
          'anitabi:uji_spot_1',
          'user_test',
          'ticket_qr',
          '/tickets/qr.png',
          nowMs,
        ],
      );

      // Time chunks (should be dropped)
      await db.customStatement(
        'INSERT INTO time_chunks (id, poi_id, author_id) VALUES (?, ?, ?);',
        ['chunk_1', 'anitabi:uji_spot_1', 'user_test'],
      );

      // 2. Execute migration
      final migrator = MigrationV9ToV10(db);
      await migrator.migrate(dropOldTables: true);

      // 3. Verify labels
      final allLabels = await db.select(db.labels).get();
      expect(allLabels.length, equals(3));
      final regionLabel = allLabels.firstWhere((l) => l.kind == 'region');
      expect(regionLabel.id, equals('roi_kyoto'));
      expect(regionLabel.name, equals('Kyoto Prefecture'));

      final animeLabel = allLabels.firstWhere((l) => l.kind == 'anime');
      expect(animeLabel.id, equals('anime_euphonium'));
      expect(animeLabel.bangumiId, equals('105151'));

      final tagLabel = allLabels.firstWhere((l) => l.kind == 'tag');
      expect(tagLabel.name, equals('Bench'));

      // 4. Verify places
      final allPlaces = await db.select(db.places).get();
      expect(allPlaces.length, equals(1));
      final place = allPlaces.first;
      expect(place.placeKey, equals('anitabi:uji_spot_1'));
      expect(place.name, equals('Kumiko Bench'));
      expect(place.visibility, equals('saved'));
      expect(place.source, equals('Anitabi'));
      expect(place.address, equals('Uji, Kyoto'));

      // 5. Verify place_labels
      final placeLabels = await db.select(db.placeLabels).get();
      expect(placeLabels.length, equals(3)); // 1 ROI + 1 anime + 1 tag
      expect(placeLabels.map((pl) => pl.labelId), containsAll(['roi_kyoto', 'anime_euphonium', 'tag_bench']));

      // 6. Verify reference images
      final refImages = await db.select(db.newReferenceImages).get();
      expect(refImages.length, equals(2)); // ref_img_1 and ref_frame_2

      final ref1 = refImages.firstWhere((r) => r.id == 'ref_img_1');
      expect(ref1.placeKey, equals('anitabi:uji_spot_1'));
      expect(ref1.episode, equals('1'));
      expect(ref1.timestampS, equals(450));
      expect(ref1.source, equals('anitabi'));

      final ref2 = refImages.firstWhere((r) => r.id == 'ref_frame_2');
      expect(ref2.episode, equals('2'));
      expect(ref2.timestampS, equals(720));

      // 7. Verify photos
      final photos = await db.select(db.photos).get();
      expect(photos.length, equals(1));
      final photo = photos.first;
      expect(photo.id, equals('photo_1'));
      expect(photo.placeKey, equals('anitabi:uji_spot_1'));
      expect(photo.referenceImageId, equals('ref_img_1'));
      expect(photo.isShared, isFalse);

      // 8. Verify old tables are dropped
      final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get();
      final tableNames = tables.map((r) => r.read<String>('name')).toSet();
      expect(tableNames.contains('time_chunks'), isFalse);
      expect(tableNames.contains('media_assets'), isFalse);
      expect(tableNames.contains('reference_images'), isFalse);
      expect(tableNames.contains('rois'), isFalse);
      expect(tableNames.contains('pois'), isFalse);
    });

    test('deduplicates anime labels with and without bangumiId and is idempotent on re-run', () async {
      await createLegacyV9Tables(db);

      // Two anime rows for the same work: one with bangumiId, one without
      await db.customStatement(
        'INSERT INTO animes (id, name, bangumi_id, author_id) VALUES (?, ?, ?, ?);',
        ['anime_with_bgm', 'K-ON!', '1424', 'u1'],
      );
      await db.customStatement(
        'INSERT INTO animes (id, name, bangumi_id, author_id) VALUES (?, ?, ?, ?);',
        ['anime_no_bgm', 'K-ON!', null, 'u1'],
      );
      await db.customStatement(
        'INSERT INTO pois (id, name, lat, lng, author_id) VALUES (?, ?, ?, ?, ?);',
        ['poi_1', 'School Gate', 35.2, 136.2, 'u1'],
      );
      await db.customStatement(
        'INSERT INTO poi_animes (poi_id, anime_id) VALUES (?, ?);',
        ['poi_1', 'anime_no_bgm'],
      );

      final migrator = MigrationV9ToV10(db);
      await migrator.migrateData();

      // Only one anime label should exist, and poi_1 should link to it
      final animeLabels = await (db.select(db.labels)..where((tbl) => tbl.kind.equals('anime'))).get();
      expect(animeLabels.length, equals(1));
      expect(animeLabels.single.id, equals('anime_with_bgm'));
      expect(animeLabels.single.bangumiId, equals('1424'));

      final pl = await db.select(db.placeLabels).get();
      expect(pl.length, equals(1));
      expect(pl.single.placeKey, equals('poi_1'));
      expect(pl.single.labelId, equals('anime_with_bgm'));

      // Re-running migrateData() at Stage 2 cutover after another POI is added in v9 is idempotent
      await db.customStatement(
        'INSERT INTO pois (id, name, lat, lng, author_id) VALUES (?, ?, ?, ?, ?);',
        ['poi_2', 'Music Room', 35.21, 136.21, 'u1'],
      );
      await db.customStatement(
        'INSERT INTO poi_animes (poi_id, anime_id) VALUES (?, ?);',
        ['poi_2', 'anime_with_bgm'],
      );
      await migrator.migrateData();

      final allPlaces = await db.select(db.places).get();
      expect(allPlaces.map((p) => p.placeKey).toSet(), equals({'poi_1', 'poi_2'}));
      final animeLabelsAfter = await (db.select(db.labels)..where((tbl) => tbl.kind.equals('anime'))).get();
      expect(animeLabelsAfter.length, equals(1));
    });
  });
}
