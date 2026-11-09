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

  group('Phase 2 Safety Net: Restoration & Undo Tests', () {
    test('restoreStop revives associated schedule items deleted with the stop', () async {
      final trip = await repo.createTrip(title: 'Restore Stop Schedule Test', ownerId: 'user_tester');
      final day = await repo.addDayBlock(trip.id, title: 'Day 1');

      final stopA = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Scheduled Spot A',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_tester',
      );
      final stopB = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Scheduled Spot B',
        lat: 35.1,
        lng: 135.1,
        addedBy: 'user_tester',
      );

      final scheduledA = await repo.scheduleStop(
        tripId: trip.id,
        stopId: stopA.id,
        dayId: day.id,
        stayMinutes: 90,
        transitMinutes: 20,
      );
      final scheduledB = await repo.scheduleStop(
        tripId: trip.id,
        stopId: stopB.id,
        dayId: day.id,
        stayMinutes: 45,
        transitMinutes: 10,
      );

      var dayItems = await repo.getScheduleItemsForDay(day.id);
      expect(dayItems.length, 2);

      // Delete Stop A
      await repo.deleteStop(stopA.id);

      // Stop A is soft deleted and not in active stops
      final activeStops = await repo.getStopsForTrip(trip.id);
      expect(activeStops.map((s) => s.id), contains(stopB.id));
      expect(activeStops.map((s) => s.id), isNot(contains(stopA.id)));

      // Day 1 schedule items now only contains Stop B
      dayItems = await repo.getScheduleItemsForDay(day.id);
      expect(dayItems.length, 1);
      expect(dayItems.first.stopId, stopB.id);

      // Restore Stop A
      await repo.restoreStop(stopA.id);

      // Stop A is restored with dirty syncStatus
      final activeStopsAfter = await repo.getStopsForTrip(trip.id);
      expect(activeStopsAfter.map((s) => s.id), contains(stopA.id));
      final restoredStopA = activeStopsAfter.firstWhere((s) => s.id == stopA.id);
      expect(restoredStopA.deletedAt, isNull);
      expect(restoredStopA.syncStatus, 1);

      // Schedule item for Stop A is also revived on Day 1 with dirty syncStatus!
      dayItems = await repo.getScheduleItemsForDay(day.id);
      expect(dayItems.length, 2);
      final restoredItemA = dayItems.firstWhere((i) => i.id == scheduledA.id);
      expect(restoredItemA.deletedAt, isNull);
      expect(restoredItemA.syncStatus, 1);
      expect(restoredItemA.stayMinutes, 90);
      expect(restoredItemA.transitMinutes, 20);
    });

    test('restoreStop does NOT revive schedule items deleted prior to stop deletion', () async {
      final trip = await repo.createTrip(title: 'No Zombie Resurrections', ownerId: 'user_tester');
      final day = await repo.addDayBlock(trip.id, title: 'Day 1');

      final stop = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot with old deleted schedule',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_tester',
      );

      final item = await repo.scheduleStop(
        tripId: trip.id,
        stopId: stop.id,
        dayId: day.id,
      );

      // User removes stop from schedule (moving to backlog)
      await repo.deleteScheduleItem(item.id);
      expect(await repo.getScheduleItemsForDay(day.id), isEmpty);

      // Small delay to ensure distinct timestamp
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // User then deletes stop from backlog
      await repo.deleteStop(stop.id);

      // Restore stop
      await repo.restoreStop(stop.id);

      // Stop is restored to active stops (backlog)
      final stops = await repo.getStopsForTrip(trip.id);
      expect(stops.length, 1);
      expect(stops.first.id, stop.id);

      // But schedule item on Day 1 MUST NOT be resurrected!
      expect(await repo.getScheduleItemsForDay(day.id), isEmpty);
    });

    test('restoreDayBlock revives day block and its active schedule items', () async {
      final trip = await repo.createTrip(title: 'Restore Day Test', ownerId: 'user_tester');
      final initialDays = await repo.getDaysForTrip(trip.id);
      final day1 = initialDays.first;
      final day2 = await repo.addDayBlock(trip.id, title: 'Day 2');

      final stop1 = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot 1',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_tester',
      );
      final stop2 = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot 2',
        lat: 35.1,
        lng: 135.1,
        addedBy: 'user_tester',
      );

      final item1 = await repo.scheduleStop(
        tripId: trip.id,
        stopId: stop1.id,
        dayId: day1.id,
      );
      await repo.scheduleStop(
        tripId: trip.id,
        stopId: stop2.id,
        dayId: day2.id,
      );

      // Delete Day 1
      await repo.deleteDayBlock(day1.id);

      var days = await repo.getDaysForTrip(trip.id);
      expect(days.length, 1);
      expect(days.first.id, day2.id);
      expect(await repo.getScheduleItemsForDay(day1.id), isEmpty);

      // Restore Day 1
      await repo.restoreDayBlock(day1.id);

      days = await repo.getDaysForTrip(trip.id);
      expect(days.length, 2);
      final restoredDay1 = days.firstWhere((d) => d.id == day1.id);
      expect(restoredDay1.deletedAt, isNull);
      expect(restoredDay1.syncStatus, 1);

      // Schedule items for Day 1 are revived
      final day1Items = await repo.getScheduleItemsForDay(day1.id);
      expect(day1Items.length, 1);
      expect(day1Items.first.id, item1.id);
      expect(day1Items.first.deletedAt, isNull);
      expect(day1Items.first.syncStatus, 1);
    });

    test('restoreDayBlock does NOT revive schedule items for stops that are currently deleted', () async {
      final trip = await repo.createTrip(title: 'Restore Day with Deleted Stop', ownerId: 'user_tester');
      final day = await repo.addDayBlock(trip.id, title: 'Day 1');

      final liveStop = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Live Stop',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_tester',
      );
      final deletedStop = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Deleted Stop',
        lat: 35.1,
        lng: 135.1,
        addedBy: 'user_tester',
      );

      final liveItem = await repo.scheduleStop(
        tripId: trip.id,
        stopId: liveStop.id,
        dayId: day.id,
      );
      final itemForDeletedStop = await repo.scheduleStop(
        tripId: trip.id,
        stopId: deletedStop.id,
        dayId: day.id,
      );

      // Delete Day 1
      await repo.deleteDayBlock(day.id);

      // Subsequently, user deletes deletedStop
      await repo.deleteStop(deletedStop.id);

      // Restore Day 1
      await repo.restoreDayBlock(day.id);

      // Live stop's item is revived
      final dayItems = await repo.getScheduleItemsForDay(day.id);
      expect(dayItems.length, 1);
      expect(dayItems.first.id, liveItem.id);

      // Deleted stop's item is NOT revived
      final rawDeletedItem = await (db.select(db.scheduleItems)..where((tbl) => tbl.id.equals(itemForDeletedStop.id))).getSingle();
      expect(rawDeletedItem.deletedAt, isNotNull);
    });

    test('restoreTrip restores trip, day blocks, stops, and schedule items', () async {
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
      final item = await repo.scheduleStop(
        tripId: trip.id,
        stopId: stop.id,
        dayId: day.id,
      );

      // Delete entire trip
      await repo.deleteTrip(trip.id);

      expect(await repo.getTrip(trip.id), isNull);
      expect(await repo.getDaysForTrip(trip.id), isEmpty);
      expect(await repo.getStopsForTrip(trip.id), isEmpty);
      expect(await repo.getScheduleItemsForTrip(trip.id), isEmpty);

      // Restore trip
      await repo.restoreTrip(trip.id);

      final restoredTrip = await repo.getTrip(trip.id);
      expect(restoredTrip, isNotNull);
      expect(restoredTrip!.deletedAt, isNull);
      expect(restoredTrip.syncStatus, 1);

      final restoredDays = await repo.getDaysForTrip(trip.id);
      expect(restoredDays.length, initialDays.length);
      expect(restoredDays.any((d) => d.id == day.id), isTrue);

      final restoredStops = await repo.getStopsForTrip(trip.id);
      expect(restoredStops.length, 1);
      expect(restoredStops.first.id, stop.id);
      expect(restoredStops.first.syncStatus, 1);

      final restoredItems = await repo.getScheduleItemsForTrip(trip.id);
      expect(restoredItems.length, 1);
      expect(restoredItems.first.id, item.id);
      expect(restoredItems.first.syncStatus, 1);
    });

    test('restoration methods enforce 30-day window check', () async {
      final trip = await repo.createTrip(title: 'Window Check Test', ownerId: 'user_tester');
      final stop = await repo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Expired Stop',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_tester',
      );

      // Simulate soft-delete 35 days ago
      final oldDate = DateTime.now().subtract(const Duration(days: 35));
      await (db.update(db.stops)..where((tbl) => tbl.id.equals(stop.id))).write(
        StopsCompanion(
          deletedAt: Value(oldDate),
        ),
      );

      // Attempt restore with default 30-day window
      await repo.restoreStop(stop.id);

      // Should remain soft-deleted
      final rawStop = await (db.select(db.stops)..where((tbl) => tbl.id.equals(stop.id))).getSingle();
      expect(rawStop.deletedAt, isNotNull);
    });

    test('entity scope isolation: restoreStop and restoreDayBlock do not cross trip boundaries', () async {
      final trip1 = await repo.createTrip(title: 'Trip 1', ownerId: 'user_tester');
      final trip2 = await repo.createTrip(title: 'Trip 2', ownerId: 'user_tester');

      final stop1 = await repo.createTripOnlySpot(
        tripId: trip1.id,
        name: 'Spot Trip 1',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_tester',
      );
      final stop2 = await repo.createTripOnlySpot(
        tripId: trip2.id,
        name: 'Spot Trip 2',
        lat: 36.0,
        lng: 136.0,
        addedBy: 'user_tester',
      );

      // Both deleted
      await repo.deleteStop(stop1.id);
      await repo.deleteStop(stop2.id);

      // Restore Trip 1 stop
      await repo.restoreStop(stop1.id);

      // Trip 1 stop is restored, Trip 2 stop is still deleted
      final activeTrip1Stops = await repo.getStopsForTrip(trip1.id);
      final activeTrip2Stops = await repo.getStopsForTrip(trip2.id);
      expect(activeTrip1Stops.map((s) => s.id), contains(stop1.id));
      expect(activeTrip2Stops.map((s) => s.id), isEmpty);
    });
  });
}
