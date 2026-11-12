import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/camera/services/photo_edit_route.dart';
import 'package:trip_planner/features/photos/providers/photos_providers.dart';
import 'package:trip_planner/features/photos/screens/photo_screen.dart';
import 'package:trip_planner/features/photos/screens/photos_screen.dart';

void main() {
  late AppDatabase db;
  late List<PhotoEditArgs> edited;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    edited = [];
  });
  tearDown(() => db.close());

  Future<void> photo(
    WidgetTester tester,
    String id,
    String placeKey,
    DateTime takenAt, {
    String kind = 'original',
    String? derivedFromId,
    bool keepAsIs = false,
    String? frameId,
  }) =>
      tester.runAsync(() => db.into(db.photos).insert(PhotosCompanion.insert(
            id: id,
            placeKey: placeKey,
            localPath: '/photos/$id.jpg',
            kind: Value(kind),
            derivedFromId: Value(derivedFromId),
            keepAsIs: Value(keepAsIs),
            referenceImageId: Value(frameId),
            takenAt: Value(takenAt),
          )));

  Future<void> place(WidgetTester tester, String key, String name) => tester.runAsync(
        () => db.into(db.places).insert(PlacesCompanion.insert(placeKey: key, name: name, lat: 34.89, lng: 135.8)),
      );

  Future<GoRouter> open(WidgetTester tester, {String location = '/photos'}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/photos',
          builder: (context, state) => PhotosScreen(filter: PhotosFilter.fromQuery(state.uri.queryParameters['filter'])),
        ),
        GoRoute(path: '/photo/:id', builder: (context, state) => PhotoScreen(photoId: state.pathParameters['id']!)),
        GoRoute(
          path: '/photo-edit',
          builder: (context, state) {
            edited.add(PhotoEditArgs.fromQuery(state.uri.queryParameters)!);
            return const Scaffold(body: Text('editor'));
          },
        ),
        GoRoute(path: '/library/places/:key', builder: (context, state) => Scaffold(body: Text('place ${state.pathParameters['key']}'))),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('me')],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  List<String> shown(WidgetTester tester) => tester
      .widgetList(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('photo:')))
      .map((w) => (w.key! as ValueKey<String>).value.substring('photo:'.length))
      .toList();

  testWidgets('with no photos: says where they come from', (tester) async {
    await open(tester);
    expect(find.text('No photos yet'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('To edit'), findsOneWidget);
    expect(find.byTooltip('Edit a photo from the gallery'), findsOneWidget);
    await close(tester);
  });

  testWidgets('every photo, newest first, by day; To edit counts and filters', (tester) async {
    await place(tester, 'uji', 'Uji Bridge');
    await place(tester, 'cafe', 'Café Rose');
    await photo(tester, 'a', 'uji', DateTime(2025, 11, 7, 9));
    await photo(tester, 'b', 'cafe', DateTime(2025, 11, 8, 10));
    await photo(tester, 'c', 'uji', DateTime(2025, 11, 8, 11), keepAsIs: true);
    await photo(tester, 'c-edit', 'uji', DateTime(2025, 11, 8, 12), kind: 'edited', derivedFromId: 'a');
    await open(tester);

    expect(shown(tester), ['c-edit', 'c', 'b', 'a']);
    expect(find.text('Sat, Nov 8, 2025'), findsOneWidget);
    expect(find.text('Fri, Nov 7, 2025'), findsOneWidget);
    // Only b waits: a has an edit, c was kept as it is.
    expect(find.text('To edit · 1'), findsOneWidget);

    await tester.tap(find.text('To edit · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Café Rose'), findsOneWidget);
    expect(find.text('Uji Bridge'), findsNothing);
    expect(find.byTooltip('Keep as it is'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(shown(tester), hasLength(4));
    await close(tester);
  });

  testWidgets('by place: the place with the newest photo first', (tester) async {
    await place(tester, 'uji', 'Uji Bridge');
    await place(tester, 'cafe', 'Café Rose');
    await photo(tester, 'a', 'uji', DateTime(2025, 11, 7, 9));
    await photo(tester, 'b', 'cafe', DateTime(2025, 11, 8, 10));
    await photo(tester, 'c', 'uji', DateTime(2025, 11, 6, 11));
    await open(tester);

    await tester.tap(find.byTooltip('Group by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('By place'));
    await tester.pumpAndSettle();
    expect(find.text('Café Rose'), findsOneWidget);
    expect(find.text('Uji Bridge'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Café Rose')).dy, lessThan(tester.getTopLeft(find.text('Uji Bridge')).dy));
    expect(shown(tester), ['b', 'a', 'c']);
    await close(tester);
  });

  testWidgets("Home's link opens on To edit, even after switching to All", (tester) async {
    await place(tester, 'uji', 'Uji Bridge');
    await photo(tester, 'a', 'uji', DateTime(2025, 11, 7, 9));
    final router = await open(tester, location: '/photos?filter=edit');
    expect(find.byTooltip('Keep as it is'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Keep as it is'), findsNothing);
    router.go('/photos?filter=edit');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Keep as it is'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a photo opens next to its frame, with Edit and its place', (tester) async {
    await place(tester, 'uji', 'Uji Bridge');
    await tester.runAsync(() => db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f1',
          placeKey: const Value('uji'),
          localPath: const Value('/frames/f1.jpg'),
        )));
    await photo(tester, 'a', 'uji', DateTime(2025, 11, 7, 9), frameId: 'f1');
    await photo(tester, 'b', 'uji', DateTime(2025, 11, 7, 8));
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('photo:a')));
    await tester.pumpAndSettle();
    expect(find.text('Your shot'), findsOneWidget);
    expect(find.text('The frame'), findsOneWidget);
    expect(find.byKey(const Key('photoScreenFrame')), findsOneWidget);
    expect(find.textContaining('Fri, Nov 7, 2025 · 09:00'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    // Looking for the frame's file on disk is real I/O.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);
    expect(edited.single.photoId, 'a');
    expect(edited.single.placeKey, 'uji');
    await close(tester);
  });

  testWidgets('a photo without a frame shows alone, and opens its place', (tester) async {
    await place(tester, 'uji', 'Uji Bridge');
    await photo(tester, 'b', 'uji', DateTime(2025, 11, 7, 8));
    final router = await open(tester);
    router.push('/photo/b');
    await tester.pumpAndSettle();
    expect(find.text('The frame'), findsNothing);
    await tester.tap(find.text('Open the place'));
    await tester.pumpAndSettle();
    expect(find.text('place uji'), findsOneWidget);
    await close(tester);
  });

  test('grouping helpers', () {
    Photo p(String id, String place, DateTime t) =>
        Photo(id: id, placeKey: place, kind: 'original', localPath: '', isShared: false, keepAsIs: false, takenAt: t, createdAt: t);
    final entries = [
      PhotoEntry(photo: p('1', 'x', DateTime(2026, 1, 2, 23))),
      PhotoEntry(photo: p('2', 'y', DateTime(2026, 1, 2, 1))),
      PhotoEntry(photo: p('3', 'x', DateTime(2026, 1, 1, 5))),
    ];
    expect(groupEntriesByDay(entries).map((g) => g.$2.map((e) => e.photo.id).toList()), [
      ['1', '2'],
      ['3'],
    ]);
    expect(groupEntriesByPlace(entries).map((g) => g.$2.map((e) => e.photo.id).toList()), [
      ['1', '3'],
      ['2'],
    ]);
    expect(photoDayName(DateTime(2026, 1, 2), DateTime(2026, 1, 2, 10)), 'Today');
    expect(photoDayName(DateTime(2026, 1, 1), DateTime(2026, 1, 2, 10)), 'Yesterday');
  });
}
