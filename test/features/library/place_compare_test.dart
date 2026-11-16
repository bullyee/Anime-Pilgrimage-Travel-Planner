import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/models/place_diff.dart';
import 'package:trip_planner/features/library/providers/place_comparison_providers.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/screens/place_screen.dart';
import 'package:trip_planner/features/library/services/anitabi_import.dart';
import 'package:trip_planner/features/library/services/place_compare_kept.dart';
import 'package:trip_planner/features/library/widgets/place_compare.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/stop_screen.dart';

PlaceFieldDiff _field(PlaceFieldType f, {double? meters, String? dir}) => PlaceFieldDiff(
      field: f,
      fieldLabel: f.name,
      localValue: 'mine',
      remoteValue: 'theirs',
      changeSummary: '',
      distanceMeters: meters,
      direction: dir,
    );

PlaceDiff _diff(List<PlaceFieldDiff> d) =>
    PlaceDiff(placeKey: 'p', localName: 'a', remoteName: 'b', targetSource: 'x', differences: d);

void main() {
  group('the hint line', () {
    test('says where the other version puts the spot, from the user\'s side', () {
      final moved = _diff([_field(PlaceFieldType.location, meters: 120, dir: 'SE')]);
      expect(compareHintText(moved, CompareSides.anitabi), 'Anitabi moved this spot 120 m SE');
      // On a stop the diff runs from the library to the stop; the line looks from the stop.
      expect(compareHintText(moved, CompareSides.library), 'Your library puts this spot 120 m NW');
    });

    test('names a single difference, and counts several', () {
      expect(compareHintText(_diff([_field(PlaceFieldType.description)]), CompareSides.library),
          'Your library has a different description');
      expect(
          compareHintText(
              _diff([_field(PlaceFieldType.name), _field(PlaceFieldType.address), _field(PlaceFieldType.links)]), CompareSides.anitabi),
          'Anitabi has 3 changes to this spot');
      expect(
          compareHintText(
              _diff([_field(PlaceFieldType.location, meters: 1500, dir: 'N'), _field(PlaceFieldType.name)]), CompareSides.anitabi),
          'Anitabi moved this spot 1.5 km N, and a different name');
    });
  });

  group('PlaceCompareKept', () {
    test('drops a kept difference until the other side changes again', () {
      final diff = _diff([_field(PlaceFieldType.name), _field(PlaceFieldType.address)]);
      final key = PlaceCompareKept.key(PlaceCompareKept.anitabi, 'p', PlaceFieldType.name);
      String? other(PlaceFieldDiff d) => d.remoteValue;

      final left = PlaceCompareKept.withoutKept(diff, {key: 'theirs'}, kind: PlaceCompareKept.anitabi, entityId: 'p', otherValue: other);
      expect(left!.differences.map((d) => d.field), [PlaceFieldType.address]);

      final again = PlaceCompareKept.withoutKept(diff, {key: 'an older value'}, kind: PlaceCompareKept.anitabi, entityId: 'p', otherValue: other);
      expect(again!.differences, hasLength(2));

      // Kept for another place, or for the library pair, it doesn't count here.
      expect(
          PlaceCompareKept.withoutKept(diff, {key: 'theirs'}, kind: PlaceCompareKept.anitabi, entityId: 'q', otherValue: other)!
              .differences,
          hasLength(2));
      final allKept = {
        key: 'theirs',
        PlaceCompareKept.key(PlaceCompareKept.anitabi, 'p', PlaceFieldType.address): 'theirs',
      };
      expect(PlaceCompareKept.withoutKept(diff, allKept, kind: PlaceCompareKept.anitabi, entityId: 'p', otherValue: other), isNull);
    });
  });

  late AppDatabase db;
  late DriftTripRepository trips;
  late DriftPlaceRepository places;
  late InMemoryPlaceCompareKeptStore kept;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trips = DriftTripRepository(db, null, 'u1');
    places = DriftPlaceRepository(db);
    kept = InMemoryPlaceCompareKeptStore();
  });
  tearDown(() => db.close());

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('StopScreen against the library', () {
    /// Uji Bridge in the library and on a trip; the trip's copy was then
    /// renamed and moved about 120 m south-east.
    Future<(Trip, Stop)> diverged() async {
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'p1',
            name: 'Uji Bridge',
            lat: 34.8920,
            lng: 135.8000,
            visibility: const Value('saved'),
          ));
      final trip = await trips.createTrip(title: 'Uji day trip', ownerId: 'u1', dayCount: 1);
      final stop = await trips.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'u1');
      await trips.updateStop(StopsCompanion(
        id: Value(stop.id),
        name: const Value('Uji Bridge (east end)'),
        lat: const Value(34.8912),
        lng: const Value(135.8010),
      ));
      await (db.update(db.stops)..where((s) => s.id.equals(stop.id))).write(const StopsCompanion(syncStatus: Value(0)));
      return (trip, (await trips.getStop(stop.id))!);
    }

    Future<void> pump(WidgetTester tester, Trip trip, Stop stop, {List<Override> overrides = const []}) async {
      tallScreen(tester);
      final router = GoRouter(initialLocation: '/trips/${trip.id}/stops/${stop.id}', routes: [
        GoRoute(
          path: '/trips/:tripId/stops/:stopId',
          builder: (_, s) => StopScreen(tripId: s.pathParameters['tripId']!, stopId: s.pathParameters['stopId']!),
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u1'),
          placeCompareKeptStoreProvider.overrideWithValue(kept),
          ...overrides,
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the hint opens the side-by-side; Use this changes the stop, Keep mine hides the rest', (tester) async {
      final (trip, stop) = await diverged();
      await pump(tester, trip, stop);

      expect(find.textContaining('Your library puts this spot'), findsOneWidget);
      expect(find.textContaining('and a different name'), findsOneWidget);
      await tester.tap(find.byKey(const Key('placeCompareHint')));
      await tester.pumpAndSettle();

      expect(find.text('This stop and your library'), findsOneWidget);
      expect(find.text('Uji Bridge (east end)'), findsWidgets);
      await tester.tap(find.byKey(const Key('useThis-name')));
      await tester.pumpAndSettle();
      final renamed = (await trips.getStop(stop.id))!;
      expect(renamed.name, 'Uji Bridge', reason: "the library's name, now on the stop");
      expect(renamed.syncStatus, 1, reason: 'it goes up to the trip like any edit');
      expect(renamed.lat, 34.8912, reason: 'only the chosen field changes');
      expect((await places.getPlace('p1'))!.name, 'Uji Bridge', reason: 'the library is never written from a stop page');

      await tester.tap(find.byKey(const Key('keepMine-location')));
      await tester.pumpAndSettle();
      expect(find.text('This stop and your library'), findsNothing, reason: 'nothing left to answer');
      expect(find.byKey(const Key('placeCompareHint')), findsNothing);
      expect(kept.kept.values, ['34.892000, 135.800000'], reason: "remembered with the library's value");
      expect((await trips.getStop(stop.id))!.lat, 34.8912);
      await disposeApp(tester);
    });

    testWidgets("a viewer can compare and keep, but can't change the trip's stop", (tester) async {
      final (trip, stop) = await diverged();
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
          .write(const TripsCompanion(ownerId: Value('aki'), sharing: Value('group')));
      TripMember member(String id, TripMemberRole role) =>
          TripMember(userId: id, tripId: trip.id, role: role, displayName: id, joinedAt: DateTime(2026));
      await pump(tester, trip, stop, overrides: [
        tripMembersProvider(trip.id).overrideWith(
            (ref) => Stream.value([member('aki', TripMemberRole.owner), member('u1', TripMemberRole.viewer)])),
      ]);

      await tester.tap(find.byKey(const Key('placeCompareHint')));
      await tester.pumpAndSettle();
      expect(find.textContaining('You can only view this trip'), findsOneWidget);
      expect(find.byKey(const Key('useThis-name')), findsNothing);
      expect(find.byKey(const Key('keepMine-name')), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets("a joined trip's stop can be saved to the library, one or all", (tester) async {
      final trip = await trips.createTrip(title: 'Kyoto with Aki', ownerId: 'u1', dayCount: 1);
      for (final (id, name) in [('s1', 'Fushimi Inari'), ('s2', 'Demachiyanagi'), ('s3', 'Kamogawa Delta')]) {
        await db.into(db.stops).insert(StopsCompanion.insert(
              id: id,
              tripId: trip.id,
              placeKey: 'anitabi:$id',
              name: name,
              lat: 35.0,
              lng: 135.77,
              addedBy: 'aki',
            ));
      }
      await pump(tester, trip, (await trips.getStop('s1'))!);

      expect(find.text('Not in your library'), findsOneWidget);
      expect(find.text('Save all 3'), findsOneWidget);
      expect(find.text('My note'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('saveToLibrary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveToLibrary')));
      await tester.pumpAndSettle();

      expect((await places.getPlace('anitabi:s1'))!.visibility, 'saved');
      expect(await places.getPlace('anitabi:s2'), isNull, reason: 'only this one');
      expect(find.text('Not in your library'), findsNothing);
      await tester.scrollUntilVisible(find.text('Open my place'), 300, scrollable: find.byType(Scrollable).first);
      await disposeApp(tester);

      await pump(tester, trip, (await trips.getStop('s2'))!);
      expect(find.text('Save all 2'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('saveAllToLibrary')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveAllToLibrary')));
      await tester.pumpAndSettle();
      expect(find.text('Saved 2 places to your library.'), findsOneWidget);
      expect((await places.getPlace('anitabi:s3'))!.visibility, 'saved');
      await disposeApp(tester);
    });
  });

  group('PlaceScreen against Anitabi', () {
    testWidgets("Anitabi's move shows as a hint, and Use this moves the place", (tester) async {
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'anitabi:a1',
            name: '修学院駅',
            lat: 35.0500,
            lng: 135.7900,
            description: const Value('音乐室'),
            privateNote: const Value('Come at dusk'),
            visibility: const Value('saved'),
          ));
      const spot = AnitabiSpot(id: 'a1', name: '修学院駅', lat: 35.0510, lng: 135.7910, note: '音乐室');
      tallScreen(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u1'),
          placeCompareKeptStoreProvider.overrideWithValue(kept),
          cachedAnitabiSpotProvider('anitabi:a1').overrideWith((ref) async => spot),
        ],
        child: const MaterialApp(home: PlaceScreen(placeKey: 'anitabi:a1')),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Anitabi moved this spot'), findsOneWidget);
      expect(find.textContaining('NE'), findsWidgets);
      await tester.tap(find.byKey(const Key('placeCompareHint')));
      await tester.pumpAndSettle();
      expect(find.text('Your place and Anitabi'), findsOneWidget);
      await tester.tap(find.byKey(const Key('useThis-location')));
      await tester.pumpAndSettle();

      final place = (await places.getPlace('anitabi:a1'))!;
      expect((place.lat, place.lng), (35.0510, 135.7910));
      expect(place.privateNote, 'Come at dusk');
      expect(find.byKey(const Key('placeCompareHint')), findsNothing);
      await disposeApp(tester);
    });

    testWidgets('no cached Anitabi data, no hint', (tester) async {
      await db.into(db.places).insert(PlacesCompanion.insert(
            placeKey: 'anitabi:a2',
            name: 'Somewhere',
            lat: 35.0,
            lng: 135.0,
            visibility: const Value('saved'),
          ));
      tallScreen(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u1'),
          placeCompareKeptStoreProvider.overrideWithValue(kept),
          cachedAnitabiSpotProvider('anitabi:a2').overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: PlaceScreen(placeKey: 'anitabi:a2')),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('placeCompareHint')), findsNothing);
      await disposeApp(tester);
    });
  });
}
