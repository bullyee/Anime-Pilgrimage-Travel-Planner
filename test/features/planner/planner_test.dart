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
import 'package:trip_planner/features/planner/widgets/planner_sheets.dart';
import 'package:trip_planner/features/trip/controllers/trips_controller.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/trip_screen.dart';

DateTime _utc(int y, int m, int d) => DateTime.utc(y, m, d);

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

  DayPlannerController controller() => container.read(dayPlannerControllerProvider.notifier);

  Future<PlannerView> view(String tripId) async => buildPlannerView(
        trip: (await repo.getTrip(tripId))!,
        days: await repo.getDaysForTrip(tripId),
        stops: await repo.getStopsForTrip(tripId),
        items: await repo.getScheduleItemsForTrip(tripId),
      );

  Future<Stop> spot(String tripId, String name) =>
      repo.createTripOnlySpot(tripId: tripId, name: name, lat: 34.9, lng: 135.8, addedBy: 'u1');

  List<String> names(PlannerDay day) => [for (final it in day.items) it.stop.name];

  group('PlannerView', () {
    test('dates, backup days, times and the backlog', () async {
      final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 2);
      await repo.addDayBlock(trip.id); // a backup day
      final days = await repo.getDaysForTrip(trip.id);
      await repo.pinDayBlockDate(days[1].id, '2027-05-03');
      final bridge = await spot(trip.id, 'Bridge');
      final shrine = await spot(trip.id, 'Shrine');
      await spot(trip.id, 'Tower');
      final skipped = await spot(trip.id, 'Skipped');
      await repo.scheduleStop(tripId: trip.id, stopId: bridge.id, dayId: days[0].id, stayMinutes: 30, transitMinutes: 10, fixedTime: 9 * 60 + 30);
      await repo.scheduleStop(tripId: trip.id, stopId: shrine.id, dayId: days[0].id);
      final s = await repo.scheduleStop(tripId: trip.id, stopId: skipped.id, dayId: days[0].id);
      await repo.updateScheduleItemStatus(itemId: s.id, status: 'skipped');

      final v = await view(trip.id);
      expect(v.days.map((d) => d.date), [_utc(2027, 4, 29), _utc(2027, 5, 3), null]);
      expect(v.days.map((d) => d.isBackup), [false, false, true]);
      expect(v.days.map((d) => d.freeDaysBefore), [0, 3, 0]); // Apr 30 – May 2
      expect(names(v.days[0]), ['Bridge', 'Shrine']);
      expect(v.days[0].items.map((i) => i.startMinutes), [570, 610]);
      expect(v.days[0].items.first.fixed, isTrue);
      expect(v.backlog.map((s) => s.name), ['Skipped', 'Tower']);
      expect(v.nextDayDate, _utc(2027, 5, 4));
    });

    test('a pin may fall after the day before it and early enough for the next pinned day', () async {
      final trip = await repo.createTrip(title: 'Golden Week', ownerId: 'u1', startDate: '2027-04-29', dayCount: 4);
      final days = await repo.getDaysForTrip(trip.id);
      await repo.pinDayBlockDate(days[3].id, '2027-05-05');
      final v = await view(trip.id);

      final second = v.pinRangeFor(v.days[1]);
      expect(second.min, _utc(2027, 4, 30));
      expect(second.max, _utc(2027, 5, 3)); // Day 3 needs May 4
      expect(second.nextPinned, v.days[3]);
      expect(second.allows(DateTime(2027, 5, 3)), isTrue);
      expect(second.allows(DateTime(2027, 5, 4)), isFalse);

      final last = v.pinRangeFor(v.days[3]);
      expect(last.min, _utc(2027, 5, 2));
      expect(last.max, isNull);
    });
  });

  group('DayPlannerController', () {
    late Trip trip;
    late List<TripDay> days;

    setUp(() async {
      trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 2);
      days = await repo.getDaysForTrip(trip.id);
    });

    test('stops go where they are dropped, within and across days', () async {
      final a = await spot(trip.id, 'A');
      final b = await spot(trip.id, 'B');
      final c = await spot(trip.id, 'C');
      expect(await controller().scheduleStop(tripId: trip.id, stopId: a.id, dayId: days[0].id), isA<Success<void>>());
      await controller().scheduleStop(tripId: trip.id, stopId: b.id, dayId: days[0].id);
      var v = await view(trip.id);
      final aItem = v.days[0].items.first.item;
      // C goes before A; then B moves to day 2.
      await controller().scheduleStop(tripId: trip.id, stopId: c.id, dayId: days[0].id, beforeItemId: aItem.id);
      v = await view(trip.id);
      expect(names(v.days[0]), ['C', 'A', 'B']);
      final bItem = v.days[0].items.last.item;
      await controller().moveItem(itemId: bItem.id, toDayId: days[1].id);
      // A moves to the end of its own day.
      await controller().moveItem(itemId: aItem.id, toDayId: days[0].id);
      v = await view(trip.id);
      expect(names(v.days[0]), ['C', 'A']);
      expect(names(v.days[1]), ['B']);
      await controller().moveItem(itemId: aItem.id, toDayId: days[0].id, beforeItemId: v.days[0].items.first.item.id);
      v = await view(trip.id);
      expect(names(v.days[0]), ['A', 'C']);
    });

    test('a stop moved to the backlog can be put back', () async {
      final a = await spot(trip.id, 'A');
      await controller().scheduleStop(tripId: trip.id, stopId: a.id, dayId: days[0].id);
      final item = (await view(trip.id)).days[0].items.single.item;
      await controller().unschedule(item.id);
      expect((await view(trip.id)).backlog.map((s) => s.name), ['A']);
      await controller().restoreItem(item.id);
      expect(names((await view(trip.id)).days[0]), ['A']);
    });

    test('stay and visited are saved', () async {
      final a = await spot(trip.id, 'A');
      await controller().scheduleStop(tripId: trip.id, stopId: a.id, dayId: days[0].id);
      final item = (await view(trip.id)).days[0].items.single.item;
      await controller().setStay(item.id, 25);
      await controller().setVisited(item.id, true);
      final it = (await view(trip.id)).days[0].items.single;
      expect(it.item.stayMinutes, 25);
      expect(it.done, isTrue);
    });

    test('travel times and fixed start times shape the day', () async {
      for (final name in ['A', 'B', 'C']) {
        final s = await spot(trip.id, name);
        await controller().scheduleStop(tripId: trip.id, stopId: s.id, dayId: days[0].id);
      }
      var v = await view(trip.id);
      final [a, b, c] = v.days[0].items.map((it) => it.item.id).toList();

      await controller().setTransit(a, 15);
      await controller().setFixedTime(c, 14 * 60);
      v = await view(trip.id);
      expect(v.days[0].items.map((it) => it.startMinutes), [540, 615, 840]); // 09:00, 10:15, 14:00
      expect(v.days[0].items.last.fixed, isTrue);

      // B fixed at 09:30 starts before A is done and the walk is over.
      await controller().setFixedTime(b, 9 * 60 + 30);
      v = await view(trip.id);
      expect(v.days[0].items[1].conflict, isTrue);

      await controller().setFixedTime(b, null);
      v = await view(trip.id);
      expect(v.days[0].items[1].startMinutes, 615);
      expect(v.days[0].items[1].fixed, isFalse);
      expect(await controller().setTransit(a, -5), isA<Failure<void>>());
    });

    test('a time in the small hours after an evening stop runs past midnight', () {
      expect(startMinutesFor(90, after: 22 * 60), 25 * 60 + 30); // 01:30 → 25:30
      expect(startMinutesFor(90, after: 9 * 60), 90);
      expect(startMinutesFor(7 * 60, after: 23 * 60), 7 * 60);
    });

    test('a new day goes before the backup days and makes the trip longer', () async {
      final backup = ((await controller().addDay(trip.id, backup: true)) as Success<String>).value;
      final added = ((await controller().addDay(trip.id, backup: false)) as Success<String>).value;
      final v = await view(trip.id);
      expect(v.trip.dayCount, 3);
      expect(v.days.map((d) => d.day.id), [days[0].id, days[1].id, added, backup]);
      expect(v.days[2].date, _utc(2027, 5, 1));
      expect(v.days[3].isBackup, isTrue);
    });

    test('days move between the trip and the backup days', () async {
      final backup = ((await controller().addDay(trip.id, backup: true)) as Success<String>).value;
      await controller().moveDayToBackup(trip.id, days[0]);
      var v = await view(trip.id);
      expect(v.trip.dayCount, 1);
      expect(v.days.map((d) => d.day.id), [days[1].id, days[0].id, backup]);
      expect(v.days[0].date, _utc(2027, 4, 29));

      await controller().moveDayToTrip(trip.id, (await repo.getDaysForTrip(trip.id)).last);
      v = await view(trip.id);
      expect(v.trip.dayCount, 2);
      expect(v.days.map((d) => d.day.id), [days[1].id, backup, days[0].id]);
      expect(v.days[2].isBackup, isTrue);
    });

    test('pinned days are not swapped or moved, and a bad pin is refused', () async {
      await repo.pinDayBlockDate(days[1].id, '2027-05-02');
      final pinned = (await repo.getDaysForTrip(trip.id))[1];
      expect(await controller().swapDays(a: days[0], b: pinned), isA<Failure<void>>());
      expect(await controller().moveDayToBackup(trip.id, pinned), isA<Failure<void>>());
      // Day 1 can't be pinned on or after Day 2's pinned date.
      final bad = await controller().pinDay(days[0].id, DateTime(2027, 5, 2));
      expect(bad, isA<Failure<void>>());
      expect(await controller().pinDay(days[0].id, DateTime(2027, 4, 30)), isA<Success<void>>());
    });

    test('removing a dated day makes the trip shorter', () async {
      await controller().removeDay(trip.id, days[0].id);
      final v = await view(trip.id);
      expect(v.trip.dayCount, 1);
      expect(v.days.single.day.id, days[1].id);
    });
  });

  group('TripScreen', () {
    Future<void> pump(WidgetTester tester, String tripId) async {
      final router = GoRouter(initialLocation: '/trips/$tripId', routes: [
        GoRoute(path: '/trips/:tripId', builder: (_, s) => TripScreen(tripId: s.pathParameters['tripId']!)),
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

    testWidgets('opens on the overview; the plan is read-only until edited', (tester) async {
      // A phone-sized screen.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 2);
      final day = (await r.getDaysForTrip(trip.id)).first;
      final bridge = await r.createTripOnlySpot(tripId: trip.id, name: 'Bridge', lat: 0, lng: 0, addedBy: 'u1');
      await r.scheduleStop(tripId: trip.id, stopId: bridge.id, dayId: day.id, fixedTime: 10 * 60);

      await pump(tester, trip.id);
      expect(find.text('Days'), findsOneWidget);

      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Bridge'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('Add from backlog'), findsNothing);

      await tester.tap(find.byTooltip('Edit the plan'));
      await tester.pumpAndSettle();
      expect(find.text('Add from backlog'), findsWidgets);
      expect(find.textContaining('Editing the plan'), findsOneWidget);

      await tester.tap(find.byTooltip('Show all days'));
      await tester.pumpAndSettle();
      expect(find.text('Day 2'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('addDayTile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addDayTile')));
      await tester.pumpAndSettle();
      expect((await r.getTrip(trip.id))!.dayCount, 3);
      expect(find.text('Day 3'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addDayTile')), findsNothing);
      await disposeApp(tester);
    });

    testWidgets('while editing, a day is named from its menu, and the name can be taken off', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      final day = (await r.getDaysForTrip(trip.id)).single;

      await pump(tester, trip.id);
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit the plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Day options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name this day'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('nameDialogField')), 'Rainy day');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await r.getDaysForTrip(trip.id)).single.title, 'Rainy day');
      expect(find.text('Rainy day'), findsWidgets);

      await tester.tap(find.byTooltip('Day options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename this day'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('nameDialogField')), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await r.getDaysForTrip(trip.id)).single.title, isNull);
      expect(day.id, isNotEmpty);
      await disposeApp(tester);
    });

    testWidgets("the Today card opens the plan on today's day", (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(
          title: 'Uji', ownerId: 'u1', startDate: isoDate(DateTime(now.year, now.month, now.day - 1)), dayCount: 3);

      await pump(tester, trip.id);
      expect(find.text('Today · Day 2'), findsOneWidget);
      await tester.tap(find.text('Open the plan'));
      await tester.pumpAndSettle();
      // Day 2 is the card in the middle, with Day 1 peeking in on the left.
      expect(tester.getTopLeft(find.text('DAY 2')).dx, lessThan(100));
      await disposeApp(tester);
    });

    testWidgets('a stop held at the edge pages past its own day and drops under the finger', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 4);
      final days = await r.getDaysForTrip(trip.id);
      final bridge = await r.createTripOnlySpot(tripId: trip.id, name: 'Bridge', lat: 0, lng: 0, addedBy: 'u1');
      await r.scheduleStop(tripId: trip.id, stopId: bridge.id, dayId: days[0].id, fixedTime: 10 * 60);

      await pump(tester, trip.id);
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit the plan'));
      await tester.pumpAndSettle();

      // Hold the stop at the right edge until the carousel has paged twice:
      // Day 1, and the row being dragged with it, are gone from the tree.
      final start = tester.getCenter(find.text('Bridge'));
      final edge = tester.view.physicalSize.width / tester.view.devicePixelRatio - 4;
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.moveTo(Offset(edge, start.dy));
      for (var i = 0; i < 34; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('DAY 1'), findsNothing);
      expect(find.text('DAY 3'), findsOneWidget);

      // Back off the edge onto Day 3 and let go.
      await gesture.moveTo(Offset(edge / 2, start.dy));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect((await r.getScheduleItemsForTrip(trip.id)).single.dayId, days[2].id);
      expect(find.text('Drop here to move it to the backlog'), findsNothing);
      await disposeApp(tester);
    });

    testWidgets('a stop opens its page from the read-only plan, and its sheet while editing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      // About 411 dp wide: the sheet's start-time row overflows at 360 dp on master.
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 1);
      final day = (await r.getDaysForTrip(trip.id)).single;
      final bridge = await r.createTripOnlySpot(tripId: trip.id, name: 'Bridge', lat: 0, lng: 0, addedBy: 'u1');
      await r.scheduleStop(tripId: trip.id, stopId: bridge.id, dayId: day.id, fixedTime: 10 * 60);
      final router = GoRouter(initialLocation: '/trips/${trip.id}', routes: [
        GoRoute(path: '/trips/:tripId', builder: (_, s) => TripScreen(tripId: s.pathParameters['tripId']!)),
        GoRoute(
          path: '/trips/:tripId/stops/:stopId',
          builder: (_, s) => Scaffold(body: Text('Stop page ${s.pathParameters['stopId']}')),
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('u1')],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bridge'));
      await tester.pumpAndSettle();
      expect(find.text('Stop page ${bridge.id}'), findsOneWidget, reason: 'no sheet in between');

      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit the plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bridge'));
      await tester.pumpAndSettle();
      expect(find.text('Move to backlog'), findsOneWidget, reason: 'the sheet, for quick changes');
      await disposeApp(tester);
    });

    testWidgets("moving a stop to the backlog shows Undo, which doesn't stay", (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      // About 411 dp wide, like a Pixel 10a.
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', startDate: '2027-04-29', dayCount: 1);
      final day = (await r.getDaysForTrip(trip.id)).single;
      final bridge = await r.createTripOnlySpot(tripId: trip.id, name: 'Bridge', lat: 0, lng: 0, addedBy: 'u1');
      await r.scheduleStop(tripId: trip.id, stopId: bridge.id, dayId: day.id, fixedTime: 10 * 60);

      await pump(tester, trip.id);
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit the plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bridge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to backlog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Moved Bridge to the backlog.'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // A SnackBar with an action would stay until dismissed, over the
      // backlog bar; this one goes by itself.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Moved Bridge to the backlog.'), findsNothing);
      await disposeApp(tester);
    });
  });

  group('Stop sheet', () {
    Future<void> openSheet(WidgetTester tester, String tripId, String stopId) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('u1')],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPlannerStopSheet(context, tripId: tripId, stopId: stopId, editing: true),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a stop in the backlog is removed from its sheet, after asking', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final r = DriftTripRepository(db);
      final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      final bridge = await r.createTripOnlySpot(tripId: trip.id, name: 'Bridge', lat: 0, lng: 0, addedBy: 'u1');

      await openSheet(tester, trip.id, bridge.id);
      await tester.ensureVisible(find.text('Remove from the trip'));
      await tester.tap(find.text('Remove from the trip'));
      await tester.pumpAndSettle();
      expect(find.text('Remove “Bridge”?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await r.getStopsForTrip(trip.id), hasLength(1));

      await tester.tap(find.text('Remove from the trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(await r.getStopsForTrip(trip.id), isEmpty);
      expect(find.text('Removed Bridge.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
