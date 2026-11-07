import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/camera/models/photo_exif_models.dart';
import 'package:trip_planner/features/camera/providers/photo_matcher_providers.dart';
import 'package:trip_planner/features/camera/services/photo_exif_extractor.dart';
import 'package:trip_planner/features/camera/services/photo_scene_matcher_service.dart';

Uint8List _createMockJpeg({
  int orientation = 1,
  String? dateTimeStr,
}) {
  final image = img.Image(width: 16, height: 16);
  img.fill(image, color: img.ColorRgb8(100, 150, 200));
  if (orientation != 1) {
    image.exif.imageIfd.orientation = orientation;
  }
  if (dateTimeStr != null) {
    image.exif.exifIfd[0x9003] = dateTimeStr; // DateTimeOriginal
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  group('PhotoExifExtractor', () {
    test('extracts orientation and DateTimeOriginal from JPEG image bytes', () {
      final jpegBytes = _createMockJpeg(
        orientation: 6,
        dateTimeStr: '2026:05:12 14:30:00',
      );

      final exif = PhotoExifExtractor.extractFromBytes(jpegBytes);
      expect(exif.orientation, 6);
      expect(exif.capturedAt, DateTime(2026, 5, 12, 14, 30, 0));
    });

    test('handles empty and corrupted byte arrays gracefully without throwing', () {
      final emptyExif = PhotoExifExtractor.extractFromBytes([]);
      expect(emptyExif.hasGps, isFalse);
      expect(emptyExif.capturedAt, isNull);

      final corruptedExif = PhotoExifExtractor.extractFromBytes([1, 2, 3, 4, 5, 6, 7, 8]);
      expect(corruptedExif.hasGps, isFalse);
    });

    test('extractFromFile falls back to file modified time if EXIF timestamp is missing', () async {
      final tempDir = Directory.systemTemp.createTempSync('exif_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final file = File('${tempDir.path}/plain.jpg');
      await file.writeAsBytes(_createMockJpeg());

      final exif = await PhotoExifExtractor.extractFromFile(file);
      expect(exif.capturedAt, isNotNull);
      final stat = await file.stat();
      expect(exif.capturedAt!.difference(stat.modified).inSeconds.abs(), lessThanOrEqualTo(2));
    });
  });

  group('PhotoSceneMatcherService - Scoring & Spatial-Temporal Alignment', () {
    const service = PhotoSceneMatcherService();

    // Spot 1: Demachi Masugata Shotengai (Tamako Market)
    final targetDemachi = StopTarget(
      stopId: 'stop_demachi',
      placeKey: 'p_demachi',
      name: 'Demachi Masugata Shotengai',
      animeTitle: 'Tamako Market',
      referenceImageId: 'ref_tamako_1',
      lat: 35.030500,
      lng: 135.770500,
      scheduledWindowStart: DateTime(2026, 5, 12, 10, 0),
      scheduledWindowEnd: DateTime(2026, 5, 12, 11, 0),
    );

    // Spot 2: Uji Bridge (Sound! Euphonium) - 16km away, scheduled in afternoon
    final targetUji = StopTarget(
      stopId: 'stop_uji',
      placeKey: 'p_uji',
      name: 'Uji Bridge',
      animeTitle: 'Sound! Euphonium',
      referenceImageId: 'ref_eupho_1',
      lat: 34.890500,
      lng: 135.808000,
      scheduledWindowStart: DateTime(2026, 5, 12, 14, 0),
      scheduledWindowEnd: DateTime(2026, 5, 12, 15, 30),
    );

    test('matches photo with high confidence when both GPS and scheduled time align', () async {
      // Photo taken at Demachi (10m away) at 10:20 (during scheduled 10:00-11:00 visit)
      final photo = PhotoInput(
        id: 'photo_1',
        explicitExif: PhotoExifData(
          lat: 35.030520,
          lng: 135.770520, // ~3 meters away
          capturedAt: DateTime(2026, 5, 12, 10, 20),
        ),
      );

      final result = await service.matchPhoto(
        photo: photo,
        targets: [targetDemachi, targetUji],
      );

      expect(result.hasMatch, isTrue);
      expect(result.isConfident, isTrue);
      expect(result.bestMatch!.stopId, 'stop_demachi');
      expect(result.bestMatch!.confidence, greaterThanOrEqualTo(0.95));
      expect(result.bestMatch!.referenceImageId, 'ref_tamako_1');
      expect(result.isAmbiguous, isFalse);
    });

    test('matches photo accurately using GPS even when photo timestamp differs', () async {
      // Photo taken at Uji Bridge with GPS, but early morning before scheduled time
      final photo = PhotoInput(
        id: 'photo_2',
        explicitExif: PhotoExifData(
          lat: 34.890510,
          lng: 135.808010, // ~2m away
          capturedAt: DateTime(2026, 5, 12, 8, 30), // Scheduled is 14:00
        ),
      );

      final result = await service.matchPhoto(
        photo: photo,
        targets: [targetDemachi, targetUji],
      );

      expect(result.hasMatch, isTrue);
      expect(result.bestMatch!.stopId, 'stop_uji');
      expect(result.bestMatch!.distanceMeters, lessThan(10.0));
    });

    test('matches photo using scheduled timeline when GPS is unavailable', () async {
      // Photo without GPS, but timestamp is 14:15 on May 12 (aligns with Uji Bridge)
      final photo = PhotoInput(
        id: 'photo_no_gps',
        explicitExif: PhotoExifData(
          capturedAt: DateTime(2026, 5, 12, 14, 15),
        ),
      );

      final result = await service.matchPhoto(
        photo: photo,
        targets: [targetDemachi, targetUji],
      );

      expect(result.hasMatch, isTrue);
      expect(result.bestMatch!.stopId, 'stop_uji');
      expect(result.bestMatch!.confidence, closeTo(0.65, 0.05));
    });

    test('detects ambiguity when two stops are at virtually identical coordinates', () async {
      // Two stops within 5 meters of each other (e.g. adjacent platforms)
      final platform1 = StopTarget(
        stopId: 'p1',
        placeKey: 'p1',
        name: 'Kyoto Station Platform 0',
        lat: 34.985833,
        lng: 135.758333,
      );
      final platform2 = StopTarget(
        stopId: 'p2',
        placeKey: 'p2',
        name: 'Kyoto Station Platform 2',
        lat: 34.985840,
        lng: 135.758340,
      );

      final photo = PhotoInput(
        id: 'photo_station',
        explicitExif: const PhotoExifData(
          lat: 34.985835,
          lng: 135.758335,
        ),
      );

      final result = await service.matchPhoto(
        photo: photo,
        targets: [platform1, platform2],
      );

      expect(result.isAmbiguous, isTrue);
      expect(result.allCandidates.length, 2);
    });
  });

  group('PhotoSceneMatcherService - SQLite Integration & Entity Scope Isolation', () {
    late AppDatabase db;
    late PhotoSceneMatcherService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = const PhotoSceneMatcherService();
    });

    tearDown(() async {
      await db.close();
    });

    test('matchPhotosForTrip queries SQLite and applyPhotoMatches commits to database', () async {
      // 0. Create Place for Demachi
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'place_demachi',
              name: 'Demachi Masugata',
              lat: 35.0305,
              lng: 135.7705,
            ),
          );

      // 1. Create Trip for Alice with date 2026-05-12
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_alice',
              title: 'Alice Tour',
              ownerId: 'user_alice',
              startDate: const Value('2026-05-12'),
              dayCount: const Value(1),
            ),
          );

      // 2. Day 1
      await db.into(db.tripDays).insert(
            TripDaysCompanion.insert(
              id: 'day_1',
              tripId: 'trip_alice',
              sortKey: 'a0',
              pinnedDate: const Value('2026-05-12'),
            ),
          );

      // 3. Stop at Demachi
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_demachi',
              tripId: 'trip_alice',
              placeKey: 'place_demachi',
              name: 'Demachi Masugata',
              lat: 35.0305,
              lng: 135.7705,
              addedBy: 'user_alice',
            ),
          );

      // 4. Schedule item (10:00 - 11:00)
      await db.into(db.scheduleItems).insert(
            ScheduleItemsCompanion.insert(
              id: 'sch_1',
              tripId: 'trip_alice',
              stopId: 'stop_demachi',
              dayId: 'day_1',
              sortKey: 'a0',
              fixedTime: const Value(600), // 10:00
              stayMinutes: const Value(60),
            ),
          );

      // 5. Test photo taken at Demachi
      final photos = [
        PhotoInput(
          id: 'photo_demachi_captured',
          explicitExif: PhotoExifData(
            lat: 35.03051,
            lng: 135.77051,
            capturedAt: DateTime(2026, 5, 12, 10, 15),
          ),
        ),
      ];

      final results = await service.matchPhotosForTrip(db, 'trip_alice', photos);
      expect(results.length, 1);
      final match = results.first;
      expect(match.hasMatch, isTrue);
      expect(match.bestMatch!.stopId, 'stop_demachi');

      // 6. Apply matches into database
      final applied = await service.applyPhotoMatches(db, 'trip_alice', results);
      expect(applied, 1);

      // Verify photo was inserted into Photos table
      final storedPhotos = await db.select(db.photos).get();
      expect(storedPhotos.length, 1);
      expect(storedPhotos.first.id, 'photo_demachi_captured');
      expect(storedPhotos.first.placeKey, 'place_demachi');
      expect(storedPhotos.first.tripId, 'trip_alice');
    });

    test('Riverpod Provider evaluates tripPhotoMatchesProvider', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoSceneMatcherServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_empty',
              title: 'Empty Trip',
              ownerId: 'user_bob',
            ),
          );

      final matches = await container.read(
        tripPhotoMatchesProvider((tripId: 'trip_empty', photos: const [])).future,
      );
      expect(matches, isEmpty);
    });
  });
}
