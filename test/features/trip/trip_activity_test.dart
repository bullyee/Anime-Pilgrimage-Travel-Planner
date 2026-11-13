// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/sync/services/firestore_sync_v2_service.dart';
import 'package:trip_planner/features/trip/models/trip_activity.dart';

class _FakeBatch implements WriteBatch {
  final List<Map<String, dynamic>> recordedOperations = [];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    recordedOperations.add({
      'path': document.path,
      'data': data as Map<String, dynamic>,
      'merge': options?.merge,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDocRef implements DocumentReference<Map<String, dynamic>> {
  @override
  final String path;
  final Map<String, dynamic> store;

  _FakeDocRef(this.path, this.store);

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store[path] = data;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionRef('$path/$collectionPath', store);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  _FakeQuerySnapshot(this.docs);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQueryDocSnapshot implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _id;
  final Map<String, dynamic> _data;
  _FakeQueryDocSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectionRef implements CollectionReference<Map<String, dynamic>> {
  final String _collectionPath;
  final Map<String, dynamic> _store;

  _FakeCollectionRef(this._collectionPath, this._store);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FakeDocRef('$_collectionPath/${path ?? "auto"}', _store);
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) => this;

  @override
  Query<Map<String, dynamic>> limit(int limit) => this;

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    // Collect docs from store matching this collection
    final matchingDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final entry in _store.entries) {
      if (entry.key.startsWith('$_collectionPath/')) {
        final docId = entry.key.split('/').last;
        matchingDocs.add(_FakeQueryDocSnapshot(docId, entry.value as Map<String, dynamic>));
      }
    }
    return Stream.value(_FakeQuerySnapshot(matchingDocs));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestoreDb implements FirebaseFirestore {
  final Map<String, dynamic> store = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionRef(collectionPath, store);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TripActivity Model Tests', () {
    final now = DateTime(2026, 11, 5, 10, 0);

    test('TripActivity.create computes 30-day expireAt and formats fields', () {
      final activity = TripActivity.create(
        id: 'act_1',
        tripId: 'trip_uji',
        actorId: 'user_alice',
        actorName: 'Alice',
        action: TripActivityAction.addStop,
        entityType: 'stop',
        entityId: 'stop_uji_bridge',
        summary: 'Alice added Uji Bridge to the trip',
        details: {'name': 'Uji Bridge', 'lat': 34.89, 'lng': 135.80},
        createdAt: now,
      );

      expect(activity.id, 'act_1');
      expect(activity.tripId, 'trip_uji');
      expect(activity.actorId, 'user_alice');
      expect(activity.actorName, 'Alice');
      expect(activity.action, TripActivityAction.addStop);
      expect(activity.entityType, 'stop');
      expect(activity.entityId, 'stop_uji_bridge');
      expect(activity.summary, 'Alice added Uji Bridge to the trip');
      expect(activity.createdAt, now);
      expect(activity.expireAt, now.add(const Duration(days: 30)));
      expect(activity.details?['name'], 'Uji Bridge');
    });

    test('toMap and fromMap serialize and deserialize cleanly', () {
      final original = TripActivity.create(
        id: 'act_2',
        tripId: 'trip_uji',
        actorId: 'user_bob',
        actorName: 'Bob',
        action: TripActivityAction.restoreStop,
        entityType: 'stop',
        entityId: 'stop_tea_shop',
        summary: 'Bob restored Tsuen Tea from trash',
        details: {'previousStatus': 'deleted'},
        createdAt: now,
      );

      final map = original.toMap();
      expect(map['id'], 'act_2');
      expect(map['action'], 'restore_stop');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['expireAt'], isA<Timestamp>());

      final restored = TripActivity.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.tripId, original.tripId);
      expect(restored.actorId, original.actorId);
      expect(restored.actorName, original.actorName);
      expect(restored.action, TripActivityAction.restoreStop);
      expect(restored.entityType, original.entityType);
      expect(restored.entityId, original.entityId);
      expect(restored.summary, original.summary);
      expect(restored.details?['previousStatus'], 'deleted');
      expect(restored.createdAt, original.createdAt);
      expect(restored.expireAt, original.expireAt);
    });

    test('TripActivityAction fallback for unknown string', () {
      expect(TripActivityAction.fromString('unknown_action'), TripActivityAction.updateTrip);
      expect(TripActivityAction.fromString('set_visited'), TripActivityAction.setVisited);
      expect(TripActivityAction.fromString('role_changed'), TripActivityAction.roleChanged);
    });
  });

  group('FirestoreSyncV2Service Activity Log Integration Tests', () {
    late _FakeFirestoreDb fakeDb;
    late FirestoreSyncV2Service service;

    setUp(() {
      fakeDb = _FakeFirestoreDb();
      service = FirestoreSyncV2Service(fakeDb);
    });

    test('buildActivityBatchOperation sets docRef path and data correctly', () {
      final batch = _FakeBatch();
      final activity = TripActivity.create(
        id: 'act_batch_1',
        tripId: 'trip_100',
        actorId: 'user_alice',
        action: TripActivityAction.addDay,
        entityType: 'day',
        entityId: 'day_2',
        summary: 'Alice added Day 2',
      );

      service.buildActivityBatchOperation(batch, activity);

      expect(batch.recordedOperations.length, 1);
      final op = batch.recordedOperations.first;
      expect(op['path'], 'tripsV2/trip_100/activity/act_batch_1');
      expect(op['data']['action'], 'add_day');
      expect(op['data']['entityId'], 'day_2');
    });

    test('recordActivity stores activity document in subcollection', () async {
      final activity = TripActivity.create(
        id: 'act_direct_1',
        tripId: 'trip_100',
        actorId: 'user_alice',
        action: TripActivityAction.removeStop,
        entityType: 'stop',
        entityId: 'stop_old',
        summary: 'Alice moved spot to trash',
      );

      await service.recordActivity(activity);

      final path = 'tripsV2/trip_100/activity/act_direct_1';
      expect(fakeDb.store.containsKey(path), isTrue);
      expect(fakeDb.store[path]['summary'], 'Alice moved spot to trash');
      expect(fakeDb.store[path]['action'], 'remove_stop');
    });

    test('watchTripActivity streams activities from subcollection', () async {
      final act1 = TripActivity.create(
        id: 'act_s1',
        tripId: 'trip_100',
        actorId: 'user_alice',
        action: TripActivityAction.addStop,
        entityType: 'stop',
        entityId: 'stop_1',
        summary: 'First action',
      );
      final act2 = TripActivity.create(
        id: 'act_s2',
        tripId: 'trip_100',
        actorId: 'user_bob',
        action: TripActivityAction.setVisited,
        entityType: 'stop',
        entityId: 'stop_1',
        summary: 'Second action',
      );

      await service.recordActivity(act1);
      await service.recordActivity(act2);

      final activities = await service.watchTripActivity('trip_100').first;
      expect(activities.length, 2);
      expect(activities.any((a) => a.id == 'act_s1'), isTrue);
      expect(activities.any((a) => a.id == 'act_s2'), isTrue);
    });
  });
}
