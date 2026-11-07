import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/anime/models/colocated_spot_models.dart';
import 'package:trip_planner/features/anime/providers/colocated_spot_providers.dart';
import 'package:trip_planner/features/anime/services/colocated_spot_linking_service.dart';
import 'package:trip_planner/features/anime/services/geohash_helper.dart';

void main() {
  group('GeohashHelper', () {
    test('encode generates accurate geohash strings of specified precision', () {
      // Kyoto Station coordinates: 34.985833, 135.758333
      final hash8 = GeohashHelper.encode(34.985833, 135.758333, precision: 8);
      expect(hash8.length, 8);
      expect(hash8.startsWith('xn0'), isTrue);

      final hash6 = GeohashHelper.encode(34.985833, 135.758333, precision: 6);
      expect(hash6.length, 6);
      expect(hash8.startsWith(hash6), isTrue);
    });

    test('decode recovers center coordinates within precision error margins', () {
      const originalLat = 34.985833;
      const originalLng = 135.758333;
      final hash = GeohashHelper.encode(originalLat, originalLng, precision: 8);
      final decoded = GeohashHelper.decode(hash);

      expect(decoded.lat, closeTo(originalLat, decoded.latError));
      expect(decoded.lng, closeTo(originalLng, decoded.lngError));
    });

    test('gridCell and neighborGridKeys generate 9 contiguous spatial cells', () {
      final cell = GeohashHelper.gridCell(34.985833, 135.758333, cellSizeMeters: 35.0);
      expect(cell.row, isNonZero);
      expect(cell.col, isNonZero);

      final neighbors = GeohashHelper.neighborGridKeys(
        34.985833,
        135.758333,
        cellSizeMeters: 35.0,
      );
      expect(neighbors.length, 9);
      expect(neighbors, contains('${cell.row}:${cell.col}'));
    });
  });

  group('ColocatedSpotLinkingService - Clustering & Cross-Anime Hubs', () {
    const service = ColocatedSpotLinkingService();

    // Scene 1: Sound! Euphonium at Kyoto Station Karasuma Exit
    const spotEuphonium = ColocatedSpotItem(
      spotId: 'spot_eupho_kyoto',
      name: 'Kyoto Station Karasuma Exit',
      animeTitle: 'Sound! Euphonium',
      lat: 34.985833,
      lng: 135.758333,
    );

    // Scene 2: The Eccentric Family at Kyoto Station (8 meters away)
    const spotEccentric = ColocatedSpotItem(
      spotId: 'spot_eccentric_kyoto',
      name: 'Kyoto Station Bus Terminal',
      animeTitle: 'The Eccentric Family',
      lat: 34.985890,
      lng: 135.758300,
    );

    // Scene 3: Tamako Market at Kyoto Station (12 meters away)
    const spotTamakoStation = ColocatedSpotItem(
      spotId: 'spot_tamako_kyoto',
      name: 'Kyoto Station Central Gate',
      animeTitle: 'Tamako Market',
      lat: 34.985790,
      lng: 135.758400,
    );

    // Scene 4: K-On! at Kamogawa Delta Stepping Stones (Kyoto)
    const spotKOnDelta = ColocatedSpotItem(
      spotId: 'spot_kon_delta',
      name: 'Kamogawa Delta Stepping Stones',
      animeTitle: 'K-On!',
      lat: 35.030500,
      lng: 135.770500,
    );

    // Scene 5: Tamako Market at Kamogawa Delta (6 meters away)
    const spotTamakoDelta = ColocatedSpotItem(
      spotId: 'spot_tamako_delta',
      name: 'Kamogawa Stepping Stones',
      animeTitle: 'Tamako Market',
      lat: 35.030540,
      lng: 135.770530,
    );

    // Scene 6: Hyouka in Takayama (Far away, isolated single anime)
    const spotHyouka = ColocatedSpotItem(
      spotId: 'spot_hyouka_takayama',
      name: 'Hie Shrine',
      animeTitle: 'Hyouka',
      lat: 36.140000,
      lng: 137.250000,
    );

    test('groups co-located spots and identifies multi-anime hubs accurately', () {
      final allSpots = [
        spotEuphonium,
        spotEccentric,
        spotTamakoStation,
        spotKOnDelta,
        spotTamakoDelta,
        spotHyouka,
      ];

      final result = service.findColocatedHubs(spots: allSpots, radiusMeters: 35.0);

      // Total clustered landmark groups = 3 (Kyoto Station, Kamogawa Delta, Takayama)
      expect(result.allGroups.length, 3);

      // Multi-anime hubs = 2 (Kyoto Station with 3 anime, Kamogawa Delta with 2 anime)
      expect(result.hubs.length, 2);

      // Hub 1: Kyoto Station (sorted first due to highest anime diversity)
      final stationHub = result.hubs.first;
      expect(stationHub.animeCount, 3);
      expect(stationHub.animeTitles, containsAll(['Sound! Euphonium', 'The Eccentric Family', 'Tamako Market']));
      expect(stationHub.spots.length, 3);
      expect(stationHub.centroidLat, closeTo(34.9858, 0.001));

      // Hub 2: Kamogawa Delta
      final deltaHub = result.hubs[1];
      expect(deltaHub.animeCount, 2);
      expect(deltaHub.animeTitles, containsAll(['K-On!', 'Tamako Market']));
      expect(deltaHub.spots.length, 2);

      // Takayama Hie Shrine is single-anime (not in hubs)
      final isolatedGroup = result.allGroups.firstWhere((g) => g.spots.any((s) => s.spotId == spotHyouka.spotId));
      expect(isolatedGroup.isMultiAnime, isFalse);
      expect(isolatedGroup.animeCount, 1);
    });

    test('builds cross-anime lookup mapping excluding spots of same anime', () {
      final result = service.findColocatedHubs(
        spots: [spotEuphonium, spotEccentric, spotTamakoStation],
        radiusMeters: 35.0,
      );

      final euphoniumCrossSpots = result.crossAnimeSpotsFor(spotEuphonium.spotId);
      expect(euphoniumCrossSpots.length, 2);
      expect(euphoniumCrossSpots.map((s) => s.animeTitle), containsAll(['The Eccentric Family', 'Tamako Market']));
      expect(euphoniumCrossSpots.any((s) => s.spotId == spotEuphonium.spotId), isFalse);
    });

    test('does not flag co-located spots from the SAME anime as multi-anime hub', () {
      // 2 different camera cuts of K-On! at Kamogawa Delta
      const spotKOnCut1 = ColocatedSpotItem(
        spotId: 'kon_cut_1',
        name: 'Kamogawa Turtle Stone',
        animeTitle: 'K-On!',
        lat: 35.03050,
        lng: 135.77050,
      );
      const spotKOnCut2 = ColocatedSpotItem(
        spotId: 'kon_cut_2',
        name: 'Kamogawa River Bank',
        animeTitle: 'K-On!',
        lat: 35.03055,
        lng: 135.77055,
      );

      final result = service.findColocatedHubs(
        spots: [spotKOnCut1, spotKOnCut2],
        radiusMeters: 35.0,
      );

      expect(result.allGroups.length, 1);
      expect(result.hubs.isEmpty, isTrue); // Not multi-anime!
      expect(result.allGroups.first.animeCount, 1);
      expect(result.crossAnimeSpotsFor(spotKOnCut1.spotId), isEmpty);
    });

    test('findNearbyCrossAnimeSpots finds adjacent scenes sorted by proximity', () {
      final nearby = service.findNearbyCrossAnimeSpots(
        spotEuphonium,
        [spotEccentric, spotTamakoStation, spotKOnDelta],
        radiusMeters: 50.0,
      );

      expect(nearby.length, 2);
      expect(nearby.first.animeTitle, 'The Eccentric Family'); // ~8m away
      expect(nearby[1].animeTitle, 'Tamako Market'); // ~12m away
    });

    test('handles empty spot list gracefully', () {
      final result = service.findColocatedHubs(spots: const []);
      expect(result.hubs, isEmpty);
      expect(result.allGroups, isEmpty);
      expect(result.coLocatedMap, isEmpty);
    });
  });

  group('ColocatedSpotLinkingService - Database Integration & Entity Scope Isolation', () {
    late AppDatabase db;
    late ColocatedSpotLinkingService service;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = const ColocatedSpotLinkingService();
    });

    tearDown(() async {
      await db.close();
    });

    test('findLibraryColocatedHubs detects multi-anime hubs from saved library', () async {
      // 1. Insert anime labels
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'label_eupho',
              kind: 'anime',
              name: 'Sound! Euphonium',
            ),
          );
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'label_tamako',
              kind: 'anime',
              name: 'Tamako Market',
            ),
          );

      // 2. Insert places at Kyoto Station
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'place_station_1',
              name: 'Kyoto Station North',
              lat: 34.985833,
              lng: 135.758333,
            ),
          );
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'place_station_2',
              name: 'Kyoto Station South',
              lat: 34.985880,
              lng: 135.758310,
            ),
          );

      // 3. Link places to different anime labels
      await db.into(db.placeLabels).insert(
            PlaceLabelsCompanion.insert(
              placeKey: 'place_station_1',
              labelId: 'label_eupho',
            ),
          );
      await db.into(db.placeLabels).insert(
            PlaceLabelsCompanion.insert(
              placeKey: 'place_station_2',
              labelId: 'label_tamako',
            ),
          );

      // 4. Run discovery
      final result = await service.findLibraryColocatedHubs(db, radiusMeters: 35.0);
      expect(result.hubs.length, 1);
      final hub = result.hubs.first;
      expect(hub.animeCount, 2);
      expect(hub.animeTitles, containsAll(['Sound! Euphonium', 'Tamako Market']));
    });

    test('findTripColocatedHubs enforces strict entity scope isolation', () async {
      // Create Trip Alice & Trip Bob
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_alice',
              title: 'Alice Trip',
              ownerId: 'user_alice',
            ),
          );
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_bob',
              title: 'Bob Trip',
              ownerId: 'user_bob',
            ),
          );

      // Insert Anime Labels
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'label_eupho',
              kind: 'anime',
              name: 'Sound! Euphonium',
            ),
          );
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'label_tamako',
              kind: 'anime',
              name: 'Tamako Market',
            ),
          );

      // Insert Stop for Alice (Euphonium only)
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_alice_station',
              tripId: 'trip_alice',
              placeKey: 'p1',
              name: 'Station Alice',
              lat: 34.985833,
              lng: 135.758333,
              addedBy: 'user_alice',
            ),
          );
      await db.into(db.stopLabels).insert(
            StopLabelsCompanion.insert(
              stopId: 'stop_alice_station',
              labelId: 'label_eupho',
            ),
          );

      // Insert Stop for Bob at the same location (Tamako only)
      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_bob_station',
              tripId: 'trip_bob',
              placeKey: 'p2',
              name: 'Station Bob',
              lat: 34.985840,
              lng: 135.758340,
              addedBy: 'user_bob',
            ),
          );
      await db.into(db.stopLabels).insert(
            StopLabelsCompanion.insert(
              stopId: 'stop_bob_station',
              labelId: 'label_tamako',
            ),
          );

      // Alice's trip should only see Euphonium (0 multi-anime hubs inside Alice's trip)
      final aliceHubs = await service.findTripColocatedHubs(db, 'trip_alice');
      expect(aliceHubs.hubs, isEmpty);
      expect(aliceHubs.allGroups.length, 1);
      expect(aliceHubs.allGroups.first.animeCount, 1);

      // Bob's trip should only see Tamako (0 multi-anime hubs inside Bob's trip)
      final bobHubs = await service.findTripColocatedHubs(db, 'trip_bob');
      expect(bobHubs.hubs, isEmpty);
      expect(bobHubs.allGroups.length, 1);
      expect(bobHubs.allGroups.first.animeCount, 1);
    });

    test('Riverpod Providers evaluate library and trip colocated hubs', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          colocatedSpotLinkingServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(libraryColocatedHubsProvider.future);
      expect(result.hubs, isEmpty);
    });
  });
}
