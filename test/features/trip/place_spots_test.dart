import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/l10n/l10n.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/providers/place_providers.dart';
import 'package:trip_planner/features/trip/models/place_spots.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/providers/trip_stop_providers.dart';
import 'package:trip_planner/features/trip/screens/trip_place_screen.dart';
import 'package:trip_planner/shared/map/app_map.dart';

void main() {
  final t0 = DateTime(2027, 6, 19, 10);

  Stop stop(String id, String name, {String? area, String? note, double lat = 34.892, double lng = 135.8075}) => Stop(
        id: id,
        tripId: 't',
        placeKey: 'p-$id',
        name: name,
        lat: lat,
        lng: lng,
        area: area,
        note: note,
        addedBy: 'u1',
        createdAt: t0,
        updatedAt: t0,
        syncStatus: 0,
      );

  NewReferenceImage frame(String id, {String? path, String? url}) =>
      NewReferenceImage(id: id, localPath: path, remoteUrl: url, createdAt: t0);

  Photo photo(String id, {String? ref, DateTime? at}) => Photo(
        id: id,
        placeKey: 'p',
        kind: 'original',
        referenceImageId: ref,
        localPath: '$id.jpg',
        isShared: false,
        keepAsIs: false,
        takenAt: at,
        createdAt: t0,
      );

  group('spotLabel', () {
    test('the note wins, first line only', () {
      expect(spotLabel(stop('a', '宇治橋 三の間', area: '宇治橋', note: '第 3 根柱子北側\n往上游'), '宇治橋'), '第 3 根柱子北側');
    });
    test('the group name in front is left out', () {
      expect(spotLabel(stop('a', '宇治橋 三の間', area: '宇治橋'), '宇治橋'), '三の間');
      expect(spotLabel(stop('a', '宇治橋・東詰', area: '宇治橋'), '宇治橋'), '東詰');
      expect(spotLabel(stop('a', 'Uji Bridge, west bank', area: 'Uji Bridge'), 'Uji Bridge'), 'west bank');
    });
    test('else the whole name', () {
      expect(spotLabel(stop('a', '宇治橋', area: '宇治橋'), '宇治橋'), '宇治橋', reason: 'nothing after the group name');
      expect(spotLabel(stop('a', '平等院'), null), '平等院');
      expect(spotLabel(stop('a', 'Gate', area: 'Cafe Rose'), 'Cafe Rose'), 'Gate');
    });
  });

  test('placeEntries: the stop\'s group, or the stop alone', () {
    final entries = [
      TripStopEntry(stop: stop('a', 'A', area: 'Rose')),
      TripStopEntry(stop: stop('b', 'B')),
      TripStopEntry(stop: stop('c', 'C', area: 'Rose')),
    ];
    expect([for (final e in placeEntries(entries, 'c')) e.stop.id], ['a', 'c']);
    expect([for (final e in placeEntries(entries, 'b')) e.stop.id], ['b']);
    expect(placeEntries(entries, 'gone'), isEmpty);
  });

  test('byDistance: nearest first, list order without a position', () {
    final near = stop('near', 'N', lat: 34.8921, lng: 135.8076);
    final far = stop('far', 'F', lat: 34.8800, lng: 135.8200);
    expect(byDistance([far, near], (s) => s), [far, near]);
    expect(byDistance([far, near], (s) => s, lat: 34.892, lng: 135.8075), [near, far]);
    expect(distanceText(42), '40 m');
    expect(distanceText(1234), '1.2 km');
  });

  group('shotFrames', () {
    test('by the frame\'s id, newest photo', () {
      final f = frame('f1', path: 'a.png');
      final shot = shotFrames(shown: [f], all: [f], photos: [
        photo('old', ref: 'f1', at: t0),
        photo('new', ref: 'f1', at: t0.add(const Duration(hours: 1))),
      ]);
      expect(shot['f1']!.id, 'new');
    });
    test('a photo of a hidden copy of the frame counts for the one shown', () {
      final shown = frame('place-f', path: 'a.png');
      final copy = frame('stop-f', path: 'a.png');
      final shot = shotFrames(shown: [shown], all: [shown, copy], photos: [photo('p', ref: 'stop-f')]);
      expect(shot.keys, ['place-f']);
    });
    test('photos of nothing, or of another frame, don\'t count', () {
      final f = frame('f1', path: 'a.png');
      final g = frame('f2', path: 'b.png');
      final shot = shotFrames(shown: [f, g], all: [f, g], photos: [photo('p', ref: 'f2'), photo('q')]);
      expect(shot.keys, ['f2']);
    });
    test('a spot with no frames counts as shot once there is a photo', () {
      expect(spotShot(shown: const [], shot: const {}, photos: [photo('p')]), isTrue);
      expect(spotShot(shown: const [], shot: const {}, photos: const []), isFalse);
      expect(spotShot(shown: [frame('f', path: 'a')], shot: const {}, photos: [photo('p')]), isFalse);
    });
  });

  test('the place page counts are plurals in every language', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.placeSpotCount(1), '1 spot');
    expect(en.placeSpotCount(3), '3 spots');
    expect(en.placeFrameCount(1), '1 frame');
    final zh = lookupAppLocalizations(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
    expect(zh.placeSpotCount(3), '3 個取景點');
    expect(zh.placeShotCount(2), '已拍 2');
    expect(lookupAppLocalizations(const Locale('ja')).placeFrameCount(2), '比較画像 2 枚');
  });

  group('TripPlaceScreen', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester, ProviderContainer container, String tripId, String stopId) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/trips/$tripId/places/$stopId', routes: [
        GoRoute(path: '/trips/:tripId', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/trips/:tripId/places/:stopId',
          builder: (_, s) => TripPlaceScreen(tripId: s.pathParameters['tripId']!, stopId: s.pathParameters['stopId']!),
        ),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('lists a group\'s spots by note or short name and filters the unshot', (tester) async {
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u1'),
        mapTilesProvider.overrideWithValue(false),
      ]);
      addTearDown(container.dispose);
      final trips = container.read(tripRepositoryProvider);
      final places = container.read(placeRepositoryProvider);

      late String firstId;
      await tester.runAsync(() async {
        final trip = await trips.createTrip(title: 'Kansai', ownerId: 'u1', dayCount: 1);
        final a = await trips.createTripOnlySpot(tripId: trip.id, name: '宇治橋 三の間', lat: 34.8921, lng: 135.8075, addedBy: 'u1', area: '宇治橋');
        final b = await trips.createTripOnlySpot(tripId: trip.id, name: '宇治橋 東詰', lat: 34.8918, lng: 135.8090, addedBy: 'u1', area: '宇治橋');
        await trips.createTripOnlySpot(tripId: trip.id, name: '平等院', lat: 34.889, lng: 135.807, addedBy: 'u1');
        firstId = '${trip.id}/${b.id}';
        final fa = await places.addReferenceImage(stopId: a.id, localPath: 'missing-a.png');
        await places.addReferenceImage(stopId: b.id, localPath: 'missing-b.png');
        await places.addPhoto(placeKey: a.placeKey, localPath: 'missing-shot.jpg', tripId: trip.id, referenceImageId: fa.id);
      });

      final ids = firstId.split('/');
      await pump(tester, container, ids[0], ids[1]);

      expect(find.text('宇治橋'), findsOneWidget, reason: 'the place has the name');
      expect(find.text('2 spots · 1 shot'), findsOneWidget);
      expect(find.text('三の間'), findsOneWidget);
      expect(find.text('東詰'), findsOneWidget);
      expect(find.text('平等院'), findsNothing, reason: 'not in the group');
      expect(find.bySemanticsLabel('Your photo of this frame'), findsOneWidget);

      await tester.tap(find.byKey(const Key('placeUnshotChip')));
      await tester.pumpAndSettle();
      expect(find.text('三の間'), findsNothing);
      expect(find.text('東詰'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
