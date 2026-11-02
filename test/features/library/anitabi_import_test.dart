import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/anime/models/bangumi_subject.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/screens/anitabi_import_screen.dart';
import 'package:trip_planner/features/library/services/anitabi_import.dart';

AnitabiSpot _spot(String id, String name, {bool located = true, String? image}) => AnitabiSpot(
      id: id,
      name: name,
      lat: located ? 34.8935 : null,
      lng: located ? 135.8075 : null,
      episode: '1',
      seconds: 192,
      imageUrl: image,
      origin: '©Kyoto Animation',
      originUrl: 'https://example.org/frame',
    );

void main() {
  test('a spot is read from Anitabi\'s static data', () {
    final spot = AnitabiSpot.fromJson({
      'id': 'abc',
      'cn': '宇治桥',
      'name': '宇治橋',
      'geo': [34.8935, 135.8075],
      'ep': 3,
      's': 252,
      'mark': 'From the east bank',
      'image': 'https://image.anitabi.cn/points/1.jpg?plan=h160',
      'origin': 'Anitabi user',
      'originURL': 'https://example.org',
    })!;
    expect(spot.placeKey, 'anitabi:abc');
    expect(spot.name, '宇治橋', reason: 'the original-language name');
    expect(spot.hasLocation, isTrue);
    expect(spot.scene, 'Ep 3 · 4:12');
    expect(spot.imageUrl, endsWith('?plan=h360'));
    expect(AnitabiSpot.fromJson({'id': 'x', 'cn': '只有中文'})!.name, '只有中文');
    expect(AnitabiSpot.fromJson({'id': 'x', 'name': 'No geo'})!.hasLocation, isFalse);
    expect(AnitabiSpot.fromJson({'name': 'No id'}), isNull);
  });

  group('importSpots', () {
    late AppDatabase db;
    late PlaceRepository places;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      places = DriftPlaceRepository(db);
    });
    tearDown(() => db.close());

    test('new spots become saved, labelled places with their frame; others are counted, not changed', () async {
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'anitabi:old',
            name: 'My own name for it',
            lat: 1,
            lng: 2,
            visibility: const Value('trip_only'),
          ));
      final downloads = <String>[];
      final summary = await AnitabiImport.importSpots(
        places: places,
        bangumiId: '115908',
        animeName: '響け！ユーフォニアム',
        spots: [
          _spot('new', '宇治橋', image: 'https://image.anitabi.cn/1.jpg'),
          _spot('old', '朝霧橋', image: 'https://image.anitabi.cn/2.jpg'),
          _spot('far', '大吉山', located: false),
        ],
        download: (url) async {
          downloads.add(url);
          return '/frames/${downloads.length}.jpg';
        },
      );
      await summary.frames;

      expect((summary.added, summary.alreadySaved, summary.withoutLocation, summary.framesPending), (1, 1, 1, 1));
      expect(downloads, ['https://image.anitabi.cn/1.jpg'], reason: 'frames only for places that are new');

      final fresh = (await places.getPlace('anitabi:new'))!;
      expect(fresh.visibility, 'saved');
      expect(fresh.source, 'Anitabi');
      final old = (await places.getPlace('anitabi:old'))!;
      expect(old.name, 'My own name for it', reason: 'a saved place keeps its own facts');
      expect(old.visibility, 'saved');
      expect(await places.getPlace('anitabi:far'), isNull);

      final anime = (await places.getLabels(kind: 'anime')).single;
      expect(anime.bangumiId, '115908');
      expect((await places.getLabelsForPlace('anitabi:old')).single.id, anime.id);
      final frame = (await places.getReferenceImagesForPlace('anitabi:new')).single;
      expect(frame.localPath, '/frames/1.jpg');
      expect(frame.episode, '1');
      expect(frame.timestampS, 192);
      expect(frame.source, '©Kyoto Animation');
      expect(frame.animeLabelId, anime.id);
    });
  });

  testWidgets('find the anime, tick the spots and import them into the library', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final router = GoRouter(initialLocation: '/start', routes: [
      GoRoute(
        path: '/start',
        builder: (context, _) => Scaffold(
          body: TextButton(onPressed: () => context.push('/import'), child: const Text('open import')),
        ),
      ),
      GoRoute(
        path: '/import',
        builder: (_, _) => AnitabiImportScreen(
          searchAnime: (q) async => [const BangumiSubject(id: '115908', name: '響け！ユーフォニアム', nameCn: '吹响吧！上低音号')],
          loadWork: (id) async => AnitabiWork(title: '響け！ユーフォニアム', spots: [
            _spot('1', '宇治橋'),
            _spot('2', '朝霧橋'),
            _spot('3', '大吉山', located: false),
          ]),
        ),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('u1')],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open import'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('animeSearchField')), 'euphonium');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('吹响吧！上低音号'), findsOneWidget, reason: 'the Chinese title shows under the Japanese one');
    await tester.tap(find.text('響け！ユーフォニアム'));
    await tester.pumpAndSettle();
    expect(find.text('2 spots · 1 without a location'), findsOneWidget);
    expect(find.text('Import 2 spots'), findsOneWidget, reason: 'everything importable starts ticked');

    await tester.tap(find.text('朝霧橋'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('anitabiImportButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to the library'));
    await tester.pumpAndSettle();

    final places = DriftPlaceRepository(db);
    expect(await places.getPlace('anitabi:1'), isNotNull);
    expect(await places.getPlace('anitabi:2'), isNull, reason: 'it was unticked');
    expect(find.text('open import'), findsOneWidget, reason: 'back where the import was opened');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
