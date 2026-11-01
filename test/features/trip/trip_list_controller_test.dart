import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/utils/schedule_logic.dart';
import 'package:trip_planner/features/trip/controllers/trip_list_controller.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  late AppDatabase db;
  late TripRepository tripRepo;
  const currentUserId = 'user_me';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tripRepo = DriftTripRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TripListController', () {
    test('aggregates trips, stop counts, and shared flags correctly', () async {
      // 1. Create personal trip
      final trip1 = await tripRepo.createTrip(
        title: 'Solo Akihabara Run',
        description: 'Buying doujinshi and figures',
        ownerId: currentUserId,
        startDate: '2027-04-01',
        dayCount: 2,
      );

      await tripRepo.createTripOnlySpot(
        tripId: trip1.id,
        name: 'Animate Akiba',
        lat: 35.7,
        lng: 139.7,
        addedBy: currentUserId,
      );

      // 2. Create shared trip
      final trip2 = await tripRepo.createTrip(
        title: 'Kyoto Sound Euphonium Tour',
        description: 'Pilgrimage with friends in Uji',
        ownerId: 'user_friend',
        startDate: '2027-05-10',
        dayCount: 3,
      );

      // Mark trip2 as shared
      await db.trips.insertOnConflictUpdate(trip2.copyWith(sharing: 'group'));

      await tripRepo.createTripOnlySpot(
        tripId: trip2.id,
        name: 'Uji Bridge',
        lat: 34.89,
        lng: 135.8,
        addedBy: 'user_friend',
      );
      await tripRepo.createTripOnlySpot(
        tripId: trip2.id,
        name: 'Mount Daikichi',
        lat: 34.895,
        lng: 135.81,
        addedBy: 'user_friend',
      );

      final controller = TripListController(
        repository: tripRepo,
        currentUserId: currentUserId,
      );

      // Allow stream to emit
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.allTrips.length, equals(2));

      final personalItem = controller.state.allTrips.firstWhere((t) => t.trip.id == trip1.id);
      expect(personalItem.stopCount, equals(1));
      expect(personalItem.isShared, isFalse);
      expect(personalItem.status, equals(TripStatus.planning));
      expect(personalItem.dateRangeDisplay, equals('2027-04-01 ~ 2027-04-02'));

      final sharedItem = controller.state.allTrips.firstWhere((t) => t.trip.id == trip2.id);
      expect(sharedItem.stopCount, equals(2));
      expect(sharedItem.isShared, isTrue);

      controller.dispose();
    });

    test('filters trips by category (all, shared, personal)', () async {
      final trip1 = await tripRepo.createTrip(
        title: 'Solo Trip',
        ownerId: currentUserId,
        startDate: '2027-04-01',
      );

      final trip2 = await tripRepo.createTrip(
        title: 'Group Trip',
        ownerId: currentUserId,
        startDate: '2027-05-01',
      );
      await db.trips.insertOnConflictUpdate(trip2.copyWith(sharing: 'group'));

      final controller = TripListController(
        repository: tripRepo,
        currentUserId: currentUserId,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Default: all
      expect(controller.state.filteredTrips.length, equals(2));

      // Filter: personal
      controller.setFilter(TripFilter.personal);
      expect(controller.state.filteredTrips.length, equals(1));
      expect(controller.state.filteredTrips.first.trip.id, equals(trip1.id));

      // Filter: shared
      controller.setFilter(TripFilter.shared);
      expect(controller.state.filteredTrips.length, equals(1));
      expect(controller.state.filteredTrips.first.trip.id, equals(trip2.id));

      controller.dispose();
    });

    test('filters trips by search query on title and description', () async {
      await tripRepo.createTrip(
        title: 'Bocchi the Rock Pilgrimage',
        description: 'Shimokitazawa live houses',
        ownerId: currentUserId,
      );
      await tripRepo.createTrip(
        title: 'Laid-Back Camp',
        description: 'Mount Fuji campsites',
        ownerId: currentUserId,
      );

      final controller = TripListController(
        repository: tripRepo,
        currentUserId: currentUserId,
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Search by title keyword
      controller.setSearchQuery('bocchi');
      expect(controller.state.filteredTrips.length, equals(1));
      expect(controller.state.filteredTrips.first.trip.title, contains('Bocchi'));

      // Search by description keyword
      controller.setSearchQuery('fuji');
      expect(controller.state.filteredTrips.length, equals(1));
      expect(controller.state.filteredTrips.first.trip.title, contains('Laid-Back Camp'));

      // Search with non-matching query
      controller.setSearchQuery('nonexistent');
      expect(controller.state.filteredTrips, isEmpty);

      controller.dispose();
    });

    test('deleteTrip soft-deletes trip and removes from list', () async {
      final trip = await tripRepo.createTrip(
        title: 'To Be Deleted',
        ownerId: currentUserId,
      );

      final controller = TripListController(
        repository: tripRepo,
        currentUserId: currentUserId,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(controller.state.allTrips.length, equals(1));

      await controller.deleteTrip(trip.id);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.state.allTrips, isEmpty);
      expect(controller.state.filteredTrips, isEmpty);

      controller.dispose();
    });
  });
}
