import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/trip_screen.dart';
import 'package:trip_planner/features/trip/services/trip_route_export_service.dart';

void main() {
  late AppDatabase db;
  late DriftTripRepository repo;
  TripRouteExportResult? sharedResult;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftTripRepository(db, null, 'u1', DriftPlaceRepository(db));
    sharedResult = null;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester, String tripId) async {
    final router = GoRouter(
      initialLocation: '/trips/$tripId',
      routes: [
        GoRoute(
          path: '/trips/:tripId',
          builder: (_, s) => TripScreen(tripId: s.pathParameters['tripId']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u1'),
          shareRouteFileProvider.overrideWithValue((result) async {
            sharedResult = result;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('TripScreen shows Export route options in popup menu and triggers GPX export', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final trip = await repo.createTrip(title: 'Kyoto Trip', ownerId: 'u1', startDate: '2026-05-01', dayCount: 2);
    final days = await repo.getDaysForTrip(trip.id);
    final stop = await repo.createTripOnlySpot(
      tripId: trip.id,
      name: 'Fushimi Inari',
      lat: 34.967,
      lng: 135.772,
      addedBy: 'u1',
    );
    await repo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days.first.id, fixedTime: 540);

    await pumpScreen(tester, trip.id);

    // Open popup menu
    final menuButton = find.byType(PopupMenuButton<String>);
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Verify menu items
    expect(find.text('Export route (GPX)'), findsOneWidget);
    expect(find.text('Export route (GeoJSON)'), findsOneWidget);

    // Tap GPX export
    await tester.tap(find.text('Export route (GPX)'));
    await tester.pumpAndSettle();

    // Verify share was invoked
    expect(sharedResult, isNotNull);
    expect(sharedResult!.mimeType, 'application/gpx+xml');
    expect(sharedResult!.stopCount, 1);
    expect(sharedResult!.content, contains('Fushimi Inari'));

    // Verify SnackBar feedback
    expect(find.text('Exported 1 stop.'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('TripScreen exports GeoJSON route', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final trip = await repo.createTrip(title: 'Kyoto Geo Trip', ownerId: 'u1', startDate: '2026-05-01', dayCount: 1);
    final days = await repo.getDaysForTrip(trip.id);
    final stop = await repo.createTripOnlySpot(
      tripId: trip.id,
      name: 'Kiyomizu-dera',
      lat: 34.994,
      lng: 135.785,
      addedBy: 'u1',
    );
    await repo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days.first.id, fixedTime: 600);

    await pumpScreen(tester, trip.id);

    // Open popup menu
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    // Tap GeoJSON export
    await tester.tap(find.text('Export route (GeoJSON)'));
    await tester.pumpAndSettle();

    expect(sharedResult, isNotNull);
    expect(sharedResult!.mimeType, 'application/geo+json');
    expect(sharedResult!.stopCount, 1);
    expect(sharedResult!.content, contains('Kiyomizu-dera'));
    expect(find.text('Exported 1 stop.'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('shows warning when trip has no stops with coordinates', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final trip = await repo.createTrip(title: 'Empty Coords Trip', ownerId: 'u1', startDate: '2026-05-01', dayCount: 1);
    final days = await repo.getDaysForTrip(trip.id);
    final stop = await repo.createTripOnlySpot(
      tripId: trip.id,
      name: 'No Location Stop',
      lat: 0.0,
      lng: 0.0,
      addedBy: 'u1',
    );
    await repo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days.first.id);

    await pumpScreen(tester, trip.id);

    // Open popup menu and select GPX
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export route (GPX)'));
    await tester.pumpAndSettle();

    expect(sharedResult, isNull);
    expect(find.text('None of the stops in this trip have coordinates to export.'), findsOneWidget);

    await disposeApp(tester);
  });
}
