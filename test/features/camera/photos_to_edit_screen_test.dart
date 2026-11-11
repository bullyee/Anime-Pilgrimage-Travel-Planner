import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/camera/screens/photos_to_edit_screen.dart';
import 'package:trip_planner/features/camera/services/photo_edit_route.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

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
    String? tripId,
    String? frameId,
    String kind = 'original',
    String? derivedFromId,
  }) => tester.runAsync(
    () => db
        .into(db.photos)
        .insert(
          PhotosCompanion.insert(
            id: id,
            placeKey: placeKey,
            localPath: '/photos/$id.jpg',
            tripId: Value(tripId),
            referenceImageId: Value(frameId),
            kind: Value(kind),
            derivedFromId: Value(derivedFromId),
            takenAt: Value(takenAt),
          ),
        ),
  );

  Future<void> place(WidgetTester tester, String key, String name) => tester.runAsync(
    () => db.into(db.places).insert(PlacesCompanion.insert(placeKey: key, name: name, lat: 34.89, lng: 135.8)),
  );

  Future<void> open(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/photos-to-edit',
      routes: [
        GoRoute(path: '/photos-to-edit', builder: (context, state) => const PhotosToEditScreen()),
        GoRoute(
          path: '/photo-edit',
          builder: (context, state) {
            edited.add(PhotoEditArgs.fromQuery(state.uri.queryParameters)!);
            return const Scaffold(body: Text('editor'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('me')],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  List<String> listed(WidgetTester tester) => tester
      .widgetList(find.byWidgetPredicate((w) => w.key is ValueKey<String>))
      .map((w) => (w.key! as ValueKey<String>).value)
      .where((k) => k.startsWith('photoToEdit:'))
      .map((k) => k.substring('photoToEdit:'.length))
      .toList();

  testWidgets('newest first, by day with the trip, and a tap opens the editor on that photo', (tester) async {
    await place(tester, 'uji', 'Uji Bridge');
    await place(tester, 'tower', 'Kyoto Tower');
    late Trip kyoto;
    await tester.runAsync(() async {
      kyoto = await DriftTripRepository(db, null, 'me').createTrip(title: 'Kyoto', ownerId: 'me');
      await db
          .into(db.newReferenceImages)
          .insert(NewReferenceImagesCompanion.insert(id: 'f1', placeKey: const Value('uji')));
    });
    await photo(tester, 'old', 'tower', DateTime(2026, 11, 7, 18));
    await photo(tester, 'a', 'uji', DateTime(2026, 11, 8, 10), tripId: kyoto.id, frameId: 'f1');
    await photo(tester, 'b', 'uji', DateTime(2026, 11, 8, 11), tripId: kyoto.id);
    // Not to edit: already edited, an edit itself, or kept as it is.
    await photo(tester, 'done', 'uji', DateTime(2026, 11, 8, 9));
    await photo(tester, 'done-edit', 'uji', DateTime(2026, 11, 8, 12), kind: 'edited', derivedFromId: 'done');

    await open(tester);

    expect(listed(tester), ['b', 'a', 'old']);
    expect(find.text('Sun, Nov 8 · Kyoto'), findsOneWidget);
    expect(find.text('Sat, Nov 7'), findsOneWidget);
    expect(find.text('10:00 · with its frame'), findsOneWidget);

    await tester.tap(find.text('10:00 · with its frame'));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);
    final args = edited.single;
    expect((args.photoId, args.placeKey, args.tripId, args.path), ('a', 'uji', kyoto.id, '/photos/a.jpg'));
    expect(args.referenceImageId, isNull, reason: "the frame has no picture on this phone");
    await close(tester);
  });

  testWidgets('an edit of a photo takes it off the list', (tester) async {
    await place(tester, 'uji', 'Uji Bridge');
    await photo(tester, 'a', 'uji', DateTime(2026, 11, 8, 10));
    await photo(tester, 'b', 'uji', DateTime(2026, 11, 8, 11));
    await open(tester);
    expect(listed(tester), ['b', 'a']);

    // What the editor saves: a new photo derived from the one edited.
    await photo(tester, 'a-edit', 'uji', DateTime(2026, 11, 8, 10), kind: 'edited', derivedFromId: 'a');
    await tester.pumpAndSettle();
    expect(listed(tester), ['b']);
    await close(tester);
  });

  testWidgets('Keep as it is takes one off the list, and Undo brings it back', (tester) async {
    await place(tester, 'uji', 'Uji Bridge');
    await photo(tester, 'a', 'uji', DateTime(2026, 11, 8, 10));
    await photo(tester, 'b', 'uji', DateTime(2026, 11, 8, 11));
    await open(tester);

    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('photoToEdit:a')), matching: find.byTooltip('Keep as it is')),
    );
    await tester.pumpAndSettle();
    expect(listed(tester), ['b']);
    expect(find.text('Kept as it is.'), findsOneWidget);
    final kept = await tester.runAsync(() => (db.select(db.photos)..where((p) => p.id.equals('a'))).getSingle());
    expect(kept!.keepAsIs, isTrue);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(listed(tester), ['b', 'a']);
    await close(tester);
  });

  testWidgets('a long press selects, and several are kept as they are at once', (tester) async {
    await place(tester, 'uji', 'Uji Bridge');
    for (final (i, id) in ['a', 'b', 'c'].indexed) {
      await photo(tester, id, 'uji', DateTime(2026, 11, 8, 10 + i));
    }
    await open(tester);

    await tester.longPress(find.byKey(const ValueKey('photoToEdit:a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('photoToEdit:c')));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    expect(edited, isEmpty, reason: 'a tap selects while selecting');

    await tester.tap(find.byKey(const Key('photosToEditKeepSelected')));
    await tester.pumpAndSettle();
    expect(listed(tester), ['b']);
    expect(find.text('Photos to edit'), findsOneWidget);
    expect(find.text('Kept 2 photos as they are.'), findsOneWidget);

    await tester.tap(find.byTooltip('Keep as it is'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to edit'), findsOneWidget);
    await close(tester);
  });
}
