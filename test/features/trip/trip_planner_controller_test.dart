import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/utils/schedule_logic.dart';
import 'package:trip_planner/features/trip/controllers/trip_planner_controller.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  late AppDatabase db;
  late TripRepository tripRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tripRepo = DriftTripRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TripPlannerController', () {
    test('loads trip, day blocks, stops, and calculates backlog & status', () async {
      final trip = await tripRepo.createTrip(
        title: 'Akihabara & Uji Pilgrimage',
        ownerId: 'user_test',
        startDate: '2027-05-01',
        dayCount: 2,
      );

      await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Kanda Myojin',
        lat: 35.702,
        lng: 139.767,
        addedBy: 'user_test',
      );

      await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Radio Kaikan',
        lat: 35.698,
        lng: 139.771,
        addedBy: 'user_test',
      );

      final controller = TripPlannerController(
        repository: tripRepo,
        tripId: trip.id,
      );

      // Await load completion
      await controller.load();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.trip?.title, equals('Akihabara & Uji Pilgrimage'));
      expect(controller.state.days.length, equals(2));
      expect(controller.state.days[0].date, equals(DateTime.utc(2027, 5, 1)));
      expect(controller.state.days[1].date, equals(DateTime.utc(2027, 5, 2)));
      expect(controller.state.stops.length, equals(2));
      expect(controller.state.backlogStops.length, equals(2));
      expect(controller.state.scheduledTimeline, isEmpty);
      expect(controller.state.tripStatus, equals(TripStatus.planning));
    });

    test('scheduleStop moves stop from backlog to scheduled timeline', () async {
      final trip = await tripRepo.createTrip(
        title: 'Tokyo Tour',
        ownerId: 'user_test',
        startDate: '2027-06-01',
        dayCount: 2,
      );

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Tokyo Tower',
        lat: 35.658,
        lng: 139.745,
        addedBy: 'user_test',
      );

      final controller = TripPlannerController(
        repository: tripRepo,
        tripId: trip.id,
      );
      await controller.load();

      expect(controller.state.backlogStops.length, equals(1));
      final dayId = controller.state.days[0].block.id;

      await controller.scheduleStop(
        stop.id,
        dayId,
        stayMinutes: 90,
        transitMinutes: 15,
        fixedTime: 600, // 10:00
      );

      expect(controller.state.backlogStops, isEmpty);
      expect(controller.state.scheduledTimeline.length, equals(1));
      final timelineItem = controller.state.scheduledTimeline.first;
      expect(timelineItem.startMinutes, equals(600));
      expect(timelineItem.endMinutes, equals(690)); // 600 + 90
      expect(timelineItem.startTimeFormatted, equals('10:00'));
      expect(timelineItem.endTimeFormatted, equals('11:30'));
    });

    test('removeScheduleItem returns stop back to backlog', () async {
      final trip = await tripRepo.createTrip(
        title: 'Kyoto Tour',
        ownerId: 'user_test',
        startDate: '2027-06-01',
        dayCount: 1,
      );

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Fushimi Inari',
        lat: 34.967,
        lng: 135.772,
        addedBy: 'user_test',
      );

      final controller = TripPlannerController(
        repository: tripRepo,
        tripId: trip.id,
      );
      await controller.load();

      final dayId = controller.state.days[0].block.id;
      await controller.scheduleStop(stop.id, dayId);

      expect(controller.state.backlogStops, isEmpty);
      expect(controller.state.rawScheduleItems.length, equals(1));

      final scheduledItemId = controller.state.rawScheduleItems.first.id;
      await controller.removeScheduleItem(scheduledItemId);

      expect(controller.state.backlogStops.length, equals(1));
      expect(controller.state.backlogStops.first.id, equals(stop.id));
      expect(controller.state.scheduledTimeline, isEmpty);
    });

    test('swapDayBlocks swaps days and recalculates block dates', () async {
      final trip = await tripRepo.createTrip(
        title: 'Multi-Day Trip',
        ownerId: 'user_test',
        startDate: '2027-07-01',
        dayCount: 2,
      );

      final controller = TripPlannerController(
        repository: tripRepo,
        tripId: trip.id,
      );
      await controller.load();

      final initialDay0Id = controller.state.days[0].block.id;
      final initialDay1Id = controller.state.days[1].block.id;

      await controller.swapDayBlocks(0, 1);

      expect(controller.state.days[0].block.id, equals(initialDay1Id));
      expect(controller.state.days[1].block.id, equals(initialDay0Id));
    });

    test('pinDate validates strictly increasing pins', () async {
      final trip = await tripRepo.createTrip(
        title: 'Pinned Dates Trip',
        ownerId: 'user_test',
        startDate: '2027-08-01',
        dayCount: 3,
      );

      final controller = TripPlannerController(
        repository: tripRepo,
        tripId: trip.id,
      );
      await controller.load();

      final day0Id = controller.state.days[0].block.id;
      final day1Id = controller.state.days[1].block.id;

      // Pin Day 0 to 2027-08-05
      await controller.pinDate(day0Id, '2027-08-05');
      expect(controller.state.days[0].date, equals(DateTime.utc(2027, 8, 5)));
      expect(controller.state.days[1].date, equals(DateTime.utc(2027, 8, 6)));

      // Pin Day 1 to a date before or equal to Day 0 should fail
      await expectLater(
        controller.pinDate(day1Id, '2027-08-04'),
        throwsArgumentError,
      );
      expect(controller.state.errorMessage, isNotNull);
    });

    test('reorderScheduleItem updates item sortKey', () async {
      final trip = await tripRepo.createTrip(
        title: 'Reorder Item Trip',
        ownerId: 'user_test',
        startDate: '2027-09-01',
        dayCount: 2,
      );

      final stop1 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot A',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_test',
      );
      final stop2 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot B',
        lat: 35.1,
        lng: 135.1,
        addedBy: 'user_test',
      );

      final controller = TripPlannerController(
        repository: tripRepo,
        tripId: trip.id,
      );
      await controller.load();

      final day0Id = controller.state.days[0].block.id;
      await controller.scheduleStop(stop1.id, day0Id);
      await controller.scheduleStop(stop2.id, day0Id);

      expect(controller.state.rawScheduleItems.length, equals(2));
      final item1 = controller.state.rawScheduleItems[1];

      // Move item1 before item0
      await controller.reorderScheduleItem(
        itemId: item1.id,
        newSortKey: '0000000000000000', // smaller sort key
      );

      expect(controller.state.scheduledTimeline.first.item.id, equals(item1.id));
    });

    test('computes timeline independently for each day block rather than accumulating across days', () async {
      final trip = await tripRepo.createTrip(
        title: 'Two Day Timeline Trip',
        ownerId: 'user_test',
        startDate: '2027-09-01',
        dayCount: 2,
      );

      final stop1 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Day 1 Spot',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_test',
      );
      final stop2 = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Day 2 Spot',
        lat: 35.1,
        lng: 135.1,
        addedBy: 'user_test',
      );

      final controller = TripPlannerController(
        repository: tripRepo,
        tripId: trip.id,
      );
      await controller.load();

      final day0Id = controller.state.days[0].block.id;
      final day1Id = controller.state.days[1].block.id;

      await controller.scheduleStop(stop1.id, day0Id, stayMinutes: 120);
      await controller.scheduleStop(stop2.id, day1Id, stayMinutes: 60);

      final day0Timeline = controller.state.scheduledTimeline.where((t) => t.item.dayId == day0Id).single;
      final day1Timeline = controller.state.scheduledTimeline.where((t) => t.item.dayId == day1Id).single;

      // Both Day 1 and Day 2 start at default 09:00 (540 minutes)
      expect(day0Timeline.startMinutes, equals(540));
      expect(day1Timeline.startMinutes, equals(540));
    });
  });
}
