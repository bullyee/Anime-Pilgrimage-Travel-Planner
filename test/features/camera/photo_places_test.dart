import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/camera/services/photo_edit_route.dart';
import 'package:trip_planner/features/camera/widgets/capture_sheets.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/services/photo_trip.dart';
import 'package:trip_planner/features/poi/services/media_asset_service.dart';
import 'package:trip_planner/features/trip/controllers/trips_controller.dart' show isoDate;
import 'package:trip_planner/features/trip/screens/new_spot_screen.dart';

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

Future<void> _place(AppDatabase db, String key, String name, {String? anime}) async {
  await db.into(db.places).insert(PlacesCompanion.insert(placeKey: key, name: name, lat: 34.89, lng: 135.8));
  if (anime != null) {
    await db.into(db.labels).insert(LabelsCompanion.insert(id: 'label-$key', kind: 'anime', name: anime));
    await db.into(db.placeLabels).insert(PlaceLabelsCompanion.insert(placeKey: key, labelId: 'label-$key'));
  }
}

/// A trip of [days] dated days from [start], with a stop at each of [placeKeys].
Future<void> _trip(
  AppDatabase db,
  String id, {
  String? start,
  int days = 2,
  List<String> placeKeys = const [],
  bool deleted = false,
}) async {
  await db.into(db.trips).insert(TripsCompanion.insert(
        id: id,
        title: 'Trip $id',
        ownerId: 'u1',
        startDate: Value(start),
        dayCount: Value(days),
        deletedAt: Value(deleted ? DateTime(2026) : null),
      ));
  for (var i = 0; i < days; i++) {
    await db.into(db.tripDays).insert(TripDaysCompanion.insert(id: '$id-day$i', tripId: id, sortKey: 'a$i'));
  }
  for (final key in placeKeys) {
    await db.into(db.stops).insert(StopsCompanion.insert(
          id: '$id-$key',
          tripId: id,
          placeKey: key,
          name: key,
          lat: 34.89,
          lng: 135.8,
          addedBy: 'u1',
        ));
  }
}

void main() {
  group('the editor route', () {
    test('a path with % and spaces arrives as it was sent (#84)', () {
      const path = '/data/user/0/app/cache/100% done & more #1 宇治橋.jpg';
      const args = PhotoEditArgs(
        path: path,
        placeKey: 'anitabi:12',
        tripId: 'trip-1',
        photoId: 'photo-1',
        referencePath: '/frames/ep 3 50%.jpg',
        referenceImageId: 'frame-1',
        capture: true,
      );
      final location = Uri.parse(args.location);
      expect(location.path, '/photo-edit');
      final read = PhotoEditArgs.fromQuery(location.queryParameters)!;
      expect(read.path, path);
      expect(read.referencePath, '/frames/ep 3 50%.jpg');
      expect((read.placeKey, read.tripId, read.photoId, read.referenceImageId), ('anitabi:12', 'trip-1', 'photo-1', 'frame-1'));
      expect((read.capture, read.upload), (true, false));
      expect(() => Uri.decodeComponent(read.path), throwsArgumentError,
          reason: 'what the old second decode did with this name');
    });

    test('the old POI route supplies the place, and a query without a path is refused', () {
      expect(PhotoEditArgs.fromQuery({'ref': '/a.jpg'}), isNull);
    });
  });

  group('tripForPhoto', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _place(db, 'uji', 'Uji Bridge');
      await _place(db, 'tower', 'Kyoto Tower');
    });
    tearDown(() => db.close());

    test('a photo goes to the trip that has the place on that day', () async {
      await _trip(db, 'kansai', start: '2026-11-01', days: 3, placeKeys: ['uji']);
      expect(await tripForPhoto(db, 'uji', DateTime(2026, 11, 1, 9)), 'kansai');
      expect(await tripForPhoto(db, 'uji', DateTime(2026, 11, 3, 23, 59)), 'kansai', reason: 'the last day counts');
      expect(await tripForPhoto(db, 'uji', DateTime(2026, 11, 4)), isNull, reason: 'the day after');
      expect(await tripForPhoto(db, 'uji', DateTime(2026, 10, 31)), isNull, reason: 'the day before');
      expect(await tripForPhoto(db, 'tower', DateTime(2026, 11, 2)), isNull, reason: 'not a stop of the trip');
    });

    test('the trip that started last wins; undated, deleted trips and deleted stops are skipped', () async {
      await _trip(db, 'long', start: '2026-11-01', days: 10, placeKeys: ['uji']);
      await _trip(db, 'weekend', start: '2026-11-07', days: 2, placeKeys: ['uji']);
      await _trip(db, 'someday', placeKeys: ['uji']);
      await _trip(db, 'gone', start: '2026-11-08', days: 1, placeKeys: ['uji'], deleted: true);
      await _trip(db, 'dropped', start: '2026-11-08', days: 1, placeKeys: ['uji']);
      await (db.update(db.stops)..where((s) => s.tripId.equals('dropped')))
          .write(StopsCompanion(deletedAt: Value(DateTime(2026))));

      expect(await tripForPhoto(db, 'uji', DateTime(2026, 11, 8)), 'weekend');
      expect(await tripForPhoto(db, 'uji', DateTime(2026, 11, 3)), 'long');
    });
  });

  group('persistMediaAsset', () {
    late AppDatabase db;
    late Directory docs;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      docs = await Directory.systemTemp.createTemp('photo_places_test_');
      PathProviderPlatform.instance = _FakePathProvider(docs.path);
    });
    tearDown(() async {
      await db.close();
      if (await docs.exists()) await docs.delete(recursive: true);
    });

    test('a photo of a new place lands in photos with its kind, source photo, trip and date', () async {
      await _place(db, 'uji', 'Uji Bridge');
      final source = File('${docs.path}/edit.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      final takenAt = DateTime(2026, 11, 2, 17, 30);

      final ok = await persistPlacePhoto(
        places: DriftPlaceRepository(db),
        source: source,
        placeKey: 'uji',
        referenceImageId: 'frame-1',
        kind: 'edited',
        derivedFromId: 'photo-0',
        tripId: 'kansai',
        takenAt: takenAt,
      );

      expect(ok, isTrue);
      final photo = (await DriftPlaceRepository(db).getPhotosForPlace('uji')).single;
      expect((photo.kind, photo.derivedFromId, photo.tripId, photo.referenceImageId), ('edited', 'photo-0', 'kansai', 'frame-1'));
      expect(photo.takenAt, takenAt);
      expect(File(photo.localPath).existsSync(), isTrue, reason: 'a copy in the app');
      expect(await db.select(db.mediaAssets).get(), isEmpty, reason: 'photos no longer go to the old table');
    });

    test('a key that is not a place fails, and leaves no copy behind', () async {
      final source = File('${docs.path}/edit.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      final ok = await persistPlacePhoto(places: DriftPlaceRepository(db), source: source, placeKey: 'nowhere');
      expect(ok, isFalse);
      expect(Directory('${docs.path}/camera_photos').existsSync(), isFalse);
    });
  });

  group('the place sheet', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await _place(db, 'uji', 'Uji Bridge', anime: 'Hibike! Euphonium');
      await _place(db, 'motosu', 'Lake Motosu', anime: 'Yuru Camp');
      await _place(db, 'tower', 'Kyoto Tower');
      await _trip(db, 'today', start: isoDate(DateTime.now()), days: 2, placeKeys: ['tower']);
    });
    tearDown(() => db.close());

    Future<void> pumpOpener(WidgetTester tester, Future<Object?> Function(BuildContext, WidgetRef) open,
        void Function(Object?) done) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('u1')],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(onPressed: () async => done(await open(context, ref)), child: const Text('open')),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets("today's trip comes first, and search narrows by name or anime", (tester) async {
      Object? picked = 'nothing yet';
      await pumpOpener(tester, (context, ref) => pickPlaceKey(context, ref), (v) => picked = v);

      expect(find.text("ON TODAY'S TRIP"), findsOneWidget);
      final tower = tester.getTopLeft(find.text('Kyoto Tower')).dy;
      expect(tower, lessThan(tester.getTopLeft(find.text('Lake Motosu')).dy));
      expect(tower, lessThan(tester.getTopLeft(find.text('Uji Bridge')).dy));

      await tester.enterText(find.byKey(const Key('placeSheetSearch')), 'euphonium');
      await tester.pumpAndSettle();
      expect(find.text('Uji Bridge'), findsOneWidget);
      expect(find.text('Lake Motosu'), findsNothing);
      expect(find.text('Kyoto Tower'), findsNothing);

      await tester.tap(find.text('Uji Bridge'));
      await tester.pumpAndSettle();
      expect(picked, 'uji');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a new place on top of a saved one offers that one, even away from the library', (tester) async {
      // Wide enough for the map's attribution line in the test font.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Where the map starts when nothing is known: over Japan.
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'center', name: 'Matsumoto', lat: 36.2048, lng: 138.2529));
      Object? returned = 'nothing yet';
      final router = GoRouter(initialLocation: '/start', routes: [
        GoRoute(
          path: '/start',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async => returned = await context.push<String>('/new'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(path: '/new', builder: (_, _) => const NewSpotScreen(returnsPlaceKey: true)),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('u1')],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Test spot');
      await tester.tap(find.text('Save to library'));
      await tester.pumpAndSettle();
      expect(find.text('“Matsumoto” is already in your library'), findsOneWidget);
      await tester.tap(find.text('Use it'));
      await tester.pumpAndSettle();
      expect(returned, 'center');
      expect(await (db.select(db.places)..where((p) => p.name.equals('Test spot'))).get(), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets("the editor's picker ticks the current place and offers no place or a new one", (tester) async {
      Object? picked = 'nothing yet';
      await pumpOpener(tester, (context, ref) => pickPhotoPlace(context, ref, current: 'motosu'), (v) => picked = v);

      final motosuRow = find.ancestor(of: find.text('Lake Motosu'), matching: find.byType(ListTile));
      expect(find.descendant(of: motosuRow, matching: find.byIcon(Icons.check)), findsOneWidget);
      final noPlaceRow = find.ancestor(of: find.text('No place'), matching: find.byType(ListTile));
      expect(find.descendant(of: noPlaceRow, matching: find.byIcon(Icons.check)), findsNothing);

      await tester.tap(find.text('New place'));
      await tester.pumpAndSettle();
      expect((picked as PhotoPlaceChoice).createNew, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
