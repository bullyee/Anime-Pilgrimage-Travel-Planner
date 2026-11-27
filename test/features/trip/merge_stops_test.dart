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
import 'package:trip_planner/features/trip/screens/trip_place_screen.dart';
import 'package:trip_planner/shared/map/app_map.dart';

void main() {
  late AppDatabase db;
  late DriftTripRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftTripRepository(db, null, 'u1');
  });
  tearDown(() => db.close());

  Future<Stop> spot(String tripId, String name, {String? note, String? area}) async {
    final s = await repo.createTripOnlySpot(tripId: tripId, name: name, lat: 0, lng: 0, addedBy: 'u1', area: area);
    if (note != null) await repo.updateStop(StopsCompanion(id: Value(s.id), note: Value(note)));
    return s;
  }

  Future<void> label(String id) => db.into(db.labels).insert(LabelsCompanion.insert(id: id, kind: 'tag', name: id));
  Future<void> frame(String id, String stopId, String path) => db.into(db.newReferenceImages).insert(
        NewReferenceImagesCompanion.insert(id: id, stopId: Value(stopId), localPath: Value(path)),
      );

  test('a merge moves notes, labels, frames and days to the kept stop', () async {
    final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 3);
    final days = await repo.getDaysForTrip(trip.id);
    final keep = await spot(trip.id, 'Cafe Rose', note: 'Try the parfait.');
    final a = await spot(trip.id, 'Cafe Rose (2)', note: 'Closed on Mondays.', area: 'Station');
    final b = await spot(trip.id, 'Cafe Rose (3)', note: 'Try the parfait.');

    await label('anime');
    await label('food');
    await repo.attachLabelToStop(keep.id, 'anime');
    await repo.attachLabelToStop(a.id, 'anime');
    await repo.attachLabelToStop(b.id, 'food');

    await frame('f1', keep.id, '/frames/ep1.jpg');
    await frame('f2', a.id, '/frames/ep1.jpg'); // the same file
    await frame('f3', a.id, '/frames/ep2.jpg');

    // Day 1: the kept stop and A (done). Day 2: B only. Day 3: A and B.
    final keptDay1 = await repo.scheduleStop(tripId: trip.id, stopId: keep.id, dayId: days[0].id);
    final aDay1 = await repo.scheduleStop(tripId: trip.id, stopId: a.id, dayId: days[0].id);
    await repo.updateScheduleItemStatus(itemId: aDay1.id, status: 'done');
    final bDay2 = await repo.scheduleStop(tripId: trip.id, stopId: b.id, dayId: days[1].id);
    final aDay3 = await repo.scheduleStop(tripId: trip.id, stopId: a.id, dayId: days[2].id);
    final bDay3 = await repo.scheduleStop(tripId: trip.id, stopId: b.id, dayId: days[2].id);
    // As if everything had synced.
    await db.update(db.stops).write(const StopsCompanion(syncStatus: Value(0), updatedBy: Value('someone')));
    await db.update(db.scheduleItems).write(const ScheduleItemsCompanion(syncStatus: Value(0)));

    await repo.mergeStops(keepId: keep.id, otherIds: [a.id, b.id]);

    final stops = await repo.getStopsForTrip(trip.id);
    final kept = stops.single;
    expect(kept.id, keep.id);
    expect(kept.name, 'Cafe Rose');
    expect(kept.note, 'Try the parfait.\n\nClosed on Mondays.');
    expect(kept.area, 'Station', reason: 'it had no group, so it takes the first other one');
    expect(kept.syncStatus, 1);
    expect(kept.updatedBy, 'u1');

    expect((await repo.getLabelsForStop(keep.id)).map((l) => l.id).toSet(), {'anime', 'food'});
    final frames = await repo.getReferenceImagesForStop(keep.id);
    expect(frames.map((f) => f.id).toSet(), {'f1', 'f3'});
    expect(await (db.select(db.newReferenceImages)..where((f) => f.id.equals('f2'))).get(), isEmpty);

    final items = await repo.getScheduleItemsForTrip(trip.id);
    expect(items.every((i) => i.stopId == keep.id), isTrue);
    expect({for (final i in items) i.id: i.dayId}, {
      keptDay1.id: days[0].id, // A's item on day 1 is dropped
      bDay2.id: days[1].id, // B's moves
      aDay3.id: days[2].id, // A's moves first; B's then is dropped
    });
    final day1 = items.firstWhere((i) => i.id == keptDay1.id);
    expect(day1.status, 'done', reason: 'A was visited on day 1');
    expect(items.every((i) => i.syncStatus == 1), isTrue);
    expect(items.any((i) => i.id == bDay3.id), isFalse);

    final removed = await (db.select(db.stops)..where((s) => s.id.isIn([a.id, b.id]))).get();
    expect(removed.every((s) => s.deletedAt != null && s.syncStatus == 1), isTrue);
    expect(removed.every((s) => s.mergedInto == keep.id), isTrue, reason: 'other phones move their own frames after it');
    final moved = frames.singleWhere((f) => f.id == 'f3');
    expect(moved.note, isNotNull, reason: 'the frames of a merged stop become spots of the kept one');
    expect(moved.lat, a.lat);
  });

  test("an empty file isn't a file, and a link and a file of the same frame are one", () async {
    final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
    final keep = await spot(trip.id, 'Bridge');
    final other = await spot(trip.id, 'Bridge (2)');
    Future<void> img(String id, String stopId, {String? path, String? url}) => db.into(db.newReferenceImages).insert(
          NewReferenceImagesCompanion.insert(id: id, stopId: Value(stopId), localPath: Value(path), remoteUrl: Value(url)),
        );
    await img('k1', keep.id, path: '', url: 'https://x/1.jpg');
    await img('k2', keep.id, path: '/f/2.jpg', url: 'https://x/2.jpg');
    await img('o1', other.id, path: '', url: 'https://x/3.jpg'); // another frame, also with an empty path
    await img('o2', other.id, url: 'https://x/2.jpg'); // k2, by its link only

    await repo.mergeStops(keepId: keep.id, otherIds: [other.id]);
    expect((await repo.getReferenceImagesForStop(keep.id)).map((f) => f.id).toSet(), {'k1', 'k2', 'o1'});
  });

  test('a skipped item on the kept stop takes a planned one of the same day', () async {
    final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
    final day = (await repo.getDaysForTrip(trip.id)).single;
    final keep = await spot(trip.id, 'Bridge');
    final other = await spot(trip.id, 'Bridge (2)');
    final skipped = await repo.scheduleStop(tripId: trip.id, stopId: keep.id, dayId: day.id);
    await repo.updateScheduleItemStatus(itemId: skipped.id, status: 'skipped');
    await repo.scheduleStop(tripId: trip.id, stopId: other.id, dayId: day.id);

    await repo.mergeStops(keepId: keep.id, otherIds: [other.id]);
    final items = await repo.getScheduleItemsForTrip(trip.id);
    final live = [for (final i in items) if (i.deletedAt == null) i];
    expect(live.single.stopId, keep.id);
    expect(live.single.status, 'planned');
  });

  test("setFrameShots leaves another trip's frames alone", () async {
    final mine = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
    final theirs = await repo.createTrip(title: 'Kyoto', ownerId: 'u1', dayCount: 1);
    final a = await spot(mine.id, 'Bridge');
    final b = await spot(theirs.id, 'Shrine');
    await frame('fa', a.id, '/f/a.jpg');
    await frame('fb', b.id, '/f/b.jpg');
    await repo.setFrameShots(tripId: mine.id, frameIds: ['fa', 'fb'], note: const Value('east end'));
    final notes = {for (final f in await db.select(db.newReferenceImages).get()) f.id: f.note};
    expect(notes, {'fa': 'east end', 'fb': null});
  });

  test('a merged stop brought back from the trash is merged into nothing', () async {
    final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
    final keep = await spot(trip.id, 'Bridge');
    final other = await spot(trip.id, 'Bridge (2)');
    await repo.mergeStops(keepId: keep.id, otherIds: [other.id]);
    expect((await repo.getStop(other.id))!.mergedInto, keep.id);
    await repo.restoreStop(other.id);
    final back = (await repo.getStop(other.id))!;
    expect((back.deletedAt, back.mergedInto), (null, null));
  });

  test('a kept stop keeps its own group', () async {
    final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
    final keep = await spot(trip.id, 'A', area: 'Rose');
    final other = await spot(trip.id, 'B', area: 'Station');
    await repo.mergeStops(keepId: keep.id, otherIds: [other.id]);
    expect((await repo.getStopsForTrip(trip.id)).single.area, 'Rose');
  });

  test('the controller refuses notes that would be too long together', () async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue('u1'),
    ]);
    addTearDown(container.dispose);
    final r = container.read(tripRepositoryProvider);
    final trip = await r.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
    final a = await r.createTripOnlySpot(tripId: trip.id, name: 'A', lat: 0, lng: 0, addedBy: 'u1');
    final b = await r.createTripOnlySpot(tripId: trip.id, name: 'B', lat: 0, lng: 0, addedBy: 'u1');
    await r.updateStop(StopsCompanion(id: Value(a.id), note: Value('a' * 1500)));
    await r.updateStop(StopsCompanion(id: Value(b.id), note: Value('b' * 1500)));

    final controller = container.read(tripStopsControllerProvider.notifier);
    final result = await controller.mergeStops(keepId: a.id, stopIds: [a.id, b.id]);
    expect(result, isA<Failure<void>>());
    expect((result as Failure).error, contains('longer than 2000'));
    expect(await r.getStopsForTrip(trip.id), hasLength(2));
    expect(await controller.mergeStops(keepId: a.id, stopIds: [a.id]), isA<Failure<void>>());
  });

  test('a merge keeps the stop that comes first in the plan, else the first added', () {
    Stop stop(String id, int day) => Stop(
          id: id,
          tripId: 't',
          placeKey: id,
          name: id,
          lat: 0,
          lng: 0,
          addedBy: 'u1',
          createdAt: DateTime(2027, 1, day),
          updatedAt: DateTime(2027),
          syncStatus: 0,
        );
    final early = TripStopEntry(stop: stop('early', 1));
    final late = TripStopEntry(stop: stop('late', 2));
    final day2 = TripStopEntry(stop: stop('day2', 3), dayIndex: 1, position: 0, startMinutes: 540);
    final day1Second = TripStopEntry(stop: stop('day1b', 4), dayIndex: 0, position: 1, startMinutes: 540);
    final day1First = TripStopEntry(stop: stop('day1a', 5), dayIndex: 0, position: 0, startMinutes: 600);
    expect(stopToKeep([late, early]).stop.id, 'early');
    expect(stopToKeep([late, day2, day1Second, day1First]).stop.id, 'day1a');
  });

  testWidgets("a place's menu merges another place into it", (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final trip = await repo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
    final day = (await repo.getDaysForTrip(trip.id)).single;
    final other = await spot(trip.id, 'Bridge (2)');
    final first = await spot(trip.id, 'Bridge');
    await repo.scheduleStop(tripId: trip.id, stopId: other.id, dayId: day.id);
    await spot(trip.id, 'Shrine');

    final router = GoRouter(initialLocation: '/trips/${trip.id}/places/${first.id}', routes: [
      GoRoute(path: '/trips/:tripId', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/trips/:tripId/places/:stopId',
        builder: (_, s) => TripPlaceScreen(tripId: s.pathParameters['tripId']!, stopId: s.pathParameters['stopId']!),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('u1'), mapTilesProvider.overrideWithValue(false)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placeMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('placeMerge')));
    await tester.pumpAndSettle();
    expect(find.text('Merge into “Bridge”'), findsOneWidget);
    await tester.tap(find.text('Bridge (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Merge “Bridge (2)” into “Bridge”?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
    await tester.pumpAndSettle();

    final stops = await repo.getStopsForTrip(trip.id);
    expect(stops.map((s) => s.name).toSet(), {'Bridge', 'Shrine'});
    expect((await repo.getScheduleItemsForTrip(trip.id)).single.stopId, first.id, reason: "the merged place's day comes along");
    expect(find.text('Merged “Bridge (2)” into this place.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
