import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/poi/models/proximity_event.dart';
import 'package:trip_planner/features/poi/providers/geofence_providers.dart';
import 'package:trip_planner/features/poi/services/pilgrimage_geofence_service.dart';
import 'package:trip_planner/features/poi/services/spatial_grid_index.dart';

void main() {
  Stop createMockStop({
    required String id,
    required String name,
    required double lat,
    required double lng,
    String? coverRemoteUrl,
  }) {
    return Stop(
      id: id,
      tripId: 't1',
      placeKey: 'p_$id',
      name: name,
      lat: lat,
      lng: lng,
      coverRemoteUrl: coverRemoteUrl,
      addedBy: 'user_1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: 0,
    );
  }

  // Kumiko Bench in Uji: 34.892500, 135.811111
  const kumikoBenchLat = 34.892500;
  const kumikoBenchLng = 135.811111;

  // Uji Bridge: 34.891667, 135.808611 (~240m away)
  const ujiBridgeLat = 34.891667;
  const ujiBridgeLng = 135.808611;

  group('SpatialGridIndex', () {
    test('retrieves near items in O(1) and excludes distant cities', () {
      final index = SpatialGridIndex<String>(cellSize: 0.005);

      // Insert Uji spot and Tokyo spot (~370 km away)
      index.insert(34.8925, 135.8111, 'kumiko_bench');
      index.insert(35.6585, 139.7454, 'tokyo_tower');

      // Query near Uji
      final ujiCandidates = index.queryCandidates(34.8926, 135.8112, radiusMeters: 100.0);
      expect(ujiCandidates.map((c) => c.item), contains('kumiko_bench'));
      expect(ujiCandidates.map((c) => c.item), isNot(contains('tokyo_tower')));

      // Query near Tokyo
      final tokyoCandidates = index.queryCandidates(35.6586, 139.7455, radiusMeters: 100.0);
      expect(tokyoCandidates.map((c) => c.item), contains('tokyo_tower'));
      expect(tokyoCandidates.map((c) => c.item), isNot(contains('kumiko_bench')));
    });
  });

  group('PilgrimageGeofenceService', () {
    late PilgrimageGeofenceService service;

    setUp(() {
      service = PilgrimageGeofenceService(
        config: const GeofenceConfig(
          enterRadiusMeters: 50.0,
          exitRadiusMeters: 75.0,
          cooldownDuration: Duration(minutes: 30),
        ),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('triggers enter event when user steps within enterRadius', () {
      final stop = createMockStop(
        id: 'stop_kumiko',
        name: '久美子長椅',
        lat: kumikoBenchLat,
        lng: kumikoBenchLng,
        coverRemoteUrl: 'https://image.anitabi.cn/cover.jpg',
      );
      service.registerStop(stop, animeName: '響け！ユーフォニアム');

      final capturedEvents = <ProximityEvent>[];
      service.eventStream.listen(capturedEvents.add, onError: (e) {});

      final now = DateTime(2026, 11, 7, 10, 0, 0);

      // 1. Far away (150m north: lat += 0.00135) -> no events
      final events1 = service.processLocationUpdate(
        kumikoBenchLat + 0.00135,
        kumikoBenchLng,
        timestamp: now,
      );
      expect(events1, isEmpty);
      expect(service.activeInsideStops, isEmpty);

      // 2. Step into 30m away (lat += 0.00027) -> triggers enter
      final events2 = service.processLocationUpdate(
        kumikoBenchLat + 0.00027,
        kumikoBenchLng,
        timestamp: now.add(const Duration(seconds: 10)),
      );
      expect(events2.length, 1);
      final event = events2.first;
      expect(event.isEnter, isTrue);
      expect(event.stopId, 'stop_kumiko');
      expect(event.stopName, '久美子長椅');
      expect(event.animeName, '響け！ユーフォニアム');
      expect(event.distanceMeters, lessThanOrEqualTo(50.0));
      expect(event.bearingCompass, isNotEmpty);
      expect(service.activeInsideStops.length, 1);
    });

    test('hysteresis buffer prevents alert spamming during GPS jitter at boundary', () {
      final stop = createMockStop(
        id: 'stop_kumiko',
        name: '久美子長椅',
        lat: kumikoBenchLat,
        lng: kumikoBenchLng,
      );
      service.registerStop(stop);

      final now = DateTime(2026, 11, 7, 10, 0, 0);

      // Enter spot (distance ~30m <= 50m)
      service.processLocationUpdate(
        kumikoBenchLat + 0.00027,
        kumikoBenchLng,
        timestamp: now,
      );
      expect(service.activeInsideStops.length, 1);

      // User pauses around the boundary: fluctuating between 55m and 65m (within 50m-75m buffer)
      // Because exit radius is 75m, this must NOT trigger exit!
      final jitterEvents = service.processLocationUpdate(
        kumikoBenchLat + 0.00054, // ~60m away
        kumikoBenchLng,
        timestamp: now.add(const Duration(seconds: 5)),
      );
      expect(jitterEvents, isEmpty);
      expect(service.activeInsideStops.length, 1);

      // Fluctuate back to 45m
      final jitterBack = service.processLocationUpdate(
        kumikoBenchLat + 0.00040,
        kumikoBenchLng,
        timestamp: now.add(const Duration(seconds: 10)),
      );
      expect(jitterBack, isEmpty);
      expect(service.activeInsideStops.length, 1);

      // Walk beyond exit radius (> 75m, lat += 0.00080 ≈ 88m) -> triggers exit
      final exitEvents = service.processLocationUpdate(
        kumikoBenchLat + 0.00080,
        kumikoBenchLng,
        timestamp: now.add(const Duration(seconds: 20)),
      );
      expect(exitEvents.length, 1);
      expect(exitEvents.first.isExit, isTrue);
      expect(exitEvents.first.stopId, 'stop_kumiko');
      expect(service.activeInsideStops, isEmpty);
    });

    test('cooldown suppresses immediate re-enter alerts within 30 minutes', () {
      final stop = createMockStop(
        id: 'stop_kumiko',
        name: '久美子長椅',
        lat: kumikoBenchLat,
        lng: kumikoBenchLng,
      );
      service.registerStop(stop);

      final t0 = DateTime(2026, 11, 7, 10, 0, 0);

      // 1. First enter at t0
      final enter1 = service.processLocationUpdate(
        kumikoBenchLat + 0.00020,
        kumikoBenchLng,
        timestamp: t0,
      );
      expect(enter1.length, 1);
      expect(enter1.first.isEnter, isTrue);

      // 2. Exit 2 minutes later
      final t1 = t0.add(const Duration(minutes: 2));
      final exit1 = service.processLocationUpdate(
        kumikoBenchLat + 0.00100,
        kumikoBenchLng,
        timestamp: t1,
      );
      expect(exit1.length, 1);
      expect(exit1.first.isExit, isTrue);

      // 3. User walks back 5 minutes later (t0 + 5m < 30m cooldown)
      // Enter alert must be suppressed!
      final t2 = t0.add(const Duration(minutes: 5));
      final enterSuppressed = service.processLocationUpdate(
        kumikoBenchLat + 0.00020,
        kumikoBenchLng,
        timestamp: t2,
      );
      expect(enterSuppressed, isEmpty, reason: 'within cooldown period');
      expect(service.activeInsideStops, isEmpty);

      // 4. User returns 35 minutes later (t0 + 35m > 30m cooldown)
      // Cooldown expired: should alert enter again!
      final t3 = t0.add(const Duration(minutes: 35));
      final enterAgain = service.processLocationUpdate(
        kumikoBenchLat + 0.00020,
        kumikoBenchLng,
        timestamp: t3,
      );
      expect(enterAgain.length, 1);
      expect(enterAgain.first.isEnter, isTrue);
      expect(service.activeInsideStops.length, 1);
    });

    test('handles multiple nearby spots and rapid movement/teleportation', () {
      final bench = createMockStop(
        id: 'stop_bench',
        name: '久美子長椅',
        lat: kumikoBenchLat,
        lng: kumikoBenchLng,
      );
      final bridge = createMockStop(
        id: 'stop_bridge',
        name: '宇治橋',
        lat: ujiBridgeLat,
        lng: ujiBridgeLng,
      );
      service.registerStops([bench, bridge]);

      final t0 = DateTime(2026, 11, 7, 10, 0, 0);

      // Stand at Kumiko Bench
      service.processLocationUpdate(kumikoBenchLat, kumikoBenchLng, timestamp: t0);
      expect(service.activeInsideStops.map((s) => s.stopId), contains('stop_bench'));
      expect(service.activeInsideStops.map((s) => s.stopId), isNot(contains('stop_bridge')));

      // Walk to Uji Bridge
      final t1 = t0.add(const Duration(minutes: 4));
      final bridgeEvents = service.processLocationUpdate(ujiBridgeLat, ujiBridgeLng, timestamp: t1);

      // Should exit bench and enter bridge
      expect(bridgeEvents.map((e) => e.eventType), containsAll([ProximityEventType.exit, ProximityEventType.enter]));
      expect(service.activeInsideStops.map((s) => s.stopId), contains('stop_bridge'));
      expect(service.activeInsideStops.map((s) => s.stopId), isNot(contains('stop_bench')));

      // Teleport far away (Kyoto Station ~14km away)
      final t2 = t1.add(const Duration(minutes: 15));
      final teleportEvents = service.processLocationUpdate(34.9858, 135.7583, timestamp: t2);
      expect(teleportEvents.length, 1);
      expect(teleportEvents.first.isExit, isTrue);
      expect(teleportEvents.first.stopId, 'stop_bridge');
      expect(service.activeInsideStops, isEmpty);
    });

    test('register and unregister stops dynamically', () {
      final bench = createMockStop(id: 's1', name: 'Spot 1', lat: 34.0, lng: 135.0);
      service.registerStop(bench);
      expect(service.trackedCount, 1);

      service.unregisterStop('s1');
      expect(service.trackedCount, 0);

      service.registerStops([bench]);
      expect(service.trackedCount, 1);

      service.clearStops();
      expect(service.trackedCount, 0);
    });
  });

  group('Geofence Riverpod Providers', () {
    test('proximityEventStreamProvider forwards proximity alerts', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(pilgrimageGeofenceServiceProvider);
      final bench = createMockStop(
        id: 'stop_bench',
        name: '久美子長椅',
        lat: kumikoBenchLat,
        lng: kumikoBenchLng,
      );
      service.registerStop(bench);

      final receivedEvents = <ProximityEvent>[];
      final sub = container.listen(
        proximityEventStreamProvider,
        (_, next) {
          next.whenData(receivedEvents.add);
        },
      );
      addTearDown(sub.close);

      // Process location update
      service.processLocationUpdate(
        kumikoBenchLat,
        kumikoBenchLng,
        timestamp: DateTime(2026, 11, 7, 12, 0, 0),
      );

      // Allow microtasks to propagate stream
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(receivedEvents.length, 1);
      expect(receivedEvents.first.stopName, '久美子長椅');
      expect(receivedEvents.first.isEnter, isTrue);

      final active = container.read(activeProximityStopsProvider);
      expect(active.length, 1);
      expect(active.first.stopId, 'stop_bench');
    });
  });
}
