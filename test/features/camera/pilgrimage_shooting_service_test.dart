import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
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
      expect(candidates[0].placeKey, equals('place_a'));
      expect(candidates[0].isTodayStop, isTrue);
      expect(candidates[0].animeTitle, equals('Sound! Euphonium'));
      expect(candidates[0].referenceFrames.length, equals(1));
      expect(candidates[0].primaryFrame?.localPath, equals('/frames/eupho_ep1.jpg'));

      // Spot B is SECOND
      expect(candidates[1].placeKey, equals('place_b'));
      expect(candidates[1].isTodayStop, isFalse);
    });

    test('finds today stop straight from createTripOnlySpot (visibility = trip_only, no relinking) first', () async {
      final now = DateTime(2026, 8, 15, 10, 0);

      // A library place 30m away
      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_saved_near',
        name: 'Saved Library Place',
        lat: 34.8911,
        lng: 135.8082,
      ));

      final trip = await tripRepo.createTrip(
        title: 'Trip Only Test',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 1,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);

      // Create a trip-only spot (has visibility = 'trip_only') and schedule it straight away without manual relinking
      final stopTripOnly = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Trip Only Spot 6m away',
        lat: 34.89105,
        lng: 135.80805,
        addedBy: 'user_tester',
      );
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stopTripOnly.id, dayId: days.first.id);

      final candidates = await service.findNearbyPlaces(
        db,
        lat: 34.8910,
        lng: 135.8080,
        maxDistanceMeters: 150.0,
        now: now,
      );

      // Both should be found, and the trip-only stop must be FIRST because it is on today's trip!
      expect(candidates.length, equals(2));
      expect(candidates[0].name, equals('Trip Only Spot 6m away'));
      expect(candidates[0].isTodayStop, isTrue);
      expect(candidates[0].todayStop?.id, equals(stopTripOnly.id));
      expect(candidates[0].place, isNotNull); // place row exists with visibility = 'trip_only'
      expect(candidates[0].place?.visibility, equals('trip_only'));

      expect(candidates[1].name, equals('Saved Library Place'));
      expect(candidates[1].isTodayStop, isFalse);
    });

    test('finds today stop whose placeKey has no row in places and matches reference frame by stopId', () async {
      final now = DateTime(2026, 8, 15, 10, 0);

      final trip = await tripRepo.createTrip(
        title: 'Remote Shared Trip',
        ownerId: 'remote_owner',
        startDate: '2026-08-15',
        dayCount: 1,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);

      // Simulate a stop synced from remote where placeKey has NO row in local places table
      const remoteStopId = 'stop_remote_123';
      const remotePlaceKey = 'remote_spot_abc';
      await db.into(db.stops).insert(StopsCompanion.insert(
        id: remoteStopId,
        tripId: trip.id,
        placeKey: remotePlaceKey,
        name: 'Remote Joined Stop',
        lat: 34.8912,
        lng: 135.8085,
        addedBy: 'remote_owner',
      ));

      // Schedule the stop on today's day block
      await tripRepo.scheduleStop(tripId: trip.id, stopId: remoteStopId, dayId: days.first.id);

      // Attach a reference frame linked by stopId (typical for shared trip frames without local placeKey)
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
        id: 'ref_stop_frame_1',
        stopId: const Value(remoteStopId),
        localPath: const Value('/frames/shared_frame.jpg'),
      ));

      // Verify no row exists in places table for remotePlaceKey
      final placeInDb = await (db.select(db.places)..where((p) => p.placeKey.equals(remotePlaceKey))).getSingleOrNull();
      expect(placeInDb, isNull);

      final candidates = await service.findNearbyPlaces(
        db,
        lat: 34.8910,
        lng: 135.8080,
        maxDistanceMeters: 150.0,
        now: now,
      );

      expect(candidates.length, equals(1));
      final candidate = candidates.first;
      expect(candidate.name, equals('Remote Joined Stop'));
      expect(candidate.placeKey, equals(remotePlaceKey));
      expect(candidate.place, isNull); // No row in places table!
      expect(candidate.isTodayStop, isTrue);
      expect(candidate.todayStop?.id, equals(remoteStopId));
      expect(candidate.referenceFrames.length, equals(1));
      expect(candidate.primaryFrame?.id, equals('ref_stop_frame_1'));
      expect(candidate.primaryFrame?.localPath, equals('/frames/shared_frame.jpg'));
    });

    test('finds stops across whole trip: target day first, other days second (with dayNumber), library third', () async {
      final now = DateTime(2026, 8, 15, 10, 0);

      final trip = await tripRepo.createTrip(
        title: 'Two Day Pilgrimage',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 2,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);
      final day1 = days[0];
      final day2 = days[1];

      // Stop on Day 1 (target day), 100m away
      final stopDay1 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Day 1 Spot (100m)',
        lat: 34.8919,
        lng: 135.8080,
        addedBy: 'user_tester',
      );
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stopDay1.id, dayId: day1.id);

      // Stop on Day 2, 20m away (closer, but scheduled on Day 2!)
      final stopDay2 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Day 2 Spot (20m closer)',
        lat: 34.8911,
        lng: 135.8081,
        addedBy: 'user_tester',
      );
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stopDay2.id, dayId: day2.id);

      // Library place, 40m away (not in trip)
      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_lib_nearby',
        name: 'Library Spot (40m)',
        lat: 34.8913,
        lng: 135.8080,
      ));

      final candidates = await service.findNearbyPlaces(
        db,
        lat: 34.8910,
        lng: 135.8080,
        tripId: trip.id,
        dayId: day1.id,
        maxDistanceMeters: 150.0,
        now: now,
      );

      expect(candidates.length, equals(3));

      // 1. Target day (Day 1) stop is FIRST even though Day 2 stop is closer!
      expect(candidates[0].name, equals('Day 1 Spot (100m)'));
      expect(candidates[0].isTargetDayStop, isTrue);
      expect(candidates[0].isTodayStop, isTrue);
      expect(candidates[0].dayNumber, equals(1));

      // 2. Day 2 stop is SECOND (tagged with Day 2 for "Other places nearby")
      expect(candidates[1].name, equals('Day 2 Spot (20m closer)'));
      expect(candidates[1].isTargetDayStop, isFalse);
      expect(candidates[1].isTodayStop, isFalse);
      expect(candidates[1].dayNumber, equals(2));

      // 3. Library spot not in trip is THIRD
      expect(candidates[2].name, equals('Library Spot (40m)'));
      expect(candidates[2].isTargetDayStop, isFalse);
      expect(candidates[2].todayStop, isNull);
    });

    test('findNearbyPlaces resolves trip from dayId and calculates correct day numbers skipping backup and deleted days', () async {
      final trip = await tripRepo.createTrip(
        title: 'Trip with Backup & Deleted Days',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 2,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);
      // days: Day 1 (index 0), Day 2 (index 1)

      // Add a backup day block (3rd block on a 2-day trip, so index 2 >= dayCount => isBackup)
      final backupDay = await tripRepo.addDayBlock(
        trip.id,
        title: 'Rain Plan Backup',
      );

      // Add a stop to Day 2
      final stopDay2 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Day 2 Shrine',
        lat: 34.8912,
        lng: 135.8082,
        addedBy: 'user_tester',
      );
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stopDay2.id, dayId: days[1].id);

      // Add a stop to Backup Day
      final stopBackup = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Backup Museum',
        lat: 34.8914,
        lng: 135.8084,
        addedBy: 'user_tester',
      );
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stopBackup.id, dayId: backupDay.id);

      // Query with dayId of Day 2, with NO tripId passed, and off-trip date (now: September)
      final candidates = await service.findNearbyPlaces(
        db,
        lat: 34.8910,
        lng: 135.8080,
        dayId: days[1].id, // Day 2 passed without tripId
        now: DateTime(2026, 9, 1),
      );

      // Should find Day 2 stop as target day stop (isTargetDayStop = true)
      final d2Candidate = candidates.firstWhere((c) => c.name == 'Day 2 Shrine');
      expect(d2Candidate.isTargetDayStop, isTrue);
      expect(d2Candidate.dayNumber, equals(2));

      // Backup day stop should have no dayNumber assigned
      final backupCandidate = candidates.firstWhere((c) => c.name == 'Backup Museum');
      expect(backupCandidate.isTargetDayStop, isFalse);
      expect(backupCandidate.dayNumber, isNull);
    });
  });

  group('PilgrimageShootingService - Nearby stop on several days', () {
    test('a stop planned on two days counts as the target day stop on either, and else its earliest day', () async {
      final trip = await tripRepo.createTrip(
        title: 'Two visits',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 3,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);
      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Uji Bridge',
        lat: 34.8912,
        lng: 135.8082,
        addedBy: 'user_tester',
      );
      // Day 3 first, so the insertion order doesn't happen to pick Day 1.
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days[2].id);
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days[0].id);

      for (final (day, number) in [(days[0], 1), (days[2], 3)]) {
        final near = (await service.findNearbyPlaces(db, lat: 34.8910, lng: 135.8080, dayId: day.id)).single;
        expect(near.isTargetDayStop, isTrue, reason: 'Day $number');
        expect((near.dayNumber, near.todayScheduleItem!.dayId), (number, day.id));
      }

      final onDay2 = (await service.findNearbyPlaces(db, lat: 34.8910, lng: 135.8080, dayId: days[1].id)).single;
      expect(onDay2.isTargetDayStop, isFalse);
      expect(onDay2.dayNumber, 1, reason: 'its earliest day');
    });
  });

  group('PilgrimageShootingService - Record Shot', () {
    test('records on-plan shot, attaches photo to trip, reuses visit, and leaves schedule item status untouched', () async {
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
      // Shot does NOT mark stop done (user's call later)
      expect(result.scheduleItem?.status, equals('planned'));

      // Verify in DB that schedule item is untouched
      final dbItem = await (db.select(db.scheduleItems)..where((s) => s.id.equals(item.id))).getSingle();
      expect(dbItem.status, equals('planned'));
    });

    test('records shot for place not in trip without mutating plan (files photo under trip, no phantom stops)', () async {
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
      expect(result.photo.tripId, equals(trip.id));
      expect(result.stop, isNull);
      expect(result.scheduleItem, isNull);

      // Verify no schedule items or stops were created in the trip
      final days = await tripRepo.getDaysForTrip(trip.id);
      final dayItems = await tripRepo.getScheduleItemsForDay(days.first.id);
      expect(dayItems, isEmpty);
      final tripStops = await tripRepo.getStopsForTrip(trip.id);
      expect(tripStops, isEmpty);
    });

    test('multiple shots at the same place write only one place_visits row for the day', () async {
      final now = DateTime(2026, 8, 15, 10, 0);

      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_multi_shot',
        name: 'Multi Shot Spot',
        lat: 34.8910,
        lng: 135.8080,
      ));

      for (var i = 1; i <= 5; i++) {
        await service.recordShot(
          db,
          sourceImagePath: '/dummy/camera/shot_$i.jpg',
          placeKey: 'place_multi_shot',
          takenAt: now,
        );
      }

      final visits = await (db.select(db.placeVisits)
            ..where((v) => v.placeKey.equals('place_multi_shot')))
          .get();
      expect(visits.length, equals(1));

      final photos = await (db.select(db.photos)
            ..where((p) => p.placeKey.equals('place_multi_shot')))
          .get();
      expect(photos.length, equals(5));
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

    test('records shot at stop whose placeKey has no prior row in places table without FK violation', () async {
      final now = DateTime(2026, 8, 15, 11, 0);

      final trip = await tripRepo.createTrip(
        title: 'Joined Trip',
        ownerId: 'remote_owner',
        startDate: '2026-08-15',
        dayCount: 1,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);

      const remoteStopId = 'stop_remote_shot';
      const remotePlaceKey = 'remote_spot_fk_test';
      await db.into(db.stops).insert(StopsCompanion.insert(
        id: remoteStopId,
        tripId: trip.id,
        placeKey: remotePlaceKey,
        name: 'Remote Stop for Shot',
        lat: 34.8910,
        lng: 135.8080,
        addedBy: 'remote_owner',
      ));
      await tripRepo.scheduleStop(tripId: trip.id, stopId: remoteStopId, dayId: days.first.id);

      final result = await service.recordShot(
        db,
        sourceImagePath: '/dummy/camera/remote_shot.jpg',
        placeKey: remotePlaceKey,
        takenAt: now,
      );

      expect(result.photo.placeKey, equals(remotePlaceKey));
      expect(result.scheduleItem?.status, equals('planned'));

      // Verify place row was safely created to maintain FK integrity
      final place = await (db.select(db.places)..where((p) => p.placeKey.equals(remotePlaceKey))).getSingleOrNull();
      expect(place, isNotNull);
      expect(place?.visibility, equals('trip_only'));
      expect(place?.name, equals('Remote Stop for Shot'));
    });

    test('recordShot handles stop moved to backlog and rescheduled without throwing Too many elements', () async {
      final now = DateTime(2026, 8, 15, 11, 0);

      final trip = await tripRepo.createTrip(
        title: 'Rescheduled Stop Trip',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 2,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Rescheduled Uji Bridge',
        lat: 34.8910,
        lng: 135.8080,
        addedBy: 'user_tester',
      );

      // 1. Schedule on Day 1
      final item1 = await tripRepo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days[0].id);

      // 2. Drag to backlog (soft delete schedule item)
      await tripRepo.deleteScheduleItem(item1.id);

      // 3. Schedule back onto Day 2
      final item2 = await tripRepo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days[1].id);

      // Verify that 2 rows exist for this stop in scheduleItems (1 soft-deleted, 1 active)
      final allItems = await (db.select(db.scheduleItems)..where((s) => s.stopId.equals(stop.id))).get();
      expect(allItems.length, equals(2));

      // 4. Shoot at the stop - must NOT throw StateError (Too many elements)
      final result = await service.recordShot(
        db,
        sourceImagePath: '/dummy/camera/rescheduled.jpg',
        placeKey: stop.placeKey!,
        stopId: stop.id,
        tripId: trip.id,
        takenAt: now,
      );

      expect(result.scheduleItem, isNotNull);
      expect(result.scheduleItem?.id, equals(item2.id));
      expect(result.scheduleItem?.dayId, equals(days[1].id));
    });

    test('recordShot throws ArgumentError when neither place nor stop exists', () async {
      expect(
        () => service.recordShot(
          db,
          sourceImagePath: '/dummy/camera/nonexistent.jpg',
          placeKey: 'completely_unknown_place_key',
        ),
        throwsA(isA<ArgumentError>()),
      );
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
      expect(candidates.first.name, equals('Provider Spot'));

      // Verify pilgrimage feed provider with LiveFeedQuery
      final lfq = LiveFeedQuery(tripId: trip.id, userLat: 34.8910, userLng: 135.8080);
      final lfqMoved = LiveFeedQuery(tripId: trip.id, userLat: 34.8920, userLng: 135.8090, deviceHeading: 90.0);
      // Riverpod equality keys on tripId/dayId so lfq == lfqMoved (no stream teardown)
      expect(lfq, equals(lfqMoved));
      expect(lfq.hashCode, equals(lfqMoved.hashCode));

      final feed = await container.read(pilgrimageFeedProvider(lfq).future);
      expect(feed, isNotNull);
      expect(feed!.trip.id, equals(trip.id));
    });
  });

  group('PilgrimageShootingService - Bearing & Orientation', () {
    test('calculateBearingDegrees computes accurate True North angles', () {
      // Due North
      expect(PilgrimageShootingService.calculateBearingDegrees(35.0, 135.0, 36.0, 135.0), closeTo(0.0, 0.5));
      // Due South
      expect(PilgrimageShootingService.calculateBearingDegrees(35.0, 135.0, 34.0, 135.0), closeTo(180.0, 0.5));
      // Due East
      expect(PilgrimageShootingService.calculateBearingDegrees(35.0, 135.0, 35.0, 136.0), closeTo(90.0, 1.0));
      // Due West
      expect(PilgrimageShootingService.calculateBearingDegrees(35.0, 135.0, 35.0, 134.0), closeTo(270.0, 1.0));
    });

    test('getCardinalDirection maps degrees to 8-point cardinal and Chinese strings', () {
      expect(PilgrimageShootingService.getCardinalDirection(0.0), equals(('N', '北')));
      expect(PilgrimageShootingService.getCardinalDirection(45.0), equals(('NE', '東北')));
      expect(PilgrimageShootingService.getCardinalDirection(90.0), equals(('E', '東')));
      expect(PilgrimageShootingService.getCardinalDirection(135.0), equals(('SE', '東南')));
      expect(PilgrimageShootingService.getCardinalDirection(180.0), equals(('S', '南')));
      expect(PilgrimageShootingService.getCardinalDirection(225.0), equals(('SW', '西南')));
      expect(PilgrimageShootingService.getCardinalDirection(270.0), equals(('W', '西')));
      expect(PilgrimageShootingService.getCardinalDirection(315.0), equals(('NW', '西北')));
      expect(PilgrimageShootingService.getCardinalDirection(359.0), equals(('N', '北')));
    });

    test('calculateClockHour maps relative heading to 12 clock positions', () {
      // Target straight ahead (bearing 90, heading 90) => 12 o'clock
      expect(PilgrimageShootingService.calculateClockHour(90.0, 90.0), equals(12));
      // Target 90 degrees right (bearing 180, heading 90) => 3 o'clock
      expect(PilgrimageShootingService.calculateClockHour(180.0, 90.0), equals(3));
      // Target 180 degrees behind (bearing 270, heading 90) => 6 o'clock
      expect(PilgrimageShootingService.calculateClockHour(270.0, 90.0), equals(6));
      // Target 90 degrees left (bearing 0, heading 90) => 9 o'clock
      expect(PilgrimageShootingService.calculateClockHour(0.0, 90.0), equals(9));
    });

    test('calculateBearingInfo handles arrived status and formatting', () {
      final closeInfo = PilgrimageShootingService.calculateBearingInfo(
        userLat: 35.00000,
        userLng: 135.00000,
        spotLat: 35.00005,
        spotLng: 135.00005,
        deviceHeading: 45.0,
        arrivalThresholdMeters: 15.0,
      );
      expect(closeInfo.isArrived, isTrue);
      expect(closeInfo.description(), contains('Arrived'));

      final farInfo = PilgrimageShootingService.calculateBearingInfo(
        userLat: 35.0000,
        userLng: 135.0000,
        spotLat: 35.0050,
        spotLng: 135.0050,
        deviceHeading: 0.0,
      );
      expect(farInfo.isArrived, isFalse);
      expect(farInfo.clockHour, isNotNull);
      expect(farInfo.description(preferClock: true), contains("o'clock"));
      expect(farInfo.description(preferClock: false), contains('NE'));
    });
  });

  group('PilgrimageShootingService - Check-in Without Photo', () {
    test('checkInWithoutPhoto marks planned schedule item as done when markDone is true', () async {
      final now = DateTime(2026, 8, 15, 10, 0);

      final trip = await tripRepo.createTrip(
        title: 'Check-in Trip',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 1,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot to Check In',
        lat: 34.8910,
        lng: 135.8080,
        addedBy: 'user_tester',
      );
      final item = await tripRepo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days.first.id);

      final result = await service.checkInWithoutPhoto(
        db,
        placeKey: stop.placeKey!,
        stopId: stop.id,
        tripId: trip.id,
        scheduleItemId: item.id,
        visitedAt: now,
        markDone: true,
      );

      expect(result.wasOffPlan, isFalse);
      expect(result.scheduleItem, isNotNull);
      expect(result.scheduleItem?.status, equals('done'));
      expect(result.visit.date, equals('2026-08-15'));

      // Check DB row
      final updatedItem = await (db.select(db.scheduleItems)..where((s) => s.id.equals(item.id))).getSingle();
      expect(updatedItem.status, equals('done'));
    });

    test('checkInWithoutPhoto logs visit but does NOT mark item done when markDone is false (for viewers)', () async {
      final now = DateTime(2026, 8, 15, 10, 0);

      final trip = await tripRepo.createTrip(
        title: 'Viewer Trip',
        ownerId: 'owner_user',
        startDate: '2026-08-15',
        dayCount: 1,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Viewer Check In Spot',
        lat: 34.8910,
        lng: 135.8080,
        addedBy: 'owner_user',
      );
      final item = await tripRepo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days.first.id);

      final result = await service.checkInWithoutPhoto(
        db,
        placeKey: stop.placeKey!,
        stopId: stop.id,
        tripId: trip.id,
        scheduleItemId: item.id,
        visitedAt: now,
        markDone: false, // Viewer!
      );

      expect(result.wasOffPlan, isFalse);
      expect(result.visit.date, equals('2026-08-15'));
      // Item status remains planned!
      expect(result.scheduleItem?.status, equals('planned'));

      final itemInDb = await (db.select(db.scheduleItems)..where((s) => s.id.equals(item.id))).getSingle();
      expect(itemInDb.status, equals('planned'));
    });

    test('checkInWithoutPhoto works with dayId and scheduleItemId on other days (Day 3)', () async {
      final now = DateTime(2026, 8, 15, 10, 0); // Day 1 date

      final trip = await tripRepo.createTrip(
        title: 'Multi-Day Scouting Trip',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 3,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);
      final day3 = days[2];

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Day 3 Peak',
        lat: 34.8910,
        lng: 135.8080,
        addedBy: 'user_tester',
      );
      final itemDay3 = await tripRepo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: day3.id);

      final result = await service.checkInWithoutPhoto(
        db,
        placeKey: stop.placeKey!,
        stopId: stop.id,
        tripId: trip.id,
        dayId: day3.id,
        scheduleItemId: itemDay3.id,
        visitedAt: now,
        markDone: true,
      );

      expect(result.wasOffPlan, isFalse);
      expect(result.scheduleItem?.id, equals(itemDay3.id));
      expect(result.scheduleItem?.status, equals('done'));
      expect(result.scheduleItem?.dayId, equals(day3.id));
    });

    test('checkInWithoutPhoto handles off-plan check-in without creating phantom schedule items', () async {
      final now = DateTime(2026, 8, 15, 10, 0);

      await placeRepo.upsertPlace(PlacesCompanion.insert(
        placeKey: 'place_off_plan_checkin',
        name: 'Off Plan Shrine',
        lat: 34.8910,
        lng: 135.8080,
      ));

      final trip = await tripRepo.createTrip(
        title: 'Strict Plan Trip',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 1,
      );

      final result = await service.checkInWithoutPhoto(
        db,
        placeKey: 'place_off_plan_checkin',
        tripId: trip.id,
        visitedAt: now,
        markDone: true,
      );

      expect(result.wasOffPlan, isTrue);
      expect(result.stop, isNull);
      expect(result.scheduleItem, isNull);
      expect(result.visit.placeKey, equals('place_off_plan_checkin'));

      // Ensure no stops or schedule items were added
      final tripStops = await tripRepo.getStopsForTrip(trip.id);
      expect(tripStops, isEmpty);
    });
  });

  group('PilgrimageShootingService - Live Pilgrimage Feed', () {
    test('getPilgrimageFeed hydrates stops, detects next target, nearest stop, and computes progress', () async {
      final now = DateTime(2026, 8, 15, 10, 0);

      final trip = await tripRepo.createTrip(
        title: 'Feed Trip',
        ownerId: 'user_tester',
        startDate: '2026-08-15',
        dayCount: 1,
      );
      final days = await tripRepo.getDaysForTrip(trip.id);

      final stop1 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Feed Stop 1',
        lat: 34.8910,
        lng: 135.8080,
        addedBy: 'user_tester',
      );
      final item1 = await tripRepo.scheduleStop(tripId: trip.id, stopId: stop1.id, dayId: days.first.id);

      final stop2 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Feed Stop 2',
        lat: 34.8920,
        lng: 135.8090,
        addedBy: 'user_tester',
      );
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stop2.id, dayId: days.first.id);

      // Check-in at stop 1
      await service.checkInWithoutPhoto(
        db,
        placeKey: stop1.placeKey!,
        scheduleItemId: item1.id,
        visitedAt: now,
        markDone: true,
      );

      // Query feed close to stop 2
      final feed = await service.getPilgrimageFeed(
        db,
        tripId: trip.id,
        dayId: days.first.id,
        userLat: 34.8921,
        userLng: 135.8091,
        deviceHeading: 0.0,
      );

      expect(feed, isNotNull);
      expect(feed!.totalCount, equals(2));
      expect(feed.completedCount, equals(1));
      expect(feed.progress, equals(0.5));

      // Stop 1 is done
      expect(feed.stops[0].isDone, isTrue);
      expect(feed.stops[0].isNextTarget, isFalse);

      // Stop 2 is next target and nearest
      expect(feed.stops[1].isPlanned, isTrue);
      expect(feed.stops[1].isNextTarget, isTrue);
      expect(feed.stops[1].isNearest, isTrue);
      expect(feed.nextTarget?.stop.id, equals(stop2.id));
      expect(feed.nearestStop?.stop.id, equals(stop2.id));
    });
  });
}
