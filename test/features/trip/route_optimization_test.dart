import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/trip/models/route_optimization_models.dart';
import 'package:trip_planner/features/trip/providers/route_optimization_providers.dart';
import 'package:trip_planner/features/trip/services/geodesic_math.dart';
import 'package:trip_planner/features/trip/services/pilgrimage_clustering_service.dart';
import 'package:trip_planner/features/trip/services/route_optimization_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // Sample Kyoto & Uji Anime Pilgrimage Spots
  // Uji spots (Sound! Euphonium)
  const keihanUji = (
    id: 's_keihan_uji',
    name: '京阪宇治站',
    lat: 34.891111,
    lng: 135.808056,
    area: '宇治地區',
  );
  const ujiBridge = (
    id: 's_uji_bridge',
    name: '宇治橋',
    lat: 34.891667,
    lng: 135.808611,
    area: '宇治地區',
  );
  const kumikoBench = (
    id: 's_kumiko_bench',
    name: '久美子長椅',
    lat: 34.892500,
    lng: 135.811111,
    area: '宇治地區',
  );
  const daikichiyama = (
    id: 's_daikichiyama',
    name: '大吉山展望台',
    lat: 34.893889,
    lng: 135.816667,
    area: '宇治地區',
  );
  const byodoin = (
    id: 's_byodoin',
    name: '平等院鳳凰堂',
    lat: 34.889444,
    lng: 135.807778,
    area: '宇治地區',
  );

  // Kyoto Station spots
  const kyotoStation = (
    id: 's_kyoto_station',
    name: '京都車站',
    lat: 34.985833,
    lng: 135.758333,
    area: '京都站周邊',
  );
  const kyotoTower = (
    id: 's_kyoto_tower',
    name: '京都塔',
    lat: 34.987500,
    lng: 135.759167,
    area: '京都站周邊',
  );

  // Fushimi Inari
  const fushimiInari = (
    id: 's_fushimi_inari',
    name: '伏見稻荷大社 千本鳥居',
    lat: 34.967222,
    lng: 135.772778,
    area: '伏見地區',
  );

  Stop createMockStop({
    required String id,
    required String tripId,
    required String name,
    required double lat,
    required double lng,
    String? area,
  }) {
    return Stop(
      id: id,
      tripId: tripId,
      placeKey: 'p_$id',
      name: name,
      lat: lat,
      lng: lng,
      area: area,
      addedBy: 'user_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 0,
    );
  }

  Future<void> seedTripData(String tripId) async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: tripId,
          title: 'Uji Pilgrimage Trip',
          ownerId: 'user_1',
        ));

    await db.into(db.tripDays).insert(TripDaysCompanion.insert(
          id: 'day_${tripId}_1',
          tripId: tripId,
          sortKey: 'a0',
        ));
  }

  group('GeodesicMath', () {
    test('haversineDistance calculates accurate geodesic meters', () {
      // Distance between Kyoto Station and Fushimi Inari (~2.45 km)
      final dist = GeodesicMath.haversineDistance(
        kyotoStation.lat,
        kyotoStation.lng,
        fushimiInari.lat,
        fushimiInari.lng,
      );
      expect(dist, greaterThan(2400));
      expect(dist, lessThan(2500));

      // Same point distance is 0.0
      expect(
        GeodesicMath.haversineDistance(kyotoStation.lat, kyotoStation.lng, kyotoStation.lat, kyotoStation.lng),
        0.0,
      );
    });

    test('estimateWalkingMinutes respects standard Japanese 80m/min rule', () {
      expect(GeodesicMath.estimateWalkingMinutes(0.0), 0);
      expect(GeodesicMath.estimateWalkingMinutes(4.0), 0);
      expect(GeodesicMath.estimateWalkingMinutes(50.0), 1);
      expect(GeodesicMath.estimateWalkingMinutes(800.0), 10);
      expect(GeodesicMath.estimateWalkingMinutes(1600.0), 20);
    });

    test('bearingDegrees and bearingToCompass correctly map 8 directions', () {
      // Going due North
      final northDeg = GeodesicMath.bearingDegrees(34.0, 135.0, 35.0, 135.0);
      expect(northDeg, closeTo(0.0, 1.0));
      expect(GeodesicMath.bearingToCompass(northDeg), 'N');

      // Going due East
      final eastDeg = GeodesicMath.bearingDegrees(34.0, 135.0, 34.0, 136.0);
      expect(eastDeg, closeTo(90.0, 2.0));
      expect(GeodesicMath.bearingToCompass(eastDeg), 'E');

      // Going due South
      final southDeg = GeodesicMath.bearingDegrees(35.0, 135.0, 34.0, 135.0);
      expect(southDeg, closeTo(180.0, 1.0));
      expect(GeodesicMath.bearingToCompass(southDeg), 'S');

      // Going due West
      final westDeg = GeodesicMath.bearingDegrees(34.0, 136.0, 34.0, 135.0);
      expect(westDeg, closeTo(270.0, 2.0));
      expect(GeodesicMath.bearingToCompass(westDeg), 'W');
    });
  });

  group('PilgrimageClusteringService', () {
    const service = PilgrimageClusteringService();

    test('groups pilgrimage spots into distinct clusters by distance threshold', () {
      final stops = [
        createMockStop(id: keihanUji.id, tripId: 't1', name: keihanUji.name, lat: keihanUji.lat, lng: keihanUji.lng, area: keihanUji.area),
        createMockStop(id: ujiBridge.id, tripId: 't1', name: ujiBridge.name, lat: ujiBridge.lat, lng: ujiBridge.lng, area: ujiBridge.area),
        createMockStop(id: kumikoBench.id, tripId: 't1', name: kumikoBench.name, lat: kumikoBench.lat, lng: kumikoBench.lng, area: kumikoBench.area),
        createMockStop(id: daikichiyama.id, tripId: 't1', name: daikichiyama.name, lat: daikichiyama.lat, lng: daikichiyama.lng, area: daikichiyama.area),
        createMockStop(id: kyotoStation.id, tripId: 't1', name: kyotoStation.name, lat: kyotoStation.lat, lng: kyotoStation.lng, area: kyotoStation.area),
        createMockStop(id: kyotoTower.id, tripId: 't1', name: kyotoTower.name, lat: kyotoTower.lat, lng: kyotoTower.lng, area: kyotoTower.area),
        createMockStop(id: fushimiInari.id, tripId: 't1', name: fushimiInari.name, lat: fushimiInari.lat, lng: fushimiInari.lng, area: fushimiInari.area),
      ];

      // With 1200m walking threshold:
      // Cluster 1: Uji spots (4 spots)
      // Cluster 2: Kyoto Station & Tower (2 spots)
      // Cluster 3: Fushimi Inari (1 spot)
      final clusters = service.clusterStops(stops, maxDistanceMeters: 1200.0);
      expect(clusters.length, 3);

      expect(clusters[0].name, '宇治地區');
      expect(clusters[0].stopCount, 4);

      expect(clusters[1].name, '京都站周邊');
      expect(clusters[1].stopCount, 2);

      expect(clusters[2].name, '伏見地區');
      expect(clusters[2].stopCount, 1);
    });

    test('autoAssignTripAreas populates missing area columns in SQLite database', () async {
      const tripId = 't_area_test';
      await seedTripData(tripId);

      // Insert spots without area
      final stopsData = [
        (id: 's1', name: '宇治橋', lat: ujiBridge.lat, lng: ujiBridge.lng),
        (id: 's2', name: '久美子長椅', lat: kumikoBench.lat, lng: kumikoBench.lng),
        (id: 's3', name: '大吉山展望台', lat: daikichiyama.lat, lng: daikichiyama.lng),
      ];

      for (final s in stopsData) {
        await db.into(db.stops).insert(StopsCompanion.insert(
              id: s.id,
              tripId: tripId,
              placeKey: 'p_${s.id}',
              name: s.name,
              lat: s.lat,
              lng: s.lng,
              area: const Value(null),
              addedBy: 'user_1',
            ));
      }

      // Also insert a stop for another trip to verify entity scope isolation
      const otherTripId = 't_other';
      await seedTripData(otherTripId);
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 's_other',
            tripId: otherTripId,
            placeKey: 'p_other',
            name: '其他行程地點',
            lat: kyotoStation.lat,
            lng: kyotoStation.lng,
            area: const Value(null),
            addedBy: 'user_1',
          ));

      final updated = await service.autoAssignTripAreas(
        db: db,
        tripId: tripId,
        maxDistanceMeters: 1000.0,
      );
      expect(updated, 3);

      // Check updated area in t_area_test
      final assignedStops = await (db.select(db.stops)
            ..where((tbl) => tbl.tripId.equals(tripId)))
          .get();
      for (final s in assignedStops) {
        expect(s.area, isNotNull);
        expect(s.area, contains('宇治橋'));
        expect(s.syncStatus, 1);
      }

      // Check other trip was untouched
      final otherStop = await (db.select(db.stops)
            ..where((tbl) => tbl.id.equals('s_other')))
          .getSingle();
      expect(otherStop.area, isNull);
    });
  });

  group('RouteOptimizationService', () {
    const service = RouteOptimizationService();

    test('optimizes zigzag pilgrimage tour into a smooth shortest path', () {
      // Intentionally scrambled zigzag sequence along the Uji river:
      // Keihan Uji -> Daikichiyama (across river & up mountain) -> Uji Bridge (back down) -> Kumiko Bench -> Byodoin
      final scrambledStops = [
        createMockStop(id: keihanUji.id, tripId: 't1', name: keihanUji.name, lat: keihanUji.lat, lng: keihanUji.lng),
        createMockStop(id: daikichiyama.id, tripId: 't1', name: daikichiyama.name, lat: daikichiyama.lat, lng: daikichiyama.lng),
        createMockStop(id: ujiBridge.id, tripId: 't1', name: ujiBridge.name, lat: ujiBridge.lat, lng: ujiBridge.lng),
        createMockStop(id: kumikoBench.id, tripId: 't1', name: kumikoBench.name, lat: kumikoBench.lat, lng: kumikoBench.lng),
        createMockStop(id: byodoin.id, tripId: 't1', name: byodoin.name, lat: byodoin.lat, lng: byodoin.lng),
      ];

      final result = service.optimizeRoute(scrambledStops);

      expect(result.orderedStops.length, 5);
      expect(result.hasImprovement, isTrue);
      expect(result.savedDistanceMeters, greaterThan(300.0));
      expect(result.totalDistanceMeters, lessThan(result.originalDistanceMeters));
      expect(result.legs.length, 4);

      for (final leg in result.legs) {
        expect(leg.distanceMeters, greaterThan(0));
        expect(leg.estimatedWalkingMinutes, greaterThan(0));
        expect(leg.bearingCompass, isNotEmpty);
      }
    });

    test('respects fixed start and end constraints', () {
      final stops = [
        createMockStop(id: keihanUji.id, tripId: 't1', name: keihanUji.name, lat: keihanUji.lat, lng: keihanUji.lng),
        createMockStop(id: daikichiyama.id, tripId: 't1', name: daikichiyama.name, lat: daikichiyama.lat, lng: daikichiyama.lng),
        createMockStop(id: ujiBridge.id, tripId: 't1', name: ujiBridge.name, lat: ujiBridge.lat, lng: ujiBridge.lng),
        createMockStop(id: kumikoBench.id, tripId: 't1', name: kumikoBench.name, lat: kumikoBench.lat, lng: kumikoBench.lng),
        createMockStop(id: byodoin.id, tripId: 't1', name: byodoin.name, lat: byodoin.lat, lng: byodoin.lng),
      ];

      // Fix starting at Keihan Uji and ending at Byodoin
      final result = service.optimizeRoute(
        stops,
        startStopId: keihanUji.id,
        endStopId: byodoin.id,
      );

      expect(result.orderedStopIds.first, keihanUji.id);
      expect(result.orderedStopIds.last, byodoin.id);
      expect(result.totalDistanceMeters, lessThan(result.originalDistanceMeters));
    });

    test('handles small and empty stop lists gracefully', () {
      expect(service.optimizeRoute([]).totalDistanceMeters, 0.0);

      final singleStop = [createMockStop(id: 's1', tripId: 't1', name: 'Spot', lat: 35.0, lng: 135.0)];
      final singleResult = service.optimizeRoute(singleStop);
      expect(singleResult.orderedStops.length, 1);
      expect(singleResult.totalDistanceMeters, 0.0);
    });

    test('2-Opt solver optimizes large tours (N > 8)', () {
      // Create 10 sequential stops placed deliberately out of order
      final largeTour = <Stop>[];
      for (var i = 0; i < 10; i++) {
        // Place in a circle: lat = 35.0 + sin, lng = 135.0 + cos
        final angle = (i * 36) * 3.14159 / 180.0;
        largeTour.add(createMockStop(
          id: 'stop_$i',
          tripId: 't1',
          name: 'Spot $i',
          lat: 35.0 + 0.01 * (i % 2 == 0 ? i : 10 - i), // zigzag latitudes
          lng: 135.0 + 0.01 * i,
        ));
      }

      final result = service.optimizeRoute(largeTour);
      expect(result.orderedStops.length, 10);
      expect(result.hasImprovement, isTrue);
      expect(result.totalDistanceMeters, lessThan(result.originalDistanceMeters));
    });

    test('applyOptimizedOrderToDay updates sortKey and transitMinutes in SQLite', () async {
      const tripId = 't_schedule_test';
      const dayId = 'day_${tripId}_1';
      await seedTripData(tripId);

      final stopsData = [keihanUji, ujiBridge, kumikoBench];
      for (final s in stopsData) {
        await db.into(db.stops).insert(StopsCompanion.insert(
              id: s.id,
              tripId: tripId,
              placeKey: 'p_${s.id}',
              name: s.name,
              lat: s.lat,
              lng: s.lng,
              addedBy: 'user_1',
            ));
      }

      // Insert schedule items in reverse order
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_3',
            tripId: tripId,
            dayId: dayId,
            stopId: kumikoBench.id,
            sortKey: 'a0',
          ));
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_2',
            tripId: tripId,
            dayId: dayId,
            stopId: ujiBridge.id,
            sortKey: 'a1',
          ));
      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: 'item_1',
            tripId: tripId,
            dayId: dayId,
            stopId: keihanUji.id,
            sortKey: 'a2',
          ));

      // Reorder to [keihanUji, ujiBridge, kumikoBench]
      await service.applyOptimizedOrderToDay(
        db: db,
        tripId: tripId,
        dayId: dayId,
        orderedStopIds: [keihanUji.id, ujiBridge.id, kumikoBench.id],
      );

      final reorderedItems = await (db.select(db.scheduleItems)
            ..where((tbl) => tbl.tripId.equals(tripId) & tbl.dayId.equals(dayId))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortKey)]))
          .get();

      expect(reorderedItems[0].stopId, keihanUji.id);
      expect(reorderedItems[0].transitMinutes, 0); // first stop has 0 transit

      expect(reorderedItems[1].stopId, ujiBridge.id);
      expect(reorderedItems[1].transitMinutes, greaterThan(0));

      expect(reorderedItems[2].stopId, kumikoBench.id);
      expect(reorderedItems[2].transitMinutes, greaterThan(0));

      for (final item in reorderedItems) {
        expect(item.syncStatus, 1);
      }
    });
  });

  group('Route Optimization Providers', () {
    test('dayOptimizedRouteProvider evaluates itinerary optimization', () async {
      const tripId = 't_provider_test';
      const dayId = 'day_${tripId}_1';
      await seedTripData(tripId);

      final stopsData = [keihanUji, daikichiyama, ujiBridge];
      for (var i = 0; i < stopsData.length; i++) {
        final s = stopsData[i];
        await db.into(db.stops).insert(StopsCompanion.insert(
              id: s.id,
              tripId: tripId,
              placeKey: 'p_${s.id}',
              name: s.name,
              lat: s.lat,
              lng: s.lng,
              addedBy: 'user_1',
            ));

        await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
              id: 'item_$i',
              tripId: tripId,
              dayId: dayId,
              stopId: s.id,
              sortKey: 'a$i',
            ));
      }

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(dayOptimizedRouteProvider((tripId: tripId, dayId: dayId)).future);
      expect(result, isNotNull);
      expect(result!.orderedStops.length, 3);
      expect(result.legs.length, 2);

      final clusters = await container.read(tripClustersProvider(tripId).future);
      expect(clusters, isNotEmpty);
      expect(clusters.first.stops.length, 3);
    });
  });
}
