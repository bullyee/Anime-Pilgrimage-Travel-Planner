import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show WriteBatch;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sync/services/firestore_sync_v2_service.dart';
import 'package:trip_planner/features/sync/services/sync_engine_service_v2.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';

/// A shared Firestore simulation that broadcasts cloud updates to both Alice and Bob.
// Extends [Fake] so that members added to [FirestoreSyncV2Service] by other
// PRs (e.g. #103's activity/photo methods) don't break compilation here; any
// unimplemented member that the engine actually calls still fails loudly with
// UnimplementedError instead of silently returning null.
class SharedCollaborativeCloud extends Fake implements FirestoreSyncV2Service {
  final Map<String, Map<String, dynamic>> trips = {};
  final Map<String, Map<String, Map<String, dynamic>>> tripDays = {};
  final Map<String, Map<String, Map<String, dynamic>>> tripStops = {};
  final Map<String, Map<String, Map<String, dynamic>>> tripScheduleItems = {};

  final Map<String, StreamController<UserTripsSnapshot>> userTripsControllers = {};
  final Map<String, StreamController<List<Map<String, dynamic>>>> daysControllers = {};
  final Map<String, StreamController<List<Map<String, dynamic>>>> stopsControllers = {};
  final Map<String, StreamController<List<Map<String, dynamic>>>> itemsControllers = {};

  void broadcastAll() {
    // Broadcast user trips to all registered users
    for (final userId in userTripsControllers.keys) {
      final userVisible = trips.values.where((t) {
        final members = (t['members'] as List?)?.cast<String>() ?? [];
        return t['ownerId'] == userId || members.contains(userId);
      }).map((t) => Map<String, dynamic>.from(t)).toList();
      userTripsControllers[userId]?.add(UserTripsSnapshot(trips: userVisible));
    }

    // Broadcast days, stops, items for each trip
    for (final tripId in trips.keys) {
      if (daysControllers.containsKey(tripId)) {
        final days = (tripDays[tripId]?.values ?? []).map((d) => Map<String, dynamic>.from(d)).toList();
        daysControllers[tripId]!.add(days);
      }
      if (stopsControllers.containsKey(tripId)) {
        final stops = (tripStops[tripId]?.values ?? []).map((s) => Map<String, dynamic>.from(s)).toList();
        stopsControllers[tripId]!.add(stops);
      }
      if (itemsControllers.containsKey(tripId)) {
        final items = (tripScheduleItems[tripId]?.values ?? []).map((i) => Map<String, dynamic>.from(i)).toList();
        itemsControllers[tripId]!.add(items);
      }
    }
  }

  @override
  Future<bool> tripExists(String tripId) async => trips.containsKey(tripId);

  @override
  Future<void> initializeCloudTrip(Trip trip, String currentUserId) async {
    trips[trip.id] = {
      'id': trip.id,
      'title': trip.title,
      'description': trip.description,
      'ownerId': trip.ownerId,
      'sharing': trip.sharing,
      'startDate': trip.startDate,
      'dayCount': trip.dayCount,
      'members': [currentUserId],
      'updatedAt': trip.updatedAt,
      'updatedBy': trip.updatedBy,
      'deletedAt': trip.deletedAt,
    };
    broadcastAll();
  }

  @override
  WriteBatch createBatch() => _SharedCloudWriteBatch(this);

  @override
  Future<void> commitBatch(WriteBatch batch) async {
    final b = batch as _SharedCloudWriteBatch;
    b.execute();
    broadcastAll();
  }

  @override
  void buildTripBatchOperations(WriteBatch batch, Trip trip) {
    final b = batch as _SharedCloudWriteBatch;
    b.addOp(() {
      final existing = trips[trip.id] ?? {};
      final members = existing['members'] ?? [trip.ownerId];
      trips[trip.id] = {
        'id': trip.id,
        'title': trip.title,
        'description': trip.description,
        'ownerId': trip.ownerId,
        'sharing': trip.sharing,
        'startDate': trip.startDate,
        'dayCount': trip.dayCount,
        'members': members,
        'updatedAt': trip.updatedAt,
        'updatedBy': trip.updatedBy,
        'deletedAt': trip.deletedAt,
      };
    });
  }

  @override
  void buildDayBatchOperations(WriteBatch batch, TripDay day) {
    final b = batch as _SharedCloudWriteBatch;
    b.addOp(() {
      tripDays.putIfAbsent(day.tripId, () => {})[day.id] = {
        'id': day.id,
        'tripId': day.tripId,
        'sortKey': day.sortKey,
        'title': day.title,
        'pinnedDate': day.pinnedDate,
        'updatedAt': day.updatedAt,
        'updatedBy': day.updatedBy,
        'deletedAt': day.deletedAt,
      };
    });
  }

  @override
  void buildStopBatchOperations(
    WriteBatch batch,
    Stop stop, {
    List<Label>? labels,
    List<NewReferenceImage>? referenceImages,
  }) {
    final b = batch as _SharedCloudWriteBatch;
    b.addOp(() {
      tripStops.putIfAbsent(stop.tripId, () => {})[stop.id] = {
        'id': stop.id,
        'tripId': stop.tripId,
        'placeKey': stop.placeKey,
        'name': stop.name,
        'lat': stop.lat,
        'lng': stop.lng,
        'description': stop.description,
        'address': stop.address,
        'businessHours': stop.businessHours,
        'contactInfo': stop.contactInfo,
        'accessTips': stop.accessTips,
        'links': stop.links,
        'coverRemoteUrl': stop.coverRemoteUrl,
        'source': stop.source,
        'sourceUrl': stop.sourceUrl,
        'area': stop.area,
        'note': stop.note,
        'addedBy': stop.addedBy,
        'updatedAt': stop.updatedAt,
        'updatedBy': stop.updatedBy,
        'deletedAt': stop.deletedAt,
      };
    });
  }

  @override
  void buildScheduleItemBatchOperations(WriteBatch batch, ScheduleItem item) {
    final b = batch as _SharedCloudWriteBatch;
    b.addOp(() {
      tripScheduleItems.putIfAbsent(item.tripId, () => {})[item.id] = {
        'id': item.id,
        'tripId': item.tripId,
        'stopId': item.stopId,
        'dayId': item.dayId,
        'sortKey': item.sortKey,
        'stayMinutes': item.stayMinutes,
        'transitMinutes': item.transitMinutes,
        'fixedTime': item.fixedTime,
        'status': item.status,
        'updatedAt': item.updatedAt,
        'updatedBy': item.updatedBy,
        'deletedAt': item.deletedAt,
      };
    });
  }

  @override
  Stream<UserTripsSnapshot> watchUserTrips(String userId) async* {
    final userVisible = trips.values.where((t) {
      final members = (t['members'] as List?)?.cast<String>() ?? [];
      return t['ownerId'] == userId || members.contains(userId);
    }).map((t) => Map<String, dynamic>.from(t)).toList();
    yield UserTripsSnapshot(trips: userVisible);
    final controller = userTripsControllers.putIfAbsent(userId, () => StreamController.broadcast());
    yield* controller.stream;
  }

  @override
  Stream<Map<String, dynamic>?> watchTrip(String tripId) async* {
    yield trips[tripId] != null ? Map<String, dynamic>.from(trips[tripId]!) : null;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTripDays(String tripId) async* {
    final days = (tripDays[tripId]?.values ?? []).map((d) => Map<String, dynamic>.from(d)).toList();
    yield days;
    final controller = daysControllers.putIfAbsent(tripId, () => StreamController.broadcast());
    yield* controller.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTripStops(String tripId) async* {
    final stops = (tripStops[tripId]?.values ?? []).map((s) => Map<String, dynamic>.from(s)).toList();
    yield stops;
    final controller = stopsControllers.putIfAbsent(tripId, () => StreamController.broadcast());
    yield* controller.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTripScheduleItems(String tripId) async* {
    final items = (tripScheduleItems[tripId]?.values ?? []).map((i) => Map<String, dynamic>.from(i)).toList();
    yield items;
    final controller = itemsControllers.putIfAbsent(tripId, () => StreamController.broadcast());
    yield* controller.stream;
  }
}

class _SharedCloudWriteBatch implements WriteBatch {
  final SharedCollaborativeCloud cloud;
  final List<void Function()> ops = [];

  _SharedCloudWriteBatch(this.cloud);

  void addOp(void Function() op) => ops.add(op);

  void execute() {
    for (final op in ops) {
      op();
    }
  }

  @override
  Future<void> commit() async => execute();

  @override
  void delete(dynamic document) {}

  @override
  void set<T>(dynamic document, T data, [dynamic options]) {}

  @override
  void update(dynamic document, Map<Object, Object?> data) {}
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase aliceDb;
  late AppDatabase bobDb;
  late SharedCollaborativeCloud cloud;
  late SyncEngineServiceV2 aliceSync;
  late SyncEngineServiceV2 bobSync;

  setUp(() {
    aliceDb = AppDatabase.forTesting(NativeDatabase.memory());
    bobDb = AppDatabase.forTesting(NativeDatabase.memory());
    cloud = SharedCollaborativeCloud();

    aliceSync = SyncEngineServiceV2(
      localDb: aliceDb,
      firestoreSync: cloud,
      currentUserId: 'alice',
    );

    bobSync = SyncEngineServiceV2(
      localDb: bobDb,
      firestoreSync: cloud,
      currentUserId: 'bob',
    );
  });

  tearDown(() async {
    aliceSync.stopSync();
    bobSync.stopSync();
    await aliceDb.close();
    await bobDb.close();
  });

  Future<void> waitForCondition(FutureOr<bool> Function() predicate, {int maxTicks = 40}) async {
    for (var i = 0; i < maxTicks; i++) {
      if (await predicate()) return;
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  test('Multi-User E2E: Alice creates trip with days & stops -> Bob joins -> Full Topological Ingestion without FK error', () async {
    aliceSync.startSync();

    final now = DateTime(2026, 11, 5, 10, 0);
    const tripId = 'collab_trip_1';

    // 1. Alice creates trip locally
    await aliceDb.into(aliceDb.trips).insert(TripsCompanion.insert(
      id: tripId,
      title: 'Tokyo Anime Pilgrimage',
      ownerId: 'alice',
      sharing: const Value('group'),
      dayCount: const Value(2),
      updatedAt: Value(now),
      syncStatus: const Value(1), // Pending upload
    ));

    // Alice creates Day 1
    await aliceDb.into(aliceDb.tripDays).insert(TripDaysCompanion.insert(
      id: 'day_1',
      tripId: tripId,
      sortKey: 'a0',
      title: const Value('Day 1 Akihabara'),
      updatedAt: Value(now),
      syncStatus: const Value(1),
    ));

    // Alice creates Stop
    await aliceDb.into(aliceDb.stops).insert(StopsCompanion.insert(
      id: 'stop_akiba',
      tripId: tripId,
      placeKey: 'anitabi:akiba_1',
      name: 'Radio Kaikan',
      lat: 35.698,
      lng: 139.771,
      addedBy: 'alice',
      updatedAt: Value(now),
      syncStatus: const Value(1),
    ));

    // Alice creates Schedule Item linking stop to day 1
    await aliceDb.into(aliceDb.scheduleItems).insert(ScheduleItemsCompanion.insert(
      id: 'sched_1',
      tripId: tripId,
      stopId: 'stop_akiba',
      dayId: 'day_1',
      sortKey: 'a0',
      updatedAt: Value(now),
      syncStatus: const Value(1),
    ));

    // Wait for Alice to push to cloud
    await waitForCondition(() => cloud.tripStops[tripId]?.containsKey('stop_akiba') == true);

    expect(cloud.trips.containsKey(tripId), isTrue);
    expect(cloud.tripDays[tripId]?.containsKey('day_1'), isTrue);
    expect(cloud.tripStops[tripId]?.containsKey('stop_akiba'), isTrue);

    // 2. Bob joins the trip (added to members list in cloud)
    final tripInCloud = cloud.trips[tripId]!;
    (tripInCloud['members'] as List).add('bob');

    // 3. Bob starts sync and receives broadcast
    bobSync.startSync();
    cloud.broadcastAll();

    // Allow async ingestion
    await waitForCondition(() async {
      final s = await (bobDb.select(bobDb.stops)..where((x) => x.id.equals('stop_akiba'))).getSingleOrNull();
      return s != null;
    });

    // Verify Bob's local database contains the full trip hierarchy in perfect topological integrity
    final bobTrip = await (bobDb.select(bobDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    expect(bobTrip, isNotNull);
    expect(bobTrip!.title, equals('Tokyo Anime Pilgrimage'));
    expect(bobTrip.ownerId, equals('alice'));

    final bobDay = await (bobDb.select(bobDb.tripDays)..where((d) => d.id.equals('day_1'))).getSingleOrNull();
    expect(bobDay, isNotNull);
    expect(bobDay!.title, equals('Day 1 Akihabara'));

    final bobStop = await (bobDb.select(bobDb.stops)..where((s) => s.id.equals('stop_akiba'))).getSingleOrNull();
    expect(bobStop, isNotNull);
    expect(bobStop!.name, equals('Radio Kaikan'));

    final bobItem = await (bobDb.select(bobDb.scheduleItems)..where((i) => i.id.equals('sched_1'))).getSingleOrNull();
    expect(bobItem, isNotNull);
    expect(bobItem!.stopId, equals('stop_akiba'));
    expect(bobItem.dayId, equals('day_1'));
  });

  test('Multi-User E2E: Concurrent additions from Alice and Bob both converge across databases', () async {
    const tripId = 'collab_trip_2';
    final t0 = DateTime(2026, 11, 5, 10, 0);

    // Set up shared trip in cloud
    cloud.trips[tripId] = {
      'id': tripId,
      'title': 'Kyoto Pilgrimage',
      'ownerId': 'alice',
      'sharing': 'group',
      'dayCount': 1,
      'members': ['alice', 'bob'],
      'updatedAt': t0,
    };
    cloud.tripDays[tripId] = {
      'day_kyoto_1': {
        'id': 'day_kyoto_1',
        'tripId': tripId,
        'sortKey': 'a0',
        'title': 'Day 1 Uji',
        'updatedAt': t0,
      }
    };

    aliceSync.startSync();
    bobSync.startSync();
    cloud.broadcastAll();
    await Future.delayed(const Duration(milliseconds: 200));

    // Alice adds Stop A ("Byodoin Temple")
    final tAlice = DateTime(2026, 11, 5, 10, 5);
    await aliceDb.into(aliceDb.stops).insert(StopsCompanion.insert(
      id: 'stop_byodoin',
      tripId: tripId,
      placeKey: 'anitabi:uji_1',
      name: 'Byodoin Temple',
      lat: 34.889,
      lng: 135.807,
      addedBy: 'alice',
      updatedAt: Value(tAlice),
      syncStatus: const Value(1),
    ));

    // Bob simultaneously adds Stop B ("Uji Bridge")
    final tBob = DateTime(2026, 11, 5, 10, 6);
    await bobDb.into(bobDb.stops).insert(StopsCompanion.insert(
      id: 'stop_uji_bridge',
      tripId: tripId,
      placeKey: 'anitabi:uji_2',
      name: 'Uji Bridge',
      lat: 34.891,
      lng: 135.809,
      addedBy: 'bob',
      updatedAt: Value(tBob),
      syncStatus: const Value(1),
    ));

    // Wait for both to push and exchange
    await waitForCondition(() =>
        cloud.tripStops[tripId]?.containsKey('stop_byodoin') == true &&
        cloud.tripStops[tripId]?.containsKey('stop_uji_bridge') == true);

    cloud.broadcastAll();
    await Future.delayed(const Duration(milliseconds: 300));

    // Verify Alice's DB has BOTH stops
    final aliceStops = await (aliceDb.select(aliceDb.stops)..where((s) => s.tripId.equals(tripId))).get();
    expect(aliceStops.map((s) => s.id).toSet(), containsAll({'stop_byodoin', 'stop_uji_bridge'}));

    // Verify Bob's DB has BOTH stops
    final bobStops = await (bobDb.select(bobDb.stops)..where((s) => s.tripId.equals(tripId))).get();
    expect(bobStops.map((s) => s.id).toSet(), containsAll({'stop_byodoin', 'stop_uji_bridge'}));
  });

  test('Multi-User E2E: Conflicting edits on the same stop converge to newer timestamp (LWW)', () async {
    const tripId = 'collab_trip_3';
    const stopId = 'stop_kanda';
    final t0 = DateTime(2026, 11, 5, 10, 0);

    cloud.trips[tripId] = {
      'id': tripId,
      'title': 'Kanda Trip',
      'ownerId': 'alice',
      'sharing': 'group',
      'dayCount': 1,
      'members': ['alice', 'bob'],
      'updatedAt': t0,
    };
    cloud.tripStops[tripId] = {
      stopId: {
        'id': stopId,
        'tripId': tripId,
        'placeKey': 'anitabi:kanda',
        'name': 'Kanda Myojin',
        'lat': 35.702,
        'lng': 139.768,
        'note': 'Initial note',
        'addedBy': 'alice',
        'updatedAt': t0,
      }
    };

    aliceSync.startSync();
    bobSync.startSync();
    cloud.broadcastAll();
    await Future.delayed(const Duration(milliseconds: 200));

    // Alice edits note at t1 (10:10)
    final tAlice = DateTime(2026, 11, 5, 10, 10);
    await DriftTripRepository(aliceDb).updateStop(StopsCompanion(
      id: const Value(stopId),
      tripId: const Value(tripId),
      note: const Value('Alice note: Buy ema plaque'),
      updatedAt: Value(tAlice),
      updatedBy: const Value('alice'),
      syncStatus: const Value(1),
    ));

    // Bob edits note at t2 (10:15 - Newer)
    final tBob = DateTime(2026, 11, 5, 10, 15);
    await DriftTripRepository(bobDb).updateStop(StopsCompanion(
      id: const Value(stopId),
      tripId: const Value(tripId),
      note: const Value('Bob newer note: Take Love Live photo at stairs'),
      updatedAt: Value(tBob),
      updatedBy: const Value('bob'),
      syncStatus: const Value(1),
    ));

    // Wait for pushes and broadcast
    await waitForCondition(() =>
        cloud.tripStops[tripId]?[stopId]?['note'] == 'Bob newer note: Take Love Live photo at stairs');

    cloud.broadcastAll();
    await Future.delayed(const Duration(milliseconds: 300));

    // Both databases should now have Bob's newer note
    final aliceStop = await (aliceDb.select(aliceDb.stops)..where((s) => s.id.equals(stopId))).getSingle();
    final bobStop = await (bobDb.select(bobDb.stops)..where((s) => s.id.equals(stopId))).getSingle();

    expect(aliceStop.note, equals('Bob newer note: Take Love Live photo at stairs'));
    expect(bobStop.note, equals('Bob newer note: Take Love Live photo at stairs'));
  });

  test('Multi-User E2E: Offline split-brain - Alice offline edits while Bob online edits, reconcile without constraint error', () async {
    const tripId = 'collab_trip_4';
    final t0 = DateTime(2026, 11, 5, 10, 0);

    cloud.trips[tripId] = {
      'id': tripId,
      'title': 'Split Brain Trip',
      'ownerId': 'alice',
      'sharing': 'group',
      'dayCount': 1,
      'members': ['alice', 'bob'],
      'updatedAt': t0,
    };
    cloud.tripDays[tripId] = {
      'day_4_1': {
        'id': 'day_4_1',
        'tripId': tripId,
        'sortKey': 'a0',
        'title': 'Day 1',
        'updatedAt': t0,
      }
    };

    aliceSync.startSync();
    bobSync.startSync();
    cloud.broadcastAll();
    await Future.delayed(const Duration(milliseconds: 200));

    // Alice goes offline!
    aliceSync.stopSync();

    // Alice adds an offline stop
    final tAliceOffline = DateTime(2026, 11, 5, 10, 20);
    await aliceDb.into(aliceDb.stops).insert(StopsCompanion.insert(
      id: 'stop_alice_offline',
      tripId: tripId,
      placeKey: 'anitabi:offline_1',
      name: 'Alice Offline Discovery',
      lat: 35.1,
      lng: 135.1,
      addedBy: 'alice',
      updatedAt: Value(tAliceOffline),
      syncStatus: const Value(1),
    ));

    // Bob (online) adds another stop
    final tBobOnline = DateTime(2026, 11, 5, 10, 25);
    await bobDb.into(bobDb.stops).insert(StopsCompanion.insert(
      id: 'stop_bob_online',
      tripId: tripId,
      placeKey: 'anitabi:online_1',
      name: 'Bob Online Spot',
      lat: 35.2,
      lng: 135.2,
      addedBy: 'bob',
      updatedAt: Value(tBobOnline),
      syncStatus: const Value(1),
    ));

    await waitForCondition(() => cloud.tripStops[tripId]?.containsKey('stop_bob_online') == true);

    // Alice comes back online!
    aliceSync.startSync();
    cloud.broadcastAll();

    await waitForCondition(() => cloud.tripStops[tripId]?.containsKey('stop_alice_offline') == true);
    cloud.broadcastAll();
    await Future.delayed(const Duration(milliseconds: 300));

    // Verify Alice has Bob's online spot
    final aliceStops = await (aliceDb.select(aliceDb.stops)..where((s) => s.tripId.equals(tripId))).get();
    expect(aliceStops.map((s) => s.id).toSet(), containsAll({'stop_alice_offline', 'stop_bob_online'}));

    // Verify Bob has Alice's formerly offline discovery
    final bobStops = await (bobDb.select(bobDb.stops)..where((s) => s.tripId.equals(tripId))).get();
    expect(bobStops.map((s) => s.id).toSet(), containsAll({'stop_alice_offline', 'stop_bob_online'}));
  });

  test('Multi-User E2E: Alice soft-deletes a stop -> propagates to Bob without FK or cascade corruption', () async {
    const tripId = 'collab_trip_5';
    const stopId = 'stop_trash_target';
    final t0 = DateTime(2026, 11, 5, 10, 0);

    cloud.trips[tripId] = {
      'id': tripId,
      'title': 'Trash Sync Trip',
      'ownerId': 'alice',
      'sharing': 'group',
      'dayCount': 1,
      'members': ['alice', 'bob'],
      'updatedAt': t0,
    };
    cloud.tripStops[tripId] = {
      stopId: {
        'id': stopId,
        'tripId': tripId,
        'placeKey': 'anitabi:trash_target',
        'name': 'Spot to delete',
        'lat': 35.0,
        'lng': 135.0,
        'addedBy': 'alice',
        'updatedAt': t0,
      }
    };

    aliceSync.startSync();
    bobSync.startSync();
    cloud.broadcastAll();
    await Future.delayed(const Duration(milliseconds: 200));

    // Alice soft-deletes the stop (moves to trash)
    final tDelete = DateTime(2026, 11, 5, 10, 30);
    await DriftTripRepository(aliceDb).updateStop(StopsCompanion(
      id: const Value(stopId),
      tripId: const Value(tripId),
      deletedAt: Value(tDelete),
      updatedAt: Value(tDelete),
      updatedBy: const Value('alice'),
      syncStatus: const Value(1),
    ));

    await waitForCondition(() => cloud.tripStops[tripId]?[stopId]?['deletedAt'] != null);
    cloud.broadcastAll();
    await Future.delayed(const Duration(milliseconds: 300));

    // Verify Bob's local database reflects the soft deletion
    final bobStop = await (bobDb.select(bobDb.stops)..where((s) => s.id.equals(stopId))).getSingle();
    expect(bobStop.deletedAt, isNotNull);
    expect(bobStop.deletedAt, equals(tDelete));
  });
}
