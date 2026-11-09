import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/core/services/trip_view_state_service.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TripViewStateService Tests', () {
    late Directory tempDir;
    late TripViewStateService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('trip_view_state_test_');
      service = TripViewStateService(overrideDir: tempDir);
      await service.ensureLoaded();
    });

    tearDown(() async {
      service.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('records, reads and streams view timestamps', () async {
      final t1 = DateTime(2026, 11, 5, 12, 0, 0);
      final streamEvents = <DateTime?>[];

      final sub = service.watchLastViewedAt('trip_1', userId: 'alice').listen(streamEvents.add);
      // Pump event loop so initial yield completes
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.getLastViewedAt('trip_1', userId: 'alice'), isNull);

      await service.markTripViewed('trip_1', userId: 'alice', at: t1);
      expect(service.getLastViewedAt('trip_1', userId: 'alice'), equals(t1));

      final t2 = DateTime(2026, 11, 5, 14, 30, 0);
      await service.markTripViewed('trip_1', userId: 'alice', at: t2);
      expect(service.getLastViewedAt('trip_1', userId: 'alice'), equals(t2));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(streamEvents, containsAllInOrder([isNull, t1, t2]));

      await sub.cancel();
    });

    test('recovers persisted timestamps across service restarts', () async {
      final t = DateTime(2026, 11, 5, 15, 0, 0);
      await service.markTripViewed('trip_xyz', userId: 'bob', at: t);

      // Create a fresh service pointing to the same directory
      final service2 = TripViewStateService(overrideDir: tempDir);
      await service2.ensureLoaded();

      expect(service2.getLastViewedAt('trip_xyz', userId: 'bob'), equals(t));
      service2.dispose();
    });

    test('multi-account isolation: accounts do not overwrite or view each other timestamps', () async {
      final tAlice = DateTime(2026, 11, 5, 10, 0, 0);
      final tBob = DateTime(2026, 11, 5, 16, 0, 0);

      await service.markTripViewed('shared_trip', userId: 'alice', at: tAlice);
      await service.markTripViewed('shared_trip', userId: 'bob', at: tBob);

      expect(service.getLastViewedAt('shared_trip', userId: 'alice'), equals(tAlice));
      expect(service.getLastViewedAt('shared_trip', userId: 'bob'), equals(tBob));
      expect(service.getLastViewedAt('shared_trip', userId: 'guest'), isNull);
    });

    test('gracefully recovers from corrupted JSON on disk', () async {
      final stateFile = File('${tempDir.path}/trip_view_state.json');
      await stateFile.writeAsString('{not valid json at all');

      final serviceCorrupted = TripViewStateService(overrideDir: tempDir);
      await serviceCorrupted.ensureLoaded();

      expect(serviceCorrupted.getLastViewedAt('any_trip', userId: 'alice'), isNull);
      await serviceCorrupted.markTripViewed('any_trip', userId: 'alice');
      expect(serviceCorrupted.getLastViewedAt('any_trip', userId: 'alice'), isNotNull);

      serviceCorrupted.dispose();
    });

    test('clearTrip and clearAll remove records properly', () async {
      await service.markTripViewed('trip_a', userId: 'u1');
      await service.markTripViewed('trip_b', userId: 'u1');

      await service.clearTrip('trip_a', userId: 'u1');
      expect(service.getLastViewedAt('trip_a', userId: 'u1'), isNull);
      expect(service.getLastViewedAt('trip_b', userId: 'u1'), isNotNull);

      await service.clearAll();
      expect(service.getLastViewedAt('trip_b', userId: 'u1'), isNull);
    });
  });

  group('TripRepository Collaborator Update Tracking', () {
    late AppDatabase db;
    late PlaceRepository placeRepo;
    late DriftTripRepository aliceRepo;
    late DriftTripRepository bobRepo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      placeRepo = DriftPlaceRepository(db);
      aliceRepo = DriftTripRepository(db, null, 'alice', placeRepo);
      bobRepo = DriftTripRepository(db, null, 'bob', placeRepo);

      // Seed a place for stop insertion
      await db.into(db.places).insert(
        PlacesCompanion.insert(
          placeKey: 'p1',
          name: 'Oarai Station',
          lat: 36.312,
          lng: 140.575,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('tracks latest collaborator updates across trip, days, stops, and schedule items', () async {
      // 1. Alice creates a group trip
      final trip = await aliceRepo.createTrip(
        title: 'Girls und Panzer Tour',
        ownerId: 'alice',
      );
      await db.update(db.trips).write(
        const TripsCompanion(sharing: drift.Value('group')),
      );

      // Alice's perspective: no collaborator updates yet
      expect(await aliceRepo.getLatestCollaboratorUpdate(trip.id, 'alice'), isNull);

      // Bob's perspective: Alice's creation is a collaborator update
      final bobUpdate1 = await bobRepo.getLatestCollaboratorUpdate(trip.id, 'bob');
      expect(bobUpdate1, isNotNull);

      // 2. Alice adds a day block
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final day = await aliceRepo.addDayBlock(trip.id);
      final bobUpdate2 = await bobRepo.getLatestCollaboratorUpdate(trip.id, 'bob');
      expect(bobUpdate2!.isAfter(bobUpdate1!), isTrue);

      // 3. Alice adds a stop
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final stop = await aliceRepo.addPlaceToTrip(
        tripId: trip.id,
        placeKey: 'p1',
        addedBy: 'alice',
      );
      final bobUpdate3 = await bobRepo.getLatestCollaboratorUpdate(trip.id, 'bob');
      expect(bobUpdate3!.isAfter(bobUpdate2), isTrue);

      // 4. Alice schedules the stop
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await aliceRepo.scheduleStop(
        tripId: trip.id,
        stopId: stop.id,
        dayId: day.id,
      );
      final bobUpdate4 = await bobRepo.getLatestCollaboratorUpdate(trip.id, 'bob');
      expect(bobUpdate4!.isAfter(bobUpdate3), isTrue);

      // 5. Bob edits the stop (Bob's update)
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await bobRepo.updateStop(
        StopsCompanion(
          id: drift.Value(stop.id),
          tripId: drift.Value(trip.id),
          note: const drift.Value('Bring camera!'),
          updatedBy: const drift.Value('bob'),
        ),
      );

      // Bob's perspective: Bob's own edit does NOT count as a collaborator update for Bob
      final bobUpdate5 = await bobRepo.getLatestCollaboratorUpdate(trip.id, 'bob');
      expect(bobUpdate5, equals(bobUpdate4));

      // Alice's perspective: Bob's edit IS a collaborator update for Alice!
      final aliceUpdate1 = await aliceRepo.getLatestCollaboratorUpdate(trip.id, 'alice');
      expect(aliceUpdate1, isNotNull);
      expect(aliceUpdate1!.isAfter(bobUpdate4), isTrue);
    });
  });

  group('hasUnreadTripUpdatesProvider Riverpod Tests', () {
    late AppDatabase db;
    late Directory tempDir;
    late TripViewStateService viewStateService;
    late DriftTripRepository repo;
    late ProviderContainer container;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('unread_provider_test_');
      viewStateService = TripViewStateService(overrideDir: tempDir);
      await viewStateService.ensureLoaded();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final placeRepo = DriftPlaceRepository(db);
      repo = DriftTripRepository(db, null, 'bob', placeRepo);

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tripViewStateServiceProvider.overrideWithValue(viewStateService),
          currentUserIdProvider.overrideWith((ref) => 'bob'),
          tripRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      viewStateService.dispose();
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('unread badge logic for private vs group trips and marking as viewed', () async {
      // 1. Create a trip owned by Alice
      final trip = await repo.createTrip(title: 'Kyoto Trip', ownerId: 'alice');
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(
        const TripsCompanion(
          sharing: drift.Value('private'), // Private trip first
        ),
      );

      // Keep providers active with listeners
      final unreadSub = container.listen(hasUnreadTripUpdatesProvider(trip.id), (_, __) {});

      // Wait for trip detail and view state to settle
      await container.read(tripDetailProvider(trip.id).future);
      await container.read(tripLastViewedAtProvider(trip.id).future);
      await container.read(tripLatestCollaboratorUpdateProvider(trip.id).future);

      // Private trip: unread is always false
      expect(container.read(hasUnreadTripUpdatesProvider(trip.id)), isFalse);

      // 2. Change trip to group sharing (shared trip)
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(
        const TripsCompanion(sharing: drift.Value('group')),
      );

      // Allow provider streams to emit
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Bob has not opened this trip yet -> should be unread!
      expect(container.read(hasUnreadTripUpdatesProvider(trip.id)), isTrue);

      // 3. Bob opens the trip -> mark as viewed
      await viewStateService.markTripViewed(trip.id, userId: 'bob');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Unread should now be cleared!
      expect(container.read(hasUnreadTripUpdatesProvider(trip.id)), isFalse);

      // 4. Alice modifies the trip (new collaborator update after last viewed)
      final afterViewed = DateTime.now().add(const Duration(seconds: 1));
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(
        TripsCompanion(
          title: const drift.Value('Kyoto Trip (Updated)'),
          updatedAt: drift.Value(afterViewed),
          updatedBy: const drift.Value('alice'),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Unread badge should reappear!
      expect(container.read(hasUnreadTripUpdatesProvider(trip.id)), isTrue);

      // 5. Bob marks as viewed again
      await viewStateService.markTripViewed(trip.id, userId: 'bob', at: afterViewed.add(const Duration(seconds: 1)));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Cleared!
      expect(container.read(hasUnreadTripUpdatesProvider(trip.id)), isFalse);

      // 6. Bob makes an update himself -> does NOT trigger unread for Bob
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(
        TripsCompanion(
          description: const drift.Value('Notes by Bob'),
          updatedAt: drift.Value(afterViewed.add(const Duration(seconds: 5))),
          updatedBy: const drift.Value('bob'),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(hasUnreadTripUpdatesProvider(trip.id)), isFalse);

      unreadSub.close();
    });
  });
}
