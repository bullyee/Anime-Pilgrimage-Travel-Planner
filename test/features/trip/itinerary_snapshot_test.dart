import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/trip/models/trip_snapshot_models.dart';
import 'package:trip_planner/features/trip/services/itinerary_snapshot_service.dart';
import 'package:trip_planner/features/trip/services/trip_snapshot_store.dart';

void main() {
  group('TripSnapshotPayload - Serialization Unit Tests', () {
    test('JSON serialization roundtrip preserves all fields, nulls, and Japanese characters', () {
      final now = DateTime.utc(2026, 11, 7, 12, 0, 0);
      final payload = TripSnapshotPayload(
        metadata: TripSnapshotMetadata(
          id: 'snap_01',
          tripId: 'trip_kyoto',
          name: 'Kyoto Eupho Draft 響け！ユーフォニアム 🌸',
          description: 'Before adding Uji Day 2',
          createdAt: now,
          createdBy: 'user_alice',
          dayCount: 1,
          stopCount: 1,
          scheduleItemCount: 1,
        ),
        trip: const TripDataSnapshot(
          title: 'Kyoto Eupho Trip',
          description: 'Sound! Euphonium real scenes',
          startDate: '2026-11-07',
          dayCount: 1,
        ),
        days: const [
          TripDaySnapshot(
            id: 'day_01',
            sortKey: 'a0',
            title: 'Day 1 - Uji River',
            pinnedDate: '2026-11-07',
          ),
        ],
        stops: const [
          StopSnapshot(
            id: 'stop_01',
            placeKey: 'place_uji_bridge',
            name: 'Uji Bridge 宇治橋',
            lat: 34.8894,
            lng: 135.8078,
            description: 'Where Kumiko ran',
            note: 'Watch sunset from the bench',
            address: 'Kyoto, Uji',
            addedBy: 'user_alice',
            labelIds: ['lbl_eupho'],
          ),
        ],
        scheduleItems: const [
          ScheduleItemSnapshot(
            id: 'item_01',
            stopId: 'stop_01',
            dayId: 'day_01',
            sortKey: 'a0',
            stayMinutes: 90,
            status: 'planned',
          ),
        ],
      );

      final jsonMap = payload.toJson();
      final jsonStr = payload.toJsonString();
      final restoredFromMap = TripSnapshotPayload.fromJson(jsonMap);
      final restoredFromStr = TripSnapshotPayload.fromJsonString(jsonStr);

      expect(restoredFromMap.metadata.name, equals('Kyoto Eupho Draft 響け！ユーフォニアム 🌸'));
      expect(restoredFromStr.metadata.id, equals('snap_01'));
      expect(restoredFromStr.stops.first.name, equals('Uji Bridge 宇治橋'));
      expect(restoredFromStr.stops.first.labelIds, equals(['lbl_eupho']));
      expect(restoredFromStr.scheduleItems.first.stayMinutes, equals(90));
    });
  });

  group('ItinerarySnapshotService - Database Integration & Rollback Tests', () {
    late AppDatabase db;
    late InMemoryTripSnapshotStore store;
    late ItinerarySnapshotService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = InMemoryTripSnapshotStore();
      service = ItinerarySnapshotService(store: store);

      // Seed initial trip
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 'trip_100',
            title: 'Initial Trip Title',
            ownerId: 'user_alice',
            description: const Value('Original Description'),
            startDate: const Value('2026-11-07'),
            dayCount: const Value(2),
          ));

      // Seed 2 Day blocks
      await db.into(db.tripDays).insert(TripDaysCompanion.insert(
            id: 'day_100_1',
            tripId: 'trip_100',
            sortKey: 'a0',
            title: const Value('Day 1 - Demachi'),
          ));
      await db.into(db.tripDays).insert(TripDaysCompanion.insert(
            id: 'day_100_2',
            tripId: 'trip_100',
            sortKey: 'a1',
            title: const Value('Day 2 - Uji'),
          ));

      // Seed Places (Parent rows)
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_tamako',
            name: 'Demachi Masugata Shotengai',
            lat: 35.0116,
            lng: 135.7681,
          ));
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_eupho',
            name: 'Uji River Bank',
            lat: 34.8894,
            lng: 135.8078,
          ));

      // Seed Labels
      await db.into(db.labels).insert(LabelsCompanion.insert(
            id: 'lbl_anime_1',
            kind: 'anime',
            name: 'Tamako Market',
          ));

      // Seed Stops
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_100_1',
            tripId: 'trip_100',
            placeKey: 'place_tamako',
            name: 'Demachi Masugata Shotengai',
            lat: 35.0116,
            lng: 135.7681,
            note: const Value('Check banner'),
            addedBy: 'user_alice',
          ));
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_100_2',
            tripId: 'trip_100',
            placeKey: 'place_eupho',
            name: 'Uji River Bank',
            lat: 34.8894,
            lng: 135.8078,
            addedBy: 'user_alice',
          ));

      // Seed StopLabels
      await db.into(db.stopLabels).insert(StopLabelsCompanion.insert(
            stopId: 'stop_100_1',
            labelId: 'lbl_anime_1',
          ));

      // Seed Schedules
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_100_1',
            tripId: 'trip_100',
            stopId: 'stop_100_1',
            dayId: 'day_100_1',
            sortKey: 'a0',
            stayMinutes: const Value(60),
            status: const Value('planned'),
          ));
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_100_2',
            tripId: 'trip_100',
            stopId: 'stop_100_2',
            dayId: 'day_100_2',
            sortKey: 'a0',
            stayMinutes: const Value(120),
            status: const Value('planned'),
          ));
    });

    tearDown(() async {
      await db.close();
    });

    test('createSnapshot captures full trip state and saves to store', () async {
      final snapshot = await service.createSnapshot(
        db,
        'trip_100',
        snapshotName: 'Baseline Snapshot',
        description: 'Before modifications',
        createdBy: 'user_alice',
      );

      expect(snapshot.metadata.name, equals('Baseline Snapshot'));
      expect(snapshot.metadata.dayCount, equals(2));
      expect(snapshot.metadata.stopCount, equals(2));
      expect(snapshot.metadata.scheduleItemCount, equals(2));
      expect(snapshot.stops.first.labelIds, equals(['lbl_anime_1']));

      final listed = await service.listSnapshots('trip_100');
      expect(listed.length, equals(1));
      expect(listed.first.id, equals(snapshot.metadata.id));
    });

    test('compareSnapshotWithCurrent detects added, removed, modified stops and schedule changes', () async {
      // Create baseline snapshot
      final snapshot = await service.createSnapshot(
        db,
        'trip_100',
        snapshotName: 'Baseline',
        createdBy: 'user_alice',
      );

      // Verify no changes initially
      final initialDiff = await service.compareSnapshotWithCurrent(db, 'trip_100', snapshot.metadata.id);
      expect(initialDiff.hasChanges, isFalse);

      // Mutate current state:
      // 1. Modify stop note
      await (db.update(db.stops)..where((s) => s.id.equals('stop_100_1'))).write(
        const StopsCompanion(note: Value('Updated banner note')),
      );

      // 2. Add a new 3rd stop
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_fushimi',
            name: 'Fushimi Inari Shrine',
            lat: 34.9671,
            lng: 135.7727,
          ));
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_100_3',
            tripId: 'trip_100',
            placeKey: 'place_fushimi',
            name: 'Fushimi Inari Shrine',
            lat: 34.9671,
            lng: 135.7727,
            addedBy: 'user_alice',
          ));

      // 3. Move stop 2 to Day 1
      await (db.update(db.scheduleItems)..where((s) => s.id.equals('item_100_2'))).write(
        const ScheduleItemsCompanion(dayId: Value('day_100_1'), stayMinutes: Value(150)),
      );

      final diffReport = await service.compareSnapshotWithCurrent(db, 'trip_100', snapshot.metadata.id);
      expect(diffReport.hasChanges, isTrue);
      expect(diffReport.addedStopNames, contains('Fushimi Inari Shrine'));
      expect(diffReport.modifiedStops.map((s) => s.name), contains('Demachi Masugata Shotengai'));
      expect(diffReport.scheduleChanges.any((sc) => sc.description.contains('Moved between day blocks')), isTrue);
    });

    test('rollbackToSnapshot restores exact historical state and preserves library Places (Rule 2)', () async {
      // 1. Capture snapshot before chaos
      final baseline = await service.createSnapshot(
        db,
        'trip_100',
        snapshotName: 'Perfect Itinerary',
        createdBy: 'user_alice',
      );

      // 2. Chaos: user renames trip, deletes day 2, adds rogue stops, modifies stop notes
      await (db.update(db.trips)..where((t) => t.id.equals('trip_100'))).write(
        const TripsCompanion(title: Value('Ruined Trip Title')),
      );
      await (db.delete(db.scheduleItems)..where((s) => s.id.equals('item_100_2'))).go();
      await (db.delete(db.stops)..where((s) => s.id.equals('stop_100_2'))).go();
      await (db.delete(db.tripDays)..where((d) => d.id.equals('day_100_2'))).go();

      // Add a rogue stop
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_rogue',
            name: 'Accidental Spot',
            lat: 35.0,
            lng: 135.0,
          ));
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_rogue',
            tripId: 'trip_100',
            placeKey: 'place_rogue',
            name: 'Accidental Spot',
            lat: 35.0,
            lng: 135.0,
            addedBy: 'user_bob',
          ));

      // 3. Perform Rollback!
      final rollback = await service.rollbackToSnapshot(
        db,
        'trip_100',
        baseline.metadata.id,
        operatedBy: 'user_alice',
      );

      expect(rollback.success, isTrue);
      expect(rollback.restoredDays, equals(2));
      expect(rollback.restoredStops, equals(2));
      expect(rollback.restoredScheduleItems, equals(2));
      expect(rollback.backupSnapshotId, isNotNull); // Safety backup was captured!

      // 4. Verify Trip Title restored
      final restoredTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_100'))).getSingle();
      expect(restoredTrip.title, equals('Initial Trip Title'));

      // 5. Verify Day blocks restored
      final restoredDays = await (db.select(db.tripDays)..where((d) => d.tripId.equals('trip_100'))).get();
      expect(restoredDays.length, equals(2));
      expect(restoredDays.map((d) => d.id), containsAll(['day_100_1', 'day_100_2']));

      // 6. Verify Stops restored (and rogue stop removed from trip)
      final restoredStops = await (db.select(db.stops)..where((s) => s.tripId.equals('trip_100'))).get();
      expect(restoredStops.length, equals(2));
      expect(restoredStops.map((s) => s.id), containsAll(['stop_100_1', 'stop_100_2']));
      expect(restoredStops.map((s) => s.name), isNot(contains('Accidental Spot')));

      // 7. Verify Rule 2: Physical Places in personal library were NOT deleted!
      final allPlaces = await db.select(db.places).get();
      expect(allPlaces.length, equals(3)); // tamako, eupho, and rogue are ALL safely intact in library!

      // 8. Verify StopLabels restored
      final restoredStopLabels = await (db.select(db.stopLabels)..where((sl) => sl.stopId.equals('stop_100_1'))).get();
      expect(restoredStopLabels.length, equals(1));
      expect(restoredStopLabels.first.labelId, equals('lbl_anime_1'));

      // 9. Verify ScheduleItems restored
      final restoredSchedules = await (db.select(db.scheduleItems)..where((s) => s.tripId.equals('trip_100'))).get();
      expect(restoredSchedules.length, equals(2));
    });

    test('Entity Scope Isolation: rolling back with snapshot from a foreign trip throws ArgumentError', () async {
      // Create a snapshot for a foreign trip
      final foreignSnapshot = TripSnapshotPayload(
        metadata: TripSnapshotMetadata(
          id: 'foreign_snap_999',
          tripId: 'foreign_trip_osaka',
          name: 'Osaka Trip Snapshot',
          createdAt: DateTime.now(),
          createdBy: 'user_eve',
          dayCount: 1,
          stopCount: 0,
          scheduleItemCount: 0,
        ),
        trip: const TripDataSnapshot(title: 'Osaka Trip'),
        days: const [],
        stops: const [],
        scheduleItems: const [],
      );
      await store.saveSnapshot(foreignSnapshot);

      // Attempting to rollback trip_100 with foreign_snap_999 MUST throw ArgumentError
      expect(
        () => service.rollbackToSnapshot(db, 'trip_100', 'foreign_snap_999'),
        throwsArgumentError,
      );
    });

    test('Adversarial: Empty trip snapshot creation, diffing, and rollback', () async {
      await db.into(db.trips).insert(TripsCompanion.insert(
            id: 'trip_empty_test',
            title: 'Empty Planned Trip',
            ownerId: 'user_alice',
          ));

      final emptySnapshot = await service.createSnapshot(
        db,
        'trip_empty_test',
        snapshotName: 'Empty Baseline',
        createdBy: 'user_alice',
      );

      expect(emptySnapshot.days, isEmpty);
      expect(emptySnapshot.stops, isEmpty);
      expect(emptySnapshot.scheduleItems, isEmpty);

      // Now add a stop to the trip
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'place_temp_1',
            name: 'Temporary Spot',
            lat: 35.0,
            lng: 135.0,
          ));
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_temp_1',
            tripId: 'trip_empty_test',
            placeKey: 'place_temp_1',
            name: 'Temporary Spot',
            lat: 35.0,
            lng: 135.0,
            addedBy: 'user_alice',
          ));

      // Diff shows added stop
      final diff = await service.compareSnapshotWithCurrent(db, 'trip_empty_test', emptySnapshot.metadata.id);
      expect(diff.hasChanges, isTrue);
      expect(diff.addedStopNames, contains('Temporary Spot'));

      // Rollback to empty snapshot
      final rollback = await service.rollbackToSnapshot(db, 'trip_empty_test', emptySnapshot.metadata.id);
      expect(rollback.success, isTrue);
      expect(rollback.restoredStops, equals(0));

      final stopsAfter = await (db.select(db.stops)..where((s) => s.tripId.equals('trip_empty_test'))).get();
      expect(stopsAfter, isEmpty);
    });

    test('Adversarial: Rollback safely restores missing backing Place into db.places (Rule 2)', () async {
      final snap = await service.createSnapshot(
        db,
        'trip_100',
        snapshotName: 'Snapshot with places',
        createdBy: 'user_alice',
      );

      // Clear the trip stops
      await (db.delete(db.scheduleItems)..where((s) => s.tripId.equals('trip_100'))).go();
      await (db.delete(db.stops)..where((s) => s.tripId.equals('trip_100'))).go();

      // Simulate accidental deletion of a backing library place
      await (db.delete(db.places)..where((p) => p.placeKey.equals('place_tamako'))).go();
      final placeBefore = await (db.select(db.places)..where((p) => p.placeKey.equals('place_tamako'))).getSingleOrNull();
      expect(placeBefore, isNull);

      // Rollback should restore backing place first to avoid FK constraint error!
      final rollback = await service.rollbackToSnapshot(db, 'trip_100', snap.metadata.id);
      expect(rollback.success, isTrue);

      final restoredPlace = await (db.select(db.places)..where((p) => p.placeKey.equals('place_tamako'))).getSingleOrNull();
      expect(restoredPlace, isNotNull);
      expect(restoredPlace!.name, equals('Demachi Masugata Shotengai'));
    });

    test('Non-existent trip or snapshot raises ArgumentError', () async {
      expect(
        () => service.createSnapshot(db, 'non_existent_trip', snapshotName: 'test', createdBy: 'u'),
        throwsArgumentError,
      );
      expect(
        () => service.compareSnapshotWithCurrent(db, 'trip_100', 'non_existent_snap'),
        throwsArgumentError,
      );
      expect(
        () => service.rollbackToSnapshot(db, 'trip_100', 'non_existent_snap'),
        throwsArgumentError,
      );
    });
  });

  group('LocalDiskTripSnapshotStore - Disk Persistence Tests', () {
    late Directory tempDir;
    late LocalDiskTripSnapshotStore diskStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('trip_snapshots_test_');
      diskStore = LocalDiskTripSnapshotStore(customBasePath: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves, lists, retrieves, and deletes snapshot files from disk', () async {
      final now = DateTime.utc(2026, 11, 7, 10, 0, 0);
      final payload = TripSnapshotPayload(
        metadata: TripSnapshotMetadata(
          id: 'disk_snap_1',
          tripId: 'trip_hakodate',
          name: 'Golden Kamuy Hakodate Tour',
          createdAt: now,
          createdBy: 'user_sugimoto',
          dayCount: 1,
          stopCount: 1,
          scheduleItemCount: 1,
        ),
        trip: const TripDataSnapshot(title: 'Hakodate Arc'),
        days: const [TripDaySnapshot(id: 'd1', sortKey: 'a0', title: 'Goryokaku')],
        stops: const [
          StopSnapshot(
            id: 's1',
            placeKey: 'place_goryokaku',
            name: 'Goryokaku Fort',
            lat: 41.7969,
            lng: 140.7569,
          ),
        ],
        scheduleItems: const [
          ScheduleItemSnapshot(id: 'i1', stopId: 's1', dayId: 'd1', sortKey: 'a0'),
        ],
      );

      // 1. Save to disk
      await diskStore.saveSnapshot(payload);

      // 2. List from disk
      final list = await diskStore.listSnapshots('trip_hakodate');
      expect(list.length, equals(1));
      expect(list.first.name, equals('Golden Kamuy Hakodate Tour'));

      // 3. Retrieve from disk
      final loaded = await diskStore.getSnapshot('disk_snap_1');
      expect(loaded, isNotNull);
      expect(loaded!.trip.title, equals('Hakodate Arc'));
      expect(loaded.stops.first.name, equals('Goryokaku Fort'));

      // 4. Delete from disk
      final deleted = await diskStore.deleteSnapshot('disk_snap_1');
      expect(deleted, isTrue);

      final listAfter = await diskStore.listSnapshots('trip_hakodate');
      expect(listAfter, isEmpty);
    });
  });
}
