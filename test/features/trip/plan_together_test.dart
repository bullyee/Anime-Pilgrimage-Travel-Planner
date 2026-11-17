import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/sync/providers/sync_v2_providers.dart';
import 'package:trip_planner/features/trip/providers/plan_together_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/trip_activity_screen.dart';
import 'package:trip_planner/features/trip/screens/trip_trash_screen.dart';
import 'package:trip_planner/features/trip/services/trip_activity_log.dart';

/// v0.4.0's planning together: the activity log the repository writes, the
/// trash and its Restore, and the unread dot.
void main() {
  late AppDatabase db;
  const me = 'user_alice';
  const bob = 'user_bob';

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The log in the order it was written.
  Future<List<TripActivity>> log() async {
    final order = [for (final r in await db.customSelect('SELECT id FROM trip_activities ORDER BY rowid').get()) r.read<String>('id')];
    final byId = {for (final a in await db.select(db.tripActivities).get()) a.id: a};
    return [for (final id in order) byId[id]!];
  }

  Future<Trip> newTrip(DriftTripRepository repo, {bool shared = true, int days = 2}) async {
    final trip = await repo.createTrip(title: 'Uji', ownerId: me, dayCount: days);
    if (shared) {
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(const TripsCompanion(sharing: Value('group')));
    }
    return trip;
  }

  group('activity log', () {
    test('a shared trip records who did what, waiting to be pushed', () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      final days = await repo.getDaysForTrip(trip.id);
      final stop = await repo.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: me);
      final item = await repo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days[0].id);
      await repo.moveScheduleItems(itemIds: [item.id], newSortKeys: ['a5'], targetDayId: days[1].id);
      await repo.updateScheduleItemStatus(itemId: item.id, status: 'done');
      await repo.deleteScheduleItems([item.id]);
      await repo.deleteStop(stop.id);
      await repo.restoreStop(stop.id);

      final entries = await log();
      expect(entries.map((e) => e.summary), [
        'added Uji Bridge',
        'planned Uji Bridge on Day 1',
        'moved Uji Bridge to Day 2',
        'marked Uji Bridge done',
        'took Uji Bridge off Day 2',
        'removed Uji Bridge',
        'restored Uji Bridge',
      ]);
      expect(entries.every((e) => e.actorId == me && e.syncStatus == 1 && e.tripId == trip.id), isTrue);
      expect(entries.first.entityType, 'stop');
      expect(entries.first.entityId, stop.id);
    });

    test('a private trip has no log, and nor does a signed-out user', () async {
      final private = DriftTripRepository(db, null, me);
      final trip = await newTrip(private, shared: false);
      await private.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: me);

      final guest = DriftTripRepository(db, null, 'guest_local_user');
      final shared = await newTrip(guest);
      await guest.createTripOnlySpot(tripId: shared.id, name: 'Kosei', lat: 34.9, lng: 135.8, addedBy: 'guest_local_user');

      expect(await log(), isEmpty);
    });

    test('quick repeated edits to the same stop make one entry', () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      final stop = await repo.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: me);
      for (final note in ['M', 'Me', 'Meet here']) {
        await repo.updateStop(StopsCompanion(id: Value(stop.id), note: Value(note)));
      }
      final edits = (await log()).where((e) => e.action == TripActivityAction.updateStop.value).toList();
      expect(edits, hasLength(1));
      expect(edits.single.summary, 'edited the note on Uji Bridge');
    });

    test('days are named by their place, backup days as such', () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo, days: 1);
      final extra = await repo.addDayBlock(trip.id, title: 'Rain');
      await repo.deleteDayBlock(extra.id);
      expect((await log()).map((e) => e.summary), ['added a backup day (Rain)', 'deleted a backup day (Rain)']);
    });

    test('merging stops is one entry, not a removal per stop', () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      final a = await repo.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: me);
      final b = await repo.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge (night)', lat: 34.89, lng: 135.80, addedBy: me);
      await repo.mergeStops(keepId: a.id, otherIds: [b.id]);
      final merged = (await log()).where((e) => e.action != TripActivityAction.addStop.value).map((e) => e.summary);
      expect(merged, ['merged Uji Bridge (night) into Uji Bridge']);
    });

    test('a trip edit is logged by what changed, and not at all when nothing did', () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      // The edit sheet sends every field.
      await repo.updateTrip(TripsCompanion(id: Value(trip.id), title: const Value('Uji'), description: const Value('Tea')));
      await repo.updateTrip(TripsCompanion(id: Value(trip.id), title: const Value('Uji'), description: const Value('Tea')));
      expect((await log()).map((e) => e.summary), ["edited the trip's description"]);
      // A rename soon after merges into the same entry.
      await repo.updateTrip(TripsCompanion(id: Value(trip.id), title: const Value('Uji 2')));
      expect((await log()).map((e) => e.summary), ['renamed the trip to "Uji 2"']);
    });

    test('long summaries are clipped, also when a repeat merges, without splitting an emoji', () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      final activity = TripActivityLog(db);
      final long = '${'a' * 478}😀${'b' * 100}';
      final clipped = TripActivityLog.clipSummary(long);
      expect(clipped.length, lessThanOrEqualTo(480));
      expect(clipped, '${'a' * 478}…');
      for (final s in ['short', long]) {
        await activity.record(
          tripId: trip.id, actorId: me, action: TripActivityAction.updateStop,
          entityType: 'stop', entityId: 's', summary: s,
        );
      }
      final entry = (await log()).single;
      expect(entry.summary.length, lessThanOrEqualTo(480));
    });

    test('expireOld drops entries older than 30 days', () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      final activity = TripActivityLog(db);
      await activity.record(
        tripId: trip.id,
        actorId: bob,
        action: TripActivityAction.addStop,
        entityType: 'stop',
        entityId: 's',
        summary: 'added Kosei',
        at: DateTime.now().subtract(const Duration(days: 31)),
      );
      await activity.record(
        tripId: trip.id,
        actorId: bob,
        action: TripActivityAction.addStop,
        entityType: 'stop',
        entityId: 't',
        summary: 'added Daikichiyama',
      );
      expect(await activity.expireOld(), 1);
      expect((await log()).map((e) => e.summary), ['added Daikichiyama']);
    });
  });

  group('restore', () {
    test('restoring a stop leaves its plan on a day deleted since in the trash', () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      final days = await repo.getDaysForTrip(trip.id);
      final stop = await repo.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: me);
      final onDay2 = await repo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days[1].id);
      await repo.deleteStop(stop.id);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.deleteDayBlock(days[1].id);

      await repo.restoreStop(stop.id);
      final restored = await (db.select(db.stops)..where((s) => s.id.equals(stop.id))).getSingle();
      expect(restored.deletedAt, isNull);
      final item = await (db.select(db.scheduleItems)..where((i) => i.id.equals(onDay2.id))).getSingle();
      expect(item.deletedAt, isNotNull);
    });

    test('restoring a trip also re-sends what this device still has live', () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      final stop = await repo.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: me);
      // Deleted on another of the owner's devices: this one pulled the trip's
      // tombstone, but not its stops'.
      await (db.update(db.stops)..where((s) => s.id.equals(stop.id))).write(const StopsCompanion(syncStatus: Value(0)));
      await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
          .write(TripsCompanion(deletedAt: Value(DateTime.now()), syncStatus: const Value(0)));

      await repo.restoreTrip(trip.id);
      final again = await (db.select(db.stops)..where((s) => s.id.equals(stop.id))).getSingle();
      expect(again.deletedAt, isNull);
      expect(again.syncStatus, 1);
      expect(again.updatedBy, me);
    });
  });

  group('unread dot', () {
    test("shows after someone else's change and clears once seen", () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(me),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(tripHasUnreadProvider(trip.id), (_, _) {});
      addTearDown(sub.close);

      Future<bool> unread() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return container.read(tripHasUnreadProvider(trip.id));
      }

      // My own change never makes a dot.
      await repo.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: me);
      expect(await unread(), isFalse);

      final activity = TripActivityLog(db);
      await activity.record(
        tripId: trip.id, actorId: bob, action: TripActivityAction.addStop,
        entityType: 'stop', entityId: 's', summary: 'added Kosei',
        at: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(await unread(), isTrue);

      await markTripActivitySeen(db, trip.id, me);
      expect(await unread(), isFalse);

      await activity.record(
        tripId: trip.id, actorId: bob, action: TripActivityAction.removeStop,
        entityType: 'stop', entityId: 's', summary: 'removed Kosei',
        at: DateTime.now().add(const Duration(seconds: 1)),
      );
      expect(await unread(), isTrue);
    });

    test("a member's clock running ahead doesn't leave the dot on", () async {
      final repo = DriftTripRepository(db, null, me);
      final trip = await newTrip(repo);
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(me),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(tripHasUnreadProvider(trip.id), (_, _) {});
      addTearDown(sub.close);

      await TripActivityLog(db).record(
        tripId: trip.id, actorId: bob, action: TripActivityAction.addStop,
        entityType: 'stop', entityId: 's', summary: 'added Kosei',
        at: DateTime.now().add(const Duration(minutes: 3)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(tripHasUnreadProvider(trip.id)), isTrue);

      await markTripActivitySeen(db, trip.id, me);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(tripHasUnreadProvider(trip.id)), isFalse);
    });
  });

  group('screens', () {
    TripMember member(String userId, String name, TripMemberRole role) => TripMember(
          userId: userId,
          tripId: 't',
          role: role,
          displayName: name,
          joinedAt: DateTime(2026, 11, 1),
        );

    Future<void> pump(WidgetTester tester, String location, {required String tripId, TripMemberRole myRole = TripMemberRole.editor}) async {
      final router = GoRouter(initialLocation: location, routes: [
        GoRoute(path: '/trips/deleted', builder: (_, _) => const DeletedTripsScreen()),
        GoRoute(path: '/trips/:tripId/trash', builder: (_, s) => TripTrashScreen(tripId: s.pathParameters['tripId']!)),
        GoRoute(path: '/trips/:tripId/activity', builder: (_, s) => TripActivityScreen(tripId: s.pathParameters['tripId']!)),
        GoRoute(path: '/trips/:tripId', builder: (_, s) => Scaffold(body: Text('trip ${s.pathParameters['tripId']}'))),
        GoRoute(path: '/trips/:tripId/stops/:stopId', builder: (_, s) => Scaffold(body: Text('stop ${s.pathParameters['stopId']}'))),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue(me),
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          syncEngineServiceV2Provider.overrideWithValue(null),
          tripMembersProvider(tripId).overrideWith((ref) => Stream.value([
                member(me, 'Alice', myRole),
                member(bob, 'Bob', TripMemberRole.owner),
              ])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('the trash lists what Bob deleted and Restore brings it back', (tester) async {
      late Trip trip;
      late Stop stop;
      await tester.runAsync(() async {
        final asBob = DriftTripRepository(db, null, bob);
        trip = await newTrip(asBob);
        stop = await asBob.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: bob);
        await asBob.deleteStop(stop.id);
      });
      await pump(tester, '/trips/${trip.id}/trash', tripId: trip.id);

      expect(find.text('Uji Bridge'), findsOneWidget);
      expect(find.textContaining('Bob deleted it today · 30 days left'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();
      final restored = await tester.runAsync(() => (db.select(db.stops)..where((s) => s.id.equals(stop.id))).getSingle());
      expect(restored!.deletedAt, isNull);
      expect(find.text('Uji Bridge'), findsNothing);
      await done(tester);
    });

    testWidgets('a viewer sees the trash but has no Restore', (tester) async {
      late Trip trip;
      await tester.runAsync(() async {
        final asBob = DriftTripRepository(db, null, bob);
        trip = await newTrip(asBob);
        final stop = await asBob.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: bob);
        await asBob.deleteStop(stop.id);
      });
      await pump(tester, '/trips/${trip.id}/trash', tripId: trip.id, myRole: TripMemberRole.viewer);
      expect(find.text('Uji Bridge'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsNothing);
      await done(tester);
    });

    testWidgets('a deleted trip can be restored from Recently deleted trips', (tester) async {
      late Trip trip;
      await tester.runAsync(() async {
        final repo = DriftTripRepository(db, null, me);
        trip = await newTrip(repo, shared: false);
        await repo.deleteTrip(trip.id);
      });
      await pump(tester, '/trips/deleted', tripId: 'none');
      expect(find.text('Uji'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();
      final restored = await tester.runAsync(() => (db.select(db.trips)..where((t) => t.id.equals(trip.id))).getSingle());
      expect(restored!.deletedAt, isNull);
      expect(find.text('No trips deleted in the last 30 days.'), findsOneWidget);
      await done(tester);
    });

    testWidgets('What changed shows who did what and clears the dot', (tester) async {
      late Trip trip;
      late Stop stop;
      await tester.runAsync(() async {
        final asBob = DriftTripRepository(db, null, bob);
        trip = await newTrip(asBob);
        stop = await asBob.createTripOnlySpot(tripId: trip.id, name: 'Uji Bridge', lat: 34.89, lng: 135.80, addedBy: bob);
      });
      await pump(tester, '/trips/${trip.id}/activity', tripId: trip.id);

      expect(find.text('Today'), findsOneWidget);
      expect(find.textContaining('added Uji Bridge'), findsOneWidget);
      final seen = await tester.runAsync(
          () => (db.select(db.tripViews)..where((v) => v.tripId.equals(trip.id) & v.userId.equals(me))).getSingleOrNull());
      expect(seen, isNotNull);

      await tester.tap(find.textContaining('added Uji Bridge'));
      await tester.pumpAndSettle();
      expect(find.text('stop ${stop.id}'), findsOneWidget);
      await done(tester);
    });
  });
}
