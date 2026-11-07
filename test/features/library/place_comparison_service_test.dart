import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/library/models/place_diff.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/services/anitabi_import.dart';
import 'package:trip_planner/features/library/services/place_comparison_service.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

void main() {
  late AppDatabase db;
  late DriftPlaceRepository placeRepo;
  late DriftTripRepository tripRepo;
  late PlaceComparisonService comparisonService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    placeRepo = DriftPlaceRepository(db);
    tripRepo = DriftTripRepository(db, null, 'user_tester', placeRepo);
    comparisonService = PlaceComparisonService(
      db: db,
      placeRepo: placeRepo,
      tripRepo: tripRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Geodesic Distance & Compass Direction Calculations', () {
    test('calculateDistanceMeters accurately computes small and large distances', () {
      // Kyoto Station to Fushimi Inari Taisha (~2.45 km)
      final d = PlaceComparisonService.calculateDistanceMeters(
        34.985833,
        135.758333,
        34.967222,
        135.772778,
      );
      expect(d, greaterThan(2400));
      expect(d, lessThan(3000));

      // Same point should be 0
      final zero = PlaceComparisonService.calculateDistanceMeters(
        35.0,
        135.0,
        35.0,
        135.0,
      );
      expect(zero, closeTo(0.0, 0.001));
    });

    test('calculateCompassDirection calculates 8 cardinal/intercardinal points', () {
      // Due North
      expect(
        PlaceComparisonService.calculateCompassDirection(35.0, 135.0, 35.01, 135.0),
        'N',
      );
      // Due East
      expect(
        PlaceComparisonService.calculateCompassDirection(35.0, 135.0, 35.0, 135.01),
        'E',
      );
      // Due South
      expect(
        PlaceComparisonService.calculateCompassDirection(35.0, 135.0, 34.99, 135.0),
        'S',
      );
      // Due West
      expect(
        PlaceComparisonService.calculateCompassDirection(35.0, 135.0, 35.0, 134.99),
        'W',
      );
      // South-East
      expect(
        PlaceComparisonService.calculateCompassDirection(35.0, 135.0, 34.99, 135.01),
        'SE',
      );
    });

    test('formatDistanceDifference formats meters and kilometers properly', () {
      expect(
        PlaceComparisonService.formatDistanceDifference(120.4, 'SE'),
        'Moved 120 m SE',
      );
      expect(
        PlaceComparisonService.formatDistanceDifference(1250.0, 'NW'),
        'Moved 1.3 km NW',
      );
    });
  });

  group('Place Comparison with AnitabiSpot', () {
    test('returns null when place and AnitabiSpot have identical facts', () {
      final place = Place(
        placeKey: 'anitabi:spot_1',
        name: 'Kumiko Bench',
        lat: 34.891111,
        lng: 135.812222,
        description: 'Uji River bench from Sound! Euphonium',
        sourceUrl: 'https://anitabi.cn/spot/1',
        visibility: 'saved',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final spot = AnitabiSpot(
        id: 'spot_1',
        name: 'Kumiko Bench',
        lat: 34.891111,
        lng: 135.812222,
        note: 'Uji River bench from Sound! Euphonium',
        originUrl: 'https://anitabi.cn/spot/1',
      );

      final diff = comparisonService.comparePlaceWithAnitabi(place, spot);
      expect(diff, isNull);
    });

    test('detects moved location, renamed spot, and updated description', () {
      final place = Place(
        placeKey: 'anitabi:spot_1',
        name: 'Old Bench',
        lat: 34.891111,
        lng: 135.812222,
        description: 'Old note',
        visibility: 'saved',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final spot = AnitabiSpot(
        id: 'spot_1',
        name: 'Kumiko Bench',
        // Moved ~110m north
        lat: 34.892111,
        lng: 135.812222,
        note: 'Updated official note',
        originUrl: 'https://anitabi.cn/spot/1',
      );

      final diff = comparisonService.comparePlaceWithAnitabi(place, spot);
      expect(diff, isNotNull);
      expect(diff!.hasDifferences, isTrue);
      expect(diff.differences.length, 4); // name, location, description, sourceUrl

      final locDiff = diff.locationDiff;
      expect(locDiff, isNotNull);
      expect(locDiff!.distanceMeters!, greaterThan(100));
      expect(locDiff.direction, 'N');
    });

    test('ignores micro GPS jitter under threshold', () {
      final place = Place(
        placeKey: 'anitabi:spot_1',
        name: 'Kumiko Bench',
        lat: 34.891111,
        lng: 135.812222,
        visibility: 'saved',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Moved ~1 meter only
      final spot = AnitabiSpot(
        id: 'spot_1',
        name: 'Kumiko Bench',
        lat: 34.891119,
        lng: 135.812222,
      );

      final diff = comparisonService.comparePlaceWithAnitabi(place, spot);
      expect(diff, isNull);
    });
  });

  group('Place Comparison with Stop', () {
    test('returns null when place and stop match', () {
      final place = Place(
        placeKey: 'place_uji_bridge',
        name: 'Uji Bridge',
        lat: 34.892,
        lng: 135.808,
        description: 'Famous historic bridge',
        accessTips: 'Take Keihan line',
        visibility: 'saved',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final stop = Stop(
        id: 'stop_1',
        tripId: 'trip_1',
        placeKey: 'place_uji_bridge',
        name: 'Uji Bridge',
        lat: 34.892,
        lng: 135.808,
        description: 'Famous historic bridge',
        accessTips: 'Take Keihan line',
        addedBy: 'user_tester',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      final diff = comparisonService.comparePlaceWithStop(place, stop);
      expect(diff, isNull);
    });

    test('detects differences in name, location, and multiple text fields', () {
      final place = Place(
        placeKey: 'place_uji_bridge',
        name: 'Uji Bridge',
        lat: 34.892,
        lng: 135.808,
        description: 'Old description',
        accessTips: 'Old tips',
        address: 'Old address',
        businessHours: 'Old hours',
        contactInfo: 'Old phone',
        links: 'https://old.link',
        sourceUrl: 'https://old.source',
        visibility: 'saved',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final stop = Stop(
        id: 'stop_1',
        tripId: 'trip_1',
        placeKey: 'place_uji_bridge',
        name: 'Historic Uji Bridge',
        lat: 34.8935, // Moved ~166 m north
        lng: 135.808,
        description: 'Collaborator description',
        accessTips: 'Updated transit tips',
        address: 'New address',
        businessHours: 'Open 24/7',
        contactInfo: 'New phone',
        links: 'https://new.link',
        sourceUrl: 'https://new.source',
        addedBy: 'user_tester',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      final diff = comparisonService.comparePlaceWithStop(place, stop);
      expect(diff, isNotNull);
      expect(diff!.differences.length, 9);
      expect(diff.hasLocationMoved, isTrue);
      expect(diff.differences.any((d) => d.field == PlaceFieldType.name), isTrue);
      expect(diff.differences.any((d) => d.field == PlaceFieldType.businessHours), isTrue);
    });
  });

  group('Trip Comparison with Library (compareTripWithLibrary)', () {
    test('identifies missing, differing, and identical stops accurately', () async {
      // 1. Create a trip
      final trip = await tripRepo.createTrip(
        title: 'Kyoto Pilgrimage',
        ownerId: 'user_tester',
      );

      // 2. Create existing personal library places
      await placeRepo.upsertPlace(
        PlacesCompanion.insert(
          placeKey: 'place_identical',
          name: 'Identical Place',
          lat: 35.0,
          lng: 135.0,
          visibility: const Value('saved'),
        ),
      );

      await placeRepo.upsertPlace(
        PlacesCompanion.insert(
          placeKey: 'place_differing',
          name: 'Local Name',
          lat: 35.0,
          lng: 135.0,
          description: const Value('Local note'),
          visibility: const Value('saved'),
        ),
      );

      // 3. Add stops to the trip
      // Stop 1: Identical
      await tripRepo.addPlaceToTrip(
        tripId: trip.id,
        placeKey: 'place_identical',
        addedBy: 'user_tester',
      );

      // Stop 2: Differing
      final stop2 = await tripRepo.addPlaceToTrip(
        tripId: trip.id,
        placeKey: 'place_differing',
        addedBy: 'user_tester',
      );
      // Mutate stop2 to differ
      await tripRepo.updateStop(
        StopsCompanion(
          id: Value(stop2.id),
          name: const Value('Remote Modified Name'),
        ),
      );

      // Stop 3: Missing from library (added directly as trip-only or from group collaborator)
      await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Collaborator Secret Spot',
        lat: 34.9,
        lng: 135.7,
        addedBy: 'collaborator_bob',
      );

      // 4. Run comparison
      final summary = await comparisonService.compareTripWithLibrary(trip.id);

      expect(summary.totalStopsCount, 3);
      expect(summary.hasDifferences, isTrue);
      expect(summary.identicalStopIds.length, 1);
      expect(summary.differingStops.length, 1);
      expect(summary.differingStops.first.placeKey, 'place_differing');
      expect(summary.missingFromLibrary.length, 1);
      expect(summary.missingFromLibrary.first.name, 'Collaborator Secret Spot');
    });
  });

  group('Resolution & Mutations (saveStopToLibrary & saveAllTripStopsToLibrary)', () {
    test('saveStopToLibrary creates new place in library and preserves reference images', () async {
      final trip = await tripRepo.createTrip(
        title: 'Uji Trip',
        ownerId: 'user_tester',
      );

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Daikichiyama Viewpoint',
        lat: 34.895,
        lng: 135.815,
        description: 'Scenic viewpoint',
        addedBy: 'collaborator_bob',
      );

      // Attach a reference image to the stop
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'ref_1',
              placeKey: Value(stop.placeKey),
              localPath: const Value('/data/ref_daikichi.jpg'),
            ),
          );

      // Save to library
      final savedPlace = await comparisonService.saveStopToLibrary(stop);
      expect(savedPlace.placeKey, stop.placeKey);
      expect(savedPlace.name, 'Daikichiyama Viewpoint');
      expect(savedPlace.visibility, 'saved');

      // Verify reference image copied to personal place
      final refImages = await placeRepo.getReferenceImagesForPlace(savedPlace.placeKey);
      expect(refImages.length, 1);
      expect(refImages.first.id, 'ref_1');
    });

    test('saveStopToLibrary promotes existing trip_only place to saved', () async {
      final trip = await tripRepo.createTrip(
        title: 'Uji Trip',
        ownerId: 'user_tester',
      );

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Hidden Shrine',
        lat: 34.89,
        lng: 135.81,
        addedBy: 'user_tester',
      );

      // Verify initial state is trip_only
      final initialPlace = await placeRepo.getPlace(stop.placeKey);
      expect(initialPlace!.visibility, 'trip_only');

      // Save to library
      final promoted = await comparisonService.saveStopToLibrary(stop);
      expect(promoted.visibility, 'saved');

      final rechecked = await placeRepo.getPlace(stop.placeKey);
      expect(rechecked!.visibility, 'saved');
    });

    test('saveAllTripStopsToLibrary batch imports missing and promotes trip_only stops', () async {
      final trip = await tripRepo.createTrip(
        title: 'Group Trip',
        ownerId: 'collaborator_alice',
      );

      // Stop 1: New spot
      await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot Alpha',
        lat: 35.1,
        lng: 135.1,
        addedBy: 'collaborator_alice',
      );

      // Stop 2: Another new spot
      await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Spot Beta',
        lat: 35.2,
        lng: 135.2,
        addedBy: 'collaborator_alice',
      );

      // Stop 3: Already saved place
      await placeRepo.upsertPlace(
        PlacesCompanion.insert(
          placeKey: 'spot_gamma',
          name: 'Spot Gamma',
          lat: 35.3,
          lng: 135.3,
          visibility: const Value('saved'),
        ),
      );
      await tripRepo.addPlaceToTrip(
        tripId: trip.id,
        placeKey: 'spot_gamma',
        addedBy: 'collaborator_alice',
      );

      // Stop 4: Truly missing place (simulating downstream synced stop from collaborator)
      await db.into(db.stops).insert(
        StopsCompanion.insert(
          id: 'stop_remote_delta',
          tripId: trip.id,
          placeKey: 'place_remote_delta',
          name: 'Spot Delta',
          lat: 35.4,
          lng: 135.4,
          addedBy: 'collaborator_alice',
        ),
      );

      // Batch save
      final result = await comparisonService.saveAllTripStopsToLibrary(trip.id);
      expect(result.newlyCreatedPlacesCount, 1);
      expect(result.promotedTripOnlyPlacesCount, 2);
      expect(result.savedPlaceKeys.length, 3);
      expect(result.totalAffected, 3);

      // Re-run batch save: should be idempotent (0 newly created, 0 promoted)
      final reRunResult = await comparisonService.saveAllTripStopsToLibrary(trip.id);
      expect(reRunResult.newlyCreatedPlacesCount, 0);
      expect(reRunResult.promotedTripOnlyPlacesCount, 0);
      expect(reRunResult.savedPlaceKeys.length, 0);
    });
  });

  group('Field Synchronization (applyStopToPlace, applyPlaceToStop, applyAnitabiToPlace)', () {
    test('applyStopToPlace selectively updates place columns while preserving private note', () async {
      await placeRepo.upsertPlace(
        PlacesCompanion.insert(
          placeKey: 'place_test',
          name: 'Old Name',
          lat: 35.0,
          lng: 135.0,
          description: const Value('Old desc'),
          privateNote: const Value('My super secret note!'),
          visibility: const Value('saved'),
        ),
      );

      final stop = Stop(
        id: 'stop_1',
        tripId: 'trip_1',
        placeKey: 'place_test',
        name: 'New Name From Stop',
        lat: 35.05,
        lng: 135.05,
        description: 'New desc',
        addedBy: 'user_tester',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: 0,
      );

      // Apply only name and description, but not location
      await comparisonService.applyStopToPlace(
        'place_test',
        stop,
        fieldsToUpdate: [PlaceFieldType.name, PlaceFieldType.description],
      );

      final updated = await placeRepo.getPlace('place_test');
      expect(updated!.name, 'New Name From Stop');
      expect(updated.description, 'New desc');
      // Location preserved
      expect(updated.lat, 35.0);
      expect(updated.lng, 135.0);
      // Private note preserved
      expect(updated.privateNote, 'My super secret note!');
    });

    test('applyPlaceToStop updates stop with entity-scope isolation and marks dirty', () async {
      final trip = await tripRepo.createTrip(
        title: 'Trip 1',
        ownerId: 'user_tester',
      );

      final stop = await tripRepo.createTripOnlySpot(
        tripId: trip.id,
        name: 'Original Stop Name',
        lat: 35.0,
        lng: 135.0,
        description: 'Original stop desc',
        area: 'Area 1',
        addedBy: 'user_tester',
      );
      await tripRepo.updateStop(
        StopsCompanion(
          id: Value(stop.id),
          note: const Value('Trip note for all members'),
        ),
      );

      final place = Place(
        placeKey: stop.placeKey,
        name: 'Updated Place Name',
        lat: 35.02,
        lng: 135.02,
        description: 'Updated place desc',
        visibility: 'saved',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await comparisonService.applyPlaceToStop(
        trip.id,
        stop.id,
        place,
        currentUserId: 'user_tester',
      );

      final updatedStop = await tripRepo.getStop(stop.id);
      expect(updatedStop!.name, 'Updated Place Name');
      expect(updatedStop.lat, 35.02);
      expect(updatedStop.description, 'Updated place desc');
      // Trip note and area preserved
      expect(updatedStop.note, 'Trip note for all members');
      expect(updatedStop.area, 'Area 1');
      // Marked dirty for sync
      expect(updatedStop.syncStatus, 1);
    });

    test('applyAnitabiToPlace updates place with new Anitabi spot details', () async {
      await placeRepo.upsertPlace(
        PlacesCompanion.insert(
          placeKey: 'anitabi:spot_99',
          name: 'Old Anitabi Name',
          lat: 34.0,
          lng: 135.0,
          description: const Value('Old note'),
          privateNote: const Value('My personal visit note'),
          visibility: const Value('saved'),
        ),
      );

      final spot = AnitabiSpot(
        id: 'spot_99',
        name: 'Refined Official Name',
        lat: 34.005,
        lng: 135.005,
        note: 'Refined official description',
        originUrl: 'https://anitabi.cn/spot/99',
      );

      await comparisonService.applyAnitabiToPlace('anitabi:spot_99', spot);

      final updated = await placeRepo.getPlace('anitabi:spot_99');
      expect(updated!.name, 'Refined Official Name');
      expect(updated.lat, 34.005);
      expect(updated.description, 'Refined official description');
      expect(updated.sourceUrl, 'https://anitabi.cn/spot/99');
      // Private note unaffected
      expect(updated.privateNote, 'My personal visit note');
    });
  });
}
