import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/services/locate.dart';
import 'package:trip_planner/features/camera/models/shooting_core_models.dart';
import 'package:trip_planner/features/camera/providers/shooting_core_providers.dart';
import 'package:trip_planner/features/camera/widgets/shoot_here_sheet.dart';

Position _at(double lat, double lng, {double accuracy = 10}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 11, 8),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Place _place(String key) => Place(
  placeKey: key,
  name: key,
  lat: 34.89,
  lng: 135.80,
  visibility: 'saved',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

NewReferenceImage _frame(String id, {String? placeKey, String? stopId, int order = 0, String? episode, String? path}) =>
    NewReferenceImage(
      id: id,
      placeKey: placeKey,
      stopId: stopId,
      localPath: path ?? '/frames/$id.jpg',
      episode: episode,
      createdAt: DateTime(2026, 1, 1 + order),
    );

Stop _stop(String placeKey) => Stop(
  id: 'stop-$placeKey',
  tripId: 'kyoto',
  placeKey: placeKey,
  name: placeKey,
  lat: 34.89,
  lng: 135.80,
  addedBy: 'me',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  syncStatus: 0,
);

/// A stop on the day shown (today), on [day] of the trip, or a library place.
NearbyShootingPlace _today(String key, double meters, {List<NewReferenceImage> frames = const []}) =>
    NearbyShootingPlace(
      place: _place(key),
      name: key,
      placeKey: key,
      distanceMeters: meters,
      isTargetDayStop: true,
      todayStop: _stop(key),
      dayNumber: 2,
      referenceFrames: frames,
    );

NearbyShootingPlace _onDay(String key, double meters, int day) => NearbyShootingPlace(
  place: _place(key),
  name: key,
  placeKey: key,
  distanceMeters: meters,
  todayStop: _stop(key),
  dayNumber: day,
);

NearbyShootingPlace _library(String key, double meters, {List<NewReferenceImage> frames = const []}) =>
    NearbyShootingPlace(place: _place(key), name: key, placeKey: key, distanceMeters: meters, referenceFrames: frames);

TodayTripInfo _kyotoToday() {
  final trip = Trip(
    id: 'kyoto',
    title: 'Kyoto',
    ownerId: 'me',
    sharing: 'private',
    dayCount: 3,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    syncStatus: 0,
  );
  final day = TripDay(id: 'd2', tripId: 'kyoto', sortKey: '1', updatedAt: DateTime(2026), syncStatus: 0);
  return TodayTripInfo(trip: trip, day: day, stops: const [], scheduleItems: const [], stopMap: const {});
}

void main() {
  late List<NearbyPlacesQuery> queries;
  late int locates;
  ShootHereChoice? picked;
  late bool closed;

  /// A page with a button that opens the sheet; the pick lands in [picked].
  Future<void> open(
    WidgetTester tester, {
    required LocateResult Function() locate,
    List<NearbyShootingPlace> nearby = const [],
    bool tripDay = false,
    bool settle = true,
  }) async {
    queries = [];
    locates = 0;
    picked = null;
    closed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locateProvider.overrideWithValue(() async {
            locates++;
            return locate();
          }),
          todayTripProvider.overrideWith((ref) async => tripDay ? _kyotoToday() : null),
          nearbyShootingPlacesProvider.overrideWith((ref, query) async {
            queries.add(query);
            return nearby;
          }),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await pickShootHere(context);
                closed = true;
              },
              child: const Text('shoot'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('shoot'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Up to the places, but not through the countdown.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  List<String> cardKeys(WidgetTester tester, String row) => tester
      .widgetList(
        find.descendant(of: find.byKey(Key(row)), matching: find.byWidgetPredicate((w) => w.key is ValueKey<String>)),
      )
      .map((w) => (w.key! as ValueKey<String>).value)
      .where((k) => k.startsWith('shootHere:'))
      .toList();

  testWidgets("on a trip day: the day's stops nearest first, the rest behind Other places nearby", (tester) async {
    await open(
      tester,
      tripDay: true,
      locate: () => LocateResult.found(_at(34.891, 135.808)),
      nearby: [
        _today(
          'bridge',
          120,
          frames: [
            // Frames come oldest first, the place's own before the stop's copies,
            // and a copy of a frame the place has shows once.
            _frame('b2', placeKey: 'bridge', order: 2),
            _frame('b1', placeKey: 'bridge', order: 1, episode: '1'),
            _frame('b1-copy', stopId: 'stop-bridge', path: '/frames/b1.jpg'),
            _frame('shared', stopId: 'stop-bridge', order: 3),
          ],
        ),
        _today('bench', 30),
        _onDay('shrine', 60, 3),
        _library('cafe', 90),
      ],
    );

    expect(queries.single.lat, 34.891);
    expect(queries.single.maxDistanceMeters, 150);
    expect(find.text("2 of today's stops are within 150 m, nearest first."), findsOneWidget);
    expect(cardKeys(tester, 'shootHereFirst').take(3), [
      'shootHere:bridge:b1',
      'shootHere:bridge:b2',
      'shootHere:bridge:shared',
    ]);
    expect(find.text('120 m · Ep 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('shootHere:bench:-')),
      200,
      scrollable: find.descendant(of: find.byKey(const Key('shootHereFirst')), matching: find.byType(Scrollable)),
    );
    expect(cardKeys(tester, 'shootHereFirst').last, 'shootHere:bench:-');
    expect(find.text('30 m · No frame yet'), findsOneWidget);

    // The others wait, closed, until asked for.
    expect(find.text('Other places nearby (2)'), findsOneWidget);
    expect(find.byKey(const Key('shootHereOtherFrames')), findsNothing);
    await tester.tap(find.text('Other places nearby (2)'));
    await tester.pumpAndSettle();
    expect(cardKeys(tester, 'shootHereOtherFrames'), ['shootHere:shrine:-', 'shootHere:cafe:-']);
    expect(find.text('Day 3 · 60 m · No frame yet'), findsOneWidget);
    expect(find.text('Library · 90 m · No frame yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shootHere:bridge:b2')));
    await tester.pumpAndSettle();
    final choice = picked! as ShootAtPlace;
    expect((choice.placeKey, choice.frame!.id, choice.tripId), ('bridge', 'b2', 'kyoto'));
  });

  testWidgets("none of the day's stops nearby: the others are open already", (tester) async {
    await open(
      tester,
      tripDay: true,
      locate: () => LocateResult.found(_at(34.891, 135.808)),
      nearby: [_onDay('shrine', 60, 3), _library('cafe', 90)],
    );

    expect(find.text("None of today's stops is within 150 m."), findsOneWidget);
    expect(cardKeys(tester, 'shootHereOtherFrames'), ['shootHere:shrine:-', 'shootHere:cafe:-']);
    await tester.tap(find.text('cafe'));
    await tester.pumpAndSettle();
    final choice = picked! as ShootAtPlace;
    expect((choice.placeKey, choice.tripId), ('cafe', null));
  });

  testWidgets('no trip today: the library places, with nothing behind a row', (tester) async {
    await open(
      tester,
      locate: () => LocateResult.found(_at(34.891, 135.808)),
      nearby: [_library('cafe', 20), _library('bench', 90)],
    );

    expect(find.text('2 places within 150 m, nearest first.'), findsOneWidget);
    expect(cardKeys(tester, 'shootHereFirst'), ['shootHere:cafe:-', 'shootHere:bench:-']);
    expect(find.byKey(const Key('shootHereOthers')), findsNothing);
  });

  testWidgets('one place with one frame: the camera opens by itself after a moment', (tester) async {
    await open(
      tester,
      settle: false,
      locate: () => LocateResult.found(_at(34.891, 135.808)),
      nearby: [
        _library('bench', 30, frames: [_frame('f1', placeKey: 'bench')]),
      ],
    );

    expect(find.text('Opening the camera for bench…'), findsOneWidget);
    expect(closed, isFalse);
    await tester.pump(shootHereAutoOpen);
    await tester.pumpAndSettle();
    final choice = picked! as ShootAtPlace;
    expect((choice.placeKey, choice.frame!.id), ('bench', 'f1'));
  });

  testWidgets("one place, but not this one: Not this place stops the countdown", (tester) async {
    await open(
      tester,
      settle: false,
      locate: () => LocateResult.found(_at(34.891, 135.808)),
      nearby: [_library('bench', 30)],
    );

    await tester.tap(find.byKey(const Key('shootHereStop')));
    await tester.pump(shootHereAutoOpen * 2);
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('One place within 150 m.'), findsOneWidget);

    await tester.tap(find.text('No reference'));
    await tester.pumpAndSettle();
    expect((picked! as ShootWithoutPlace).kind, ShootHereOther.noReference);
  });

  testWidgets('one place with several frames: the user picks the frame', (tester) async {
    await open(
      tester,
      settle: false,
      locate: () => LocateResult.found(_at(34.891, 135.808)),
      nearby: [
        _library(
          'bench',
          30,
          frames: [
            _frame('f1', placeKey: 'bench'),
            _frame('f2', placeKey: 'bench', order: 1),
          ],
        ),
      ],
    );

    expect(find.byKey(const Key('shootHereStop')), findsNothing);
    await tester.pump(shootHereAutoOpen * 2);
    expect(closed, isFalse);
    expect(cardKeys(tester, 'shootHereFirst'), ['shootHere:bench:f1', 'shootHere:bench:f2']);
  });

  testWidgets('nothing nearby: says so, with a rough fix noted, and the other ways still work', (tester) async {
    await open(tester, locate: () => LocateResult.found(_at(34.891, 135.808, accuracy: 120)));

    expect(
      find.text('None of your saved places is within 150 m. Your location is rough (±120 m), so some may be missing.'),
      findsOneWidget,
    );
    await tester.tap(find.text("Another place's frames"));
    await tester.pumpAndSettle();
    expect((picked! as ShootWithoutPlace).kind, ShootHereOther.anotherPlace);
  });

  testWidgets('no location access: explains, asks again, and finds the places once allowed', (tester) async {
    var allowed = false;
    await open(
      tester,
      locate: () =>
          allowed ? LocateResult.found(_at(34.891, 135.808)) : const LocateResult.failed(LocateProblem.denied),
      nearby: [_library('bench', 30), _library('cafe', 40)],
    );

    expect(find.text('Allow location access to see the places around you. You can still shoot below.'), findsOneWidget);
    expect(queries, isEmpty);
    allowed = true;
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(locates, 2);
    expect(find.text('bench'), findsOneWidget);
  });

  testWidgets('location off: a way to the settings, and shooting still works', (tester) async {
    await open(tester, locate: () => const LocateResult.failed(LocateProblem.serviceOff));
    expect(find.textContaining('Location is turned off'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('No reference'), findsOneWidget);
  });

  testWidgets('location refused for good: a way to the settings, and shooting still works', (tester) async {
    await open(tester, locate: () => const LocateResult.failed(LocateProblem.deniedForever));
    expect(find.textContaining('Location access is off for Trip Planner'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    await tester.tap(find.text('A reference from the gallery'));
    await tester.pumpAndSettle();
    expect((picked! as ShootWithoutPlace).kind, ShootHereOther.gallery);
  });

  testWidgets('no fix: try again finds the place', (tester) async {
    var tries = 0;
    await open(
      tester,
      locate: () =>
          ++tries == 1 ? const LocateResult.failed(LocateProblem.noFix) : LocateResult.found(_at(34.891, 135.808)),
      nearby: [_library('bench', 30), _library('cafe', 40)],
    );

    expect(find.text("Couldn't find where you are. Try again in the open."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('bench'), findsOneWidget);
  });
}
