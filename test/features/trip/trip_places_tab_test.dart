import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/home/providers/home_providers.dart';
import 'package:trip_planner/features/planner/models/planner_view.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/trip/controllers/trips_controller.dart' show isoDate;
import 'package:trip_planner/features/trip/models/place_spots.dart';
import 'package:trip_planner/features/trip/models/trip_places_view.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/trip_places_tab.dart';

/// The trip page's Places tab: days as categories holding places, Unsorted,
/// the search, and what editors can do that viewers can't.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime(2027, 6, 19, 10);

  Future<void> pump(WidgetTester tester, String tripId, {bool? canEdit}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/trips/$tripId', routes: [
      GoRoute(path: '/trips/:tripId', builder: (_, s) => Scaffold(body: TripPlacesTab(tripId: s.pathParameters['tripId']!))),
      GoRoute(path: '/trips/:tripId/places/:stopId', builder: (_, s) => Scaffold(body: Text('place ${s.pathParameters['stopId']}'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u1'),
        homeClockProvider.overrideWithValue(() => now),
        if (canEdit != null) canEditTripProvider.overrideWith((ref, id) => canEdit),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// A trip starting today: Day 1 "Uji" with 宇治橋 and 平等院, Day 2 with
  /// nothing, and 西宮 on no day. 宇治橋 has frames, one of them shot.
  Future<({String tripId, Map<String, String> ids, List<TripDay> days})> seed() async {
    final repo = DriftTripRepository(db, null, 'u1');
    final trip = await repo.createTrip(title: 'Kansai', ownerId: 'u1', startDate: isoDate(now), dayCount: 2);
    final days = await repo.getDaysForTrip(trip.id);
    await repo.updateDayBlock(TripDaysCompanion(id: Value(days[0].id), title: const Value('Uji')));
    final ids = <String, String>{};
    for (final (name, day) in [('宇治橋', 0), ('平等院', 0), ('西宮', null)]) {
      final s = await repo.createTripOnlySpot(tripId: trip.id, name: name, lat: 34.89, lng: 135.80, addedBy: 'u1');
      ids[name] = s.id;
      if (day != null) await repo.scheduleStop(tripId: trip.id, stopId: s.id, dayId: days[day].id);
    }
    for (final (id, note, episode) in [('f1', '三の間', '3'), ('f2', '東詰', '12')]) {
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: id,
            stopId: Value(ids['宇治橋']),
            localPath: Value('missing-$id.png'),
            note: Value(note),
            episode: Value(episode),
          ));
    }
    await db.into(db.photos).insert(PhotosCompanion.insert(
          id: 'ph',
          placeKey: (await repo.getStop(ids['宇治橋']!))!.placeKey,
          kind: const Value('original'),
          localPath: 'missing.jpg',
          referenceImageId: const Value('f1'),
        ));
    return (tripId: trip.id, ids: ids, days: await repo.getDaysForTrip(trip.id));
  }

  testWidgets('days hold their places, then Unsorted; rows count spots, frames and shots', (tester) async {
    late ({String tripId, Map<String, String> ids, List<TripDay> days}) t;
    await tester.runAsync(() async => t = await seed());
    await pump(tester, t.tripId);

    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(find.text('Uji'), findsOneWidget, reason: 'the day goes by its title');
    expect(find.text('Day 2'), findsOneWidget, reason: 'an untitled day goes by its number');
    expect(find.byKey(const Key('todayBadge')), findsOneWidget);
    expect(find.byKey(const Key('todayCard')), findsOneWidget);
    expect(top(find.text('Uji')), lessThan(top(find.text('平等院'))));
    expect(top(find.text('Day 2')), lessThan(top(find.text('Unsorted'))));
    expect(top(find.text('Unsorted')), lessThan(top(find.text('西宮'))));
    expect(find.text('No places yet. Open a place and tap its day to move it here.'), findsOneWidget, reason: 'Day 2 is empty');
    expect(find.textContaining('2 spots · 2 frames · 1 shot'), findsOneWidget);

    await tester.tap(find.text('平等院'));
    await tester.pumpAndSettle();
    expect(find.text('place ${t.ids['平等院']}'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the search finds places by name, spot note and episode', (tester) async {
    late ({String tripId, Map<String, String> ids, List<TripDay> days}) t;
    await tester.runAsync(() async => t = await seed());
    await pump(tester, t.tripId);

    await tester.enterText(find.byKey(const Key('placesSearch')), '東詰');
    await tester.pumpAndSettle();
    expect(find.text('宇治橋'), findsOneWidget);
    expect(find.text('Spots: 東詰'), findsOneWidget);
    expect(find.text('平等院'), findsNothing);
    expect(find.byKey(const Key('todayCard')), findsNothing);

    await tester.enterText(find.byKey(const Key('placesSearch')), '12');
    await tester.pumpAndSettle();
    expect(find.text('1 frame: 12'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('placesSearch')), '西');
    await tester.pumpAndSettle();
    expect(find.text('西宮'), findsOneWidget);
    expect(find.text('宇治橋'), findsNothing);

    await tester.enterText(find.byKey(const Key('placesSearch')), 'nothing');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches “nothing”.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("an editor reorders a day's places, and deleting a day sends its places to Unsorted", (tester) async {
    late ({String tripId, Map<String, String> ids, List<TripDay> days}) t;
    await tester.runAsync(() async => t = await seed());
    await pump(tester, t.tripId);
    final repo = DriftTripRepository(db, null, 'u1');
    Future<List<String>> dayOrder() async {
      final items = await repo.getScheduleItemsForDay(t.days[0].id);
      return [for (final i in items) i.stopId];
    }

    await tester.tap(find.byKey(ValueKey('dayMenu-${t.days[0].id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dayReorder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('down-${t.ids['宇治橋']}')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(dayOrder), [t.ids['平等院'], t.ids['宇治橋']]);
    await tester.tap(find.byKey(const Key('reorderDone')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('dayMenu-${t.days[0].id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dayDelete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final stops = await tester.runAsync(() => repo.getStopsForTrip(t.tripId));
    expect(stops, hasLength(3), reason: 'no place is deleted');
    expect(await tester.runAsync(() => repo.getScheduleItemsForTrip(t.tripId)), isEmpty);
    expect(find.text('Uji'), findsNothing);
    await unmount(tester);
  });

  testWidgets('an editor adds a day with a name', (tester) async {
    late ({String tripId, Map<String, String> ids, List<TripDay> days}) t;
    await tester.runAsync(() async => t = await seed());
    await pump(tester, t.tripId);

    await tester.scrollUntilVisible(find.byKey(const Key('newDayButton')), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const Key('newDayButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('dayNameField')), 'Next time');
    await tester.tap(find.byKey(const Key('daySave')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    final days = await tester.runAsync(() => DriftTripRepository(db, null, 'u1').getDaysForTrip(t.tripId));
    expect(days!.map((d) => d.title), contains('Next time'));
    expect(find.text('Next time'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a viewer sees the days and places, with no menus, reordering or new days', (tester) async {
    late ({String tripId, Map<String, String> ids, List<TripDay> days}) t;
    await tester.runAsync(() async => t = await seed());
    await pump(tester, t.tripId, canEdit: false);

    expect(find.text('宇治橋'), findsOneWidget);
    expect(find.byKey(ValueKey('dayMenu-${t.days[0].id}')), findsNothing);
    expect(find.byKey(ValueKey('down-${t.ids['宇治橋']}')), findsNothing);
    expect(find.byKey(const Key('newDayButton')), findsNothing);
    await unmount(tester);
  });

  group('the view', () {
    final t0 = DateTime(2027);
    Stop stop(String id, {String? area}) => Stop(
          id: id,
          tripId: 't',
          placeKey: 'p-$id',
          name: id,
          lat: 0,
          lng: 0,
          area: area,
          addedBy: 'u1',
          createdAt: t0,
          updatedAt: t0,
          syncStatus: 0,
        );

    test("a group's stops are one place where its first stop comes, with all their items", () {
      final places = placesOfStops(
        [stop('a', area: 'Rose'), stop('b'), stop('c', area: 'Rose')],
        itemOfStop: {'a': 'ia', 'b': 'ib', 'c': 'ic'},
      );
      expect([for (final p in places) p.name], ['Rose', 'b']);
      expect(places.first.itemIds, ['ia', 'ic']);
      expect(places.first.id, 'a');
    });

    test('reorderTarget: before the place it passes, or the end of the day', () {
      final places = placesOfStops([stop('a'), stop('b'), stop('c')], itemOfStop: {'a': 'ia', 'b': 'ib', 'c': 'ic'});
      expect(reorderTarget(places, places[2], -1)!.before, 'ib');
      expect(reorderTarget(places, places[0], 1)!.before, 'ic');
      expect(reorderTarget(places, places[1], 1)!.before, isNull);
      expect(reorderTarget(places, places[0], -1), isNull);
      expect(reorderTarget(places, places[2], 1), isNull);
    });

    test('matchPlace: name, spot notes and episodes', () {
      final place = placesOfStops([stop('宇治橋')]).single;
      final frames = [
        NewReferenceImage(id: 'f1', stopId: '宇治橋', localPath: 'a.png', note: '三の間', episode: '3', createdAt: t0),
      ];
      final content = TripFrameIndex(own: frames, library: const [], photos: const []).place(place.stops);
      expect(matchPlace(place, content, '宇治').name, isTrue);
      expect(matchPlace(place, content, '三の').spots, ['三の間']);
      expect(matchPlace(place, content, '3').frames.single.id, 'f1');
      expect(matchPlace(place, content, 'x').any, isFalse);
    });

    test("todaySection finds the day dated today, and buildTripPlacesView leaves the rest to Unsorted", () {
      final trip = Trip(
        id: 't',
        title: 'T',
        ownerId: 'u1',
        startDate: '2027-06-19',
        dayCount: 1,
        sharing: 'private',
        createdAt: t0,
        updatedAt: t0,
        syncStatus: 0,
      );
      final day = TripDay(id: 'd1', tripId: 't', sortKey: 'a0', updatedAt: t0, syncStatus: 0);
      final view = buildTripPlacesView(buildPlannerView(
        trip: trip,
        days: [day],
        stops: [stop('a'), stop('b')],
        items: [
          ScheduleItem(id: 'i', tripId: 't', stopId: 'a', dayId: 'd1', sortKey: 'a0', stayMinutes: 60, transitMinutes: 0, status: 'planned', updatedAt: t0, syncStatus: 0),
        ],
      ));
      expect(view.todaySection(DateTime(2027, 6, 19))!.dayId, 'd1');
      expect(view.todaySection(DateTime(2027, 6, 20)), isNull);
      expect([for (final p in view.unsorted.places) p.id], ['b']);
      expect(view.sectionOf('b')!.isUnsorted, isTrue);
    });
  });
}
