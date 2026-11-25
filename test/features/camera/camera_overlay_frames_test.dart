import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/core/providers/thumbnail_cache_provider.dart';
import 'package:trip_planner/core/services/thumbnail_cache_service.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/camera/providers/camera_provider.dart';
import 'package:trip_planner/features/camera/screens/camera_screen.dart';
import 'package:trip_planner/features/camera/services/anime_camera_launcher.dart'
    show debugAnimeCameraSupportedOverride, resolvePlaceReferenceFrames;
import 'package:trip_planner/features/camera/widgets/capture_sheets.dart' show spotFramesOnDevice;
import 'package:trip_planner/features/library/providers/place_providers.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/stop_screen.dart';
import 'package:trip_planner/shared/theme/app_theme.dart';

const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
const _tinyPngDataUrl = 'data:image/png;base64,$_tinyPngBase64';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late DriftPlaceRepository placeRepo;
  late DriftTripRepository tripRepo;
  late Directory tempDir;
  late ThumbnailCacheService cacheService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    placeRepo = DriftPlaceRepository(db);
    tripRepo = DriftTripRepository(db, null, 'u1', placeRepo);
    tempDir = Directory.systemTemp.createTempSync('cam_overlay_test_');
    cacheService = ThumbnailCacheService(overrideCacheDir: tempDir);
  });

  tearDown(() async {
    debugAnimeCameraSupportedOverride = null;
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seedCacheFile(String url) async {
    final file = await cacheService.getCacheFile(url);
    await file.writeAsBytes(base64Decode(_tinyPngBase64));
  }

  List<Override> baseOverrides() => [
        databaseProvider.overrideWithValue(db),
        placeRepositoryProvider.overrideWithValue(placeRepo),
        tripRepositoryProvider.overrideWithValue(tripRepo),
        thumbnailCacheServiceProvider.overrideWithValue(cacheService),
        currentUserIdProvider.overrideWithValue('u1'),
      ];

  testWidgets('spotFramesOnDevice resolves stop-scoped frames, tripId lookup, and deduplication', (tester) async {
    const sharedUrl = 'https://example.com/shared_stop_frame.jpg';
    const stopExtraUrl = 'https://example.com/extra_stop_frame.jpg';
    const dupDataUrl = _tinyPngDataUrl;

    await tester.runAsync(() async {
      // Shared stop whose place is NOT in the personal library, plus another stop with both place and stop frames.
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'p_both',
              name: 'Place With Frames',
              lat: 34.89,
              lng: 135.80,
              visibility: const Value('saved'),
            ),
          );
      final trip = await tripRepo.createTrip(title: 'Uji Trip', ownerId: 'u1', dayCount: 1);

      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_only',
              tripId: trip.id,
              placeKey: 'unlisted_place',
              name: 'Shared Only Stop',
              lat: 34.90,
              lng: 135.81,
              addedBy: 'aki',
            ),
          );
      await seedCacheFile(sharedUrl);
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'rf_stop_only',
              stopId: const Value('stop_only'),
              remoteUrl: const Value(sharedUrl),
            ),
          );

      final mixedStop = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'p_both', addedBy: 'u1');
      await seedCacheFile(stopExtraUrl);
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'rf_place_1',
              placeKey: const Value('p_both'),
              localPath: const Value(dupDataUrl),
            ),
          );
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'rf_stop_dup',
              stopId: Value(mixedStop.id),
              localPath: const Value(dupDataUrl),
            ),
          );
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'rf_stop_extra',
              stopId: Value(mixedStop.id),
              remoteUrl: const Value(stopExtraUrl),
            ),
          );
    });

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: Consumer(
          builder: (_, ref, _) {
            capturedRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );

    await tester.runAsync(() async {
      final trip = (await tripRepo.getTrips()).single;
      final stops = await tripRepo.getStopsForTrip(trip.id);
      final mixedStop = stops.firstWhere((s) => s.placeKey == 'p_both');

      // 1. Stop-scoped remoteUrl frame is found via stopId even though unlisted_place isn't in places table.
      final sharedFrames = await spotFramesOnDevice(
        capturedRef,
        placeKey: 'unlisted_place',
        stopId: 'stop_only',
        tripId: trip.id,
      );
      expect(sharedFrames.map((f) => f.id).toList(), ['rf_stop_only']);

      // 2. Omitting stopId resolves stop from (tripId, placeKey) and finds the stop-scoped frame.
      final resolvedByTrip = await spotFramesOnDevice(
        capturedRef,
        placeKey: 'unlisted_place',
        tripId: trip.id,
      );
      expect(resolvedByTrip.map((f) => f.id).toList(), ['rf_stop_only']);

      // 3. Place + stop frames merge place-first and deduplicate matching paths/URLs.
      final merged = await spotFramesOnDevice(
        capturedRef,
        placeKey: 'p_both',
        stopId: mixedStop.id,
        tripId: trip.id,
      );
      expect(merged.map((f) => f.id).toList(), ['rf_place_1', 'rf_stop_extra']);
    });
  });

  testWidgets('CameraScreen loads stop-scoped frame into cameraProvider even when placeKey has no place frames',
      (tester) async {
    final trip = await tripRepo.createTrip(title: 'Shared Trip', ownerId: 'u1', dayCount: 1);
    await db.into(db.stops).insert(
          StopsCompanion.insert(
            id: 'stop_shared',
            tripId: trip.id,
            placeKey: 'other_place',
            name: 'Shared Spot',
            lat: 34.90,
            lng: 135.81,
            addedBy: 'aki',
          ),
        );
    await db.into(db.newReferenceImages).insert(
          NewReferenceImagesCompanion.insert(
            id: 'rf_shared',
            stopId: const Value('stop_shared'),
            localPath: const Value(_tinyPngDataUrl),
          ),
        );

    final container = ProviderContainer(overrides: baseOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: CameraScreen(
            placeKey: 'other_place',
            tripId: trip.id,
            stopId: 'stop_shared',
            frameId: 'rf_shared',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final camState = container.read(cameraProvider);
    expect(camState.referenceImageId, 'rf_shared');
    expect(camState.effectiveReferencePath, _tinyPngDataUrl);
  });

  testWidgets('CameraScreen defaults to first frame when frameId is omitted', (tester) async {
    final trip = await tripRepo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
    await db.into(db.stops).insert(
          StopsCompanion.insert(
            id: 'stop1',
            tripId: trip.id,
            placeKey: 'p1',
            name: 'Stop 1',
            lat: 34.9,
            lng: 135.8,
            addedBy: 'u1',
          ),
        );
    await db.into(db.newReferenceImages).insert(
          NewReferenceImagesCompanion.insert(
            id: 'rf_first',
            stopId: const Value('stop1'),
            localPath: const Value(_tinyPngDataUrl),
          ),
        );

    final container = ProviderContainer(overrides: baseOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: CameraScreen(placeKey: 'p1', tripId: trip.id, stopId: 'stop1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(cameraProvider).referenceImageId, 'rf_first');
    expect(container.read(cameraProvider).effectiveReferencePath, _tinyPngDataUrl);
  });

  testWidgets('CameraScreen falls back to direct frameId lookup across places', (tester) async {
    await db.into(db.places).insert(
          PlacesCompanion.insert(
            placeKey: 'different_place',
            name: 'Other Place',
            lat: 35.0,
            lng: 135.7,
            visibility: const Value('saved'),
          ),
        );
    await db.into(db.newReferenceImages).insert(
          NewReferenceImagesCompanion.insert(
            id: 'rf_orphan',
            placeKey: const Value('different_place'),
            localPath: const Value(_tinyPngDataUrl),
          ),
        );

    final container = ProviderContainer(overrides: baseOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const CameraScreen(frameId: 'rf_orphan'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(cameraProvider).referenceImageId, 'rf_orphan');
    expect(container.read(cameraProvider).effectiveReferencePath, _tinyPngDataUrl);
  });

  testWidgets('StopScreen Take photo forwards stopId and frameId to /camera route', (tester) async {
    debugAnimeCameraSupportedOverride = true;
    final trip = await tripRepo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
    await db.into(db.stops).insert(
          StopsCompanion.insert(
            id: 'stop_nav',
            tripId: trip.id,
            placeKey: 'shared_pk',
            name: 'Byodoin',
            lat: 34.889,
            lng: 135.807,
            addedBy: 'aki',
          ),
        );
    await db.into(db.newReferenceImages).insert(
          NewReferenceImagesCompanion.insert(
            id: 'rf_nav',
            stopId: const Value('stop_nav'),
            localPath: const Value(_tinyPngDataUrl),
          ),
        );

    Uri? pushedCameraUri;
    final router = GoRouter(
      initialLocation: '/trips/${trip.id}/stops/stop_nav',
      routes: [
        GoRoute(
          path: '/trips/:tripId/stops/:stopId',
          builder: (_, s) => StopScreen(
            tripId: s.pathParameters['tripId']!,
            stopId: s.pathParameters['stopId']!,
          ),
        ),
        GoRoute(
          path: '/camera',
          builder: (_, s) {
            pushedCameraUri = s.uri;
            return CameraScreen(
              placeKey: s.uri.queryParameters['place'],
              tripId: s.uri.queryParameters['trip'],
              stopId: s.uri.queryParameters['stop'],
              frameId: s.uri.queryParameters['frame'],
            );
          },
        ),
      ],
    );

    final container = ProviderContainer(overrides: baseOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(pushedCameraUri?.path, '/camera');
    expect(pushedCameraUri?.queryParameters['place'], 'shared_pk');
    expect(pushedCameraUri?.queryParameters['trip'], trip.id);
    expect(pushedCameraUri?.queryParameters['stop'], 'stop_nav');
    expect(pushedCameraUri?.queryParameters['frame'], 'rf_nav');
    expect(container.read(cameraProvider).referenceImageId, 'rf_nav');
    expect(container.read(cameraProvider).effectiveReferencePath, _tinyPngDataUrl);
  });

  testWidgets('resolvePlaceReferenceFrames resolves cached link-only frame without throwing on null localPath',
      (tester) async {
    const cachedUrl = 'https://example.com/cached_anitabi.jpg';
    late String expectedCachedPath;

    await tester.runAsync(() async {
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'p_cached',
              name: 'Cached Spot',
              lat: 34.89,
              lng: 135.80,
              visibility: const Value('saved'),
            ),
          );
      await seedCacheFile(cachedUrl);
      expectedCachedPath = (await cacheService.getCacheFile(cachedUrl)).path;
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'rf_local',
              placeKey: const Value('p_cached'),
              localPath: const Value(_tinyPngDataUrl),
              createdAt: Value(DateTime(2026, 1, 1)),
            ),
          );
      await db.into(db.newReferenceImages).insert(
            NewReferenceImagesCompanion.insert(
              id: 'rf_cached_link',
              placeKey: const Value('p_cached'),
              remoteUrl: const Value(cachedUrl),
              createdAt: Value(DateTime(2026, 1, 2)),
            ),
          );
    });

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: Consumer(
          builder: (_, ref, _) {
            capturedRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );

    await tester.runAsync(() async {
      final picked = (await placeRepo.getReferenceImage('rf_cached_link'))!;
      final resolved = await resolvePlaceReferenceFrames(
        capturedRef,
        placeKey: 'p_cached',
        picked: picked,
      );
      expect(resolved, isNotNull);
      expect(resolved!.index, 1);
      expect(
        resolved.frames.map((s) => (s.imageId, s.path)).toList(),
        [
          ('rf_local', _tinyPngDataUrl),
          ('rf_cached_link', expectedCachedPath),
        ],
      );
    });
  });
}
