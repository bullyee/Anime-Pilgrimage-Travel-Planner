// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/sync/services/firestore_sync_v2_service.dart';

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
  _FakeDocRef(this.path);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionRef('$path/$collectionPath');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollectionRef implements CollectionReference<Map<String, dynamic>> {
  final String _collectionPath;
  _FakeCollectionRef(this._collectionPath);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FakeDocRef('$_collectionPath/${path ?? "auto"}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestoreDb implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionRef(collectionPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeFirestoreDb fakeDb;
  late FirestoreSyncV2Service service;
  late _FakeBatch batch;

  setUp(() {
    fakeDb = _FakeFirestoreDb();
    service = FirestoreSyncV2Service(fakeDb);
    batch = _FakeBatch();
  });

  group('FirestoreSyncV2Service - TTL expireAt & batch operations', () {
    final t1 = DateTime(2026, 11, 1, 12, 0);
    final tDelete = DateTime(2026, 11, 2, 8, 30);

    test('buildTripBatchOperations sets expireAt 30 days after deletedAt, or FieldValue.delete() when active', () {
      final activeTrip = Trip(
        id: 'trip_1',
        title: 'Active Trip',
        ownerId: 'alice',
        sharing: 'group',
        startDate: null,
        dayCount: 3,
        createdAt: t1,
        updatedAt: t1,
        syncStatus: 0,
      );

      service.buildTripBatchOperations(batch, activeTrip);
      expect(batch.recordedOperations.length, 1);
      final activeData = batch.recordedOperations.first['data'];
      expect(activeData['deletedAt'], isNull);
      expect(activeData['expireAt'], equals(FieldValue.delete()));

      // Soft-deleted trip
      final deletedTrip = activeTrip.copyWith(deletedAt: Value(tDelete));
      service.buildTripBatchOperations(batch, deletedTrip);
      expect(batch.recordedOperations.length, 2);
      final deletedData = batch.recordedOperations[1]['data'];
      expect(deletedData['deletedAt'], equals(Timestamp.fromDate(tDelete)));
      expect(
        deletedData['expireAt'],
        equals(Timestamp.fromDate(tDelete.add(const Duration(days: 30)))),
      );
    });

    test('buildDayBatchOperations sets expireAt 30 days after deletedAt, or FieldValue.delete() when active', () {
      final activeDay = TripDay(
        id: 'day_1',
        tripId: 'trip_1',
        sortKey: 'a0',
        title: 'Day 1',
        pinnedDate: null,
        updatedAt: t1,
        syncStatus: 0,
      );

      service.buildDayBatchOperations(batch, activeDay);
      final activeData = batch.recordedOperations.first['data'];
      expect(activeData['deletedAt'], isNull);
      expect(activeData['expireAt'], equals(FieldValue.delete()));

      final deletedDay = activeDay.copyWith(deletedAt: Value(tDelete));
      service.buildDayBatchOperations(batch, deletedDay);
      final deletedData = batch.recordedOperations[1]['data'];
      expect(deletedData['deletedAt'], equals(Timestamp.fromDate(tDelete)));
      expect(
        deletedData['expireAt'],
        equals(Timestamp.fromDate(tDelete.add(const Duration(days: 30)))),
      );
    });

    test('buildStopBatchOperations sets expireAt 30 days after deletedAt, or FieldValue.delete() when active', () {
      final activeStop = Stop(
        id: 'stop_1',
        tripId: 'trip_1',
        placeKey: 'place_1',
        name: 'Spot 1',
        lat: 35.0,
        lng: 135.0,
        addedBy: 'alice',
        createdAt: t1,
        updatedAt: t1,
        syncStatus: 0,
      );

      service.buildStopBatchOperations(batch, activeStop);
      final activeData = batch.recordedOperations.first['data'];
      expect(activeData['deletedAt'], isNull);
      expect(activeData['expireAt'], equals(FieldValue.delete()));

      final deletedStop = activeStop.copyWith(deletedAt: Value(tDelete));
      service.buildStopBatchOperations(batch, deletedStop);
      final deletedData = batch.recordedOperations[1]['data'];
      expect(deletedData['deletedAt'], equals(Timestamp.fromDate(tDelete)));
      expect(
        deletedData['expireAt'],
        equals(Timestamp.fromDate(tDelete.add(const Duration(days: 30)))),
      );
    });

    test('buildScheduleItemBatchOperations sets expireAt 30 days after deletedAt, or FieldValue.delete() when active', () {
      final activeItem = ScheduleItem(
        id: 'item_1',
        tripId: 'trip_1',
        stopId: 'stop_1',
        dayId: 'day_1',
        sortKey: 'a0',
        stayMinutes: 60,
        transitMinutes: 15,
        status: 'none',
        updatedAt: t1,
        syncStatus: 0,
      );

      service.buildScheduleItemBatchOperations(batch, activeItem);
      final activeData = batch.recordedOperations.first['data'];
      expect(activeData['deletedAt'], isNull);
      expect(activeData['expireAt'], equals(FieldValue.delete()));

      final deletedItem = activeItem.copyWith(deletedAt: Value(tDelete));
      service.buildScheduleItemBatchOperations(batch, deletedItem);
      final deletedData = batch.recordedOperations[1]['data'];
      expect(deletedData['deletedAt'], equals(Timestamp.fromDate(tDelete)));
      expect(
        deletedData['expireAt'],
        equals(Timestamp.fromDate(tDelete.add(const Duration(days: 30)))),
      );
    });
  });
}
