import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/utils/schedule_logic.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/camera/models/shooting_core_models.dart';
import 'package:trip_planner/features/camera/providers/shooting_core_providers.dart';
import 'package:trip_planner/features/home/providers/home_providers.dart';
import 'package:trip_planner/features/home/screens/home_screen.dart';
import 'package:trip_planner/features/home/widgets/next_trip_card.dart';
import 'package:trip_planner/features/library/models/library_entry.dart';
import 'package:trip_planner/features/library/providers/library_providers.dart';
import 'package:trip_planner/features/planner/models/planner_view.dart';
import 'package:trip_planner/features/planner/providers/planner_providers.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/trip/models/trip_summary.dart';
import 'package:trip_planner/features/trip/providers/trip_list_providers.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

/// Records status changes; nothing else is called from Home.
class _Trips implements TripRepository {
  final statuses = <(String, String)>[];

  @override
  Future<void> updateScheduleItemStatus({required String itemId, required String status}) async =>
      statuses.add((itemId, status));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Trip _trip(String id, String title, {String? start, int days = 3, DateTime? created}) => Trip(
      id: id,
      title: title,
      ownerId: 'me',
      sharing: 'private',
      startDate: start,
      dayCount: days,
      createdAt: created ?? DateTime(2026, 11, 1),
      updatedAt: DateTime(2026),
      syncStatus: 0,
    );

TripSummary _summary(Trip trip, {DateTime? first, DateTime? last, TripStatus status = TripStatus.planning}) =>
    TripSummary(trip: trip, status: status, firstDate: first, lastDate: last, dayCount: trip.dayCount, stopCount: 0);

DateTime _d(int day) => DateTime.utc(2026, 11, day);

Place _place(String key, double lat, double lng, {String visibility = 'saved'}) => Place(
      placeKey: key,
      name: key,
      lat: lat,
      lng: lng,
      visibility: visibility,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// A day of [trip] on Nov [date], with stops named [stops]; those in [done]
/// are visited.
PlannerDay _day(Trip trip, int index, int date, List<String> stops, {Set<String> done = const {}}) {
  final day = TripDay(id: '${trip.id}-d$index', tripId: trip.id, sortKey: '$index', updatedAt: DateTime(2026), syncStatus: 0);
  return PlannerDay(
    day: day,
    index: index,
    isBackup: false,
    date: _d(date),
    pinConflict: false,
    freeDaysBefore: 0,
    items: [
      for (final (i, name) in stops.indexed)
        PlannerItem(
          item: ScheduleItem(
            id: '${day.id}-$i',
            tripId: trip.id,
            stopId: 'stop-$name',
            dayId: day.id,
            sortKey: '$i',
            stayMinutes: 60,
            transitMinutes: 0,
            status: done.contains(name) ? 'done' : 'planned',
            updatedAt: DateTime(2026),
            syncStatus: 0,
          ),
          stop: Stop(
            id: 'stop-$name',
            tripId: trip.id,
            placeKey: name,
            name: name,
            lat: 34.89 + i * 0.001,
            lng: 135.8 + i * 0.001,
            addedBy: 'me',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            syncStatus: 0,
          ),
          startMinutes: 9 * 60 + i * 60,
          endMinutes: 10 * 60 + i * 60,
          fixed: false,
          conflict: false,
        ),
    ],
  );
}

void main() {
  group('pickHomeFocus', () {
    final kyoto = _trip('kyoto', 'Kyoto');
    final tokyo = _trip('tokyo', 'Tokyo');
    final later = _trip('later', 'Someday', created: DateTime(2026, 11, 5));

    test('a trip covering today is the trip day', () {
      final focus = pickHomeFocus([
        _summary(tokyo, first: _d(20), last: _d(22)),
        _summary(kyoto, first: _d(14), last: _d(16)),
      ], DateTime(2026, 11, 15, 23, 59));
      expect((focus as HomeTripDay).trip.trip.id, 'kyoto');
    });

    test('the day after the last day, the trip is over and the next one shows', () {
      final focus = pickHomeFocus([
        _summary(kyoto, first: _d(14), last: _d(16)),
        _summary(tokyo, first: _d(20), last: _d(22)),
      ], DateTime(2026, 11, 17, 0, 1));
      expect((focus as HomeNextTrip).trip!.trip.id, 'tokyo');
    });

    test('with nothing coming up, the newest trip with no dates; with no trips, nothing', () {
      expect((pickHomeFocus([_summary(tokyo), _summary(later)], DateTime(2026, 11, 9)) as HomeNextTrip).trip!.trip.id, 'later');
      expect((pickHomeFocus([], DateTime(2026, 11, 9)) as HomeNextTrip).trip, isNull);
    });

    test('two trips today: the one that started last', () {
      final focus = pickHomeFocus([
        _summary(kyoto, first: _d(10), last: _d(16)),
        _summary(tokyo, first: _d(15), last: _d(15)),
      ], DateTime(2026, 11, 15));
      expect((focus as HomeTripDay).trip.trip.id, 'tokyo');
    });
  });

  group('describeDays and nearbyPlaces', () {
    test('runs of days read as ranges', () {
      expect(describeDays([3]), 'Day 3');
      expect(describeDays([3, 7, 8, 9, 10, 11]), 'Day 3, Days 7–11');
    });

    test('saved places within 3 km, nearest first, three at most', () {
      LibraryEntry e(Place p) => LibraryEntry(place: p, labels: const [], tripIds: const {});
      final uji = LatLng(34.8930, 135.8062);
      final near = nearbyPlaces([
        e(_place('far', 35.0116, 135.7681)), // Kyoto Station, about 13 km
        e(_place('bridge', 34.8931, 135.8063)),
        e(_place('tripOnly', 34.8931, 135.8063, visibility: 'trip_only')),
        e(_place('station', 34.8939, 135.8070)),
        e(_place('park', 34.8881, 135.8087)),
        e(_place('dam', 34.8809, 135.8281)),
      ], uji);
      expect([for (final n in near) n.entry.place.placeKey], ['bridge', 'station', 'park']);
      expect(formatMeters(near[1].meters), '120 m');
      expect(formatMeters(2345), '2.3 km');
    });
  });

  group('HomeScreen', () {
    final kyoto = _trip('kyoto', 'Kyoto · Uji', start: '2026-11-14');
    final view = PlannerView(
      trip: kyoto,
      days: [
        _day(kyoto, 0, 14, ['Fushimi Inari']),
        _day(kyoto, 1, 15, ['Keihan Uji Station', 'Uji Bridge', 'Asagiri Bridge'], done: {'Keihan Uji Station'}),
        _day(kyoto, 2, 16, []),
      ],
      backlog: const [],
    );

    Future<_Trips> pump(WidgetTester tester,
        {required DateTime now,
        required List<TripSummary> trips,
        bool canEdit = true,
        List<PhotoToEditItem> toEdit = const []}) async {
      final repo = _Trips();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          homeClockProvider.overrideWithValue(() => now),
          homeMapTilesProvider.overrideWithValue(false),
          homeWhereProvider.overrideWith((ref) async => (allowed: false, at: null)),
          libraryEntriesProvider.overrideWith((ref) => const AsyncData(<LibraryEntry>[])),
          tripSummariesProvider.overrideWith((ref) => AsyncData(trips)),
          plannerViewProvider.overrideWith((ref, id) => AsyncData(view)),
          stopReferenceImagesProvider.overrideWith((ref, id) => Stream.value(const <NewReferenceImage>[])),
          canEditTripProvider.overrideWith((ref, id) => canEdit),
          tripRepositoryProvider.overrideWithValue(repo),
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          photosToEditStreamProvider.overrideWith((ref) => Stream.value(toEdit)),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets("on a trip day: today's card, with a map and the next stop", (tester) async {
      final repo = await pump(tester, now: DateTime(2026, 11, 15, 10), trips: [_summary(kyoto, first: _d(14), last: _d(16))]);
      expect(find.byKey(const Key('homePhotosToEdit')), findsNothing, reason: 'no photos to edit');

      expect(find.text('TODAY · SUN, NOV 15'), findsOneWidget);
      expect(find.text('Day 2 of 3'), findsOneWidget);
      expect(find.text('Kyoto · Uji'), findsOneWidget);
      expect(find.text('1 of 3 visited'), findsOneWidget);
      expect(find.byKey(const Key('homeTodayMap')), findsOneWidget);
      expect(find.text('2 · NEXT'), findsOneWidget);
      expect(find.text('Uji Bridge'), findsOneWidget);
      expect(find.text('Fushimi Inari'), findsNothing, reason: 'the other days live on the day map');

      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();
      expect(repo.statuses, [('kyoto-d1-1', 'done')]);
      expect(find.text('Uji Bridge done'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repo.statuses.last, ('kyoto-d1-1', 'planned'));
    });

    testWidgets('photos to edit: a row under the top card, only when there are some', (tester) async {
      PhotoToEditItem item(String id) => PhotoToEditItem(
            photo: Photo(
              id: id,
              placeKey: 'uji',
              kind: 'original',
              localPath: '/photos/$id.jpg',
              isShared: false,
              keepAsIs: false,
              createdAt: DateTime(2026, 11, 15),
            ),
          );
      await pump(tester,
          now: DateTime(2026, 11, 15, 10),
          trips: [_summary(kyoto, first: _d(14), last: _d(16))],
          toEdit: [item('a'), item('b'), item('c')]);
      expect(find.text('3 photos to edit'), findsOneWidget);
      final card = tester.getTopLeft(find.byKey(const Key('homePhotosToEdit')));
      expect(card.dy, greaterThan(tester.getBottomLeft(find.byKey(const Key('homeToday'))).dy));
    });

    testWidgets('a viewer sees the next stop but no Mark done', (tester) async {
      await pump(tester,
          now: DateTime(2026, 11, 15, 10), trips: [_summary(kyoto, first: _d(14), last: _d(16))], canEdit: false);
      expect(find.text('Uji Bridge'), findsOneWidget);
      expect(find.text('Mark done'), findsNothing);
    });

    testWidgets('a trip day with nothing planned', (tester) async {
      await pump(tester, now: DateTime(2026, 11, 16, 10), trips: [_summary(kyoto, first: _d(14), last: _d(16))]);
      expect(find.text('Nothing planned for Day 3.'), findsOneWidget);
      expect(find.text('Plan this day'), findsOneWidget);
      expect(find.byKey(const Key('homeTodayMap')), findsNothing);
    });

    testWidgets('on other days: the next trip on a map, with what is still to plan', (tester) async {
      await pump(tester, now: DateTime(2026, 11, 6, 10), trips: [_summary(kyoto, first: _d(14), last: _d(16))]);

      expect(find.text('NEXT TRIP · IN 8 DAYS'), findsOneWidget);
      expect(find.text('Nov 14 – Nov 16'), findsOneWidget);
      expect(find.text('Kyoto · Uji'), findsOneWidget);
      expect(find.byKey(const Key('homeTripMap')), findsOneWidget);
      expect(find.text('3 days · 4 stops'), findsOneWidget);
      expect(find.text('Day 3 not planned'), findsOneWidget);
      expect(find.text('Continue planning'), findsOneWidget);
    });

    testWidgets('with no trips: a way to plan one', (tester) async {
      await pump(tester, now: DateTime(2026, 11, 6), trips: const []);

      expect(find.text('Plan a trip'), findsOneWidget);
      expect(find.text('Import from Anitabi'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.byKey(const Key('homeNearYou')), findsNothing, reason: 'an empty library has nothing near');
    });
  });
}
