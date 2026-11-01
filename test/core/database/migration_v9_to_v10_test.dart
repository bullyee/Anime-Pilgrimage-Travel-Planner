import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/database/migrations/migration_v9_to_v10.dart';

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

    test('migrates legacy v8 database to v10 preserving data', () async {
      final nowMs = DateTime.utc(2026, 6, 1).millisecondsSinceEpoch;

      // Seed v8 records (where POI has no v9 columns like last_modified_at)
      await db.into(db.rois).insert(
            RoisCompanion.insert(
              id: 'roi_shiga',
              name: 'Shiga',
              authorId: 'u1',
              createdAt: Value(nowMs),
            ),
          );

      await db.into(db.pois).insert(
            PoisCompanion.insert(
              id: 'custom_spot_1',
              roiId: const Value('roi_shiga'),
              name: 'Toyosato Primary School',
              lat: 35.20,
              lng: 136.23,
              authorId: 'u1',
              createdAt: Value(nowMs),
              // v8 has null lastModifiedAt
            ),
          );

      // Run migration
      final migrator = MigrationV9ToV10(db);
      await migrator.migrate(dropOldTables: true);

      // Verify v10 places
      final place = await (db.select(db.places)..where((tbl) => tbl.placeKey.equals('custom_spot_1'))).getSingle();
      expect(place.name, equals('Toyosato Primary School'));
      expect(place.source, isNull); // Custom spot, not anitabi
      expect(place.visibility, equals('saved'));

      // Verify region label
      final regionLabel = await (db.select(db.labels)..where((tbl) => tbl.id.equals('roi_shiga'))).getSingle();
      expect(regionLabel.name, equals('Shiga'));
      expect(regionLabel.kind, equals('region'));
    });
  });
}
