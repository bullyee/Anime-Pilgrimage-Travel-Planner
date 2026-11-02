import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/database/migrations/migration_v9_to_v10.dart';

const _v10Tables = [
  'stop_labels',
  'schedule_items',
  'stops',
  'trip_days',
  'trips',
  'place_labels',
  'photos',
  'place_visits',
  'v10_reference_images',
  'labels',
  'places',
];

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

      // 1. Seed v9 tables
      await db.into(db.rois).insert(
            RoisCompanion.insert(
              id: 'roi_kyoto',
              name: 'Kyoto Prefecture',
              authorId: 'user_test',
              createdAt: Value(nowMs),
            ),
          );

      await db.into(db.animes).insert(
            AnimesCompanion.insert(
              id: 'anime_euphonium',
              name: 'Hibike! Euphonium',
              bangumiId: const Value('105151'),
              authorId: 'user_test',
              createdAt: Value(nowMs),
            ),
          );

      await db.into(db.tags).insert(
            TagsCompanion.insert(
              id: 'tag_bench',
              name: 'Bench',
              authorId: 'user_test',
              createdAt: Value(nowMs),
            ),
          );

      await db.into(db.pois).insert(
            PoisCompanion.insert(
              id: 'anitabi:uji_spot_1',
              roiId: const Value('roi_kyoto'),
              name: 'Kumiko Bench',
              lat: 34.89,
              lng: 135.81,
              description: const Value('Iconic river bench scene'),
              address: const Value('Uji, Kyoto'),
              localCoverImagePath: const Value('/images/cover.jpg'),
              authorId: 'user_test',
              createdAt: Value(nowMs),
              lastModifiedAt: Value(DateTime.utc(2026, 10, 20)),
            ),
          );

      await db.into(db.poiAnimes).insert(
            PoiAnimesCompanion.insert(
              poiId: 'anitabi:uji_spot_1',
              animeId: 'anime_euphonium',
            ),
          );

      await db.into(db.poiTags).insert(
            PoiTagsCompanion.insert(
              poiId: 'anitabi:uji_spot_1',
              tagId: 'tag_bench',
            ),
          );

      // Reference image with JSON metadata
      await db.into(db.referenceImages).insert(
            ReferenceImagesCompanion.insert(
              id: 'ref_img_1',
              poiId: 'anitabi:uji_spot_1',
              authorId: 'user_test',
              localPath: const Value('/ref/shot.jpg'),
              remoteUrl: const Value('https://cdn.anitabi.cn/shot.jpg'),
              metadata: const Value('{"source": "anitabi", "ep": 1, "s": 450}'),
              createdAt: Value(nowMs),
            ),
          );

      // Media assets: user_photo, reference_frame, and ticket_qr
      await db.into(db.mediaAssets).insert(
            MediaAssetsCompanion.insert(
              id: 'photo_1',
              poiId: 'anitabi:uji_spot_1',
              authorId: 'user_test',
              type: 'user_photo',
              localPath: const Value('/photos/my_trip.jpg'),
              referenceImageId: const Value('ref_img_1'),
              createdAt: Value(nowMs),
            ),
          );

      await db.into(db.mediaAssets).insert(
            MediaAssetsCompanion.insert(
              id: 'ref_frame_2',
              poiId: 'anitabi:uji_spot_1',
              authorId: 'user_test',
              type: 'reference_frame',
              localPath: const Value('/ref/frame2.jpg'),
              metadata: const Value('{"source": "anitabi", "ep": "2", "s": 720}'),
              createdAt: Value(nowMs),
            ),
          );

      await db.into(db.mediaAssets).insert(
            MediaAssetsCompanion.insert(
              id: 'ticket_qr_1',
              poiId: 'anitabi:uji_spot_1',
              authorId: 'user_test',
              type: 'ticket_qr',
              localPath: const Value('/tickets/qr.png'),
              createdAt: Value(nowMs),
            ),
          );

      // Time chunks (should be dropped)
      await db.into(db.timeChunks).insert(
            TimeChunksCompanion.insert(
              id: 'chunk_1',
              poiId: 'anitabi:uji_spot_1',
              authorId: 'user_test',
            ),
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

    test('real onUpgrade from a v8 database file (8 -> 9 -> 10) preserves data', () async {
      final dir = await Directory.systemTemp.createTemp('mig_v8_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/v8.sqlite');

      // Build a real v8 database file: drop v10 tables, rebuild `pois` without
      // the v9 columns (sync_status, is_deleted, has_ever_synced, last_modified_at),
      // and set user_version = 8.
      final seedDb = AppDatabase.forTesting(NativeDatabase(file));
      await seedDb.customStatement('PRAGMA foreign_keys = OFF');
      for (final t in _v10Tables) {
        await seedDb.customStatement('DROP TABLE $t');
      }
      await seedDb.customStatement('DROP TABLE pois');
      await seedDb.customStatement('''
        CREATE TABLE pois (
          id TEXT NOT NULL PRIMARY KEY,
          roi_id TEXT NULL REFERENCES rois(id) ON DELETE SET NULL,
          name TEXT NOT NULL,
          lat REAL NOT NULL,
          lng REAL NOT NULL,
          description TEXT NULL,
          address TEXT NULL,
          business_hours TEXT NULL,
          contact_info TEXT NULL,
          local_cover_image_path TEXT NULL,
          remote_cover_image_url TEXT NULL,
          created_at INTEGER NOT NULL DEFAULT 0,
          author_id TEXT NOT NULL,
          is_shared INTEGER NOT NULL DEFAULT 0
        );
      ''');

      final nowMs = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;
      await seedDb.into(seedDb.rois).insert(
            RoisCompanion.insert(
              id: 'roi_shiga',
              name: 'Shiga',
              authorId: 'u1',
              createdAt: Value(nowMs),
            ),
          );
      await seedDb.customStatement(
        'INSERT INTO pois (id, roi_id, name, lat, lng, created_at, author_id, is_shared) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        ['custom_spot_1', 'roi_shiga', 'Toyosato Primary School', 35.20, 136.23, nowMs, 'u1', 0],
      );
      await seedDb.customStatement('PRAGMA user_version = 8');
      await seedDb.close();

      // Reopen with AppDatabase so Drift runs onUpgrade(8 -> 10)
      final upgradedDb = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() => upgradedDb.close());

      final place = await (upgradedDb.select(upgradedDb.places)
            ..where((tbl) => tbl.placeKey.equals('custom_spot_1')))
          .getSingle();
      expect(place.name, equals('Toyosato Primary School'));
      expect(place.source, isNull);
      expect(place.visibility, equals('saved'));

      final regionLabel = await (upgradedDb.select(upgradedDb.labels)
            ..where((tbl) => tbl.id.equals('roi_shiga')))
          .getSingle();
      expect(regionLabel.name, equals('Shiga'));
      expect(regionLabel.kind, equals('region'));

      final placeLabels = await upgradedDb.select(upgradedDb.placeLabels).get();
      expect(placeLabels.single.placeKey, equals('custom_spot_1'));
      expect(placeLabels.single.labelId, equals('roi_shiga'));
    });

    test('deduplicates anime labels with and without bangumiId and is idempotent on re-run', () async {
      // Two anime rows for the same work: one with bangumiId, one without
      await db.into(db.animes).insert(
            AnimesCompanion.insert(
              id: 'anime_with_bgm',
              name: 'K-ON!',
              bangumiId: const Value('1424'),
              authorId: 'u1',
            ),
          );
      await db.into(db.animes).insert(
            AnimesCompanion.insert(
              id: 'anime_no_bgm',
              name: 'K-ON!',
              authorId: 'u1',
            ),
          );
      await db.into(db.pois).insert(
            PoisCompanion.insert(
              id: 'poi_1',
              name: 'School Gate',
              lat: 35.2,
              lng: 136.2,
              authorId: 'u1',
            ),
          );
      await db.into(db.poiAnimes).insert(
            PoiAnimesCompanion.insert(poiId: 'poi_1', animeId: 'anime_no_bgm'),
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
      await db.into(db.pois).insert(
            PoisCompanion.insert(
              id: 'poi_2',
              name: 'Music Room',
              lat: 35.21,
              lng: 136.21,
              authorId: 'u1',
            ),
          );
      await db.into(db.poiAnimes).insert(
            PoiAnimesCompanion.insert(poiId: 'poi_2', animeId: 'anime_with_bgm'),
          );
      await migrator.migrateData();

      final allPlaces = await db.select(db.places).get();
      expect(allPlaces.map((p) => p.placeKey).toSet(), equals({'poi_1', 'poi_2'}));
      final animeLabelsAfter = await (db.select(db.labels)..where((tbl) => tbl.kind.equals('anime'))).get();
      expect(animeLabelsAfter.length, equals(1));
    });
  });
}
