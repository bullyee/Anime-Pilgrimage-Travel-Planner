import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  late AppDatabase db;
  late DriftTripRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftTripRepository(db, null, 'user_tester');
  });

  tearDown(() => db.close());

  group('Phase 2 Safety Net: Trash & Recovery Tests', () {
    test('stops deleted within 30 days appear in trash, active stops do not', () async {
      final trip = await repo.createTrip(title: 'Trash Test Trip', ownerId: 'user_tester');

      // Add two stops
      final stop1 = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot To Keep',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_tester',
      );
      final stop2 = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot To Delete',
        lat: 35.1,
        lng: 135.1,
        addedBy: 'user_tester',
      );

      // Initially trash is empty
      var trash = await repo.getTrashStops(trip.id);
      expect(trash, isEmpty);

      // Delete stop2
      await repo.deleteStop(stop2.id);

      // Stop1 is still in active stops, Stop2 is in trash
      final active = await repo.getStopsForTrip(trip.id);
      expect(active.length, 1);
      expect(active.first.id, stop1.id);

      trash = await repo.getTrashStops(trip.id);
      expect(trash.length, 1);
      expect(trash.first.id, stop2.id);
      expect(trash.first.deletedAt, isNotNull);

      // Stream also emits trash
      final trashStream = await repo.watchTrashStops(trip.id).first;
      expect(trashStream.length, 1);
      expect(trashStream.first.id, stop2.id);
    });

    test('restoreStop brings a deleted stop back to active stops with dirty syncStatus', () async {
      final trip = await repo.createTrip(title: 'Restore Stop Test', ownerId: 'user_tester');

      final stop = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Recoverable Spot',
        lat: 34.9,
        lng: 135.8,
        addedBy: 'user_tester',
      );

      // Delete
      await repo.deleteStop(stop.id);
      expect(await repo.getTrashStops(trip.id), isNotEmpty);
      expect(await repo.getStopsForTrip(trip.id), isEmpty);

      // Restore
      await repo.restoreStop(stop.id);

      // Check active
      final active = await repo.getStopsForTrip(trip.id);
      expect(active.length, 1);
      expect(active.first.id, stop.id);
      expect(active.first.deletedAt, isNull);
      expect(active.first.syncStatus, 1, reason: 'Restored stop must be dirty to push upstream');

      // Trash is now empty again
      expect(await repo.getTrashStops(trip.id), isEmpty);
    });

    test('restoreTrip restores trip and child days/stops', () async {
      final trip = await repo.createTrip(title: 'Full Trip Recovery', ownerId: 'user_tester');
      final day = await repo.addDayBlock(trip.id, title: 'Day 2');
      final initialDays = await repo.getDaysForTrip(trip.id);
      final stop = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Child Spot',
        lat: 34.9,
        lng: 135.8,
        addedBy: 'user_tester',
      );

      // Delete entire trip
      await repo.deleteTrip(trip.id);

      expect(await repo.getTrip(trip.id), isNull);
      expect(await repo.getDaysForTrip(trip.id), isEmpty);
      expect(await repo.getStopsForTrip(trip.id), isEmpty);

      // Restore trip
      await repo.restoreTrip(trip.id);

      final restoredTrip = await repo.getTrip(trip.id);
      expect(restoredTrip, isNotNull);
      expect(restoredTrip!.deletedAt, isNull);

      final restoredDays = await repo.getDaysForTrip(trip.id);
      expect(restoredDays.length, initialDays.length);
      expect(restoredDays.any((d) => d.id == day.id), isTrue);

      final restoredStops = await repo.getStopsForTrip(trip.id);
      expect(restoredStops.length, 1);
      expect(restoredStops.first.id, stop.id);
    });

    test('purgeExpiredTrash permanently purges items older than retention window', () async {
      final trip = await repo.createTrip(title: 'Purge Test', ownerId: 'user_tester');

      final recentStop = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Recent Delete',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_tester',
      );
      final expiredStop = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Expired Delete',
        lat: 35.1,
        lng: 135.1,
        addedBy: 'user_tester',
      );

      final now = DateTime.now();
      // Soft-delete recent stop (2 days ago)
      await (db.update(db.stops)..where((s) => s.id.equals(recentStop.id))).write(
        StopsCompanion(
          deletedAt: Value(now.subtract(const Duration(days: 2))),
        ),
      );

      // Soft-delete expired stop (35 days ago)
      await (db.update(db.stops)..where((s) => s.id.equals(expiredStop.id))).write(
        StopsCompanion(
          deletedAt: Value(now.subtract(const Duration(days: 35))),
        ),
      );

      // Purge with default 30-day retention
      final purged = await repo.purgeExpiredTrash(retention: const Duration(days: 30));
      expect(purged, greaterThanOrEqualTo(1));

      // Expired stop is permanently gone from DB
      final allStopsInDb = await db.select(db.stops).get();
      expect(allStopsInDb.any((s) => s.id == expiredStop.id), isFalse);

      // Recent stop is still in DB (in trash)
      expect(allStopsInDb.any((s) => s.id == recentStop.id), isTrue);
      final trash = await repo.getTrashStops(trip.id);
      expect(trash.any((s) => s.id == recentStop.id), isTrue);
    });
  });
}

