import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/providers/place_providers.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/screens/trip_place_screen.dart';
import 'package:trip_planner/shared/map/app_map.dart';

/// The place page: a place's spots with their frames and photos, its day,
/// its note, and what editors can change there that viewers can't.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer containerFor({bool? canEdit}) {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue('u1'),
      mapTilesProvider.overrideWithValue(false),
      if (canEdit != null) canEditTripProvider.overrideWith((ref, id) => canEdit),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container, String tripId, String stopId) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/trips/$tripId/places/$stopId', routes: [
      GoRoute(path: '/trips/:tripId', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/trips/:tripId/stops/:stopId', builder: (_, s) => Scaffold(body: Text('stop ${s.pathParameters['stopId']}'))),
      GoRoute(
        path: '/trips/:tripId/places/:stopId',
        builder: (_, s) => TripPlaceScreen(tripId: s.pathParameters['tripId']!, stopId: s.pathParameters['stopId']!),
      ),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// 宇治橋 as one stop on Day 1: 三の間 (two frames, one shot) and 東詰,
  /// whose frame nobody placed.
  Future<({String tripId, String stopId})> seedUji(ProviderContainer container, {String? note}) async {
    late ({String tripId, String stopId}) ids;
    final trips = container.read(tripRepositoryProvider);
    final places = container.read(placeRepositoryProvider);
    final trip = await trips.createTrip(title: 'Kansai', ownerId: 'u1', dayCount: 1);
    final s = await trips.createTripOnlySpot(tripId: trip.id, name: '宇治橋', lat: 34.892, lng: 135.808, addedBy: 'u1');
    if (note != null) await trips.updateStop(StopsCompanion(id: Value(s.id), note: Value(note)));
    final day = (await trips.getDaysForTrip(trip.id)).single;
    await trips.scheduleStop(tripId: trip.id, stopId: s.id, dayId: day.id);
    for (final (id, spotNote, lat) in [('f1', '三の間', 34.8921), ('f2', '三の間', 34.89212), ('f3', '東詰', null)]) {
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: id,
            stopId: Value(s.id),
            localPath: Value('missing-$id.png'),
            note: Value(spotNote),
            lat: Value(lat),
            lng: Value(lat == null ? null : 135.8075),
          ));
    }
    await places.addPhoto(placeKey: s.placeKey, localPath: 'missing-shot.jpg', tripId: trip.id, referenceImageId: 'f1');
    ids = (tripId: trip.id, stopId: s.id);
    return ids;
  }

  testWidgets('a group\'s spots by note or short name, filtered to the unshot', (tester) async {
    final container = containerFor();
    final trips = container.read(tripRepositoryProvider);
    final places = container.read(placeRepositoryProvider);
    late String tripId, stopId;
    await tester.runAsync(() async {
      final trip = await trips.createTrip(title: 'Kansai', ownerId: 'u1', dayCount: 1);
      final a = await trips.createTripOnlySpot(tripId: trip.id, name: '宇治橋 三の間', lat: 34.8921, lng: 135.8075, addedBy: 'u1', area: '宇治橋');
      final b = await trips.createTripOnlySpot(tripId: trip.id, name: '宇治橋 東詰', lat: 34.8918, lng: 135.8090, addedBy: 'u1', area: '宇治橋');
      await trips.createTripOnlySpot(tripId: trip.id, name: '平等院', lat: 34.889, lng: 135.807, addedBy: 'u1');
      tripId = trip.id;
      stopId = b.id;
      final fa = await places.addReferenceImage(stopId: a.id, localPath: 'missing-a.png');
      await places.addReferenceImage(stopId: b.id, localPath: 'missing-b.png');
      await places.addPhoto(placeKey: a.placeKey, localPath: 'missing-shot.jpg', tripId: trip.id, referenceImageId: fa.id);
    });
    await pump(tester, container, tripId, stopId);

    expect(find.text('宇治橋'), findsOneWidget, reason: 'the place has the group\'s name');
    expect(find.textContaining('2 spots · 2 frames · 1 shot'), findsOneWidget);
    expect(find.text('三の間'), findsWidgets);
    expect(find.text('東詰'), findsWidgets);
    expect(find.text('平等院'), findsNothing, reason: 'not in the group');
    expect(find.bySemanticsLabel('Your photo of this frame'), findsOneWidget);
    expect(find.text('Unsorted'), findsOneWidget, reason: 'on no day');

    await tester.tap(find.byKey(const Key('placeUnshotChip')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('placePage')), matching: find.text('東詰')), findsOneWidget);
    expect(find.bySemanticsLabel('Your photo of this frame'), findsNothing);
    await unmount(tester);
  });

  testWidgets('one stop: spots by note, its day, counts, and the stop page in the menu', (tester) async {
    final container = containerFor();
    late ({String tripId, String stopId}) ids;
    await tester.runAsync(() async => ids = await seedUji(container));
    await pump(tester, container, ids.tripId, ids.stopId);

    expect(find.text('宇治橋'), findsOneWidget);
    expect(find.textContaining('2 spots · 3 frames · 1 shot'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Position estimated'), findsOneWidget, reason: '東詰 is placed by its stop only');
    expect(find.text('Not shot 2'), findsOneWidget, reason: 'both spots have a frame to shoot');

    await tester.tap(find.byKey(const Key('placeMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placeDetails')));
    await tester.pumpAndSettle();
    expect(find.text('stop ${ids.stopId}'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an editor names a spot: every frame of it gets the note', (tester) async {
    final container = containerFor();
    late ({String tripId, String stopId}) ids;
    await tester.runAsync(() async => ids = await seedUji(container));
    await pump(tester, container, ids.tripId, ids.stopId);

    await tester.tap(find.byKey(const ValueKey('spotMenu-f1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('spotNoteField')), '三之間');
    await tester.tap(find.byKey(const Key('spotNoteSave')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final notes = await tester.runAsync(() async => {
          for (final f in await db.select(db.newReferenceImages).get()) f.id: f.note,
        });
    expect(notes, {'f1': '三之間', 'f2': '三之間', 'f3': '東詰'});
    final stop = await tester.runAsync(() => (db.select(db.stops)..where((s) => s.id.equals(ids.stopId))).getSingle());
    expect(stop!.syncStatus, 1);
    expect(find.text('三之間'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('an editor writes the place note; it saves after a pause', (tester) async {
    final container = containerFor();
    late ({String tripId, String stopId}) ids;
    await tester.runAsync(() async => ids = await seedUji(container));
    await pump(tester, container, ids.tripId, ids.stopId);

    await tester.scrollUntilVisible(find.byKey(const Key('placeNotes')), 300, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const Key('placeNotes')), 'Shoot at dusk');
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final stop = await tester.runAsync(() => (db.select(db.stops)..where((s) => s.id.equals(ids.stopId))).getSingle());
    expect(stop!.note, 'Shoot at dusk');
    await unmount(tester);
  });

  testWidgets('an editor moves the place off its day from the day chip', (tester) async {
    final container = containerFor();
    late ({String tripId, String stopId}) ids;
    await tester.runAsync(() async => ids = await seedUji(container));
    await pump(tester, container, ids.tripId, ids.stopId);

    await tester.tap(find.byKey(const Key('placeDayChip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('moveTo-unsorted')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final items = await tester.runAsync(() => container.read(tripRepositoryProvider).getScheduleItemsForTrip(ids.tripId));
    expect(items, isEmpty);
    expect(find.text('Unsorted'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a viewer sees the place, its note and spots, but nothing to change', (tester) async {
    final container = containerFor(canEdit: false);
    late ({String tripId, String stopId}) ids;
    await tester.runAsync(() async => ids = await seedUji(container, note: 'Exit 2, then left'));
    await pump(tester, container, ids.tripId, ids.stopId);

    expect(find.byKey(const ValueKey('spotMenu-f1')), findsNothing);
    expect(find.byKey(const Key('placeNotes')), findsNothing);
    expect(find.byType(ActionChip), findsNothing, reason: 'the day chip only shows the day');
    await tester.tap(find.byKey(const Key('placeMenu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placeMerge')), findsNothing);
    await tester.tapAt(const Offset(10, 600));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('placeNotesText')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Exit 2, then left'), findsOneWidget);
    await unmount(tester);
  });
}
