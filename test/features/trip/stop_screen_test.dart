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
import 'package:trip_planner/features/library/controllers/place_controller.dart' show PlaceFacts;
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/widgets/place_page_parts.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/trip/controllers/trip_stops_controller.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/stop_screen.dart';
import 'package:trip_planner/features/trip/screens/trip_stops_screen.dart';

NewReferenceImage _frame(String id, {String? local, String? remote}) =>
    NewReferenceImage(id: id, localPath: local, remoteUrl: remote, createdAt: DateTime(2026));

void main() {
  late AppDatabase db;
  late DriftTripRepository trips;
  late DriftPlaceRepository places;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trips = DriftTripRepository(db, null, 'u1');
    places = DriftPlaceRepository(db);
  });
  tearDown(() => db.close());

  /// A trip with one day, and Uji Bridge from the library on it at 09:00
  /// unless [planned] is false.
  Future<(Trip, Stop)> uji({bool planned = true}) async {
    await db.into(db.places).insert(PlacesCompanion.insert(
          placeKey: 'p1',
          name: 'Uji Bridge',
          lat: 34.89,
          lng: 135.80,
          visibility: const Value('saved'),
          accessTips: const Value('Keihan Uji Station'),
          source: const Value('Anitabi'),
        ));
    final trip = await trips.createTrip(title: 'Uji day trip', ownerId: 'u1', dayCount: 1);
    final stop = await trips.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'u1');
    if (planned) {
      final day = (await trips.getDaysForTrip(trip.id)).single;
      await trips.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: day.id, fixedTime: 9 * 60);
    }
    return (trip, stop);
  }

  group('TripStopsController trip notes', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer(overrides: [
          databaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u1'),
        ]));
    tearDown(() => container.dispose());

    test('saves the note on the stop for the trip, and an empty one clears it', () async {
      final (_, stop) = await uji();
      final controller = container.read(tripStopsControllerProvider.notifier);

      expect(await controller.setNote(stop.id, '  Meet at the east exit  '), isA<Success<void>>());
      final saved = (await trips.getStop(stop.id))!;
      expect(saved.note, 'Meet at the east exit');
      expect(saved.syncStatus, 1, reason: 'it goes up to the trip');

      await controller.setNote(stop.id, '   ');
      expect((await trips.getStop(stop.id))!.note, isNull);
    });

    test('counts the length the way the rules do: UTF-16 code units', () async {
      final (_, stop) = await uji();
      final controller = container.read(tripStopsControllerProvider.notifier);

      expect(await controller.setNote(stop.id, '漢' * 2000), isA<Success<void>>());
      expect(await controller.setNote(stop.id, '😀' * 1000), isA<Success<void>>(), reason: '2000 code units');
      expect(await controller.setNote(stop.id, '😀' * 1001), isA<Failure<void>>(), reason: '2002 code units');
      expect((await trips.getStop(stop.id))!.note, '😀' * 1000);
    });

    test('editing the facts changes the stop, not the library place', () async {
      final (_, stop) = await uji();
      final controller = container.read(tripStopsControllerProvider.notifier);

      expect(await controller.updateFacts(stop.id, const PlaceFacts(name: 'Uji Bridge (east)', accessTips: 'Exit 2')),
          isA<Success<void>>());
      final saved = (await trips.getStop(stop.id))!;
      expect((saved.name, saved.accessTips), ('Uji Bridge (east)', 'Exit 2'));
      final place = (await places.getPlace('p1'))!;
      expect((place.name, place.accessTips), ('Uji Bridge', 'Keihan Uji Station'));
    });
  });

  group('helpers', () {
    test('truncateUtf16 keeps two-unit characters whole', () {
      expect(truncateUtf16('abc', 5), 'abc');
      expect(truncateUtf16('abcdef', 4), 'abcd');
      expect(truncateUtf16('a😀', 2), 'a', reason: 'half an emoji would be left otherwise');
    });

    test('a stop shows the place frames first, then copies the place lacks', () {
      final frames = stopFrames(
        place: [_frame('own', local: '/f/a.jpg'), _frame('none')],
        stop: [_frame('copy', local: '/f/a.jpg'), _frame('remote', remote: 'https://image.anitabi.cn/b.jpg')],
      );
      expect(frames.map((f) => f.id), ['own', 'remote']);
    });
  });

  group('StopScreen', () {
    Future<void> pump(WidgetTester tester, String location, {List<Override> overrides = const []}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: location, routes: [
        GoRoute(path: '/trips/:tripId/stops', builder: (_, s) => TripStopsScreen(tripId: s.pathParameters['tripId']!)),
        GoRoute(
          path: '/trips/:tripId/stops/:stopId',
          builder: (_, s) => StopScreen(tripId: s.pathParameters['tripId']!, stopId: s.pathParameters['stopId']!),
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('u1'), ...overrides],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> disposeApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    Finder inCard(String title, Finder finder) => find.descendant(of: find.widgetWithText(Card, title), matching: finder);

    testWidgets('a stop in the list opens on its own page: the plan, then what the trip shares, then your own', (tester) async {
      final (trip, _) = await uji();
      await pump(tester, '/trips/${trip.id}/stops');
      await tester.tap(find.text('Uji Bridge'));
      await tester.pumpAndSettle();

      expect(find.text('Uji day trip · Day 1'), findsOneWidget);
      expect(inCard('Plan', find.text('09:00 · fixed')), findsOneWidget);
      expect(inCard('Plan', find.text('First stop of the day')), findsOneWidget);
      expect(inCard('Plan', find.text('Shared with the trip')), findsOneWidget);
      expect(inCard('About this spot', find.text('Keihan Uji Station')), findsOneWidget, reason: 'the copied facts');
      // Outside edit mode there is nothing to fill in: no empty notes, no time buttons.
      expect(find.text('Trip note'), findsNothing);
      expect(find.text('Set a time'), findsNothing);
      expect(find.byTooltip('5 minutes longer'), findsNothing);
      // The page's list, not the frames' carousel inside it.
      await tester.scrollUntilVisible(find.text('Open my place'), 300, scrollable: find.byType(Scrollable).first);
      expect(inCard('My photos', find.text('Only you')), findsOneWidget);
      expect(find.text('My note'), findsNothing);
      // The source sits at the foot of the page, after the map.
      const source = 'Spot data from Anitabi, CC BY-NC-SA 4.0 · copied into this trip';
      await tester.scrollUntilVisible(find.text(source), 300, scrollable: find.byType(Scrollable).first);
      expect(tester.getTopLeft(find.text(source)).dy, greaterThan(tester.getTopLeft(find.text('Location')).dy));
      await disposeApp(tester);
    });

    testWidgets('the trip note is written on the stop, capped at 2000 code units', (tester) async {
      final (trip, stop) = await uji();
      await pump(tester, '/trips/${trip.id}/stops/${stop.id}');

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('tripNoteField')), '😀' * 1001);
      await tester.pump();
      expect(find.text('2000 / 2000'), findsOneWidget, reason: 'a paste over the cap is cut, not refused');

      await tester.enterText(find.byKey(const Key('tripNoteField')), 'Meet at the east exit at 10:00');
      await tester.pump();
      expect(find.text('30 / 2000'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(inCard('Trip note', find.text('Meet at the east exit at 10:00')), findsOneWidget);
      expect((await trips.getStop(stop.id))!.note, 'Meet at the east exit at 10:00');
      expect((await places.getPlace('p1'))!.privateNote, isNull, reason: 'the trip note is not your own note');
      await disposeApp(tester);
    });

    testWidgets('marking a stop visited marks it for the trip and adds your visit; taking it back removes both', (tester) async {
      final (trip, stop) = await uji();
      await pump(tester, '/trips/${trip.id}/stops/${stop.id}');

      await tester.tap(find.widgetWithText(FilterChip, 'Mark visited'));
      await tester.pumpAndSettle();
      expect((await trips.getScheduleItemsForTrip(trip.id)).single.status, 'done');
      final visits = await places.getVisitsForPlace('p1');
      expect(visits.single.tripId, trip.id);
      expect(find.widgetWithText(FilterChip, 'Visited'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Visited'));
      await tester.pumpAndSettle();
      expect((await trips.getScheduleItemsForTrip(trip.id)).single.status, 'planned');
      expect(await places.getVisitsForPlace('p1'), isEmpty);
      await disposeApp(tester);
    });

    testWidgets('the stay changes in steps of five minutes', (tester) async {
      final (trip, stop) = await uji();
      await pump(tester, '/trips/${trip.id}/stops/${stop.id}');

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('5 minutes longer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('5 minutes longer'));
      await tester.pumpAndSettle();
      expect((await trips.getScheduleItemsForTrip(trip.id)).single.stayMinutes, 65);
      expect(inCard('Plan', find.text('65 min')), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets("the pencil edits the stop's copy of the facts on the page itself", (tester) async {
      final (trip, stop) = await uji();
      await pump(tester, '/trips/${trip.id}/stops/${stop.id}');

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Editing'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('placeField_name')), 'Uji Bridge (east)');
      await tester.ensureVisible(find.byKey(const Key('placeField_access')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('placeField_access')), 'Exit 2, then left');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Uji Bridge (east)'), findsWidgets);
      expect(inCard('About this spot', find.text('Exit 2, then left')), findsOneWidget);
      final saved = (await trips.getStop(stop.id))!;
      expect((saved.name, saved.accessTips), ('Uji Bridge (east)', 'Exit 2, then left'));
      final place = (await places.getPlace('p1'))!;
      expect((place.name, place.accessTips), ('Uji Bridge', 'Keihan Uji Station'), reason: 'the library keeps its own copy');
      await disposeApp(tester);
    });

    testWidgets('back in edit mode asks before it drops the changes', (tester) async {
      final (trip, stop) = await uji();
      await pump(tester, '/trips/${trip.id}/stops/${stop.id}');

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('tripNoteField')), 'Meet at the gate');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tripNoteField')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tripNoteField')), findsNothing);
      expect(find.text('Uji Bridge'), findsWidgets, reason: 'still on the stop page');
      expect((await trips.getStop(stop.id))!.note, isNull);
      await disposeApp(tester);
    });

    testWidgets("a day's title names it on the stop page", (tester) async {
      final (trip, stop) = await uji();
      final day = (await trips.getDaysForTrip(trip.id)).single;
      await trips.updateDayBlock(TripDaysCompanion(id: Value(day.id), title: const Value('Uji')));
      await pump(tester, '/trips/${trip.id}/stops/${stop.id}');

      expect(find.text('Uji day trip · Day 1 · Uji'), findsOneWidget);
      expect(inCard('Plan', find.text('Day 1 · Uji')), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('a label added on a stop goes on the stop, not on the place', (tester) async {
      final (trip, stop) = await uji();
      await pump(tester, '/trips/${trip.id}/stops/${stop.id}');

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Label'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regions'));
      await tester.enterText(find.byKey(const Key('labelNameField')), 'Uji');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create “Uji”'));
      await tester.pumpAndSettle();

      expect((await trips.getLabelsForStop(stop.id)).single.name, 'Uji');
      expect(await places.getLabelsForPlace('p1'), isEmpty);
      await disposeApp(tester);
    });

    testWidgets("a viewer sees the trip's parts but can only change their own note", (tester) async {
      final (trip, stop) = await uji();
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
          .write(const TripsCompanion(ownerId: Value('aki'), sharing: Value('group')));
      TripMember member(String id, TripMemberRole role) =>
          TripMember(userId: id, tripId: trip.id, role: role, displayName: id, joinedAt: DateTime(2026));
      await pump(tester, '/trips/${trip.id}/stops/${stop.id}', overrides: [
        tripMembersProvider(trip.id).overrideWith(
            (ref) => Stream.value([member('aki', TripMemberRole.owner), member('u1', TripMemberRole.viewer)])),
      ]);

      expect(find.byTooltip('More'), findsNothing, reason: 'rename, move and remove change the trip');
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Mark visited')).onSelected, isNull);
      expect(find.textContaining('Marking it visited'), findsNothing);

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tripNoteField')), findsNothing);
      expect(find.byKey(const Key('placeField_name')), findsNothing);
      expect(find.text('Set a time'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Label'), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const Key('placeNoteField')), 300, scrollable: find.byType(Scrollable).first);
      await tester.enterText(find.byKey(const Key('placeNoteField')), 'Shoot from the east bank');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect((await places.getPlace('p1'))!.privateNote, 'Shoot from the east bank');
      final saved = (await trips.getStop(stop.id))!;
      expect((saved.note, saved.name), (null, 'Uji Bridge'));
      await disposeApp(tester);
    });

    testWidgets('a stop in the backlog can be put on a day from its page', (tester) async {
      final (trip, stop) = await uji(planned: false);
      await pump(tester, '/trips/${trip.id}/stops/${stop.id}');

      expect(find.text('Uji day trip · Not on a day yet'), findsOneWidget);
      await tester.tap(find.text('Add to a day'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Day 1'));
      await tester.pumpAndSettle();

      expect((await trips.getScheduleItemsForTrip(trip.id)).single.stopId, stop.id);
      expect(find.text('Uji day trip · Day 1'), findsOneWidget);
      await disposeApp(tester);
    });
  });
}
