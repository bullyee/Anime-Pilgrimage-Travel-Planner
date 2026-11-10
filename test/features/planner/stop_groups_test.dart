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
import 'package:trip_planner/features/planner/controllers/day_planner_controller.dart';
import 'package:trip_planner/features/planner/models/planner_view.dart';
import 'package:trip_planner/features/trip/controllers/trip_stops_controller.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/trip_screen.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue('u1'),
    ]);
    repo = container.read(tripRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  DayPlannerController planner() => container.read(dayPlannerControllerProvider.notifier);
  TripStopsController stops() => container.read(tripStopsControllerProvider.notifier);

  Future<PlannerView> view(String tripId) async => buildPlannerView(
        trip: (await repo.getTrip(tripId))!,
        days: await repo.getDaysForTrip(tripId),
        stops: await repo.getStopsForTrip(tripId),
        items: await repo.getScheduleItemsForTrip(tripId),
      );

  Future<Stop> spot(String tripId, String name, {String? area}) async {
    final s = await repo.createTripOnlySpot(tripId: tripId, name: name, lat: 34.9, lng: 135.8, addedBy: 'u1');
    if (area != null) await repo.setStopsArea([s.id], area);
    return s;
  }

  List<String> names(PlannerDay day) => [for (final it in day.items) it.stop.name];

  group('PlannerView blocks', () {
    test('a group\'s consecutive stops form one block; a lone one stays a stop', () async {
      final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 1);
      final day = (await repo.getDaysForTrip(trip.id)).single;
      for (final (name, area) in [('Gate', null), ('Rose 1', 'Cafe Rose'), ('Rose 2', 'Cafe Rose'), ('Bridge', null), ('Rose 3', 'Cafe Rose')]) {
        final s = await spot(trip.id, name, area: area);
        await repo.scheduleStop(tripId: trip.id, stopId: s.id, dayId: day.id, stayMinutes: 30, transitMinutes: 10);
      }

      final d = (await view(trip.id)).days.single;
      expect(names(d), ['Gate', 'Rose 1', 'Rose 2', 'Bridge', 'Rose 3'], reason: 'items stay flat');
      final blocks = d.blocks;
      expect(blocks.map((b) => b.items.length), [1, 2, 1, 1]);
      expect(blocks.map((b) => b.group), [null, 'Cafe Rose', null, null]);
      expect(blocks[3].first.group, 'Cafe Rose', reason: 'a lone stop of a group still knows its group');
      // 09:00 Gate (30 + 10), 09:40 Rose 1, 10:20 Rose 2 ending 10:50.
      expect(blocks[1].startMinutes, 9 * 60 + 40);
      expect(blocks[1].endMinutes, 10 * 60 + 50);
      expect(blocks[1].visited, 0);
    });

    test('the backlog shows a group\'s stops as one entry, by its name', () async {
      final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      final day = (await repo.getDaysForTrip(trip.id)).single;
      await spot(trip.id, 'Zoo');
      await spot(trip.id, 'Rose 1', area: 'Cafe Rose');
      await spot(trip.id, 'Rose 2', area: 'Cafe Rose');
      await spot(trip.id, 'Aquarium');
      await spot(trip.id, 'Lone', area: 'Station');
      final planned = await spot(trip.id, 'Planned', area: 'Station');
      await repo.scheduleStop(tripId: trip.id, stopId: planned.id, dayId: day.id);

      final entries = (await view(trip.id)).backlogEntries;
      expect(entries.map((e) => e.name), ['Aquarium', 'Cafe Rose', 'Lone', 'Zoo']);
      expect(entries[1].stops.map((s) => s.name), ['Rose 1', 'Rose 2']);
      expect(entries[2].isGroup, isFalse, reason: 'only one of its stops is in the backlog');
    });
  });

  group('grouping', () {
    late Trip trip;
    late List<TripDay> days;

    setUp(() async {
      trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 2);
      days = await repo.getDaysForTrip(trip.id);
    });

    test('grouping names the stops for sync and keeps them together on each day', () async {
      final a = await spot(trip.id, 'A');
      final x = await spot(trip.id, 'X');
      final b = await spot(trip.id, 'B');
      final y = await spot(trip.id, 'Y');
      final c = await spot(trip.id, 'C');
      for (final s in [a, x, b, y]) {
        await repo.scheduleStop(tripId: trip.id, stopId: s.id, dayId: days[0].id);
      }
      for (final s in [c, x, a]) {
        await repo.scheduleStop(tripId: trip.id, stopId: s.id, dayId: days[1].id);
      }
      // As if everything had synced.
      await db.update(db.stops).write(const StopsCompanion(syncStatus: Value(0), updatedBy: Value('someone')));

      final result = await stops().groupStops(tripId: trip.id, stopIds: [a.id, b.id, c.id], name: '  Cafe Rose ');
      expect(result, isA<Success<void>>());

      final all = await repo.getStopsForTrip(trip.id);
      final grouped = all.where((s) => s.area == 'Cafe Rose').map((s) => s.name).toSet();
      expect(grouped, {'A', 'B', 'C'});
      for (final s in all.where((s) => s.area != null)) {
        expect(s.syncStatus, 1);
        expect(s.updatedBy, 'u1');
      }
      final v = await view(trip.id);
      expect(names(v.days[0]), ['A', 'B', 'X', 'Y'], reason: 'B moves up to follow A');
      expect(names(v.days[1]), ['C', 'A', 'X'], reason: 'A follows C, the first of them');
      expect(v.days[0].blocks.first.group, 'Cafe Rose');
    });

    test('group names are checked', () async {
      final a = await spot(trip.id, 'A');
      final b = await spot(trip.id, 'B');
      expect(await stops().groupStops(tripId: trip.id, stopIds: [a.id, b.id], name: ' '), isA<Failure<void>>());
      expect(await stops().groupStops(tripId: trip.id, stopIds: [a.id, b.id], name: 'x' * 101), isA<Failure<void>>());
      expect(await stops().groupStops(tripId: trip.id, stopIds: [a.id], name: 'One'), isA<Failure<void>>());
    });

    test('ungrouping clears the group, renaming changes every stop', () async {
      final a = await spot(trip.id, 'A');
      final b = await spot(trip.id, 'B');
      final c = await spot(trip.id, 'C');
      await stops().groupStops(tripId: trip.id, stopIds: [a.id, b.id, c.id], name: 'Cafe Rose');

      await stops().renameGroup(tripId: trip.id, from: 'Cafe Rose', to: 'Rose Café');
      expect((await repo.getStopsForTrip(trip.id)).map((s) => s.area).toSet(), {'Rose Café'});

      // Taking one out leaves the other two grouped.
      await stops().ungroupStops(tripId: trip.id, stopIds: [c.id]);
      expect({for (final s in await repo.getStopsForTrip(trip.id)) s.name: s.area}, {'A': 'Rose Café', 'B': 'Rose Café', 'C': null});

      await stops().ungroup(tripId: trip.id, name: 'Rose Café');
      expect((await repo.getStopsForTrip(trip.id)).every((s) => s.area == null), isTrue);
    });

    test('a group left with one stop ends, and the rest close ranks', () async {
      final a = await spot(trip.id, 'A');
      final b = await spot(trip.id, 'B');
      final c = await spot(trip.id, 'C');
      final d = await spot(trip.id, 'D');
      await stops().groupStops(tripId: trip.id, stopIds: [a.id, b.id, c.id], name: 'Rose');
      for (final s in [a, b, c]) {
        await repo.scheduleStop(tripId: trip.id, stopId: s.id, dayId: days[0].id);
      }
      // B taken out of the middle: A and C come together again.
      await stops().ungroupStops(tripId: trip.id, stopIds: [b.id]);
      expect(names((await view(trip.id)).days[0]), ['A', 'C', 'B']);

      // Moving C into another group leaves A alone, which is no group.
      await stops().groupStops(tripId: trip.id, stopIds: [c.id, d.id], name: 'Station');
      expect({for (final s in await repo.getStopsForTrip(trip.id)) s.name: s.area},
          {'A': null, 'B': null, 'C': 'Station', 'D': 'Station'});
    });

    test('a group moves, goes to the backlog and back, and is scheduled together', () async {
      final a = await spot(trip.id, 'A', area: 'Rose');
      final b = await spot(trip.id, 'B', area: 'Rose');
      final x = await spot(trip.id, 'X');
      await repo.scheduleStop(tripId: trip.id, stopId: x.id, dayId: days[1].id);
      await planner().scheduleStops(tripId: trip.id, stopIds: [a.id, b.id], dayId: days[1].id, beforeItemId: (await repo.getScheduleItemsForDay(days[1].id)).single.id);
      var v = await view(trip.id);
      expect(names(v.days[1]), ['A', 'B', 'X']);

      final ids = [for (final it in v.days[1].blocks.first.items) it.item.id];
      await planner().moveItems(itemIds: ids, toDayId: days[0].id);
      v = await view(trip.id);
      expect(names(v.days[0]), ['A', 'B']);
      expect(names(v.days[1]), ['X']);

      await planner().unscheduleItems(ids);
      expect((await view(trip.id)).backlogEntries.single.group, 'Rose');
      await planner().restoreItems(ids);
      expect(names((await view(trip.id)).days[0]), ['A', 'B']);
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, String tripId, {TripTab tab = TripTab.plan}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/trips/$tripId', routes: [
        GoRoute(path: '/trips/:tripId', builder: (_, s) => TripScreen(tripId: s.pathParameters['tripId']!, initialTab: tab)),
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

    testWidgets('in the Stops tab, held stops are grouped into one row', (tester) async {
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      for (final name in ['Cafe Rose', 'Cafe Rose', 'Bridge']) {
        await r.createTripOnlySpot(tripId: trip.id, name: name, lat: 0, lng: 0, addedBy: 'u1');
      }
      await pump(tester, trip.id, tab: TripTab.stops);

      await tester.longPress(find.text('Cafe Rose').first);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Cafe Rose').last);
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Group'));
      await tester.pumpAndSettle();
      // Prefilled with the stops' common name.
      expect(tester.widget<TextField>(find.byKey(const Key('nameDialogField'))).controller!.text, 'Cafe Rose');
      await tester.tap(find.widgetWithText(FilledButton, 'Group'));
      await tester.pumpAndSettle();

      expect(find.text('2 stops'), findsOneWidget);
      expect(find.text('Cafe Rose'), findsOneWidget, reason: 'one row, closed');
      expect(find.text('Bridge'), findsOneWidget);
      await tester.tap(find.text('2 stops'));
      await tester.pumpAndSettle();
      expect(find.text('Cafe Rose'), findsNWidgets(3));
      await disposeApp(tester);
    });

    testWidgets('Plan shows a group as one closed block that opens', (tester) async {
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 1);
      final day = (await r.getDaysForTrip(trip.id)).single;
      for (final name in ['Rose 1', 'Rose 2', 'Rose 3']) {
        final s = await r.createTripOnlySpot(tripId: trip.id, name: name, lat: 0, lng: 0, addedBy: 'u1', area: 'Cafe Rose');
        await r.scheduleStop(tripId: trip.id, stopId: s.id, dayId: day.id, stayMinutes: 20);
      }
      await pump(tester, trip.id);

      expect(find.text('Cafe Rose'), findsOneWidget);
      expect(find.text('3 stops · 0 visited'), findsOneWidget);
      expect(find.text('–10:00'), findsOneWidget);
      expect(find.text('Rose 1'), findsNothing);
      await tester.tap(find.text('Cafe Rose'));
      await tester.pumpAndSettle();
      expect(find.text('Rose 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Mark as visited').first);
      await tester.pumpAndSettle();
      expect(find.text('3 stops · 1 visited'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('while editing, a group dragged to another day moves all of its stops', (tester) async {
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 4);
      final days = await r.getDaysForTrip(trip.id);
      for (final name in ['Rose 1', 'Rose 2']) {
        final s = await r.createTripOnlySpot(tripId: trip.id, name: name, lat: 0, lng: 0, addedBy: 'u1', area: 'Cafe Rose');
        await r.scheduleStop(tripId: trip.id, stopId: s.id, dayId: days[0].id);
      }
      await pump(tester, trip.id);
      await tester.tap(find.byTooltip('Edit the plan'));
      await tester.pumpAndSettle();

      // Hold the group at the right edge until the carousel has paged twice.
      final start = tester.getCenter(find.text('Cafe Rose'));
      final edge = tester.view.physicalSize.width / tester.view.devicePixelRatio - 4;
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.moveTo(Offset(edge, start.dy));
      for (var i = 0; i < 34; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('DAY 3'), findsOneWidget);
      await gesture.moveTo(Offset(edge / 2, start.dy));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final items = await r.getScheduleItemsForTrip(trip.id);
      expect(items.map((i) => i.dayId).toSet(), {days[2].id});
      await disposeApp(tester);
    });

    testWidgets('a group dropped on the backlog bar comes back with one Undo', (tester) async {
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 1);
      final day = (await r.getDaysForTrip(trip.id)).single;
      for (final name in ['Rose 1', 'Rose 2', 'Rose 3']) {
        final s = await r.createTripOnlySpot(tripId: trip.id, name: name, lat: 0, lng: 0, addedBy: 'u1', area: 'Cafe Rose');
        await r.scheduleStop(tripId: trip.id, stopId: s.id, dayId: day.id);
      }
      await pump(tester, trip.id);
      await tester.tap(find.byTooltip('Edit the plan'));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text('Cafe Rose')));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final bar = find.text('Drop here to move it to the backlog');
      expect(bar, findsOneWidget);
      await gesture.moveTo(tester.getCenter(bar));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(await r.getScheduleItemsForTrip(trip.id), isEmpty);
      expect(find.text('Moved Cafe Rose (3 stops) to the backlog.'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await r.getScheduleItemsForTrip(trip.id), hasLength(3));
      await disposeApp(tester);
    });
  });
}
