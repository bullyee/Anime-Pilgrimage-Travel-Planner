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
import 'package:trip_planner/features/trip/screens/trip_map_view.dart';
import 'package:trip_planner/features/trip/screens/trip_place_screen.dart' show FrameCell;
import 'package:trip_planner/features/trip/screens/trip_places_tab.dart';
import 'package:trip_planner/shared/map/app_map.dart';

/// The trip page's Places tab: days as categories holding places, Unsorted,
/// the search, and what editors can do that viewers can't.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime(2027, 6, 19, 10);

  /// A day's header: its title starts the line, its date and count follow.
  Finder header(String title) => find.textContaining(RegExp('^${RegExp.escape(title)}(\\s|\$)'));

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
        mapTilesProvider.overrideWithValue(false),
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
    expect(header('Uji'), findsOneWidget, reason: 'the day goes by its title');
    expect(header('Day 2'), findsOneWidget, reason: 'an untitled day goes by its number');
    expect(find.byKey(const Key('todayBadge')), findsOneWidget);
    expect(find.byKey(const Key('todayCard')), findsOneWidget);
    expect(top(header('Uji')), lessThan(top(find.text('平等院'))));
    expect(top(header('Day 2')), lessThan(top(header('Unsorted'))));
    expect(find.textContaining('2 spots · 2 frames · 1 shot'), findsOneWidget);

    // Only today's day starts open; the others say how many places they hold.
    expect(find.text('西宮'), findsNothing);
    expect(find.textContaining('Unsorted   1 place'), findsOneWidget, reason: 'Unsorted, closed');
    expect(find.textContaining('· 0 places'), findsOneWidget, reason: 'Day 2, closed, after its date');
    await tester.tap(header('Unsorted'));
    await tester.pumpAndSettle();
    expect(top(header('Unsorted')), lessThan(top(find.text('西宮'))));
    await tester.tap(header('Day 2'));
    await tester.pumpAndSettle();
    expect(find.text('No places yet. Open a place and tap its day to move it here.'), findsOneWidget, reason: 'Day 2 is empty');
    await tester.tap(header('Uji'));
    await tester.pumpAndSettle();
    expect(find.text('平等院'), findsNothing, reason: 'today can be closed too');
    await tester.tap(header('Uji'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('平等院'));
    await tester.pumpAndSettle();
    expect(find.text('place ${t.ids['平等院']}'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the map shows the places as pins; a day narrows them and draws its route; a pin opens its card', (tester) async {
    late ({String tripId, Map<String, String> ids, List<TripDay> days}) t;
    await tester.runAsync(() async => t = await seed());
    await pump(tester, t.tripId);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.byType(TripMapView), findsOneWidget);
    expect(find.byKey(const Key('placesSearch')), findsNothing);
    expect(find.byKey(const Key('mapDay-all')), findsOneWidget);
    expect(find.byKey(ValueKey('mapDay-${t.days[0].id}')), findsOneWidget);

    // The three places share a position: one stack, which can't part.
    final stack = find.byKey(ValueKey('cluster:place:${t.ids['宇治橋']}'));
    expect(find.descendant(of: stack, matching: find.byType(FaceCluster)), findsOneWidget);
    expect(find.descendant(of: stack, matching: find.text('3')), findsOneWidget);
    expect(find.byKey(const Key('dayRoute')), findsNothing, reason: 'no route for all days');

    await tester.tap(find.byKey(ValueKey('mapDay-${t.days[0].id}')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: stack, matching: find.text('2')), findsOneWidget, reason: "Day 1's two places");
    expect(find.byKey(const Key('dayRoute')), findsOneWidget);

    await tester.tap(stack);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mapCrowdCard')), findsOneWidget);
    expect(find.text('2 places'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('crowd-${t.ids['宇治橋']}-')));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('mapPlaceCard'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining('宇治橋')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining('2 spots · 2 frames')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byType(FrameCell)), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('mapOpenPlace')));
    await tester.pumpAndSettle();
    expect(find.text('place ${t.ids['宇治橋']}'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("every day's menu sits at the end of its header, whatever the title's length", (tester) async {
    late ({String tripId, Map<String, String> ids, List<TripDay> days}) t;
    await tester.runAsync(() async {
      t = await seed();
      await DriftTripRepository(db, null, 'u1').updateDayBlock(TripDaysCompanion(id: Value(t.days[1].id), title: const Value('A much longer day title')));
    });
    await pump(tester, t.tripId);

    final right = [for (final d in t.days) tester.getTopRight(find.byKey(ValueKey('dayMenu-${d.id}'))).dx];
    expect(right[0], right[1]);
    await unmount(tester);
  });

  testWidgets('the tag chips narrow the list to places with any picked tag; the search finds tags too', (tester) async {
    late ({String tripId, Map<String, String> ids, List<TripDay> days}) t;
    await tester.runAsync(() async {
      t = await seed();
      for (final (id, kind, name) in [('l1', 'anime', 'Eupho'), ('l2', 'tag', 'Shrine')]) {
        await db.into(db.labels).insert(LabelsCompanion.insert(id: id, kind: kind, name: name));
      }
      for (final (stop, label) in [('宇治橋', 'l1'), ('西宮', 'l1'), ('平等院', 'l2')]) {
        await db.into(db.stopLabels).insert(StopLabelsCompanion.insert(stopId: t.ids[stop]!, labelId: label));
      }
    });
    await pump(tester, t.tripId);

    expect(find.text('Eupho  2'), findsOneWidget);
    expect(find.text('Shrine  1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tag-anime-Eupho')));
    await tester.pumpAndSettle();
    expect(find.text('宇治橋'), findsOneWidget);
    expect(find.text('西宮'), findsOneWidget, reason: 'a filter opens every day it matches in');
    expect(find.text('平等院'), findsNothing);
    expect(header('Day 2'), findsNothing, reason: 'a day with no match hides');
    expect(find.byKey(const Key('todayCard')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('tag-tag-Shrine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-tag-Shrine')));
    await tester.pumpAndSettle();
    expect(find.text('平等院'), findsOneWidget, reason: 'any picked tag lets a place through');

    await tester.drag(find.byKey(const Key('placesTags')), const Offset(600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tagsClear')));
    await tester.pumpAndSettle();
    expect(header('Day 2'), findsOneWidget);
    expect(find.text('西宮'), findsNothing, reason: 'Unsorted is closed again');

    await tester.enterText(find.byKey(const Key('placesSearch')), 'shrine');
    await tester.pumpAndSettle();
    expect(find.text('平等院'), findsOneWidget);
    expect(find.text('Tags: Shrine'), findsOneWidget);
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
    expect(header('Uji'), findsNothing);
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
    expect(header('Next time'), findsOneWidget);
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

    test('defaultOpen: today\'s day, else the first with places', () {
      PlacesSection section(String? dayId, DateTime? date, List<String> stops) => PlacesSection(
            day: dayId == null
                ? null
                : PlannerDay(
                    day: TripDay(id: dayId, tripId: 't', sortKey: dayId, updatedAt: t0, syncStatus: 0),
                    index: 0,
                    isBackup: false,
                    date: date,
                    pinConflict: false,
                    freeDaysBefore: 0,
                    items: const [],
                  ),
            places: placesOfStops([for (final s in stops) stop(s)]),
          );
      final view = TripPlacesView(
        days: [section('d1', DateTime(2027, 6, 18), []), section('d2', DateTime(2027, 6, 19), ['a']), section('d3', DateTime(2027, 6, 20), ['b'])],
        unsorted: section(null, null, ['c']),
      );
      expect(view.defaultOpen(DateTime(2027, 6, 20)), {'d3'});
      expect(view.defaultOpen(DateTime(2027, 7, 1)), {'d2'});
    });

    test('labelFilterOptions: anime, then tags, then regions, the most used first', () {
      final places = placesOfStops([stop('a'), stop('b'), stop('c')]);
      const eupho = (kind: 'anime', name: 'Eupho');
      const kon = (kind: 'anime', name: 'K-On');
      const shrine = (kind: 'tag', name: 'Shrine');
      const uji = (kind: 'region', name: 'Uji');
      final labels = {
        'a': [uji, kon, shrine],
        'b': [eupho, shrine],
        'c': [eupho],
      };
      expect([for (final o in labelFilterOptions(places, labels)) '${o.label.name} ${o.count}'], ['Eupho 2', 'K-On 1', 'Shrine 2', 'Uji 1']);
      expect([for (final p in places) if (placeHasAnyLabel(p, labels, {kon, uji})) p.id], ['a']);
      expect(places.every((p) => placeHasAnyLabel(p, labels, const {})), isTrue);
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
