import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/core/utils/app_result.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/trip/controllers/trip_stops_controller.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/providers/trip_stop_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/library_picker_screen.dart';
import 'package:trip_planner/features/trip/screens/trip_stops_tab.dart';

Future<void> _savePlace(AppDatabase db, String key, String name) => db.into(db.places).insert(
      PlacesCompanion.insert(placeKey: key, name: name, lat: 34.89, lng: 135.80, visibility: const Value('saved')),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('TripStopsController', () {
    late ProviderContainer container;
    late TripRepository repo;
    late Trip trip;

    setUp(() async {
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u1'),
      ]);
      repo = container.read(tripRepositoryProvider);
      trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 2);
    });
    tearDown(() => container.dispose());

    TripStopsController controller() => container.read(tripStopsControllerProvider.notifier);

    test('library places become stops, and ones already in the trip are skipped', () async {
      await _savePlace(db, 'anitabi:1', '宇治橋');
      await _savePlace(db, 'anitabi:2', '朝霧橋');

      final first = await controller().addFromLibrary(tripId: trip.id, placeKeys: ['anitabi:1']);
      expect((first as Success<int>).value, 1);
      final second = await controller().addFromLibrary(tripId: trip.id, placeKeys: ['anitabi:1', 'anitabi:2']);
      expect((second as Success<int>).value, 1);

      final stops = await repo.getStopsForTrip(trip.id);
      expect(stops.map((s) => s.placeKey).toSet(), {'anitabi:1', 'anitabi:2'});
      expect(stops.every((s) => s.addedBy == 'u1'), isTrue);
    });

    test('a place picked again becomes a second stop of the trip', () async {
      await _savePlace(db, 'anitabi:1', '宇治橋');
      await controller().addFromLibrary(tripId: trip.id, placeKeys: ['anitabi:1']);
      final again = await controller().addFromLibrary(tripId: trip.id, placeKeys: ['anitabi:1'], repeat: true);
      expect((again as Success<int>).value, 1);
      final stops = await repo.getStopsForTrip(trip.id);
      expect(stops.map((s) => s.placeKey), ['anitabi:1', 'anitabi:1']);
      expect(stops.map((s) => s.id).toSet(), hasLength(2), reason: 'two stops, each with its own plan');
      expect(stops.map((s) => s.name).toSet(), {'宇治橋', '宇治橋 (2)'}, reason: 'a name of its own to tell them apart');

      // A third one takes the next number, or the name it is given.
      await controller().addFromLibrary(tripId: trip.id, placeKeys: ['anitabi:1'], repeat: true);
      await controller().addFromLibrary(tripId: trip.id, placeKeys: ['anitabi:1'], repeat: true, names: {'anitabi:1': '宇治橋 (night)'});
      expect((await repo.getStopsForTrip(trip.id)).map((s) => s.name).toSet(), {'宇治橋', '宇治橋 (2)', '宇治橋 (3)', '宇治橋 (night)'});
    });

    test('a stop is renamed in its trip without touching the library place', () async {
      await _savePlace(db, 'anitabi:1', '宇治橋');
      await controller().addFromLibrary(tripId: trip.id, placeKeys: ['anitabi:1']);
      final stop = (await repo.getStopsForTrip(trip.id)).single;
      expect(await controller().renameStop(stop.id, '  '), isA<Failure<void>>());
      await controller().renameStop(stop.id, '宇治橋 (dusk)');
      expect((await repo.getStop(stop.id))!.name, '宇治橋 (dusk)');
      final place = await (db.select(db.places)..where((p) => p.placeKey.equals('anitabi:1'))).getSingle();
      expect(place.name, '宇治橋');
    });

    test('a new spot needs a name and is kept out of the library', () async {
      expect(await controller().createSpot(tripId: trip.id, name: ' ', lat: 1, lng: 2), isA<Failure<Stop>>());

      final result = await controller().createSpot(
        tripId: trip.id,
        name: ' Hotel ',
        lat: 35.0,
        lng: 135.75,
        address: '  ',
        description: 'Check-in from 15:00',
      );
      final stop = (result as Success<Stop>).value;
      expect(stop.name, 'Hotel');
      expect(stop.address, isNull);
      expect(stop.description, 'Check-in from 15:00');
      final place = await (db.select(db.places)..where((p) => p.placeKey.equals(stop.placeKey))).getSingle();
      expect(place.visibility, 'trip_only');
    });

    test('removing a stop also takes it off its day', () async {
      final stop = ((await controller().createSpot(tripId: trip.id, name: 'Spot', lat: 1, lng: 2)) as Success<Stop>).value;
      final day = (await repo.getDaysForTrip(trip.id)).first;
      await repo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: day.id);

      expect(await controller().removeStop(stop.id), isA<Success<void>>());
      expect(await repo.getStopsForTrip(trip.id), isEmpty);
      expect(await repo.getScheduleItemsForDay(day.id), isEmpty);
    });
  });

  group('buildStopEntries', () {
    Stop stop(String id, String name) => Stop(
          id: id,
          tripId: 't',
          placeKey: id,
          name: name,
          lat: 0,
          lng: 0,
          addedBy: 'u1',
          createdAt: DateTime(2027),
          updatedAt: DateTime(2027),
          syncStatus: 0,
        );
    TripDay day(String id, String key) => TripDay(id: id, tripId: 't', sortKey: key, updatedAt: DateTime(2027), syncStatus: 0);
    ScheduleItem item(String stopId, String dayId, String key, {int stay = 60, String status = 'planned'}) => ScheduleItem(
          id: 'i-$stopId',
          tripId: 't',
          stopId: stopId,
          dayId: dayId,
          sortKey: key,
          stayMinutes: stay,
          transitMinutes: 0,
          status: status,
          updatedAt: DateTime(2027),
          syncStatus: 0,
        );

    test('planned stops come first by day and time, then the rest by name', () {
      final entries = buildStopEntries(
        stops: [stop('a', 'Zoo'), stop('b', 'Bridge'), stop('c', 'Café'), stop('d', 'Aquarium'), stop('e', 'Skipped')],
        days: [day('d2', 'a1'), day('d1', 'a0'), day('backup', 'a2')],
        items: [
          item('b', 'd2', 'a0'),
          item('c', 'd1', 'a1'),
          item('a', 'd1', 'a0', stay: 90),
          item('d', 'backup', 'a0'),
          item('e', 'd1', 'a2', status: 'skipped'),
        ],
        dayCount: 2,
      );
      expect(entries.map((e) => e.stop.name), ['Zoo', 'Café', 'Bridge', 'Aquarium', 'Skipped']);
      expect(stopWhenLine(entries[0]), 'Day 1 · 09:00');
      expect(stopWhenLine(entries[1]), 'Day 1 · 10:30');
      expect(stopWhenLine(entries[2]), 'Day 2 · 09:00');
      expect(stopWhenLine(entries[3]), 'Backup day · 09:00');
      expect(stopWhenLine(entries[4]), 'Not on a day yet');
    });

    test('the list can be ordered by name or by when stops were added', () {
      Stop added(String id, String name, int day) => stop(id, name).copyWith(createdAt: DateTime(2027, 1, day));
      final planOrder = [
        TripStopEntry(stop: added('a', 'zoo', 1), dayIndex: 0),
        TripStopEntry(stop: added('b', 'Bridge', 3)),
        TripStopEntry(stop: added('c', 'aquarium', 2)),
      ];
      List<String> names(StopOrder order) => [for (final e in orderStopEntries(planOrder, order)) e.stop.name];

      expect(names(StopOrder.plan), ['zoo', 'Bridge', 'aquarium']);
      expect(names(StopOrder.name), ['aquarium', 'Bridge', 'zoo'], reason: 'letter case aside');
      expect(names(StopOrder.added), ['Bridge', 'aquarium', 'zoo'], reason: 'the newest first');
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, String location) async {
      final router = GoRouter(initialLocation: location, routes: [
        GoRoute(path: '/trips/:tripId/stops', builder: (_, s) => Scaffold(body: TripStopsTab(tripId: s.pathParameters['tripId']!))),
        GoRoute(path: '/trips/:tripId/stops/add', builder: (_, s) => LibraryPickerScreen(tripId: s.pathParameters['tripId']!)),
        GoRoute(path: '/trips/:tripId/stops/new', builder: (_, _) => const Scaffold(body: Text('new spot'))),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('u1')],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> disposeApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('an empty trip offers both ways to add stops', (tester) async {
      final trip = await DriftTripRepository(db).createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      await pump(tester, '/trips/${trip.id}/stops');
      expect(find.text('No stops yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Add stops'));
      await tester.pumpAndSettle();
      expect(find.text('From my library'), findsOneWidget);
      await tester.tap(find.text('New spot'));
      await tester.pumpAndSettle();
      expect(find.text('new spot'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('picking library places adds them to the trip', (tester) async {
      final repo = DriftTripRepository(db);
      final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      await _savePlace(db, 'anitabi:1', '宇治橋');
      await _savePlace(db, 'anitabi:2', '朝霧橋');
      await pump(tester, '/trips/${trip.id}/stops/add');

      await tester.tap(find.text('宇治橋'));
      await tester.pump();
      await tester.tap(find.text('Add 1 stop'));
      await tester.pumpAndSettle();

      final stops = await repo.getStopsForTrip(trip.id);
      expect(stops.single.name, '宇治橋');
      await disposeApp(tester);
    });

    testWidgets('the stop list shows where each stop is planned', (tester) async {
      final repo = DriftTripRepository(db);
      final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      final day = (await repo.getDaysForTrip(trip.id)).single;
      final bridge = await repo.createTripOnlySpot(tripId: trip.id, name: '宇治橋', lat: 0, lng: 0, addedBy: 'u1');
      await repo.createTripOnlySpot(tripId: trip.id, name: '朝霧橋', lat: 0, lng: 0, addedBy: 'u1');
      await repo.scheduleStop(tripId: trip.id, stopId: bridge.id, dayId: day.id, fixedTime: 9 * 60 + 30);

      await pump(tester, '/trips/${trip.id}/stops');
      expect(find.text('Day 1 · 09:30'), findsOneWidget);
      expect(find.text('Not on a day yet'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('the sort menu orders the stops by name', (tester) async {
      final repo = DriftTripRepository(db);
      final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      final day = (await repo.getDaysForTrip(trip.id)).single;
      final zoo = await repo.createTripOnlySpot(tripId: trip.id, name: 'Zoo', lat: 0, lng: 0, addedBy: 'u1');
      await repo.createTripOnlySpot(tripId: trip.id, name: 'Aquarium', lat: 0, lng: 0, addedBy: 'u1');
      await repo.scheduleStop(tripId: trip.id, stopId: zoo.id, dayId: day.id, fixedTime: 9 * 60);

      await pump(tester, '/trips/${trip.id}/stops');
      double top(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(top('Zoo'), lessThan(top('Aquarium')), reason: 'planned first');

      await tester.tap(find.byTooltip('Sort stops'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(top('Aquarium'), lessThan(top('Zoo')));
      await disposeApp(tester);
    });
  });
}
