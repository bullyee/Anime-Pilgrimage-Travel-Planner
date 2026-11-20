import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sync/services/firestore_sync_v2_service.dart';
import 'package:trip_planner/features/sync/services/sync_engine_service_v2.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

import 'sync_engine_v2_test.dart' show FakeFirestoreSyncV2Service;

/// The cloud half of v0.4.0's trash and activity log: tombstones get a TTL,
/// activity entries go up with their change and come down from others, and a
/// device that missed a purged tombstone hides the row anyway.
void main() {
  late AppDatabase db;
  late FakeFirestoreSyncV2Service cloud;
  late SyncEngineServiceV2 engine;
  const me = 'user_alice';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cloud = FakeFirestoreSyncV2Service();
    engine = SyncEngineServiceV2(localDb: db, firestoreSync: cloud, currentUserId: me);
  });

  tearDown(() async {
    engine.stopSync();
    await db.close();
  });

  Future<void> settle([int ms = 600]) => Future.delayed(Duration(milliseconds: ms));

  Future<void> sharedTrip(String id, {String owner = me, int syncStatus = 0}) async {
    await db.into(db.trips).insert(TripsCompanion.insert(
          id: id,
          title: 'Uji',
          ownerId: owner,
          sharing: const Value('group'),
          dayCount: const Value(2),
          updatedAt: Value(DateTime.now()),
          syncStatus: Value(syncStatus),
        ));
  }

  Future<void> stop(String id, String tripId, {required DateTime updatedAt, int syncStatus = 0, DateTime? deletedAt}) async {
    await db.into(db.stops).insert(StopsCompanion.insert(
          id: id,
          tripId: tripId,
          placeKey: 'anitabi:$id',
          name: 'Stop $id',
          lat: 34.9,
          lng: 135.8,
          addedBy: me,
          updatedAt: Value(updatedAt),
          updatedBy: const Value('user_bob'),
          deletedAt: Value(deletedAt),
          syncStatus: Value(syncStatus),
        ));
  }

  group('tombstone TTL', () {
    test('a live row has no expireAt, a deleted one expires 30 days from the push', () {
      final now = DateTime(2026, 11, 16, 12);
      expect(FirestoreSyncV2Service.tombstoneExpiry(null, now: now), isNull);
      final expiry = FirestoreSyncV2Service.tombstoneExpiry(DateTime(2026, 11, 1), now: now)!;
      expect(expiry, isA<Timestamp>());
      expect(expiry.toDate(), now.add(const Duration(days: 30)));
    });
  });

  group('activity entries', () {
    test('go up in the same push as the change, then count as synced', () async {
      await sharedTrip('t1');
      await stop('s1', 't1', updatedAt: DateTime.now());
      cloud.trips['t1'] = {'id': 't1'};
      engine.startSync();

      await DriftTripRepository(db, null, me).deleteStop('s1');
      await settle(1500);

      final pushed = cloud.tripActivity['t1']!.values.toList();
      expect(pushed, hasLength(1));
      expect(pushed.single['summary'], 'removed Stop s1');
      expect(pushed.single['actorId'], me);
      expect(cloud.tripStops['t1']!['s1']!['deletedAt'], isNotNull);

      final local = await db.select(db.tripActivities).getSingle();
      expect(local.syncStatus, 0);
    });

    test('an entry merged while its push is in flight goes up again under a new id', () async {
      await sharedTrip('t1');
      await stop('s1', 't1', updatedAt: DateTime.now());
      cloud.trips['t1'] = {'id': 't1'};
      final repo = DriftTripRepository(db, null, me);
      var editedMidFlight = false;
      cloud.onBeforeCommit = () async {
        if (editedMidFlight) return;
        editedMidFlight = true;
        await repo.updateStop(const StopsCompanion(id: Value('s1'), note: Value('Meet here')));
      };
      engine.startSync();

      await repo.updateStop(const StopsCompanion(id: Value('s1'), note: Value('Meet')));
      await settle(2000);

      // The log is append-only in Firestore: the merged entry is a second
      // document, never a rewrite of the first.
      final pushed = cloud.tripActivity['t1']!;
      expect(pushed, hasLength(2));
      final local = await db.select(db.tripActivities).getSingle();
      expect(local.syncStatus, 0);
      expect(pushed.keys, contains(local.id));
    });

    test("only the signed-in user's entries go up", () async {
      await sharedTrip('t1');
      await stop('s1', 't1', updatedAt: DateTime.now());
      cloud.trips['t1'] = {'id': 't1'};
      // Left behind by another account on this device.
      await db.into(db.tripActivities).insert(TripActivitiesCompanion.insert(
            id: 'theirs',
            tripId: 't1',
            actorId: 'user_bob',
            action: 'add_stop',
            entityType: 'stop',
            entityId: 's9',
            summary: 'added Kosei',
            createdAt: DateTime.now(),
            syncStatus: const Value(1),
          ));
      engine.startSync();

      await DriftTripRepository(db, null, me).deleteStop('s1');
      await settle(1500);

      expect(cloud.tripActivity['t1']!.values.map((e) => e['actorId']), [me]);
      final theirs = await (db.select(db.tripActivities)..where((a) => a.id.equals('theirs'))).getSingle();
      expect(theirs.syncStatus, 1);
    });

    test("other members' entries come down into the local log; old ones are skipped", () async {
      await sharedTrip('t1', owner: 'user_bob');
      engine.startSync();
      cloud.emitUserTrips([
        {'id': 't1', 'title': 'Uji', 'ownerId': 'user_bob', 'sharing': 'group', 'dayCount': 2, 'updatedAt': DateTime.now()},
      ]);
      await settle(200);

      cloud.emitActivity('t1', [
        {
          'id': 'a1',
          'tripId': 't1',
          'actorId': 'user_bob',
          'action': 'move_stop',
          'entityType': 'stop',
          'entityId': 's1',
          'summary': 'moved Uji Bridge to Day 2',
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1))),
        },
        {
          'id': 'a_old',
          'tripId': 't1',
          'actorId': 'user_bob',
          'action': 'add_stop',
          'entityType': 'stop',
          'entityId': 's2',
          'summary': 'added Daikichiyama',
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 40))),
        },
      ]);
      await settle(200);

      final rows = await db.select(db.tripActivities).get();
      expect(rows.map((r) => r.id), ['a1']);
      expect(rows.single.summary, 'moved Uji Bridge to Day 2');
      expect(rows.single.syncStatus, 0);
    });
  });

  group('a trip arriving', () {
    Map<String, dynamic> tripDoc() =>
        {'id': 't1', 'title': 'Uji', 'ownerId': 'user_bob', 'sharing': 'group', 'dayCount': 2, 'updatedAt': DateTime.now()};
    Map<String, dynamic> stopDoc(String id) => {
          'id': id,
          'tripId': 't1',
          'placeKey': 'anitabi:$id',
          'name': 'Stop $id',
          'lat': 34.9,
          'lng': 135.8,
          'addedBy': 'user_bob',
          'updatedAt': DateTime.now(),
        };

    test('a just-joined trip is arriving until the server sent its days, stops and schedule', () async {
      await sharedTrip('t1', owner: 'user_bob');
      final changes = <bool>[];
      final sub = engine.arrivingStream.listen((trips) => changes.add(trips.contains('t1')));
      engine.startSync();
      cloud.emitUserTrips([tripDoc()]);
      await settle(200);
      expect(engine.isTripArriving('t1'), isTrue);

      // The cache says nothing about what the server has.
      cloud.emitDays('t1', RemoteDocList(const [], isFromCache: true));
      cloud.emitDays('t1', RemoteDocList(const [], isFromCache: false));
      cloud.emitStops('t1', RemoteDocList([stopDoc('s1'), stopDoc('s2'), stopDoc('s3')], isFromCache: false));
      await settle(200);
      expect(engine.isTripArriving('t1'), isTrue);
      expect(await db.select(db.stops).get(), hasLength(3));

      cloud.emitScheduleItems('t1', RemoteDocList(const [], isFromCache: false));
      await settle(200);
      expect(engine.isTripArriving('t1'), isFalse);
      expect(changes, [true, false]);
      await sub.cancel();
    });

    test("a trip whose days are already here isn't arriving", () async {
      await sharedTrip('t1', owner: 'user_bob');
      await db.into(db.tripDays).insert(TripDaysCompanion.insert(id: 'd1', tripId: 't1', sortKey: 'a0'));
      engine.startSync();
      cloud.emitUserTrips([tripDoc()]);
      await settle(200);
      expect(engine.isTripArriving('t1'), isFalse);
    });

    test('schedule items that come before their days and stops land once those do', () async {
      await sharedTrip('t1', owner: 'user_bob');
      engine.startSync();
      cloud.emitUserTrips([tripDoc()]);
      await settle(200);

      final now = DateTime.now();
      cloud.emitScheduleItems('t1', RemoteDocList([
        for (var i = 0; i < 3; i++)
          {'id': 'i$i', 'tripId': 't1', 'dayId': 'd1', 'stopId': 's$i', 'sortKey': 'a$i', 'updatedAt': now},
      ], isFromCache: false));
      await settle(200);
      expect(await db.select(db.scheduleItems).get(), isEmpty);

      cloud.emitDays('t1', RemoteDocList([
        {'id': 'd1', 'tripId': 't1', 'sortKey': 'a0', 'updatedAt': now},
      ], isFromCache: false));
      cloud.emitStops('t1', RemoteDocList([for (var i = 0; i < 3; i++) stopDoc('s$i')], isFromCache: false));
      await settle(300);

      // No new trip snapshot came; each stop that landed let its items in.
      expect((await db.select(db.scheduleItems).get()).map((i) => i.id).toSet(), {'i0', 'i1', 'i2'});
      expect(engine.isTripArriving('t1'), isFalse);
    });

    test('on the web, a trip already here is checked against the server too', () async {
      await sharedTrip('t1', owner: 'user_bob');
      await db.into(db.tripDays).insert(TripDaysCompanion.insert(id: 'd1', tripId: 't1', sortKey: 'a0'));
      engine.stopSync();
      engine = SyncEngineServiceV2(localDb: db, firestoreSync: cloud, currentUserId: me, confirmEveryTrip: true);
      engine.startSync();
      cloud.emitUserTrips([tripDoc()]);
      await settle(200);
      expect(engine.isTripArriving('t1'), isTrue);

      cloud.emitDays('t1', RemoteDocList(const [], isFromCache: false));
      cloud.emitStops('t1', RemoteDocList(const [], isFromCache: false));
      cloud.emitScheduleItems('t1', RemoteDocList(const [], isFromCache: false));
      await settle(300);
      expect(engine.isTripArriving('t1'), isFalse);
    });

    test("a snapshot's stops land together", () async {
      await sharedTrip('t1', owner: 'user_bob');
      engine.startSync();
      cloud.emitUserTrips([tripDoc()]);
      await settle(200);

      final counts = <int>[];
      final sub = (db.select(db.stops)..where((s) => s.tripId.equals('t1'))).watch().listen((rows) => counts.add(rows.length));
      await settle(50);
      cloud.emitStops('t1', RemoteDocList([for (var i = 0; i < 5; i++) stopDoc('s$i')], isFromCache: false));
      await settle(300);
      expect(counts, [0, 5]);
      await sub.cancel();
    });
  });

  group("tombstones in someone else's name", () {
    test('a deleted row waiting on this device goes up in its user\'s name; others are left alone', () async {
      await sharedTrip('t1');
      final now = DateTime.now();
      // Deleted before the trip was shared (or by an older build): someone
      // else's updatedBy, so the rules would refuse its expireAt.
      await stop('waiting', 't1', updatedAt: now, syncStatus: 1, deletedAt: now);
      // Bob's own deletion, already in the cloud.
      await stop('bobs', 't1', updatedAt: now, deletedAt: now);
      // A live row Bob edited, waiting to go up: not a tombstone.
      await stop('live', 't1', updatedAt: now, syncStatus: 1);
      cloud.trips['t1'] = {'id': 't1'};
      engine.startSync();
      await settle(1500);

      expect(cloud.tripStops['t1']!['waiting']!['updatedBy'], me);
      expect(cloud.tripStops['t1']!['live']!['updatedBy'], 'user_bob');
      final rows = {for (final r in await db.select(db.stops).get()) r.id: r};
      expect(rows['waiting']!.updatedBy, me);
      expect(rows['waiting']!.syncStatus, 0);
      expect(rows['bobs']!.updatedBy, 'user_bob');
      expect(rows['live']!.updatedBy, 'user_bob');
    });
  });

  group('an entry the rules refuse', () {
    test("doesn't hold the trip back: the changes and the other entries go up, it stays on this phone", () async {
      await sharedTrip('t1');
      await stop('s1', 't1', updatedAt: DateTime.now());
      await stop('s2', 't1', updatedAt: DateTime.now());
      cloud.trips['t1'] = {'id': 't1'};
      final repo = DriftTripRepository(db, null, me);
      await repo.deleteStop('s1');
      await repo.deleteStop('s2');
      final entries = await db.select(db.tripActivities).get();
      expect(entries, hasLength(2));
      final refused = entries.first.id;
      cloud.refusedActivityIds.add(refused);

      engine.startSync();
      await settle(1500);

      expect(cloud.tripStops['t1']!['s1']!['deletedAt'], isNotNull);
      expect(cloud.tripStops['t1']!['s2']!['deletedAt'], isNotNull);
      expect(cloud.tripActivity['t1']!.keys, [entries.last.id]);
      final local = await db.select(db.tripActivities).get();
      expect(local.map((a) => a.syncStatus), everyElement(0));
      expect(local.map((a) => a.id), containsAll([refused, entries.last.id]));
      expect(engine.getTripSyncStatus('t1'), TripSyncStatus.synced);
    });
  });

  group('tombstones purged while away', () {
    test('a server snapshot without an old clean stop hides it; recent, dirty and cached cases are left alone', () async {
      final old = DateTime.now().subtract(const Duration(days: 45));
      await sharedTrip('t1', owner: 'user_bob');
      await stop('gone', 't1', updatedAt: old);
      await stop('recent', 't1', updatedAt: DateTime.now().subtract(const Duration(days: 3)));
      await stop('dirty', 't1', updatedAt: old, syncStatus: 1);
      await stop('kept', 't1', updatedAt: old);

      // Offline for pushes, so 'dirty' still has its local change when the snapshot arrives.
      cloud.failCommit = true;
      engine.startSync();
      cloud.emitUserTrips([
        {'id': 't1', 'title': 'Uji', 'ownerId': 'user_bob', 'sharing': 'group', 'dayCount': 2, 'updatedAt': DateTime.now()},
      ]);
      await settle(200);

      Map<String, dynamic> doc(String id) => {
            'id': id,
            'tripId': 't1',
            'placeKey': 'anitabi:$id',
            'name': 'Stop $id',
            'lat': 34.9,
            'lng': 135.8,
            'addedBy': me,
            'updatedAt': old,
          };

      // From the cache: says nothing about what the server has.
      cloud.emitStops('t1', RemoteDocList([doc('kept')], isFromCache: true));
      await settle(200);
      expect((await (db.select(db.stops)..where((s) => s.id.equals('gone'))).getSingle()).deletedAt, isNull);

      // From the server: 'gone' was purged there.
      cloud.emitStops('t1', RemoteDocList([doc('kept')], isFromCache: false));
      await settle(200);

      Future<Stop> row(String id) => (db.select(db.stops)..where((s) => s.id.equals(id))).getSingle();
      expect((await row('gone')).deletedAt, isNotNull);
      expect((await row('gone')).syncStatus, 0, reason: 'never pushed back');
      expect((await row('recent')).deletedAt, isNull, reason: 'changed within 29 days, so it would still be on the server');
      expect((await row('dirty')).deletedAt, isNull, reason: 'local edits are pushed, not dropped');
      expect((await row('kept')).deletedAt, isNull);
    });

    test('a plain list (older callers) never hides anything', () async {
      final old = DateTime.now().subtract(const Duration(days: 45));
      await sharedTrip('t1', owner: 'user_bob');
      await stop('gone', 't1', updatedAt: old);
      engine.startSync();
      cloud.emitUserTrips([
        {'id': 't1', 'title': 'Uji', 'ownerId': 'user_bob', 'sharing': 'group', 'dayCount': 2, 'updatedAt': DateTime.now()},
      ]);
      await settle(200);
      cloud.emitStops('t1', []);
      await settle(200);
      expect((await (db.select(db.stops)..where((s) => s.id.equals('gone'))).getSingle()).deletedAt, isNull);
    });
  });
}
