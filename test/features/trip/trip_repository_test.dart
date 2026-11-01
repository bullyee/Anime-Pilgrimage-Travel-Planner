import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  late AppDatabase db;
  late PlaceRepository placeRepo;
  late TripRepository tripRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    placeRepo = DriftPlaceRepository(db);
    tripRepo = DriftTripRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TripRepository Integration Tests', () {
    test('createTrip initializes day blocks with sorted fractional keys', () async {
      final trip = await tripRepo.createTrip(
        title: 'Kyoto Anime Tour',
        ownerId: 'user_1',
        startDate: '2027-04-10',
        dayCount: 3,
      );

      expect(trip.title, equals('Kyoto Anime Tour'));
      expect(trip.dayCount, equals(3));

      final days = await tripRepo.getDaysForTrip(trip.id);
      expect(days.length, equals(3));

      // Check that fractional keys are sorted
      expect(days[0].sortKey.compareTo(days[1].sortKey), lessThan(0));
      expect(days[1].sortKey.compareTo(days[2].sortKey), lessThan(0));
    });

    test('addDayBlock appends block and swapDayBlocks swaps their order', () async {
      final trip = await tripRepo.createTrip(
        title: 'Short Trip',
        ownerId: 'user_1',
        dayCount: 2,
      );

      final newDay = await tripRepo.addDayBlock(trip.id, title: 'Backup Day');
      final allDays = await tripRepo.getDaysForTrip(trip.id);
      expect(allDays.length, equals(3));
      expect(allDays.last.id, equals(newDay.id));

      // Swap day 0 and day 1
      final day0Id = allDays[0].id;
      final day1Id = allDays[1].id;
      final sort0 = allDays[0].sortKey;
      final sort1 = allDays[1].sortKey;

      await tripRepo.swapDayBlocks(day0Id, day1Id);

      final daysAfterSwap = await tripRepo.getDaysForTrip(trip.id);
      // The day with day1Id now comes first
      expect(daysAfterSwap[0].id, equals(day1Id));
      expect(daysAfterSwap[0].sortKey, equals(sort0));
      expect(daysAfterSwap[1].id, equals(day0Id));
      expect(daysAfterSwap[1].sortKey, equals(sort1));
    });

    test('pinDayBlockDate enforces strictly increasing pin rule', () async {
      final trip = await tripRepo.createTrip(
        title: 'Pilgrimage',
        ownerId: 'user_1',
        dayCount: 3,
      );

      final days = await tripRepo.getDaysForTrip(trip.id);

      // Pin day 0 to 2027-04-10
      await tripRepo.pinDayBlockDate(days[0].id, '2027-04-10');

      // Pin day 1 to 2027-04-12 (valid)
      await tripRepo.pinDayBlockDate(days[1].id, '2027-04-12');

      // Pin day 2 to 2027-04-11 (invalid: earlier than day 1)
      expect(
        () => tripRepo.pinDayBlockDate(days[2].id, '2027-04-11'),
        throwsArgumentError,
      );

      // Pinning a block to the same date as a previous unpinned block is also rejected
      final datedTrip = await tripRepo.createTrip(
        title: 'Dated Trip',
        ownerId: 'user_1',
        startDate: '2027-05-01',
        dayCount: 2,
      );
      final datedDays = await tripRepo.getDaysForTrip(datedTrip.id);
      // Day 0 is unpinned and has computed date 2027-05-01; pinning Day 1 to 2027-05-01 must fail
      expect(
        () => tripRepo.pinDayBlockDate(datedDays[1].id, '2027-05-01'),
        throwsArgumentError,
      );
    });

    test('deleteDayBlock tombstones the day and its schedule items', () async {
      final trip = await tripRepo.createTrip(title: 'Delete Day Test', ownerId: 'user_1', dayCount: 2);
      final days = await tripRepo.getDaysForTrip(trip.id);
      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot A',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'user_1',
      );
      await tripRepo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days[0].id);

      await tripRepo.deleteDayBlock(days[0].id);

      final remainingDays = await tripRepo.getDaysForTrip(trip.id);
      expect(remainingDays.map((d) => d.id).toList(), equals([days[1].id]));
      expect(await tripRepo.getScheduleItemsForTrip(trip.id), isEmpty);
    });

    test('addPlaceToTrip copies place facts, reference images and labels', () async {
      // 1. Create a Place with labels and reference image
      final animeLabel = await placeRepo.getOrCreateLabel(kind: 'anime', name: 'Hyouka', bangumiId: '32000');
      await placeRepo.upsertPlace(
        PlacesCompanion.insert(
          placeKey: 'anitabi:takayama_cafe',
          name: 'Bagpipe Cafe',
          lat: 36.14,
          lng: 137.25,
          description: const Value('Eru and Hotaro coffee shop'),
          accessTips: const Value('Best seat near the clock'),
        ),
      );
      await placeRepo.attachLabelToPlace('anitabi:takayama_cafe', animeLabel.id);

      // Insert reference image for place
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'ref_1',
              placeKey: const Value('anitabi:takayama_cafe'),
              episode: const Value('EP 02'),
              timestampS: const Value(742),
            ),
          );

      // 2. Create Trip and add Place
      final trip = await tripRepo.createTrip(
        title: 'Takayama Run',
        ownerId: 'user_1',
      );

      final stop = await tripRepo.addPlaceToTrip(
        tripId: trip.id,
        placeKey: 'anitabi:takayama_cafe',
        addedBy: 'user_1',
      );

      // Stop facts copied
      expect(stop.name, equals('Bagpipe Cafe'));
      expect(stop.description, equals('Eru and Hotaro coffee shop'));
      expect(stop.accessTips, equals('Best seat near the clock'));
      expect(stop.tripId, equals(trip.id));

      // Stop reference image copied with stopId
      final stopRefImages = await (db.select(db.newReferenceImages)..where((tbl) => tbl.stopId.equals(stop.id))).get();
      expect(stopRefImages.length, equals(1));
      expect(stopRefImages.first.episode, equals('EP 02'));

      // Stop labels copied
      final stopLabels = await (db.select(db.stopLabels)..where((tbl) => tbl.stopId.equals(stop.id))).get();
      expect(stopLabels.length, equals(1));
      expect(stopLabels.first.labelId, equals(animeLabel.id));
    });

    test('createTripOnlySpot creates trip_only place and links as stop', () async {
      final trip = await tripRepo.createTrip(title: 'Exploring', ownerId: 'user_1');

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Hidden Shrine',
        lat: 35.5,
        lng: 136.5,
        addedBy: 'user_1',
        accessTips: 'Up the hill',
      );

      expect(stop.name, equals('Hidden Shrine'));
      expect(stop.accessTips, equals('Up the hill'));

      final place = await placeRepo.getPlace(stop.placeKey);
      expect(place, isNotNull);
      expect(place!.visibility, equals('trip_only'));
    });

    test('scheduleStop and reorderScheduleItem', () async {
      final trip = await tripRepo.createTrip(title: 'Day Planning', ownerId: 'user_1');
      final days = await tripRepo.getDaysForTrip(trip.id);
      final dayId = days.first.id;

      final stop1 = await tripRepo.createTripOnlySpot(tripId: trip.id, name: 'Spot 1', lat: 35.0, lng: 135.0, addedBy: 'u1');
      final stop2 = await tripRepo.createTripOnlySpot(tripId: trip.id, name: 'Spot 2', lat: 35.1, lng: 135.1, addedBy: 'u1');

      final item1 = await tripRepo.scheduleStop(
        tripId: trip.id,
        stopId: stop1.id,
        dayId: dayId,
        stayMinutes: 45,
        transitMinutes: 15,
      );

      final item2 = await tripRepo.scheduleStop(
        tripId: trip.id,
        stopId: stop2.id,
        dayId: dayId,
        stayMinutes: 60,
      );

      expect(item1.sortKey.compareTo(item2.sortKey), lessThan(0));

      final items = await tripRepo.getScheduleItemsForDay(dayId);
      expect(items.length, equals(2));

      // Reorder item2 before item1
      await tripRepo.reorderScheduleItem(
        itemId: item2.id,
        newSortKey: '00', // smaller sort key
      );

      final reordered = await tripRepo.getScheduleItemsForDay(dayId);
      expect(reordered.first.id, equals(item2.id));
    });
  });
}

