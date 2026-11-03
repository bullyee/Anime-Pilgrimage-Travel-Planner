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
import 'package:trip_planner/features/library/controllers/library_controller.dart';
import 'package:trip_planner/features/library/models/library_entry.dart';
import 'package:trip_planner/features/library/providers/library_providers.dart';
import 'package:trip_planner/features/library/providers/place_providers.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/screens/library_screen.dart';
import 'package:trip_planner/features/library/screens/place_screen.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

Future<void> _savePlace(AppDatabase db, String key, String name, {String visibility = 'saved', String? address}) =>
    db.into(db.places).insert(PlacesCompanion.insert(
          placeKey: key,
          name: name,
          lat: 34.89,
          lng: 135.80,
          address: Value(address),
          visibility: Value(visibility),
        ));

Place _place(String key, String name, {String visibility = 'saved', String? address}) => Place(
      placeKey: key,
      name: name,
      lat: 0,
      lng: 0,
      address: address,
      visibility: visibility,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Label _label(String id, String kind, String name) => Label(id: id, kind: kind, name: name, createdAt: DateTime(2026));

void main() {
  group('library entries and filters', () {
    final euph = _label('a1', 'anime', 'Hibike! Euphonium');
    final yuru = _label('a2', 'anime', 'Yuru Camp');
    final night = _label('t1', 'tag', 'night shot');
    final uji = _label('r1', 'region', 'Uji');
    final labels = [euph, yuru, night, uji];

    final entries = buildLibraryEntries(
      places: [
        _place('p1', 'Uji Bridge', address: 'Uji, Kyoto'),
        _place('p2', 'asagiri bridge'),
        _place('p3', 'Lake Motosu'),
        _place('p4', 'Trip-only spot', visibility: 'trip_only'),
      ],
      labels: labels,
      links: [
        const PlaceLabel(placeKey: 'p1', labelId: 'r1'),
        const PlaceLabel(placeKey: 'p1', labelId: 'a1'),
        const PlaceLabel(placeKey: 'p2', labelId: 'a1'),
        const PlaceLabel(placeKey: 'p2', labelId: 't1'),
        const PlaceLabel(placeKey: 'p3', labelId: 'a2'),
      ],
      stops: [('p1', 'trip_a'), ('p1', 'trip_b'), ('p1', 'trip_a')],
    );

    List<String> names(LibraryFilter f) => [for (final e in filterLibrary(entries, f, labels)) e.place.name];

    test('entries are sorted by name and know their labels and trips', () {
      expect(entries.map((e) => e.place.name), ['asagiri bridge', 'Lake Motosu', 'Trip-only spot', 'Uji Bridge']);
      final bridge = entries.last;
      expect(bridge.labels.map((l) => l.name), ['Hibike! Euphonium', 'Uji'], reason: 'anime before regions');
      expect(bridge.tripIds, {'trip_a', 'trip_b'});
    });

    test('trip-only places are hidden unless asked for', () {
      expect(names(const LibraryFilter()), isNot(contains('Trip-only spot')));
      expect(names(const LibraryFilter(includeTripOnly: true)), contains('Trip-only spot'));
    });

    test('search matches names, addresses and labels', () {
      expect(names(const LibraryFilter(query: 'BRIDGE')), ['asagiri bridge', 'Uji Bridge']);
      expect(names(const LibraryFilter(query: 'kyoto')), ['Uji Bridge']);
      expect(names(const LibraryFilter(query: 'yuru')), ['Lake Motosu']);
    });

    test('picked labels: any within a kind, all kinds together', () {
      expect(names(const LibraryFilter(labelIds: {'a1', 'a2'})), ['asagiri bridge', 'Lake Motosu', 'Uji Bridge']);
      expect(names(const LibraryFilter(labelIds: {'a1', 'r1'})), ['Uji Bridge']);
      expect(names(const LibraryFilter(labelIds: {'a1', 't1'})), ['asagiri bridge']);
    });
  });

  group('LibraryController', () {
    late AppDatabase db;
    late ProviderContainer container;
    late PlaceRepository places;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u1'),
      ]);
      places = container.read(placeRepositoryProvider);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    LibraryController controller() => container.read(libraryControllerProvider.notifier);

    test('a new place needs a name and is saved to the library', () async {
      expect(await controller().createPlace(name: '  ', lat: 1, lng: 2), isA<Failure<Place>>());
      final created = await controller().createPlace(name: ' Uji Bridge ', lat: 34.89, lng: 135.80, address: ' ');
      final place = (created as Success<Place>).value;
      expect(place.name, 'Uji Bridge');
      expect(place.address, isNull);
      expect(place.visibility, 'saved');
    });

    test('labels are reused by name, and renaming onto another label merges them', () async {
      await _savePlace(db, 'p1', 'Uji Bridge');
      await _savePlace(db, 'p2', 'Byodoin');
      final first = (await controller().addLabel('p1', kind: 'tag', name: 'night shot') as Success<Label>).value;
      final again = (await controller().addLabel('p2', kind: 'tag', name: 'night shot') as Success<Label>).value;
      expect(again.id, first.id);

      final other = (await controller().addLabel('p2', kind: 'tag', name: 'sunset') as Success<Label>).value;
      final renamed = (await controller().renameLabel(other.id, 'night shot') as Success<Label>).value;
      expect(renamed.id, first.id, reason: 'the existing label survives');
      expect((await places.getLabels(kind: 'tag')).map((l) => l.name), ['night shot']);
      expect((await places.getLabelsForPlace('p2')).map((l) => l.name), ['night shot']);
    });

    test('merging moves the places over; labels of different kinds do not merge', () async {
      await _savePlace(db, 'p1', 'Uji Bridge');
      final a = (await controller().addLabel('p1', kind: 'anime', name: 'Euphonium') as Success<Label>).value;
      final b = (await controller().createLabel(kind: 'anime', name: 'Hibike! Euphonium') as Success<Label>).value;
      final region = (await controller().createLabel(kind: 'region', name: 'Uji') as Success<Label>).value;
      expect(await controller().mergeLabels(source: a, target: region), isA<Failure<void>>());

      await controller().mergeLabels(source: a, target: b);
      expect((await places.getLabelsForPlace('p1')).map((l) => l.id), [b.id]);
      expect(await places.getLabel(a.id), isNull);
    });

    test('a label nothing uses any more goes away; one a frame still uses stays', () async {
      await _savePlace(db, 'p1', 'Uji Bridge');
      await _savePlace(db, 'p2', 'Byodoin');
      final solo = (await controller().addLabel('p1', kind: 'tag', name: 'Dusk') as Success<Label>).value;
      final framed = (await controller().addLabel('p1', kind: 'anime', name: 'Euphonium') as Success<Label>).value;
      await places.addReferenceImage(placeKey: 'p2', localPath: '/nowhere/frame.png', animeLabelId: framed.id);
      final spare = (await controller().createLabel(kind: 'region', name: 'Uji') as Success<Label>).value;

      await controller().removeLabel('p1', solo.id);
      expect(await places.getLabel(solo.id), isNull, reason: 'no place, stop or frame used it any more');
      await controller().removeLabel('p1', framed.id);
      expect(await places.getLabel(framed.id), isNotNull, reason: 'a frame still names it');
      expect(await places.getLabel(spare.id), isNotNull, reason: 'made for later, and no change touched it');

      expect((await controller().deleteUnusedLabels() as Success<int>).value, 1);
      expect(await places.getLabel(spare.id), isNull);
      expect(await places.getLabel(framed.id), isNotNull);
    });

    test('labels go on and off several places at once', () async {
      for (final key in ['p1', 'p2', 'p3']) {
        await _savePlace(db, key, 'Place $key');
      }
      final label = (await controller().addLabelToPlaces(['p1', 'p2'], kind: 'region', name: 'Uji') as Success<Label>).value;
      expect((await places.getPlacesByLabel(label.id)).map((p) => p.placeKey).toSet(), {'p1', 'p2'});
      // Adding again is harmless, and removing touches only the given places.
      await controller().addLabelToPlaces(['p2', 'p3'], kind: 'region', name: 'Uji');
      await controller().removeLabelFromPlaces(['p1', 'p2'], label.id);
      expect((await places.getPlacesByLabel(label.id)).map((p) => p.placeKey), ['p3']);
    });

    test('several places leave the library at once: hidden when in a trip, deleted otherwise', () async {
      final trips = DriftTripRepository(db);
      final trip = await trips.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      for (final key in ['p1', 'p2', 'p3']) {
        await _savePlace(db, key, 'Place $key');
      }
      await trips.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'u1');
      final sub = container.listen(libraryEntriesProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final entries = container.read(libraryEntriesProvider).requireValue;

      final result = await controller().removeManyFromLibrary(entries);
      expect((result as Success<(int, int)>).value, (1, 2));
      expect((await places.getPlace('p1'))!.visibility, 'trip_only');
      expect(await places.getPlace('p2'), isNull);
      expect(await places.getPlace('p3'), isNull);
      sub.close();
    });

    test('merging moves labels, frames, photos, visits, notes and trip stops to the kept place', () async {
      final trips = DriftTripRepository(db);
      final trip = await trips.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      await _savePlace(db, 'keep', 'Uji Bridge');
      await _savePlace(db, 'dupe', '宇治橋');
      await places.updatePlace(const PlacesCompanion(placeKey: Value('keep'), privateNote: Value('Tripod.')));
      await places.updatePlace(const PlacesCompanion(placeKey: Value('dupe'), privateNote: Value('East bank at dusk.')));
      final a = (await controller().addLabel('keep', kind: 'tag', name: 'Bridge') as Success<Label>).value;
      final b = (await controller().addLabel('dupe', kind: 'anime', name: 'Euphonium') as Success<Label>).value;
      await places.addPhoto(placeKey: 'dupe', localPath: '/nowhere/photo.jpg');
      await places.addReferenceImage(placeKey: 'dupe', localPath: '/nowhere/frame.png');
      await places.addVisit(placeKey: 'keep', date: '2026-11-01');
      await places.addVisit(placeKey: 'dupe', date: '2026-11-01'); // the same visit
      await places.addVisit(placeKey: 'dupe', date: '2025-04-29');
      // Added by a trip mate; the merge is this user's edit.
      await trips.addPlaceToTrip(tripId: trip.id, placeKey: 'dupe', addedBy: 'u2');

      expect(await controller().mergePlaces(keep: 'keep', others: ['keep', 'dupe']), isA<Success<void>>());

      expect(await places.getPlace('dupe'), isNull);
      final kept = (await places.getPlace('keep'))!;
      expect(kept.name, 'Uji Bridge', reason: 'the kept facts stay');
      expect(kept.privateNote, 'Tripod.\n\nEast bank at dusk.');
      expect((await places.getLabelsForPlace('keep')).map((l) => l.id).toSet(), {a.id, b.id});
      expect((await places.getPhotosForPlace('keep')), hasLength(1));
      expect((await places.getReferenceImagesForPlace('keep')), hasLength(1));
      expect((await places.getVisitsForPlace('keep')).map((v) => v.date).toSet(), {'2026-11-01', '2025-04-29'});
      final stop = (await trips.getStopsForTrip(trip.id)).single;
      expect(stop.placeKey, 'keep');
      expect(stop.name, '宇治橋', reason: 'the trip keeps its own copy of the facts');
      expect((stop.updatedBy, stop.syncStatus), ('u1', 1), reason: 'stamped as an edit by the user, to sync');
      expect(await controller().mergePlaces(keep: 'keep', others: ['keep']), isA<Failure<void>>());
    });

    test('removing a place in a trip only hides it; otherwise it is deleted', () async {
      final trips = DriftTripRepository(db);
      final trip = await trips.createTrip(title: 'Uji', ownerId: 'u1', dayCount: 1);
      await _savePlace(db, 'p1', 'Uji Bridge');
      await _savePlace(db, 'p2', 'Byodoin');
      await trips.addPlaceToTrip(tripId: trip.id, placeKey: 'p1', addedBy: 'u1');

      final sub = container.listen(libraryEntriesProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final entries = container.read(libraryEntriesProvider).requireValue;
      LibraryEntry entry(String key) => entries.firstWhere((e) => e.place.placeKey == key);
      expect(entry('p1').tripIds, {trip.id});

      expect((await controller().removeFromLibrary(entry('p1')) as Success<RemovedPlace>).value, RemovedPlace.hidden);
      expect((await places.getPlace('p1'))!.visibility, 'trip_only');
      expect((await trips.getStopsForTrip(trip.id)).single.placeKey, 'p1', reason: 'the trip keeps its stop');

      expect((await controller().removeFromLibrary(entry('p2')) as Success<RemovedPlace>).value, RemovedPlace.deleted);
      expect(await places.getPlace('p2'), isNull);
      sub.close();
    });
  });

  group('LibraryScreen', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/library', routes: [
        GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
        GoRoute(path: '/library/new', builder: (_, _) => const Scaffold(body: Text('new place'))),
        GoRoute(path: '/library/labels', builder: (_, _) => const Scaffold(body: Text('labels'))),
        GoRoute(path: '/library/places/:placeKey', builder: (_, s) => PlaceScreen(placeKey: s.pathParameters['placeKey']!)),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db), currentUserIdProvider.overrideWithValue('u1')],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> disposeApp(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('an empty library offers to add a place', (tester) async {
      await pump(tester);
      expect(find.text('Your library is empty'), findsOneWidget);
      await tester.tap(find.text('Add a place'));
      await tester.pumpAndSettle();
      expect(find.text('new place'), findsOneWidget);
      await disposeApp(tester);
    });

    testWidgets('search and a label filter narrow the list', (tester) async {
      final places = DriftPlaceRepository(db);
      await _savePlace(db, 'p1', 'Uji Bridge');
      await _savePlace(db, 'p2', 'Lake Motosu');
      final euph = await places.getOrCreateLabel(kind: 'anime', name: 'Hibike! Euphonium');
      await places.attachLabelToPlace('p1', euph.id);
      await pump(tester);
      expect(find.text('Uji Bridge'), findsOneWidget);
      expect(find.text('Lake Motosu'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'motosu');
      await tester.pumpAndSettle();
      expect(find.text('Uji Bridge'), findsNothing);
      expect(find.text('Lake Motosu'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear the search'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Anime'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Hibike! Euphonium'));
      await tester.tap(find.text('Show places'));
      await tester.pumpAndSettle();
      expect(find.text('Anime · 1'), findsOneWidget);
      expect(find.text('Uji Bridge'), findsOneWidget);
      expect(find.text('Lake Motosu'), findsNothing);
      await disposeApp(tester);
    });

    testWidgets('holding a place starts picking; picked places get a label and leave together', (tester) async {
      await _savePlace(db, 'p1', 'Uji Bridge');
      await _savePlace(db, 'p2', 'Byodoin');
      await _savePlace(db, 'p3', 'Lake Motosu');
      await pump(tester);

      await tester.longPress(find.text('Uji Bridge'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Add place'), findsNothing);
      await tester.tap(find.text('Byodoin'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit labels'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a label to all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regions'));
      await tester.enterText(find.byKey(const Key('labelNameField')), 'Uji');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create “Uji”'));
      await tester.pumpAndSettle();
      expect(find.text('On 2 of 2'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final places = DriftPlaceRepository(db);
      final uji = (await places.getLabels(kind: 'region')).single;
      expect((await places.getPlacesByLabel(uji.id)).map((p) => p.placeKey).toSet(), {'p1', 'p2'});

      await tester.tap(find.byTooltip('Remove from library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(await places.getPlace('p1'), isNull);
      expect(await places.getPlace('p2'), isNull);
      expect(find.text('Lake Motosu'), findsOneWidget);
      expect(find.text('Add place'), findsOneWidget, reason: 'picking ends after the places are removed');
      await disposeApp(tester);
    });

    testWidgets('a place opens on its page: a filler for the missing frames, then visits and a note', (tester) async {
      await _savePlace(db, 'anitabi:42', 'Uji Bridge');
      await pump(tester);
      await tester.tap(find.text('Uji Bridge'));
      await tester.pumpAndSettle();
      expect(find.text('No anime frames yet'), findsOneWidget);
      expect(find.text('Not visited yet'), findsOneWidget);

      await tester.tap(find.text("I'm here"));
      await tester.pumpAndSettle();
      expect(find.textContaining('Visited once · last'), findsOneWidget);
      await tester.tap(find.text("I'm here"));
      await tester.pumpAndSettle();
      expect(find.text('Today is on record already.'), findsOneWidget);

      await tester.ensureVisible(find.text('Write'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('placeNoteField')), 'Bring the tripod.');
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Bring the tripod.'), findsOneWidget);
      final places = DriftPlaceRepository(db);
      expect((await places.getPlace('anitabi:42'))!.privateNote, 'Bring the tripod.');
      expect((await places.getVisitsForPlace('anitabi:42')), hasLength(1));
      await disposeApp(tester);
    });

    testWidgets('a label is added to a place on its page', (tester) async {
      await _savePlace(db, 'p1', 'Uji Bridge');
      await pump(tester);
      await tester.tap(find.text('Uji Bridge'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Label'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regions'));
      await tester.enterText(find.byKey(const Key('labelNameField')), 'Uji');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create “Uji”'));
      await tester.pumpAndSettle();

      final labels = await DriftPlaceRepository(db).getLabelsForPlace('p1');
      expect(labels.single.kind, 'region');
      expect(labels.single.name, 'Uji');
      await disposeApp(tester);
    });
  });
}
