import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/services/library_backup_service.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;
  const backupService = LibraryBackupService();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('pilgrimage_backup_test_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Exporting empty database creates valid archive with manifest and library payload', () async {
    final zipFile = await backupService.exportLibraryArchive(
      db,
      targetZipPath: p.join(tempDir.path, 'empty.pilgrimage'),
    );

    expect(await zipFile.exists(), isTrue);

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final manifestEntry = archive.findFile('manifest.json');
    expect(manifestEntry, isNotNull);
    final manifestJson = jsonDecode(utf8.decode(manifestEntry!.content as List<int>)) as Map<String, dynamic>;
    expect(manifestJson['format'], equals('anime_pilgrimage_library'));
    expect(manifestJson['version'], equals(1));
    expect(manifestJson['schemaVersion'], equals(14));
    expect((manifestJson['counts'] as Map)['places'], equals(0));

    final payloadEntry = archive.findFile('library.json');
    expect(payloadEntry, isNotNull);
    final payloadJson = jsonDecode(utf8.decode(payloadEntry!.content as List<int>)) as Map<String, dynamic>;
    expect(payloadJson['places'], isEmpty);
  });

  test('Full roundtrip: exports and imports places, labels, visits, photos, and frames with physical files', () async {
    // 1. Seed database with places and labels
    await db.into(db.places).insert(
          PlacesCompanion.insert(
            placeKey: 'place_kitauji',
            name: 'Kitauji High School',
            chineseName: const Value('北宇治高校'),
            lat: 34.889,
            lng: 135.801,
            privateNote: const Value('Hibike Euphonium scene'),
          ),
        );

    await db.into(db.labels).insert(
          LabelsCompanion.insert(
            id: 'label_eupho',
            kind: 'anime',
            name: 'Sound! Euphonium',
          ),
        );

    await db.into(db.placeLabels).insert(
          PlaceLabelsCompanion.insert(
            placeKey: 'place_kitauji',
            labelId: 'label_eupho',
          ),
        );

    await db.into(db.placeVisits).insert(
          PlaceVisitsCompanion.insert(
            id: 'visit_1',
            placeKey: 'place_kitauji',
            date: '2026-08-15',
          ),
        );

    // Create physical dummy photo file
    final sourcePhotoFile = File(p.join(tempDir.path, 'source_photo.jpg'));
    final photoRawBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]; // fake jpeg header
    await sourcePhotoFile.writeAsBytes(photoRawBytes);

    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'photo_1',
            placeKey: 'place_kitauji',
            localPath: sourcePhotoFile.path,
            createdAt: Value(DateTime(2026, 8, 15, 14, 35)),
            kind: const Value('original'),
            keepAsIs: const Value(false),
          ),
        );

    // Create physical dummy frame file
    final sourceFrameFile = File(p.join(tempDir.path, 'source_frame.png'));
    final frameRawBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]; // fake png header
    await sourceFrameFile.writeAsBytes(frameRawBytes);

    await db.into(db.newReferenceImages).insert(
          NewReferenceImagesCompanion.insert(
            id: 'ref_1',
            placeKey: const Value('place_kitauji'),
            localPath: Value(sourceFrameFile.path),
            remoteUrl: const Value('https://example.com/frame.png'),
          ),
        );

    // 2. Export library
    final exportPath = p.join(tempDir.path, 'kitauji.pilgrimage');
    final zipFile = await backupService.exportLibraryArchive(db, targetZipPath: exportPath);
    expect(await zipFile.exists(), isTrue);

    // 3. Create fresh target database and storage directory
    final targetDb = AppDatabase.forTesting(NativeDatabase.memory());
    final targetStorageDir = Directory(p.join(tempDir.path, 'target_app_storage'));
    await targetStorageDir.create(recursive: true);

    try {
      // 4. Import archive into target database
      final summary = await backupService.importLibraryArchive(
        targetDb,
        zipFile,
        baseStorageDir: targetStorageDir,
      );

      expect(summary.placesImported, equals(1));
      expect(summary.labelsImported, equals(1));
      expect(summary.placeLabelsImported, equals(1));
      expect(summary.visitsImported, equals(1));
      expect(summary.photosImported, equals(1));
      expect(summary.referenceImagesImported, equals(1));

      // 5. Verify database contents in targetDb
      final importedPlaces = await targetDb.select(targetDb.places).get();
      expect(importedPlaces.length, equals(1));
      expect(importedPlaces.first.placeKey, equals('place_kitauji'));
      expect(importedPlaces.first.name, equals('Kitauji High School'));
      expect(importedPlaces.first.chineseName, equals('北宇治高校'));

      final importedVisits = await targetDb.select(targetDb.placeVisits).get();
      expect(importedVisits.length, equals(1));
      expect(importedVisits.first.id, equals('visit_1'));

      final importedPhotos = await targetDb.select(targetDb.photos).get();
      expect(importedPhotos.length, equals(1));
      expect(importedPhotos.first.id, equals('photo_1'));

      // Verify physical photo file exists in new target location and content matches
      final restoredPhotoFile = File(importedPhotos.first.localPath);
      expect(await restoredPhotoFile.exists(), isTrue);
      expect(await restoredPhotoFile.readAsBytes(), equals(photoRawBytes));
      expect(importedPhotos.first.localPath.startsWith(targetStorageDir.path), isTrue);

      final importedRefs = await targetDb.select(targetDb.newReferenceImages).get();
      expect(importedRefs.length, equals(1));
      expect(importedRefs.first.id, equals('ref_1'));

      // Verify physical frame file exists in new target location and content matches
      final restoredFrameFile = File(importedRefs.first.localPath!);
      expect(await restoredFrameFile.exists(), isTrue);
      expect(await restoredFrameFile.readAsBytes(), equals(frameRawBytes));
      expect(importedRefs.first.localPath!.startsWith(targetStorageDir.path), isTrue);
    } finally {
      await targetDb.close();
    }
  });

  test('Corrupt archive or missing manifest throws FormatException', () async {
    // Empty zip with no manifest
    final archive = Archive();
    final dummyBytes = utf8.encode('{}');
    archive.addFile(ArchiveFile('some_file.txt', dummyBytes.length, dummyBytes));
    final encoded = ZipEncoder().encode(archive)!;

    final invalidZip = File(p.join(tempDir.path, 'invalid.pilgrimage'));
    await invalidZip.writeAsBytes(encoded);

    expect(
      () => backupService.importLibraryArchive(db, invalidZip),
      throwsA(isA<FormatException>()),
    );
  });

  test('Importing into database with existing place records updates without foreign key violation', () async {
    // Pre-insert an older version of the place
    await db.into(db.places).insert(
          PlacesCompanion.insert(
            placeKey: 'place_kitauji',
            name: 'Old Name',
            lat: 34.889,
            lng: 135.801,
          ),
        );

    // Build zip with updated place
    final archive = Archive();
    final manifestBytes = utf8.encode(jsonEncode({'format': 'anime_pilgrimage_library', 'version': 1}));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    final payload = {
      'places': [
        {
          'placeKey': 'place_kitauji',
          'name': 'Updated Name',
          'lat': 34.889,
          'lng': 135.801,
          'chineseName': '更新後的名稱',
        }
      ],
      'labels': [],
      'placeLabels': [],
      'visits': [],
      'photos': [],
      'referenceImages': [],
    };
    final payloadBytes = utf8.encode(jsonEncode(payload));
    archive.addFile(ArchiveFile('library.json', payloadBytes.length, payloadBytes));

    final zipFile = File(p.join(tempDir.path, 'update.pilgrimage'));
    await zipFile.writeAsBytes(ZipEncoder().encode(archive)!);

    final summary = await backupService.importLibraryArchive(db, zipFile);
    expect(summary.placesImported, equals(1));

    final places = await db.select(db.places).get();
    expect(places.length, equals(1));
    expect(places.first.name, equals('Updated Name'));
    expect(places.first.chineseName, equals('更新後的名稱'));
  });

  test('Adversarial: deduplicates labels by bangumiId and (kind, name) without UNIQUE constraint failure and remaps references', () async {
    // 1. Source device DB has an anime label with bangumiId '115908' and a region label 'Kyoto'
    await db.into(db.places).insert(
          PlacesCompanion.insert(
            placeKey: 'place_uji',
            name: 'Uji Bridge',
            lat: 34.89,
            lng: 135.80,
          ),
        );
    await db.into(db.labels).insert(
          LabelsCompanion.insert(
            id: 'old_anime_uuid',
            kind: 'anime',
            name: 'Hibike! Euphonium',
            bangumiId: const Value('115908'),
          ),
        );
    await db.into(db.labels).insert(
          LabelsCompanion.insert(
            id: 'old_region_uuid',
            kind: 'region',
            name: 'Kyoto',
          ),
        );
    await db.into(db.placeLabels).insert(
          PlaceLabelsCompanion.insert(placeKey: 'place_uji', labelId: 'old_anime_uuid'),
        );
    await db.into(db.placeLabels).insert(
          PlaceLabelsCompanion.insert(placeKey: 'place_uji', labelId: 'old_region_uuid'),
        );
    await db.into(db.newReferenceImages).insert(
          NewReferenceImagesCompanion.insert(
            id: 'ref_uji',
            placeKey: const Value('place_uji'),
            animeLabelId: const Value('old_anime_uuid'),
          ),
        );

    final exportPath = p.join(tempDir.path, 'label_dedup.pilgrimage');
    final zipFile = await backupService.exportLibraryArchive(db, targetZipPath: exportPath);

    // 2. Target device DB ALREADY has the same anime (bangumiId '115908') and region ('Kyoto') with DIFFERENT UUIDs
    final targetDb = AppDatabase.forTesting(NativeDatabase.memory());
    final targetStorageDir = Directory(p.join(tempDir.path, 'target_dedup_storage'));
    await targetStorageDir.create(recursive: true);

    try {
      await targetDb.into(targetDb.labels).insert(
            LabelsCompanion.insert(
              id: 'new_device_anime_uuid',
              kind: 'anime',
              name: 'Sound! Euphonium',
              bangumiId: const Value('115908'),
            ),
          );
      await targetDb.into(targetDb.labels).insert(
            LabelsCompanion.insert(
              id: 'new_device_region_uuid',
              kind: 'region',
              name: 'Kyoto',
            ),
          );

      // 3. Import must succeed without SqliteException(2067): UNIQUE constraint failed
      final summary = await backupService.importLibraryArchive(
        targetDb,
        zipFile,
        baseStorageDir: targetStorageDir,
      );
      expect(summary.placesImported, equals(1));
      expect(summary.labelsImported, equals(2));
      expect(summary.placeLabelsImported, equals(2));
      expect(summary.referenceImagesImported, equals(1));

      // Verify targetDb still has only 2 labels with the target device's UUIDs
      final targetLabels = await targetDb.select(targetDb.labels).get();
      expect(targetLabels.map((l) => l.id).toSet(), equals({'new_device_anime_uuid', 'new_device_region_uuid'}));

      // Verify placeLabels and referenceImage animeLabelId were remapped to target device's UUIDs
      final targetPlaceLabels = await targetDb.select(targetDb.placeLabels).get();
      expect(
        targetPlaceLabels.map((pl) => pl.labelId).toSet(),
        equals({'new_device_anime_uuid', 'new_device_region_uuid'}),
      );

      final targetRef = await (targetDb.select(targetDb.newReferenceImages)..where((r) => r.id.equals('ref_uji'))).getSingle();
      expect(targetRef.animeLabelId, equals('new_device_anime_uuid'));
    } finally {
      await targetDb.close();
    }
  });

  test('Adversarial: preserves distinct photos with identical basenames and restores place coverLocalPath', () async {
    final dirA = Directory(p.join(tempDir.path, 'dirA'))..createSync(recursive: true);
    final dirB = Directory(p.join(tempDir.path, 'dirB'))..createSync(recursive: true);
    final coverFile = File(p.join(tempDir.path, 'cover.jpg'))..writeAsBytesSync([1, 2, 3, 4]);
    final photoFileA = File(p.join(dirA.path, 'IMG_0001.jpg'))..writeAsBytesSync([10, 20, 30]);
    final photoFileB = File(p.join(dirB.path, 'IMG_0001.jpg'))..writeAsBytesSync([40, 50, 60, 70]);

    await db.into(db.places).insert(
          PlacesCompanion.insert(
            placeKey: 'place_cover_test',
            name: 'Cover Test Spot',
            lat: 35.0,
            lng: 135.0,
            coverLocalPath: Value(coverFile.path),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'photo_a',
            placeKey: 'place_cover_test',
            localPath: photoFileA.path,
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'photo_b',
            placeKey: 'place_cover_test',
            localPath: photoFileB.path,
          ),
        );

    final exportPath = p.join(tempDir.path, 'collision_test.pilgrimage');
    final zipFile = await backupService.exportLibraryArchive(db, targetZipPath: exportPath);

    final targetDb = AppDatabase.forTesting(NativeDatabase.memory());
    final targetStorageDir = Directory(p.join(tempDir.path, 'target_collision_storage'))..createSync(recursive: true);

    try {
      await backupService.importLibraryArchive(targetDb, zipFile, baseStorageDir: targetStorageDir);

      final restoredPlace = await (targetDb.select(targetDb.places)..where((p) => p.placeKey.equals('place_cover_test'))).getSingle();
      expect(restoredPlace.coverLocalPath, isNotNull);
      expect(restoredPlace.coverLocalPath!.startsWith(targetStorageDir.path), isTrue);
      expect(File(restoredPlace.coverLocalPath!).readAsBytesSync(), equals([1, 2, 3, 4]));

      final restoredA = await (targetDb.select(targetDb.photos)..where((p) => p.id.equals('photo_a'))).getSingle();
      final restoredB = await (targetDb.select(targetDb.photos)..where((p) => p.id.equals('photo_b'))).getSingle();
      expect(restoredA.localPath, isNot(equals(restoredB.localPath)));
      expect(File(restoredA.localPath).readAsBytesSync(), equals([10, 20, 30]));
      expect(File(restoredB.localPath).readAsBytesSync(), equals([40, 50, 60, 70]));
    } finally {
      await targetDb.close();
    }
  });
}
