import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/camera/models/shooting_core_models.dart';
import 'package:trip_planner/features/camera/providers/shooting_core_providers.dart';
import 'package:trip_planner/features/camera/services/pilgrimage_shooting_service.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  late AppDatabase db;
  late PlaceRepository placeRepo;
  late TripRepository tripRepo;
  const service = PilgrimageShootingService();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    placeRepo = DriftPlaceRepository(db);
    tripRepo = DriftTripRepository(db, null, 'user_tester', placeRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('PilgrimageShootingService - Distance & Geodesics', () {
    test('calculateDistanceMeters computes accurate Haversine distance', () {
      // Tokyo Station (35.6812, 139.7671) to Akihabara Station (35.6983, 139.7730) ~ 2.0 km
      final dist = PilgrimageShootingService.calculateDistanceMeters(
        35.6812,
        139.7671,
        35.6983,
        139.7730,
      );
      expect(dist, greaterThan(1900));
      expect(dist, lessThan(2100));

      // Close points: Uji Bridge to Kumiko Bench (~120m)
      final closeDist = PilgrimageShootingService.calculateDistanceMeters(
        34.8910,
        135.8080,
        34.8915,
        135.8090,
      );
      expect(closeDist, greaterThan(80));
      expect(closeDist, lessThan(150));
    });
  });

  group('PilgrimageShootingService - Today Trip Resolution', () {
    test('resolves active trip and day block for today calendar date', () async {
      final now = DateTime(2026, 8, 15, 14, 0);

      final trip = await tripRepo.createTrip(
        title: 'Kyoto Summer Tour',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 2,
      );

      final todayInfo = await service.getTodayTrip(db, now: now);
      expect(todayInfo, isNotNull);
      expect(todayInfo!.trip.id, equals(trip.id));
      expect(todayInfo.trip.title, equals('Kyoto Summer Tour'));
      expect(todayInfo.day.sortKey, isNotEmpty);
    });

    test('returns null if no trip dates match today', () async {
      final now = DateTime(2026, 8, 15);

      await tripRepo.createTrip(
        title: 'Future Trip',
        ownerId: 'user_tester',
        startDate: '2026-09-01',
        dayCount: 3,
      );

      final todayInfo = await service.getTodayTrip(db, now: now);
      expect(todayInfo, isNull);
    });
  });

  group('PilgrimageShootingService - Nearby Places (Shoot here)', () {
    test('finds places within 150m and prioritizes today trip stops at the top', () async {
      final now = DateTime(2026, 8, 15, 10, 0);

      // 1. Setup Places in Library
      // Place A: 120m away, scheduled in today's trip
      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_a',
        name: 'Spot A (Today Stop)',
        lat: 34.8915,
        lng: 135.8090,
      ));

      // Place B: 30m away, NOT in trip (closer, but not in today's trip!)
      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_b',
        name: 'Spot B (Closer, but not in trip)',
        lat: 34.8911,
        lng: 135.8082,
      ));

      // Place C: 500m away (outside 150m radius)
      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_c',
        name: 'Spot C (Far)',
        lat: 34.8960,
        lng: 135.8150,
      ));

      // Add Anime label to Place A
      await db.into(db.labels).insert(LabelsCompanion.insert(
        id: 'label_eupho',
        kind: 'anime',
        name: 'Sound! Euphonium',
      ));
      await db.into(db.placeLabels).insert(PlaceLabelsCompanion.insert(
        placeKey: 'place_a',
        labelId: 'label_eupho',
      ));

      // Add reference frame to Place A
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
        id: 'ref_a1',
        placeKey: const Value('place_a'),
        localPath: const Value('/frames/eupho_ep1.jpg'),
      ));

      // 2. Setup Today Trip with Stop A
      final trip = await tripRepo.createTrip(
        title: 'Uji Tour',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 1,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);
      final stopA = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot A (Today Stop)',
        lat: 34.8915,
        lng: 135.8090,
        addedBy: 'user_tester',
      );
      // Link stopA to place_a
      await (db.update(db.stops)..where((s) => s.id.equals(stopA.id))).write(
        const StopsCompanion(placeKey: Value('place_a')),
      );
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stopA.id, dayId: days.first.id);

      // Current User location at (34.8910, 135.8080)
      final candidates = await service.findNearbyPlaces(
        db,
        lat: 34.8910,
        lng: 135.8080,
        maxDistanceMeters: 150.0,
        now: now,
      );

      // Verify: Spot C is excluded (>150m)
      expect(candidates.length, equals(2));

      // Spot A must be FIRST because it is on today's trip schedule, even though Spot B is closer!
      expect(candidates[0].place.placeKey, equals('place_a'));
      expect(candidates[0].isTodayStop, isTrue);
      expect(candidates[0].animeTitle, equals('Sound! Euphonium'));
      expect(candidates[0].referenceFrames.length, equals(1));
      expect(candidates[0].primaryFrame?.localPath, equals('/frames/eupho_ep1.jpg'));

      // Spot B is SECOND
      expect(candidates[1].place.placeKey, equals('place_b'));
      expect(candidates[1].isTodayStop, isFalse);
    });
  });

  group('PilgrimageShootingService - Record Shot', () {
    test('records on-plan shot, creates Photo & PlaceVisit, and marks schedule item done', () async {
      final now = DateTime(2026, 8, 15, 11, 30);

      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_uji',
        name: 'Uji Bridge',
        lat: 34.8910,
        lng: 135.8080,
      ));

      final trip = await tripRepo.createTrip(
        title: 'Pilgrimage Trip',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 1,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);
      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Uji Bridge',
        lat: 34.8910,
        lng: 135.8080,
        addedBy: 'user_tester',
      );
      await (db.update(db.stops)..where((s) => s.id.equals(stop.id))).write(
        const StopsCompanion(placeKey: Value('place_uji')),
      );
      final item = await tripRepo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days.first.id);

      final result = await service.recordShot(
        db,
        sourceImagePath: '/dummy/camera/shot_1.jpg',
        placeKey: 'place_uji',
        takenAt: now,
      );

      expect(result.wasOffPlan, isFalse);
      expect(result.photo.placeKey, equals('place_uji'));
      expect(result.photo.kind, equals('original'));
      expect(result.photo.keepAsIs, isFalse);
      expect(result.visit.date, equals('2026-08-15'));
      expect(result.scheduleItem?.status, equals('done'));

      // Verify in DB
      final dbItem = await (db.select(db.scheduleItems)..where((s) => s.id.equals(item.id))).getSingle();
      expect(dbItem.status, equals('done'));
      expect(dbItem.syncStatus, equals(1)); // marked dirty for sync
    });

    test('records off-plan shot, automatically adds place to today day and marks done', () async {
      final now = DateTime(2026, 8, 15, 15, 0);

      // Place in library but not planned in today's trip
      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_kumiko_bench',
        name: 'Kumiko Bench',
        lat: 34.8900,
        lng: 135.8150,
      ));

      final trip = await tripRepo.createTrip(
        title: 'Pilgrimage Trip',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 1,
      );

      final result = await service.recordShot(
        db,
        sourceImagePath: '/dummy/camera/bench_shot.jpg',
        placeKey: 'place_kumiko_bench',
        takenAt: now,
      );

      expect(result.wasOffPlan, isTrue);
      expect(result.photo.placeKey, equals('place_kumiko_bench'));
      expect(result.stop?.name, equals('Kumiko Bench'));
      expect(result.scheduleItem?.status, equals('done'));
      expect(result.scheduleItem?.sortKey, isNotEmpty);

      // Verify schedule items on day block
      final days = await tripRepo.getDaysForTrip(trip.id);
      final dayItems = await tripRepo.getScheduleItemsForDay(days.first.id);
      expect(dayItems.length, equals(1));
      expect(dayItems.first.status, equals('done'));
    });

    test('records shot without a trip cleanly (personal library only)', () async {
      final now = DateTime(2026, 8, 15, 16, 0);

      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_solitary',
        name: 'Solitary Shrine',
        lat: 34.9000,
        lng: 135.8200,
      ));

      final result = await service.recordShot(
        db,
        sourceImagePath: '/dummy/camera/solo.jpg',
        placeKey: 'place_solitary',
        takenAt: now,
      );

      expect(result.wasOffPlan, isFalse);
      expect(result.photo.placeKey, equals('place_solitary'));
      expect(result.visit.date, equals('2026-08-15'));
      expect(result.stop, isNull);
      expect(result.scheduleItem, isNull);
    });
  });

  group('PilgrimageShootingService - Photos to Edit Inbox', () {
    test('streams unedited photos and removes them when derived or marked keepAsIs', () async {
      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_test',
        name: 'Test Spot',
        lat: 35.0,
        lng: 135.0,
      ));

      // Record photo 1
      final shot1 = await service.recordShot(
        db,
        sourceImagePath: '/photos/shot1.jpg',
        placeKey: 'place_test',
      );

      // Record photo 2
      final shot2 = await service.recordShot(
        db,
        sourceImagePath: '/photos/shot2.jpg',
        placeKey: 'place_test',
      );

      var inbox = await service.watchPhotosToEdit(db).first;
      expect(inbox.length, equals(2));

      // Mark photo 1 as keepAsIs
      await service.markPhotoAsKeptAsIs(db, shot1.photo.id);

      inbox = await service.watchPhotosToEdit(db).first;
      expect(inbox.length, equals(1));
      expect(inbox.first.photo.id, equals(shot2.photo.id));

      // Derive edited version from photo 2
      await db.into(db.photos).insert(PhotosCompanion.insert(
        id: 'photo_edited_2',
        placeKey: 'place_test',
        localPath: '/photos/shot2_cutout.png',
        kind: const Value('edited'),
        derivedFromId: Value(shot2.photo.id),
      ));

      inbox = await service.watchPhotosToEdit(db).first;
      expect(inbox, isEmpty);
    });
  });

  group('PilgrimageShootingService - Riverpod Providers', () {
    test('providers resolve todayTrip and nearbyShootingPlaces correctly', () async {
      final now = DateTime.now();
      final todayIso = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_prov',
        name: 'Provider Spot',
        lat: 34.8910,
        lng: 135.8080,
      ));

      final trip = await tripRepo.createTrip(
        title: 'Provider Trip',
        ownerId: 'user_tester',
        startDate: todayIso,
        dayCount: 1,
      );

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);

      final todayInfo = await container.read(todayTripProvider.future);
      expect(todayInfo, isNotNull);
      expect(todayInfo!.trip.id, equals(trip.id));

      final candidates = await container.read(
        nearbyShootingPlacesProvider(const NearbyPlacesQuery(lat: 34.8910, lng: 135.8080)).future,
      );
      expect(candidates.length, equals(1));
      expect(candidates.first.place.name, equals('Provider Spot'));
    });
  });
}
