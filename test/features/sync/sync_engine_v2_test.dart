import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show WriteBatch;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sync/services/firestore_sync_v2_service.dart';
import 'package:trip_planner/features/sync/services/sync_engine_service_v2.dart';

class FakeFirestoreSyncV2Service implements FirestoreSyncV2Service {
  final Map<String, Map<String, dynamic>> trips = {};
  final Map<String, Map<String, Map<String, dynamic>>> tripDays = {};
  final Map<String, Map<String, Map<String, dynamic>>> tripStops = {};
  final Map<String, Map<String, Map<String, dynamic>>> tripScheduleItems = {};

  final StreamController<List<Map<String, dynamic>>> userTripsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final Map<String, StreamController<List<Map<String, dynamic>>>> daysControllers = {};
  final Map<String, StreamController<List<Map<String, dynamic>>>> stopsControllers = {};
  final Map<String, StreamController<List<Map<String, dynamic>>>> itemsControllers = {};

  bool failCommit = false;
  Future<void> Function()? onBeforeCommit;

  void emitUserTrips(List<Map<String, dynamic>> data) {
    userTripsController.add(data);
  }

  void emitDays(String tripId, List<Map<String, dynamic>> days) {
    daysControllers.putIfAbsent(tripId, () => StreamController.broadcast()).add(days);
  }

  void emitStops(String tripId, List<Map<String, dynamic>> stops) {
    stopsControllers.putIfAbsent(tripId, () => StreamController.broadcast()).add(stops);
  }

  void emitScheduleItems(String tripId, List<Map<String, dynamic>> items) {
    itemsControllers.putIfAbsent(tripId, () => StreamController.broadcast()).add(items);
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
  }

  @override
  WriteBatch createBatch() => _FakeV2WriteBatch(this);

  @override
  Future<void> commitBatch(WriteBatch batch) async {
    if (onBeforeCommit != null) {
      await onBeforeCommit!();
    }
    if (failCommit) {
      throw Exception('Simulated Firestore network timeout / offline failure');
    }
    final fakeBatch = batch as _FakeV2WriteBatch;
    fakeBatch.execute();
  }

  @override
  void buildTripBatchOperations(WriteBatch batch, Trip trip) {
    final fakeBatch = batch as _FakeV2WriteBatch;
    fakeBatch.addOp(() {
      trips.putIfAbsent(trip.id, () => {})['id'] = trip.id;
      trips[trip.id]!['title'] = trip.title;
      trips[trip.id]!['description'] = trip.description;
      trips[trip.id]!['ownerId'] = trip.ownerId;
      trips[trip.id]!['sharing'] = trip.sharing;
      trips[trip.id]!['startDate'] = trip.startDate;
      trips[trip.id]!['dayCount'] = trip.dayCount;
      trips[trip.id]!['updatedAt'] = trip.updatedAt;
      trips[trip.id]!['updatedBy'] = trip.updatedBy;
      trips[trip.id]!['deletedAt'] = trip.deletedAt;
    });
  }

  @override
  void buildDayBatchOperations(WriteBatch batch, TripDay day) {
    final fakeBatch = batch as _FakeV2WriteBatch;
    fakeBatch.addOp(() {
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
    final fakeBatch = batch as _FakeV2WriteBatch;
    fakeBatch.addOp(() {
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
        'addedBy': stop.addedBy,
        'updatedAt': stop.updatedAt,
        'updatedBy': stop.updatedBy,
        'deletedAt': stop.deletedAt,
        'labels': labels
            ?.map((l) => {
                  'id': l.id,
                  'kind': l.kind,
                  'name': l.name,
                  'bangumiId': l.bangumiId,
                })
            .toList(),
        'referenceImages': referenceImages
            ?.where((img) => img.remoteUrl != null && img.remoteUrl!.isNotEmpty)
            .map((img) => {
                  'id': img.id,
                  'remoteUrl': img.remoteUrl,
                  'animeLabelId': img.animeLabelId,
                  'episode': img.episode,
                  'timestampS': img.timestampS,
                  'source': img.source,
                  'sourceUrl': img.sourceUrl,
                })
            .toList(),
      };
    });
  }

  @override
  void buildScheduleItemBatchOperations(WriteBatch batch, ScheduleItem item) {
    final fakeBatch = batch as _FakeV2WriteBatch;
    fakeBatch.addOp(() {
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
  Stream<List<Map<String, dynamic>>> watchUserTrips(String userId) {
    return userTripsController.stream;
  }

  @override
  Stream<Map<String, dynamic>?> watchTrip(String tripId) {
    return Stream.value(trips[tripId]);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTripDays(String tripId) {
    return daysControllers
        .putIfAbsent(tripId, () => StreamController.broadcast())
        .stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTripStops(String tripId) {
    return stopsControllers
        .putIfAbsent(tripId, () => StreamController.broadcast())
        .stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchTripScheduleItems(String tripId) {
    return itemsControllers
        .putIfAbsent(tripId, () => StreamController.broadcast())
        .stream;
  }
}

class _FakeV2WriteBatch implements WriteBatch {
  final FakeFirestoreSyncV2Service service;
  final List<void Function()> operations = [];

  _FakeV2WriteBatch(this.service);

  void addOp(void Function() op) => operations.add(op);

  void execute() {
    for (final op in operations) {
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
  late AppDatabase db;
  late FakeFirestoreSyncV2Service fakeFirestore;
  late SyncEngineServiceV2 syncEngine;
  const currentUserId = 'user_alice';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeFirestore = FakeFirestoreSyncV2Service();
    syncEngine = SyncEngineServiceV2(
      localDb: db,
      firestoreSync: fakeFirestore,
      currentUserId: currentUserId,
    );
  });

  tearDown(() async {
    syncEngine.stopSync();
    await db.close();
  });

  group('SyncEngineServiceV2 - Upstream Push', () {
    test('pushes dirty trips, days, stops, and schedule items to Firestore', () async {
      syncEngine.startSync();

      final now = DateTime.now();

      // Create a shared group trip
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_1',
              title: 'Kyoto Pilgrimage',
              ownerId: currentUserId,
              sharing: const Value('group'),
              startDate: const Value('2026-11-10'),
              dayCount: const Value(2),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncStatus: const Value(1), // Dirty
            ),
          );

      // Create Day Block
      await db.into(db.tripDays).insert(
            TripDaysCompanion.insert(
              id: 'day_1',
              tripId: 'trip_1',
              sortKey: 'a0',
              title: const Value('Day 1 Arashiyama'),
              updatedAt: Value(now),
              syncStatus: const Value(1), // Dirty
            ),
          );

      // Create Stop with Label
      await db.into(db.labels).insert(
            LabelsCompanion.insert(
              id: 'label_k-on',
              kind: 'anime',
              name: 'K-ON!',
              bangumiId: const Value('1234'),
            ),
          );

      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_1',
              tripId: 'trip_1',
              placeKey: 'anitabi:42',
              name: 'Former Toyosato Elementary School',
              lat: 35.201,
              lng: 136.234,
              area: const Value('Toyosato'),
              addedBy: currentUserId,
              updatedAt: Value(now),
              syncStatus: const Value(1), // Dirty
            ),
          );

      await db.into(db.stopLabels).insert(
            StopLabelsCompanion.insert(
              stopId: 'stop_1',
              labelId: 'label_k-on',
            ),
          );

      // Create Schedule Item
      await db.into(db.scheduleItems).insert(
            ScheduleItemsCompanion.insert(
              id: 'item_1',
              tripId: 'trip_1',
              stopId: 'stop_1',
              dayId: 'day_1',
              sortKey: 'a0',
              stayMinutes: const Value(90),
              updatedAt: Value(now),
              syncStatus: const Value(1), // Dirty
            ),
          );

      // Wait for debounce timer (300ms) to trigger push
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify FakeFirestore received the records
      expect(fakeFirestore.trips.containsKey('trip_1'), isTrue);
      expect(fakeFirestore.trips['trip_1']!['title'], 'Kyoto Pilgrimage');

      expect(fakeFirestore.tripDays['trip_1']?['day_1'], isNotNull);
      expect(fakeFirestore.tripDays['trip_1']!['day_1']!['title'], 'Day 1 Arashiyama');

      expect(fakeFirestore.tripStops['trip_1']?['stop_1'], isNotNull);
      final remoteStop = fakeFirestore.tripStops['trip_1']!['stop_1']!;
      expect(remoteStop['name'], 'Former Toyosato Elementary School');
      expect(remoteStop['area'], 'Toyosato');
      final remoteLabels = remoteStop['labels'] as List;
      expect(remoteLabels.length, 1);
      expect(remoteLabels.first['name'], 'K-ON!');

      expect(fakeFirestore.tripScheduleItems['trip_1']?['item_1'], isNotNull);
      expect(fakeFirestore.tripScheduleItems['trip_1']!['item_1']!['stayMinutes'], 90);

      // Verify local records are marked syncStatus = 0 (synced)
      final localTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_1'))).getSingle();
      expect(localTrip.syncStatus, 0);

      final localDay = await (db.select(db.tripDays)..where((d) => d.id.equals('day_1'))).getSingle();
      expect(localDay.syncStatus, 0);

      final localStop = await (db.select(db.stops)..where((s) => s.id.equals('stop_1'))).getSingle();
      expect(localStop.syncStatus, 0);

      final localItem = await (db.select(db.scheduleItems)..where((i) => i.id.equals('item_1'))).getSingle();
      expect(localItem.syncStatus, 0);

      expect(syncEngine.getTripSyncStatus('trip_1'), TripSyncStatus.synced);
    });

    test('concurrent local edit during commitBatch is not lost and triggers a follow-up push', () async {
      final t1 = DateTime(2026, 11, 1, 10, 0, 0);
      final t2 = DateTime(2026, 11, 1, 10, 0, 5);

      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_concurrent',
              title: 'Initial Title',
              ownerId: currentUserId,
              sharing: const Value('group'),
              updatedAt: Value(t1),
              syncStatus: const Value(1),
            ),
          );

      // Simulate user editing the trip while the first commitBatch is in flight
      var editedMidFlight = false;
      fakeFirestore.onBeforeCommit = () async {
        if (!editedMidFlight) {
          editedMidFlight = true;
          await (db.update(db.trips)..where((t) => t.id.equals('trip_concurrent'))).write(
            TripsCompanion(
              title: const Value('Updated Mid-Flight Title'),
              updatedAt: Value(t2),
              syncStatus: const Value(1),
            ),
          );
        }
      };

      syncEngine.startSync();
      await Future.delayed(const Duration(milliseconds: 900));

      expect(fakeFirestore.trips['trip_concurrent']!['title'], equals('Updated Mid-Flight Title'));
      final localTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_concurrent'))).getSingle();
      expect(localTrip.syncStatus, equals(0));
    });

    test('retains dirty status and marks trip offline on network commit failure', () async {
      fakeFirestore.failCommit = true;
      syncEngine.startSync();

      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_offline',
              title: 'Offline Trip',
              ownerId: currentUserId,
              sharing: const Value('group'),
              syncStatus: const Value(1),
            ),
          );

      await Future.delayed(const Duration(milliseconds: 500));

      final localTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_offline'))).getSingle();
      expect(localTrip.syncStatus, 1); // Still dirty
      expect(syncEngine.getTripSyncStatus('trip_offline'), TripSyncStatus.offline);
    });
  });

  group('SyncEngineServiceV2 - Downstream Pull', () {
    test('applies remote trip and pulls subcollections with natural key label matching', () async {
      syncEngine.startSync();

      final now = DateTime.now();

      // Emit remote trip from cloud
      fakeFirestore.emitUserTrips([
        {
          'id': 'trip_remote',
          'title': 'Remote Shonan Trip',
          'description': 'Slam Dunk & Bunny Girl',
          'ownerId': 'user_bob',
          'sharing': 'group',
          'dayCount': 3,
          'updatedAt': now,
        }
      ]);

      await Future.delayed(const Duration(milliseconds: 100));

      final localTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_remote'))).getSingleOrNull();
      expect(localTrip, isNotNull);
      expect(localTrip!.title, 'Remote Shonan Trip');
      expect(localTrip.ownerId, 'user_bob');

      // Emit remote schedule item BEFORE day and stop to verify out-of-order FK buffering
      fakeFirestore.emitScheduleItems('trip_remote', [
        {
          'id': 'remote_item_1',
          'tripId': 'trip_remote',
          'stopId': 'remote_stop_1',
          'dayId': 'remote_day_1',
          'sortKey': 'a0',
          'stayMinutes': 45,
          'fixedTime': 600, // 10:00
          'updatedAt': now,
        }
      ]);

      await Future.delayed(const Duration(milliseconds: 50));

      // Emit remote day
      fakeFirestore.emitDays('trip_remote', [
        {
          'id': 'remote_day_1',
          'tripId': 'trip_remote',
          'sortKey': 'a0',
          'title': 'Kamakura Coast',
          'updatedAt': now,
        }
      ]);

      // Emit remote stop with both anime label (Bangumi natural key), region label, and reference image
      fakeFirestore.emitStops('trip_remote', [
        {
          'id': 'remote_stop_1',
          'tripId': 'trip_remote',
          'placeKey': 'anitabi:100',
          'name': 'Kamakurakokomae Station',
          'lat': 35.306,
          'lng': 139.502,
          'area': 'Enoden Line',
          'addedBy': 'user_bob',
          'updatedAt': now,
          'labels': [
            {'kind': 'anime', 'name': 'Slam Dunk', 'bangumiId': '999'},
            {'kind': 'region', 'name': 'Kamakura', 'bangumiId': null},
          ],
          'referenceImages': [
            {
              'id': 'ref_shonan_1',
              'remoteUrl': 'https://image.anitabi.cn/points/100/1.jpg',
              'episode': 'OP',
              'timestampS': 55,
            }
          ],
        }
      ]);

      await Future.delayed(const Duration(milliseconds: 200));

      final localDay = await (db.select(db.tripDays)..where((d) => d.id.equals('remote_day_1'))).getSingleOrNull();
      expect(localDay, isNotNull);
      expect(localDay!.title, 'Kamakura Coast');

      final localStop = await (db.select(db.stops)..where((s) => s.id.equals('remote_stop_1'))).getSingleOrNull();
      expect(localStop, isNotNull);
      expect(localStop!.name, 'Kamakurakokomae Station');
      expect(localStop.area, 'Enoden Line');

      // Verify labels were naturally matched or created locally
      final labels = await db.select(db.labels).get();
      expect(labels.any((l) => l.kind == 'anime' && l.bangumiId == '999'), isTrue);
      expect(labels.any((l) => l.kind == 'region' && l.name == 'Kamakura'), isTrue);

      final stopLabels = await (db.select(db.stopLabels)..where((sl) => sl.stopId.equals('remote_stop_1'))).get();
      expect(stopLabels.length, 2);

      // Verify stop reference image was synced
      final stopRefs = await (db.select(db.newReferenceImages)..where((r) => r.stopId.equals('remote_stop_1'))).get();
      expect(stopRefs.length, 1);
      expect(stopRefs.single.remoteUrl, 'https://image.anitabi.cn/points/100/1.jpg');

      // Verify buffered schedule item was flushed once day and stop arrived
      final localItem = await (db.select(db.scheduleItems)..where((i) => i.id.equals('remote_item_1'))).getSingleOrNull();
      expect(localItem, isNotNull);
      expect(localItem!.stayMinutes, 45);
      expect(localItem.fixedTime, 600);
    });

    test('when owner deletes or unshares a trip, collaborator keeps a private unsynced copy', () async {
      syncEngine.startSync();
      final t1 = DateTime(2026, 11, 1, 10, 0);
      final t2 = DateTime(2026, 11, 1, 11, 0);

      // Collaborator (user_alice) receives a shared trip owned by user_bob
      fakeFirestore.emitUserTrips([
        {
          'id': 'trip_bob',
          'title': 'Bob Shared Trip',
          'ownerId': 'user_bob',
          'sharing': 'group',
          'dayCount': 1,
          'updatedAt': t1,
        }
      ]);
      await Future.delayed(const Duration(milliseconds: 100));

      // Now user_bob deletes the trip in the cloud
      fakeFirestore.emitUserTrips([
        {
          'id': 'trip_bob',
          'title': 'Bob Shared Trip',
          'ownerId': 'user_bob',
          'sharing': 'group',
          'dayCount': 1,
          'updatedAt': t2,
          'deletedAt': t2,
        }
      ]);
      await Future.delayed(const Duration(milliseconds: 100));

      final localTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_bob'))).getSingle();
      expect(localTrip.deletedAt, isNull);
      expect(localTrip.sharing, equals('private'));
      expect(localTrip.ownerId, equals(currentUserId));
      expect(localTrip.syncStatus, equals(0));
    });

    test('respects Last-Write-Wins (LWW) and does not overwrite newer local updates', () async {
      syncEngine.startSync();

      final oldTimestamp = DateTime(2026, 10, 1, 10, 0);
      final newTimestamp = DateTime(2026, 11, 1, 12, 0);

      // Local has a newer version of the trip
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_lww',
              title: 'Local Newer Title',
              ownerId: currentUserId,
              sharing: const Value('group'),
              updatedAt: Value(newTimestamp),
              syncStatus: const Value(0),
            ),
          );

      // Cloud delivers an older version
      fakeFirestore.emitUserTrips([
        {
          'id': 'trip_lww',
          'title': 'Stale Remote Title',
          'ownerId': currentUserId,
          'sharing': 'group',
          'updatedAt': oldTimestamp,
        }
      ]);

      await Future.delayed(const Duration(milliseconds: 100));

      final localTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_lww'))).getSingle();
      expect(localTrip.title, 'Local Newer Title'); // Local was preserved!
    });
  });

  group('SyncEngineServiceV2 - shareTrip', () {
    test('converts private trip to shared group and initializes cloud document without uploading personal photos', () async {
      final now = DateTime.now();

      // Create private trip with day, stop, schedule item
      await db.into(db.trips).insert(
            TripsCompanion.insert(
              id: 'trip_private',
              title: 'Secret Pilgrimage',
              ownerId: currentUserId,
              sharing: const Value('private'),
              updatedAt: Value(now),
              syncStatus: const Value(0),
            ),
          );

      await db.into(db.tripDays).insert(
            TripDaysCompanion.insert(
              id: 'day_p',
              tripId: 'trip_private',
              sortKey: 'a0',
              syncStatus: const Value(0),
            ),
          );

      await db.into(db.stops).insert(
            StopsCompanion.insert(
              id: 'stop_p',
              tripId: 'trip_private',
              placeKey: 'anitabi:77',
              name: 'Private Shrine Spot',
              lat: 35.0,
              lng: 135.0,
              addedBy: currentUserId,
              syncStatus: const Value(0),
            ),
          );

      await db.into(db.scheduleItems).insert(
            ScheduleItemsCompanion.insert(
              id: 'item_p',
              tripId: 'trip_private',
              stopId: 'stop_p',
              dayId: 'day_p',
              sortKey: 'a0',
              syncStatus: const Value(0),
            ),
          );

      // Create personal photo in personal layer
      await db.into(db.places).insert(
            PlacesCompanion.insert(
              placeKey: 'anitabi:77',
              name: 'Private Shrine Spot',
              lat: 35.0,
              lng: 135.0,
            ),
          );

      await db.into(db.photos).insert(
            PhotosCompanion.insert(
              id: 'personal_photo_1',
              placeKey: 'anitabi:77',
              localPath: '/local/storage/shrine.jpg',
              tripId: const Value('trip_private'),
            ),
          );

      syncEngine.startSync();
      await syncEngine.shareTrip('trip_private');

      // Wait for debounced push to complete
      for (var i = 0; i < 20; i++) {
        if (fakeFirestore.trips.containsKey('trip_private')) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final updatedTrip = await (db.select(db.trips)..where((t) => t.id.equals('trip_private'))).getSingle();
      expect(updatedTrip.sharing, 'group');
      expect(fakeFirestore.trips.containsKey('trip_private'), isTrue);
      expect(fakeFirestore.trips['trip_private']!['sharing'], 'group');

      expect(fakeFirestore.tripDays['trip_private']?['day_p'], isNotNull);
      expect(fakeFirestore.tripStops['trip_private']?['stop_p'], isNotNull);
      expect(fakeFirestore.tripScheduleItems['trip_private']?['item_p'], isNotNull);

      // Personal photos are never uploaded or referenced in cloud trip
      expect(fakeFirestore.trips['trip_private']!.containsKey('photos'), isFalse);
    });
  });
}
