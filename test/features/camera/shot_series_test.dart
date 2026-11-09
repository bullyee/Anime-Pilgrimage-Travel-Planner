import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/camera/models/shot_series.dart';
import 'package:trip_planner/features/camera/screens/shot_series_screen.dart';
import 'package:trip_planner/features/camera/services/kept_shots.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

/// A store that keeps series in memory, so widget tests need no file I/O.
class _MemoryStore extends ShotSeriesStore {
  final series = <String, ShotSeries>{};
  var _next = 0;

  @override
  Future<ShotSeries> create({
    String? placeKey,
    String? tripId,
    String? referencePath,
    String? referenceImageId,
    DateTime? now,
  }) async {
    final created = ShotSeries(
      id: 's${_next++}',
      createdAt: now ?? DateTime(2026, 11, 8),
      placeKey: placeKey,
      tripId: tripId,
      referencePath: referencePath,
      referenceImageId: referenceImageId,
    );
    return series[created.id] = created;
  }

  @override
  Future<ShotSeries?> load(String id) async => series[id];

  @override
  Future<ShotSeries> addShot(ShotSeries s, String sourcePath, {DateTime? takenAt}) async =>
      series[s.id] = s.withShots([...s.shots, SeriesShot(sourcePath, takenAt ?? DateTime(2026, 11, 8))]);

  @override
  Future<ShotSeries> saveKept(ShotSeries s, Iterable<String> kept) async => series[s.id] = s.withKept(kept);

  @override
  Future<void> discard(String id) async => series.remove(id);
}

Future<void> _place(AppDatabase db, String key) =>
    db.into(db.places).insert(PlacesCompanion.insert(placeKey: key, name: key, lat: 34.89, lng: 135.8));

void main() {
  group('ShotSeriesStore', () {
    late Directory root;
    late ShotSeriesStore store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('shot_series_test_');
      store = ShotSeriesStore(root: () async => Directory(p.join(root.path, 'shot_series')));
    });
    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('a series is written as soon as it starts, and reads back the same', () async {
      final created = await store.create(
        placeKey: 'uji',
        tripId: 'kansai',
        referencePath: '/frames/uji.jpg',
        referenceImageId: 'frame-1',
        now: DateTime(2026, 11, 8, 10),
      );
      final loaded = await store.load(created.id);
      expect(loaded, isNotNull);
      expect(loaded!.placeKey, 'uji');
      expect(loaded.tripId, 'kansai');
      expect(loaded.referencePath, '/frames/uji.jpg');
      expect(loaded.referenceImageId, 'frame-1');
      expect(loaded.createdAt, DateTime(2026, 11, 8, 10));
      expect(loaded.shots, isEmpty);
    });

    test("a shot moves out of the camera's temporary file into the series", () async {
      final camera = File(p.join(root.path, 'camera_tmp.jpg'))..writeAsBytesSync([0xFF, 0xD8, 0xFF, 1]);
      var series = await store.create(placeKey: 'uji');
      series = await store.addShot(series, camera.path, takenAt: DateTime(2026, 11, 8, 10, 1));

      expect(camera.existsSync(), isFalse);
      expect(series.shots, hasLength(1));
      final shot = File(series.shots.single.path);
      expect(shot.readAsBytesSync(), [0xFF, 0xD8, 0xFF, 1]);
      expect(p.isWithin(p.join(root.path, 'shot_series', series.id), shot.path), isTrue);

      final loaded = await store.load(series.id);
      expect(loaded!.shots.single.path, shot.path);
      expect(loaded.shots.single.takenAt, DateTime(2026, 11, 8, 10, 1));
    });

    test('after a restart, the latest series is found with its shots', () async {
      final older = await store.create(placeKey: 'tower', now: DateTime(2026, 11, 7));
      var newer = await store.create(placeKey: 'uji', now: DateTime(2026, 11, 8));
      final camera = File(p.join(root.path, 'shot.jpg'))..writeAsBytesSync([1, 2, 3]);
      newer = await store.addShot(newer, camera.path);

      final latest = await ShotSeriesStore(root: () async => Directory(p.join(root.path, 'shot_series'))).latest();
      expect(latest!.id, newer.id);
      expect(latest.shots, hasLength(1));
      expect(older.id, isNot(newer.id));
    });

    test('a folder without a readable series is cleared away', () async {
      final broken = Directory(p.join(root.path, 'shot_series', 'broken'))..createSync(recursive: true);
      File(p.join(broken.path, 'series.json')).writeAsStringSync('{not json');

      expect(await store.latest(), isNull);
      expect(broken.existsSync(), isFalse);
    });

    test('the picks are written with the series and outlive more shots', () async {
      var series = await store.create(placeKey: 'uji');
      for (final name in ['a.jpg', 'b.jpg']) {
        series = await store.addShot(series, (File(p.join(root.path, name))..writeAsBytesSync([1])).path);
      }
      final first = series.shots.first.path;
      series = await store.saveKept(series, [first, '/not/a/shot.jpg']);
      expect(series.kept, {first}, reason: 'only shots of the series can be kept');

      series = await store.addShot(series, (File(p.join(root.path, 'c.jpg'))..writeAsBytesSync([1])).path);
      final loaded = await store.load(series.id);
      expect(loaded!.shots, hasLength(3));
      expect(loaded.kept, {first});
    });

    test('a shot whose file has gone is dropped, with its pick', () async {
      var series = await store.create();
      for (final name in ['a.jpg', 'b.jpg']) {
        series = await store.addShot(series, (File(p.join(root.path, name))..writeAsBytesSync([1])).path);
      }
      series = await store.saveKept(series, series.shots.map((s) => s.path));
      File(series.shots.first.path).deleteSync();

      final loaded = await store.load(series.id);
      expect(loaded!.shots.map((s) => s.path), [series.shots.last.path]);
      expect(loaded.kept, {series.shots.last.path});
    });

    test('discarding deletes the series with every shot in it', () async {
      var series = await store.create();
      final camera = File(p.join(root.path, 'shot.jpg'))..writeAsBytesSync([1]);
      series = await store.addShot(series, camera.path);
      final shotPath = series.shots.single.path;

      await store.discard(series.id);
      expect(File(shotPath).existsSync(), isFalse);
      expect(await store.load(series.id), isNull);
      expect(await store.latest(), isNull);
    });
  });

  group('saveKeptShots', () {
    late AppDatabase db;
    late Directory docs;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      docs = await Directory.systemTemp.createTemp('kept_shots_test_');
      PathProviderPlatform.instance = _FakePathProvider(docs.path);
      await _place(db, 'uji');
    });
    tearDown(() async {
      await db.close();
      if (await docs.exists()) await docs.delete(recursive: true);
    });

    SeriesShot shot(String name, DateTime takenAt) {
      final file = File(p.join(docs.path, name))..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      return SeriesShot(file.path, takenAt);
    }

    test("kept shots join the place's photos with their frame, trip and time, and go to the gallery", () async {
      final a = shot('a.jpg', DateTime(2026, 11, 8, 10));
      final b = shot('b.jpg', DateTime(2026, 11, 8, 10, 1));
      final series = ShotSeries(
        id: 's',
        createdAt: DateTime(2026, 11, 8),
        placeKey: 'uji',
        tripId: 'kansai',
        referenceImageId: 'frame-1',
        shots: [a, b],
      );
      final gallery = <String>[];

      final result = await saveKeptShots(
        series: series,
        kept: [b],
        places: DriftPlaceRepository(db),
        db: db,
        toGallery: (path) async => gallery.add(path),
      );

      expect(result.toPlace, 1);
      expect(result.toGallery, 1);
      expect(gallery, [b.path]);
      final photos = await db.select(db.photos).get();
      expect(photos, hasLength(1));
      expect(photos.single.placeKey, 'uji');
      expect(photos.single.tripId, 'kansai');
      expect(photos.single.referenceImageId, 'frame-1');
      expect(photos.single.kind, 'original');
      expect(photos.single.takenAt, DateTime(2026, 11, 8, 10, 1));
      expect(File(photos.single.localPath).existsSync(), isTrue);
    });

    test('a gallery refusal still saves every shot to the place', () async {
      final series = ShotSeries(
        id: 's',
        createdAt: DateTime(2026, 11, 8),
        placeKey: 'uji',
        shots: [shot('a.jpg', DateTime(2026, 11, 8)), shot('b.jpg', DateTime(2026, 11, 8))],
      );
      final result = await saveKeptShots(
        series: series,
        kept: series.shots,
        places: DriftPlaceRepository(db),
        db: db,
        toGallery: (path) async => throw StateError('no access to the gallery'),
      );

      expect(result.toPlace, 2);
      expect(result.toGallery, 0);
      expect(result.galleryError, isA<StateError>());
      expect(await db.select(db.photos).get(), hasLength(2));
    });

    test('without a place, shots only go to the gallery', () async {
      final series = ShotSeries(id: 's', createdAt: DateTime(2026, 11, 8), shots: [shot('a.jpg', DateTime(2026, 11, 8))]);
      final gallery = <String>[];
      final result = await saveKeptShots(
        series: series,
        kept: series.shots,
        places: DriftPlaceRepository(db),
        db: db,
        toGallery: (path) async => gallery.add(path),
      );

      expect(result.toPlace, 0);
      expect(result.toGallery, 1);
      expect(await db.select(db.photos).get(), isEmpty);
    });
  });

  group('ShotSeriesScreen', () {
    late AppDatabase db;
    late _MemoryStore store;
    late List<String> gallery;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = _MemoryStore();
      gallery = [];
    });
    tearDown(() => db.close());

    /// Opens the shots screen from a home page, with a camera that returns
    /// [shots] one by one and then backs out.
    Future<void> open(WidgetTester tester, List<String> shots, {ShotSeriesArgs args = const ShotSeriesArgs()}) async {
      final queue = [...shots];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => context.push('/shots'), child: const Text('home')),
              ),
            ),
          ),
          GoRoute(
            path: '/shots',
            builder: (context, state) => ShotSeriesScreen(
              args: args,
              camera: () async => queue.isEmpty ? null : queue.removeAt(0),
              gallery: (path) async => gallery.add(path),
            ),
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), shotSeriesStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
    }

    testWidgets('the camera reopens after each shot until the user backs out, then they pick', (tester) async {
      await open(tester, ['a.jpg', 'b.jpg', 'c.jpg']);

      expect(find.text('3 shots · tap the ones to keep'), findsOneWidget);
      expect(store.series.values.single.shots.map((s) => s.path), ['a.jpg', 'b.jpg', 'c.jpg']);
      // From several, nothing is kept until the user picks.
      expect(tester.widget<FilledButton>(find.ancestor(of: find.text('Pick to keep'), matching: find.byWidgetPredicate((w) => w is FilledButton))).onPressed, isNull);

      // The last shot is showing; tap it to keep it.
      await tester.tap(find.text('Shot 3 of 3'));
      await tester.pump();
      expect(find.text('Keep 1'), findsOneWidget);

      await tester.tap(find.text('Keep 1'));
      await tester.pumpAndSettle();

      expect(gallery, ['c.jpg']);
      expect(store.series, isEmpty, reason: 'the series and its other shots are gone once saved');
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('picks are saved as the user makes them', (tester) async {
      await open(tester, ['a.jpg', 'b.jpg']);

      await tester.tap(find.text('Shot 2 of 2'));
      await tester.pump();
      expect(store.series.values.single.kept, {'b.jpg'});
      await tester.tap(find.text('Shot 2 of 2'));
      await tester.pump();
      expect(store.series.values.single.kept, isEmpty);
    });

    testWidgets('back after Android killed the app: the picks so far, on the newest shot', (tester) async {
      final series = await store.create();
      store.series[series.id] = series.withShots([
        for (final name in ['a.jpg', 'b.jpg', 'c.jpg']) SeriesShot(name, DateTime(2026, 11, 8)),
      ]).withKept(['a.jpg']);

      await open(tester, [], args: ShotSeriesArgs(seriesId: series.id));

      expect(find.text('3 shots · tap the ones to keep'), findsOneWidget);
      expect(find.text('Shot 3 of 3'), findsOneWidget);
      await tester.tap(find.text('Keep 1'));
      await tester.pumpAndSettle();
      expect(gallery, ['a.jpg']);
      expect(store.series, isEmpty);
    });

    testWidgets('a single shot is kept unless the user says otherwise', (tester) async {
      await open(tester, ['a.jpg']);

      expect(find.text('1 shot'), findsOneWidget);
      await tester.tap(find.text('Keep 1'));
      await tester.pumpAndSettle();
      expect(gallery, ['a.jpg']);
    });

    testWidgets('backing out of the camera without a shot leaves nothing behind', (tester) async {
      await open(tester, []);

      expect(store.series, isEmpty);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('discarding asks first, then deletes the shots', (tester) async {
      await open(tester, ['a.jpg', 'b.jpg']);

      await tester.tap(find.byTooltip('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Discard these 2 shots?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      expect(store.series, isEmpty);
      expect(gallery, isEmpty);
      expect(find.text('home'), findsOneWidget);
    });
  });
}
