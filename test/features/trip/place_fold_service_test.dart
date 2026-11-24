import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/trip/models/place_spots.dart';
import 'package:trip_planner/features/trip/providers/trip_place_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/services/place_fold_service.dart';
import 'package:trip_planner/features/trip/widgets/place_fold_banner.dart';

/// A group of stops folds into one stop: its members' positions and short
/// names go onto their frames, and nothing the user made is lost.
void main() {
  final t0 = DateTime(2027, 6, 1, 9);

  /// The trip "Uji": the group 宇治橋 of 東詰 (planned first, on day 1) and
  /// 三の間 (day 2, with a library place and its frame), the unplanned group
  /// Cafe of c-2 and c-1, and 平等院 in no group. [laterFirst] swaps when the
  /// stops were added, which isn't synced and mustn't matter.
  Future<void> seed(AppDatabase db, {bool laterFirst = false, String sharing = 'private'}) async {
    DateTime added(int n) => t0.add(Duration(minutes: laterFirst ? 10 - n : n));
    await db.into(db.trips).insert(TripsCompanion.insert(id: 't', title: 'Uji', ownerId: 'u1', sharing: Value(sharing), dayCount: const Value(2)));
    await db.into(db.tripDays).insert(TripDaysCompanion.insert(id: 'd1', tripId: 't', sortKey: 'a0'));
    await db.into(db.tripDays).insert(TripDaysCompanion.insert(id: 'd2', tripId: 't', sortKey: 'a1'));
    await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'pl-bay', name: '宇治橋 三の間', lat: 34.8921, lng: 135.8075));
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'lib-bay',
          placeKey: const Value('pl-bay'),
          localPath: const Value('/lib/bay.png'),
        ));
    Future<void> stop(String id, String name, {String? area, double lat = 34.892, double lng = 135.808, String? placeKey, int n = 0}) =>
        db.into(db.stops).insert(StopsCompanion.insert(
              id: id,
              tripId: 't',
              placeKey: placeKey ?? 'pl-$id',
              name: name,
              lat: lat,
              lng: lng,
              area: Value(area),
              note: Value(id == 's-bay' ? 'Third bay, upstream side' : null),
              addedBy: 'u1',
              createdAt: Value(added(n)),
              syncStatus: const Value(0),
            ));
    await stop('s-gate', '宇治橋 東詰', area: '宇治橋', lat: 34.8918, lng: 135.8090, n: 1);
    await stop('s-bay', '宇治橋 三の間', area: '宇治橋', lat: 34.8921, lng: 135.8075, placeKey: 'pl-bay', n: 2);
    await stop('c-2', 'Cafe counter', area: 'Cafe', n: 3);
    await stop('c-1', 'Cafe window', area: 'Cafe', n: 4);
    await stop('s-other', '平等院', n: 5);
    Future<void> item(String id, String stopId, String dayId) => db.into(db.scheduleItems).insert(
          ScheduleItemsCompanion.insert(id: id, tripId: 't', stopId: stopId, dayId: dayId, sortKey: 'a0', syncStatus: const Value(0)),
        );
    await item('i-gate', 's-gate', 'd1');
    await item('i-bay', 's-bay', 'd2');
    Future<void> frame(String id, String stopId, String path, {String? note, double? lat, double? lng}) =>
        db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
              id: id,
              stopId: Value(stopId),
              localPath: Value(path),
              note: Value(note),
              lat: Value(lat),
              lng: Value(lng),
            ));
    await frame('f-gate', 's-gate', '/f/gate.png');
    await frame('f-bay', 's-bay', '/f/bay.png');
    await frame('f-pillar', 's-bay', '/f/pillar.png', note: '柱の陰', lat: 34.89216, lng: 135.80752);
    await db.into(db.labels).insert(LabelsCompanion.insert(id: 'anime', kind: 'anime', name: 'Hibike'));
    await db.into(db.labels).insert(LabelsCompanion.insert(id: 'food', kind: 'tag', name: 'Food'));
    await db.into(db.stopLabels).insert(StopLabelsCompanion.insert(stopId: 's-bay', labelId: 'anime'));
    await db.into(db.stopLabels).insert(StopLabelsCompanion.insert(stopId: 's-gate', labelId: 'food'));
    // A photo of a frame of 三の間, and one of its library place's frame.
    await db.into(db.photos).insert(PhotosCompanion.insert(
          id: 'ph-bay',
          placeKey: 'pl-bay',
          kind: const Value('original'),
          localPath: '/p/bay.jpg',
          tripId: const Value('t'),
          referenceImageId: const Value('f-bay'),
        ));
    await db.into(db.photos).insert(PhotosCompanion.insert(
          id: 'ph-lib',
          placeKey: 'pl-bay',
          kind: const Value('original'),
          localPath: '/p/lib.jpg',
          referenceImageId: const Value('lib-bay'),
        ));
  }

  group('folding', () {
    late AppDatabase db;
    late DriftTripRepository repo;
    late PlaceFoldService service;
    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = DriftTripRepository(db, null, 'u1');
      service = PlaceFoldService(db, repo);
      await seed(db);
    });
    tearDown(() => db.close());

    Future<Stop> stop(String id) => (db.select(db.stops)..where((s) => s.id.equals(id))).getSingle();
    Future<List<NewReferenceImage>> framesOf(String stopId) =>
        (db.select(db.newReferenceImages)..where((f) => f.stopId.equals(stopId))).get();

    test('the first stop in the plan stays, named after the group, and the others go', () async {
      expect(await service.foldTrip('t'), 2);

      final kept = await stop('s-gate');
      expect(kept.name, '宇治橋');
      expect(kept.area, isNull);
      expect(kept.note, isNull, reason: 'a member\'s note names its spot, not the place');
      expect(kept.syncStatus, 1);
      final bay = await stop('s-bay');
      expect(bay.deletedAt, isNotNull);
      expect(bay.mergedInto, 's-gate');
      expect((await stop('c-1')).name, 'Cafe', reason: 'unplanned: the smallest id');
      final counter = await stop('c-2');
      expect((counter.deletedAt, counter.area, counter.name), (null, null, 'Cafe counter'), reason: 'no frame to be a spot of: a place of its own');
      expect((await stop('s-other')).name, '平等院');
    });

    test("a member's note that doesn't fit on a spot goes into the place's note", () async {
      await (db.update(db.stops)..where((s) => s.id.equals('s-bay')))
          .write(const StopsCompanion(note: Value('Third bay, upstream side\nBring a tripod')));
      await service.foldTrip('t');
      expect((await stop('s-gate')).note, 'Third bay, upstream side\nBring a tripod');
      final bay = (await framesOf('s-gate')).firstWhere((f) => f.localPath == '/f/bay.png');
      expect(bay.note, 'Third bay, upstream side', reason: 'its first line still names the spot');
    });

    test('frames take their stop\'s position and short name, and nothing is lost', () async {
      await service.foldTrip('t');
      final frames = {for (final f in await framesOf('s-gate')) f.localPath: f};
      expect(frames.keys.toSet(), {'/f/gate.png', '/f/bay.png', '/f/pillar.png', '/lib/bay.png'});
      expect(frames['/f/gate.png']!.note, '東詰');
      expect(frames['/f/gate.png']!.lat, 34.8918);
      expect(frames['/f/bay.png']!.note, 'Third bay, upstream side', reason: 'the stop\'s note first, as on the place page');
      expect(frames['/f/bay.png']!.lng, 135.8075);
      expect(frames['/f/pillar.png']!.note, '柱の陰', reason: 'a frame\'s own note stays');
      expect(frames['/f/pillar.png']!.lat, 34.89216);
      final copy = frames['/lib/bay.png']!;
      expect(copy.placeKey, isNull, reason: 'a copy for the trip, the library\'s own untouched');
      expect(copy.note, 'Third bay, upstream side');
      expect((await (db.select(db.newReferenceImages)..where((f) => f.id.equals('lib-bay'))).getSingle()).stopId, isNull);

      final labels = await (db.select(db.stopLabels)..where((l) => l.stopId.equals('s-gate'))).get();
      expect({for (final l in labels) l.labelId}, {'anime', 'food'});
      final items = await (db.select(db.scheduleItems)..where((i) => i.deletedAt.isNull())).get();
      expect({for (final i in items) i.id: (i.stopId, i.dayId)}, {
        'i-gate': ('s-gate', 'd1'),
        'i-bay': ('s-gate', 'd2'),
      });
    });

    test('the photos still count as shot on the place page', () async {
      await service.foldTrip('t');
      final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      final own = await container.read(tripFramesProvider('t').future);
      final library = await container.read(tripLibraryFramesProvider('t').future);
      final photos = await container.read(tripPhotosProvider('t').future);
      expect({for (final p in photos) p.id}, {'ph-bay', 'ph-lib'});

      final kept = await stop('s-gate');
      final spots = placeSpots(
        stops: [kept],
        framesOf: (s) => placeFramesOf(
          own: [for (final f in own) if (f.stopId == s.id) f],
          library: [for (final f in library) if (f.placeKey == s.placeKey) f],
        ),
      );
      expect({for (final s in spots) s.label}, {'東詰', 'Third bay, upstream side', '柱の陰'});
      final bay = spots.singleWhere((s) => s.label == 'Third bay, upstream side');
      expect(bay.frames, hasLength(2), reason: 'its frame and the library\'s, one spot');
      final shot = shotFrames(shown: bay.frames, all: [...own, ...library], photos: photos);
      expect(shot.length, 2, reason: 'the library photo counts for its copy');
      final gate = spots.singleWhere((s) => s.label == '東詰');
      expect(shotFrames(shown: gate.frames, all: [...own, ...library], photos: photos), isEmpty);
    });

    test('folding again does nothing', () async {
      await service.foldTrip('t');
      Future<List<Object>> snapshot() async => [
            ...await db.select(db.stops).get(),
            ...await db.select(db.newReferenceImages).get(),
            ...await db.select(db.scheduleItems).get(),
          ];
      final before = await snapshot();
      expect(await service.foldTrip('t'), 0);
      expect(await snapshot(), before);
    });

    test('a shared trip with changes not uploaded yet waits', () async {
      expect(await service.hasUnsyncedChanges('t'), isFalse);
      await service.foldTrip('t');
      expect(await service.hasUnsyncedChanges('t'), isTrue);
    });
  });

  test('two phones with the same trip keep the same stops', () async {
    final a = AppDatabase.forTesting(NativeDatabase.memory());
    final b = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(a.close);
    addTearDown(b.close);
    await seed(a);
    await seed(b, laterFirst: true);
    await PlaceFoldService(a, DriftTripRepository(a, null, 'u1')).foldTrip('t');
    await PlaceFoldService(b, DriftTripRepository(b, null, 'u2')).foldTrip('t');
    Future<List<String>> live(AppDatabase db) async =>
        [for (final s in await (db.select(db.stops)..where((s) => s.deletedAt.isNull())..orderBy([(s) => OrderingTerm(expression: s.id)])).get()) s.id];
    // c-2 has no frame to be a spot of Cafe, so it stays a place of its own.
    expect(await live(a), ['c-1', 'c-2', 's-gate', 's-other']);
    expect(await live(b), await live(a));
  });

  test("a record it can't read folds nothing, and a write replaces it whole", () async {
    final dir = await Directory.systemTemp.createTemp('fold');
    addTearDown(() => dir.delete(recursive: true));
    final store = FilePlaceFoldStore(directory: () async => dir);
    expect((await store.read()).since, isNull, reason: 'no file yet: the first run');

    File('${dir.path}/place_fold.json').writeAsStringSync('{"since": 1, "do');
    expect(store.read, throwsA(anything));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seed(db);
    final service = PlaceFoldService(db, DriftTripRepository(db, null, 'u1'));
    await expectLater(service.foldPrivateTripsOnce(store), throwsA(anything));
    expect((await (db.select(db.stops)..where((s) => s.deletedAt.isNotNull())).get()), isEmpty);

    await store.write(PlaceFoldState(since: DateTime(2026, 11, 1), done: const {'t'}));
    expect((await store.read()).done, {'t'});
    expect(File('${dir.path}/place_fold.json.tmp').existsSync(), isFalse);
  });

  test('private trips fold once, the first time; shared ones and newer ones wait', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftTripRepository(db, null, 'u1');
    final service = PlaceFoldService(db, repo);
    await seed(db);
    final shared = await repo.createTrip(title: 'Shared', ownerId: 'u1', dayCount: 1);
    await (db.update(db.trips)..where((t) => t.id.equals(shared.id))).write(const TripsCompanion(sharing: Value('group')));
    await repo.createTripOnlySpot(tripId: shared.id, name: 'A', lat: 0, lng: 0, addedBy: 'u1', area: 'G');
    await repo.createTripOnlySpot(tripId: shared.id, name: 'B', lat: 0, lng: 0, addedBy: 'u1', area: 'G');

    final store = InMemoryPlaceFoldStore();
    final since = DateTime.now().add(const Duration(seconds: 5));
    expect(await service.foldPrivateTripsOnce(store, now: since), 2);
    expect(store.state.done, contains('t'));
    expect(store.state.since, since);
    expect((await repo.getStopsForTrip(shared.id)).where((s) => s.area == 'G'), hasLength(2), reason: 'shared: an owner or editor decides');

    // A private trip made with this version keeps the groups made in it.
    final fresh = await repo.createTrip(title: 'New', ownerId: 'u1', dayCount: 1);
    await (db.update(db.trips)..where((t) => t.id.equals(fresh.id))).write(TripsCompanion(createdAt: Value(since.add(const Duration(minutes: 1)))));
    await repo.createTripOnlySpot(tripId: fresh.id, name: 'A', lat: 0, lng: 0, addedBy: 'u1', area: 'G');
    await repo.createTripOnlySpot(tripId: fresh.id, name: 'B', lat: 0, lng: 0, addedBy: 'u1', area: 'G');
    expect(await service.foldPrivateTripsOnce(store), 0);
    expect((await repo.getStopsForTrip(fresh.id)).where((s) => s.area == 'G'), hasLength(2));
    expect(store.state.done, containsAll(['t', fresh.id]));
  });

  group('banner', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await seed(db, sharing: 'group');
    });
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester, {required bool canEdit}) async {
      final trip = await tester.runAsync(() => (db.select(db.trips)..where((t) => t.id.equals('t'))).getSingle());
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u1'),
          canEditTripProvider.overrideWith((ref, id) => canEdit),
        ],
        child: MaterialApp(home: Scaffold(body: PlaceFoldBanner(trip: trip!))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a viewer doesn\'t see it', (tester) async {
      await pump(tester, canEdit: false);
      expect(find.byKey(const Key('placeFoldBanner')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an editor turns the groups into places, and it goes', (tester) async {
      await pump(tester, canEdit: true);
      expect(find.byKey(const Key('placeFoldBanner')), findsOneWidget);
      await tester.tap(find.text('Turn into places'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('placeFoldConfirm')));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      expect(find.text('Made 2 places.'), findsOneWidget);
      expect(find.byKey(const Key('placeFoldBanner')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
