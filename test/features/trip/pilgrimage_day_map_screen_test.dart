import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/camera/services/anime_camera_launcher.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/pilgrimage_day_map_screen.dart';
import 'package:trip_planner/features/trip/screens/trip_screen.dart';

void main() {
  late AppDatabase db;
  late DriftTripRepository trips;

  setUp(() {
    debugAnimeCameraSupportedOverride = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trips = DriftTripRepository(db, null, 'u1');
  });

  tearDown(() {
    debugAnimeCameraSupportedOverride = null;
    return db.close();
  });

  Future<(Trip, List<TripDay>, List<Stop>)> setupTestTrip() async {
    // 1. Insert places
    await db.into(db.places).insert(PlacesCompanion.insert(
          placeKey: 'p1',
          name: 'Uji Bridge',
          lat: 34.8900,
          lng: 135.8000,
          visibility: const Value('saved'),
          source: const Value('Anitabi'),
        ));
    await db.into(db.places).insert(PlacesCompanion.insert(
          placeKey: 'p2',
          name: 'Byodoin Temple',
          lat: 34.8850,
          lng: 135.8100,
          visibility: const Value('saved'),
          source: const Value('Anitabi'),
        ));
    await db.into(db.places).insert(PlacesCompanion.insert(
          placeKey: 'p3',
          name: 'Kumiko Bench',
          lat: 34.8950,
          lng: 135.8200,
          visibility: const Value('saved'),
          source: const Value('Anitabi'),
        ));

    // 2. Create 2-day trip
    final trip = await trips.createTrip(title: 'Kyoto Pilgrimage', ownerId: 'u1', dayCount: 2);
    final days = await trips.getDaysForTrip(trip.id);
    final day1 = days[0];
    final day2 = days[1];

    // 3. Add stops
    final stop1 = await trips.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'u1');
    final stop2 = await trips.addPlaceToTrip(tripId: trip.id, placeKey: 'p2', addedBy: 'u1');
    final stop3 = await trips.addPlaceToTrip(tripId: trip.id, placeKey: 'p3', addedBy: 'u1');

    // 4. Schedule stops: Day 1 has stop1 (done) and stop2 (unvisited); Day 2 has stop3
    final item1 = await trips.scheduleStop(tripId: trip.id, stopId: stop1.id, dayId: day1.id, fixedTime: 9 * 60);
    await trips.updateScheduleItemStatus(itemId: item1.id, status: 'done');
    await trips.scheduleStop(tripId: trip.id, stopId: stop2.id, dayId: day1.id, fixedTime: 11 * 60);
    await trips.scheduleStop(tripId: trip.id, stopId: stop3.id, dayId: day2.id, fixedTime: 14 * 60);

    return (trip, days, [stop1, stop2, stop3]);
  }

  Future<void> pumpMapScreen(
    WidgetTester tester, {
    required String tripId,
    String? dayId,
    List<dynamic> extraOverrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/trips/$tripId/map${dayId != null ? '?day=$dayId' : ''}',
      routes: [
        GoRoute(
          path: '/trips/:tripId/map',
          builder: (_, s) => PilgrimageDayMapScreen(
            tripId: s.pathParameters['tripId']!,
            initialDayId: s.uri.queryParameters['day'],
          ),
        ),
        GoRoute(
          path: '/trips/:tripId/stops/:stopId',
          builder: (_, s) => Scaffold(body: Text('StopDetails:${s.pathParameters['stopId']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u1'),
          ...extraOverrides.cast(),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PilgrimageDayMapScreen', () {
    testWidgets('renders map with day stops and progress counter', (tester) async {
      final (trip, days, _) = await setupTestTrip();
      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      // Verify header progress: 1 of 2 visited · 1 left
      expect(find.text('Kyoto Pilgrimage'), findsOneWidget);
      expect(find.text('1 of 2 visited · 1 left'), findsOneWidget);

      // Verify day chips are rendered
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);

      // Verify stop markers exist (Stop 1 is marked done with check, Stop 2 has number '2')
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('tapping a stop pin opens bottom card with frame and actions', (tester) async {
      final (trip, days, _) = await setupTestTrip();
      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      // Tap stop 2 marker ('2')
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Bottom card opens with Byodoin Temple facts and action buttons
      expect(find.text('Byodoin Temple'), findsOneWidget);
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Mark visited'), findsOneWidget);
      expect(find.byTooltip('Stop details'), findsOneWidget);

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('tapping Mark visited updates schedule item and top progress', (tester) async {
      final (trip, days, _) = await setupTestTrip();
      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      // Tap stop 2 pin to show card
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Tap 'Mark visited'
      await tester.tap(find.text('Mark visited'));
      await tester.pumpAndSettle();

      // Verify progress updates to all visited
      expect(find.text('🎉 All 2 visited!'), findsOneWidget);
      expect(find.text('Visited'), findsWidgets);

      // Verify database reflects the change
      final scheduleItems = await (db.select(db.scheduleItems)..where((s) => s.tripId.equals(trip.id))).get();
      final doneItems = scheduleItems.where((s) => s.status == 'done').length;
      expect(doneItems, 2);

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('switching day chip updates active stops and progress', (tester) async {
      final (trip, days, _) = await setupTestTrip();
      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      expect(find.text('1 of 2 visited · 1 left'), findsOneWidget);

      // Tap 'Day 2' chip
      await tester.tap(find.text('Day 2'));
      await tester.pumpAndSettle();

      // Day 2 has 1 stop (Kumiko Bench, unvisited)
      expect(find.text('0 of 1 visited · 1 left'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('empty day displays friendly empty state card', (tester) async {
      final trip = await trips.createTrip(title: 'Empty Trip', ownerId: 'u1', dayCount: 1);
      final days = await trips.getDaysForTrip(trip.id);

      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      expect(find.text('No stops on this day'), findsOneWidget);
      expect(find.text('No stops'), findsOneWidget);

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('navigating to stop details works from bottom card', (tester) async {
      final (trip, days, stops) = await setupTestTrip();
      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      // Tap stop 2 marker
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Tap 'Stop details' icon button
      await tester.tap(find.byTooltip('Stop details'));
      await tester.pumpAndSettle();

      // Verify navigation to details route
      expect(find.text('StopDetails:${stops[1].id}'), findsOneWidget);

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('TripScreen app bar action navigates to PilgrimageDayMapScreen', (tester) async {
      final (trip, _, _) = await setupTestTrip();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final router = GoRouter(
        initialLocation: '/trips/${trip.id}',
        routes: [
          GoRoute(
            path: '/trips/:tripId',
            builder: (_, s) => TripScreen(tripId: s.pathParameters['tripId']!),
          ),
          GoRoute(
            path: '/trips/:tripId/map',
            builder: (_, s) => const Scaffold(body: Text('PilgrimageMapPageReached')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWithValue('u1'),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Tap pilgrimage map icon in app bar
      expect(find.byTooltip('Pilgrimage map'), findsOneWidget);
      await tester.tap(find.byTooltip('Pilgrimage map'));
      await tester.pumpAndSettle();

      expect(find.text('PilgrimageMapPageReached'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('viewer cannot mark visited (button hidden)', (tester) async {
      final (trip, days, _) = await setupTestTrip();
      await pumpMapScreen(
        tester,
        tripId: trip.id,
        dayId: days[0].id,
        extraOverrides: [
          canEditTripProvider(trip.id).overrideWithValue(false),
        ],
      );

      // Tap stop 2 marker
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Card is open with stop details, but Mark visited button is not present
      expect(find.text('Byodoin Temple'), findsOneWidget);
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Mark visited'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Take photo is hidden on unsupported platforms', (tester) async {
      debugAnimeCameraSupportedOverride = false;
      final (trip, days, _) = await setupTestTrip();
      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      // Tap stop 2 marker
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(find.text('Byodoin Temple'), findsOneWidget);
      expect(find.text('Take photo'), findsNothing);
      expect(find.text('Mark visited'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('swiping or tapping frame preview cycles current frame', (tester) async {
      final (trip, days, stops) = await setupTestTrip();
      // Insert 2 frames for stop 2 / place p2
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'ref1',
            placeKey: const Value('p2'),
            localPath: const Value('p2_frame1.jpg'),
          ));
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'ref2',
            placeKey: const Value('p2'),
            localPath: const Value('p2_frame2.jpg'),
          ));

      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      // Open stop 2
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Verify frame counter badge shows 1/2
      expect(find.text('1/2'), findsOneWidget);

      // Tap the frame preview to cycle to frame 2
      await tester.tap(find.text('1/2'));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);

      // Tap again to cycle back to frame 1
      await tester.tap(find.text('2/2'));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('offline frame missing local file shows snackbar instead of opening camera', (tester) async {
      final (trip, days, stops) = await setupTestTrip();
      // Insert frame with localPath pointing to non-existent local file
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'ref_offline',
            placeKey: const Value('p2'),
            localPath: const Value('/nonexistent/frame.jpg'),
          ));

      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      // Open stop 2
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Tap Take photo inside runAsync so real File.exists() completes
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Take photo'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify snackbar is shown
      expect(find.text("This frame isn't on this phone yet. Try again when you're online."), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('mark visited on joined trip without place row updates schedule item cleanly', (tester) async {
      // Create trip and stops where stop2 has placeKey 'external_p' that does NOT exist in db.places
      final trip = await trips.createTrip(title: 'Joined Trip', ownerId: 'other_user', dayCount: 1);
      final days = await trips.getDaysForTrip(trip.id);
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_remote_1',
            tripId: trip.id,
            placeKey: 'external_p1',
            name: 'Remote Spot 1',
            lat: 34.8900,
            lng: 135.8000,
            addedBy: 'other_user',
          ));
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: 'stop_remote_2',
            tripId: trip.id,
            placeKey: 'external_p2',
            name: 'Remote Spot 2',
            lat: 34.8850,
            lng: 135.8100,
            addedBy: 'other_user',
          ));
      await trips.scheduleStop(tripId: trip.id, stopId: 'stop_remote_1', dayId: days[0].id, fixedTime: 9 * 60);
      await trips.scheduleStop(tripId: trip.id, stopId: 'stop_remote_2', dayId: days[0].id, fixedTime: 11 * 60);

      await pumpMapScreen(
        tester,
        tripId: trip.id,
        dayId: days[0].id,
        extraOverrides: [
          canEditTripProvider(trip.id).overrideWithValue(true),
        ],
      );

      // Open remote spot 2 pin
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Tap Mark visited and pump for SnackBar
      await tester.tap(find.text('Mark visited'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Toast says "Marked visited for the trip." (not added to your visits)
      expect(find.text('Marked visited for the trip.'), findsOneWidget);

      // Verify schedule item is updated to done
      final item = await (db.select(db.scheduleItems)..where((s) => s.stopId.equals('stop_remote_2'))).getSingle();
      expect(item.status, 'done');

      // Verify no place_visits rows were inserted for external_p2
      final visits = await (db.select(db.placeVisits)..where((v) => v.placeKey.equals('external_p2'))).get();
      expect(visits, isEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('rapid double-tap on Mark visited is guarded against concurrent race conditions', (tester) async {
      final (trip, days, stops) = await setupTestTrip();
      await pumpMapScreen(tester, tripId: trip.id, dayId: days[0].id);

      // Select unvisited stop 2
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Rapid double-tap before the first async mutation settles
      await tester.tap(find.text('Mark visited'));
      await tester.tap(find.text('Mark visited'));
      await tester.pumpAndSettle();

      // Verify exactly one visit was recorded and item is done
      final item = await (db.select(db.scheduleItems)..where((s) => s.stopId.equals(stops[1].id))).getSingle();
      expect(item.status, 'done');
      final visits = await (db.select(db.placeVisits)..where((v) => v.placeKey.equals('p2'))).get();
      expect(visits.length, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
