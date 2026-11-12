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
import 'package:trip_planner/features/library/controllers/place_controller.dart';
import 'package:trip_planner/features/library/models/frames.dart';
import 'package:trip_planner/features/library/providers/place_providers.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/screens/place_screen.dart';
import 'package:trip_planner/features/library/widgets/place_page_parts.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/trip/controllers/trip_stops_controller.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/stop_screen.dart';
import 'package:trip_planner/features/trip/screens/trip_screen.dart';
import 'package:trip_planner/shared/theme/app_theme.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('validateFrameImageUrl', () {
    test('accepts http/https and preserves percent-encoded URL segments without double decoding', () {
      final res = validateFrameImageUrl('  https://example.com/path/frame%201%25.jpg?w=800  ');
      expect(res.error, isNull);
      expect(res.url, 'https://example.com/path/frame%201%25.jpg?w=800');
    });

    test('rejects invalid schemes, whitespace, userinfo, and overlong UTF-16 URLs', () {
      expect(validateFrameImageUrl('').error, isNotNull);
      expect(validateFrameImageUrl('   ').error, isNotNull);
      expect(validateFrameImageUrl('ftp://example.com/a.jpg').error, isNotNull);
      expect(validateFrameImageUrl('javascript:alert(1)').error, isNotNull);
      expect(validateFrameImageUrl('file:///etc/passwd').error, isNotNull);
      expect(validateFrameImageUrl('https://user:pass@example.com/a.jpg').error, isNotNull);
      expect(validateFrameImageUrl('https://example.com/has space.jpg').error, isNotNull);

      final tooLong = 'https://example.com/${'😀' * 1000}';
      expect(tooLong.length, greaterThan(maxFrameUrlLength));
      expect(validateFrameImageUrl(tooLong).error, contains('$maxFrameUrlLength'));
    });
  });

  group('PlaceController & TripStopsController URL frames', () {
    late AppDatabase db;
    late DriftPlaceRepository placeRepo;
    late DriftTripRepository tripRepo;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      placeRepo = DriftPlaceRepository(db);
      tripRepo = DriftTripRepository(db, null, 'u1', placeRepo);
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        placeRepositoryProvider.overrideWithValue(placeRepo),
        tripRepositoryProvider.overrideWithValue(tripRepo),
        currentUserIdProvider.overrideWithValue('u1'),
      ]);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('PlaceController adds URL frame, deduplicates, and copies to stops with remoteUrl intact', () async {
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'p1', name: 'Keihan Uji', lat: 34.89, lng: 135.80));
      final pc = container.read(placeControllerProvider.notifier);

      final first = await pc.addFrameFromUrl('p1', url: 'https://cdn.example.com/ep5.jpg', episode: '5');
      expect(first, isA<Success<NewReferenceImage>>());
      final frame = (first as Success<NewReferenceImage>).value;
      expect(frame.remoteUrl, 'https://cdn.example.com/ep5.jpg');
      expect(frame.episode, '5');
      expect(frame.source, 'Link');

      // Duplicate link refused
      expect(await pc.addFrameFromUrl('p1', url: 'https://cdn.example.com/ep5.jpg'), isA<Failure<NewReferenceImage>>());

      // Adding place to trip copies remoteUrl to stop
      final trip = await tripRepo.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      final stop = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'u1');
      final stopFrames = await tripRepo.getReferenceImagesForStop(stop.id);
      expect(stopFrames.single.remoteUrl, 'https://cdn.example.com/ep5.jpg');
    });

    test('TripStopsController adds/removes URL frame, marks stop dirty, and enforces stop isolation', () async {
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'p1', name: 'Stop 1', lat: 34.89, lng: 135.80));
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'p2', name: 'Stop 2', lat: 34.90, lng: 135.81));
      final trip = await tripRepo.createTrip(title: 'Group Trip', ownerId: 'u1', dayCount: 1);
      final stop1 = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'u1');
      final stop2 = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'p2', addedBy: 'u1');

      // Reset syncStatus to 0 to prove add/remove mark stop dirty
      await (db.update(db.stops)..where((s) => s.id.equals(stop1.id))).write(const StopsCompanion(syncStatus: Value(0)));

      final sc = container.read(tripStopsControllerProvider.notifier);
      final added = await sc.addFrameFromUrl(stop1.id, url: 'https://cdn.example.com/custom.png', episode: '12');
      expect(added, isA<Success<NewReferenceImage>>());
      final frame1 = (added as Success<NewReferenceImage>).value;
      expect((await tripRepo.getStop(stop1.id))!.syncStatus, 1);

      // Entity scope isolation: cannot remove stop1's frame through stop2
      final badDelete = await sc.removeFrame(stop2.id, frame1);
      expect(badDelete, isA<Failure<void>>());
      expect(await placeRepo.getReferenceImage(frame1.id), isNotNull);

      // Reset syncStatus then remove legitimately through stop1
      await (db.update(db.stops)..where((s) => s.id.equals(stop1.id))).write(const StopsCompanion(syncStatus: Value(0)));
      expect(await sc.removeFrame(stop1.id, frame1), isA<Success<void>>());
      expect(await placeRepo.getReferenceImage(frame1.id), isNull);
      expect((await tripRepo.getStop(stop1.id))!.syncStatus, 1);
    });
  });

  group('Widget notices & dialogs', () {
    late AppDatabase db;
    late DriftPlaceRepository placeRepo;
    late DriftTripRepository tripRepo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      placeRepo = DriftPlaceRepository(db);
      tripRepo = DriftTripRepository(db, null, 'u1', placeRepo);
    });

    tearDown(() => db.close());

    Future<void> disposeApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('PlaceScreen displays URL-only frames in FrameHero', (tester) async {
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'p_url',
              name: 'URL Spot',
              lat: 34.9,
              lng: 135.8,
              visibility: const Value('saved'),
            ),
          );
      await placeRepo.addReferenceImage(
        placeKey: 'p_url',
        remoteUrl: 'https://example.com/url_only.jpg',
        episode: '8',
        source: 'Link',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            placeRepositoryProvider.overrideWithValue(placeRepo),
            tripRepositoryProvider.overrideWithValue(tripRepo),
            currentUserIdProvider.overrideWithValue('u1'),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const PlaceScreen(placeKey: 'p_url')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('Ep 8'), findsOneWidget);
      expect(find.text('No anime frames yet'), findsNothing);
      await disposeApp(tester);
    });

    testWidgets('StopScreen shows LocalFramesSyncNote only when shared trip stop has local-only frame',
        (tester) async {
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'p1', name: 'Obaku', lat: 34.9, lng: 135.8));
      final trip = await tripRepo.createTrip(title: 'Kansai', ownerId: 'u1', dayCount: 1);
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
          .write(const TripsCompanion(sharing: Value('group')));
      final stop = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'u1');

      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: 'local_only_1',
            stopId: Value(stop.id),
            localPath: const Value('/tmp/does_not_need_file_for_callout.jpg'),
          ));

      final router = GoRouter(
        initialLocation: '/t',
        routes: [
          GoRoute(
            path: '/t',
            builder: (_, _) => StopScreen(tripId: trip.id, stopId: stop.id),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            placeRepositoryProvider.overrideWithValue(placeRepo),
            tripRepositoryProvider.overrideWithValue(tripRepo),
            currentUserIdProvider.overrideWithValue('u1'),
            myTripRoleProvider(trip.id).overrideWithValue(TripMemberRole.owner),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LocalFramesSyncNote), findsOneWidget);
      expect(find.textContaining('saved on this phone only'), findsOneWidget);
      expect(find.text('Sync via Google Drive'), findsOneWidget);

      // Replacing local-only frame with URL-backed frame removes the warning
      await (db.delete(db.newReferenceImages)..where((r) => r.id.equals('local_only_1'))).go();
      await placeRepo.addReferenceImage(stopId: stop.id, remoteUrl: 'https://example.com/a.jpg');
      await tester.pumpAndSettle();
      expect(find.byType(LocalFramesSyncNote), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('TripScreen Members tab offers Share local frames and Import local frames', (tester) async {
      final trip = await tripRepo.createTrip(title: 'Kansai', ownerId: 'u1', dayCount: 1);
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
          .write(const TripsCompanion(sharing: Value('group')));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            placeRepositoryProvider.overrideWithValue(placeRepo),
            tripRepositoryProvider.overrideWithValue(tripRepo),
            currentUserIdProvider.overrideWithValue('u1'),
            myTripRoleProvider(trip.id).overrideWithValue(TripMemberRole.owner),
            tripMembersProvider(trip.id).overrideWith(
              (_) => Stream.value([
                TripMember(userId: 'u1', tripId: trip.id, role: TripMemberRole.owner, displayName: 'U1', joinedAt: DateTime(2026)),
              ]),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: TripScreen(tripId: trip.id, initialTab: TripTab.members)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync via my Google Drive'), findsOneWidget);
      expect(find.text('Share local frames'), findsOneWidget);
      expect(find.text('Import local frames'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('askFrameImageUrl keeps dialog open on invalid URL and accepts valid URL', (tester) async {
      ({String url, String? episode})? output;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => output = await askFrameImageUrl(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'not-a-valid-url');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid http:// or https:// image link.'), findsOneWidget);
      expect(output, isNull);

      await tester.enterText(find.byType(TextField).first, 'https://example.com/frame.jpg');
      await tester.enterText(find.byType(TextField).last, '7');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(output, isNotNull);
      expect(output!.url, 'https://example.com/frame.jpg');
      expect(output!.episode, '7');
    });
  });
}
