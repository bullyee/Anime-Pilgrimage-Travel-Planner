import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/sync/services/firestore_sync_v2_service.dart';
import 'package:trip_planner/features/trip/models/trip_photo.dart';

void main() {
  group('TripPhoto Model Tests', () {
    test('serialization to and from Map preserves all fields and timestamps', () {
      final now = DateTime(2026, 11, 5, 14, 0, 0);
      final taken = DateTime(2026, 11, 1, 9, 30, 0);
      final deleted = now.add(const Duration(days: 1));
      final expire = deleted.add(const Duration(days: 30));

      final photo = TripPhoto(
        id: 'photo_100',
        tripId: 'trip_k_on',
        stopId: 'stop_toyosato',
        placeKey: 'anitabi:1234',
        storagePath: 'tripsV2/trip_k_on/trip_photos/photo_100.jpg',
        url: 'https://firebasestorage.googleapis.com/v0/b/bucket/o/photo_100.jpg',
        caption: 'Toyosato Primary School Music Room',
        uploadedBy: 'user_yui',
        uploadedByName: 'Yui Hirasawa',
        takenAt: taken,
        createdAt: now,
        updatedAt: now,
        deletedAt: deleted,
        expireAt: expire,
      );

      final map = photo.toMap();
      expect(map['id'], equals('photo_100'));
      expect(map['tripId'], equals('trip_k_on'));
      expect(map['stopId'], equals('stop_toyosato'));
      expect(map['placeKey'], equals('anitabi:1234'));
      expect(map['storagePath'], equals('tripsV2/trip_k_on/trip_photos/photo_100.jpg'));
      expect(map['caption'], equals('Toyosato Primary School Music Room'));
      expect(map['uploadedBy'], equals('user_yui'));
      expect(map['uploadedByName'], equals('Yui Hirasawa'));
      expect(map['takenAt'], isA<Timestamp>());
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['deletedAt'], isA<Timestamp>());
      expect(map['expireAt'], isA<Timestamp>());

      final reconstructed = TripPhoto.fromMap(map);
      expect(reconstructed.id, equals(photo.id));
      expect(reconstructed.tripId, equals(photo.tripId));
      expect(reconstructed.stopId, equals(photo.stopId));
      expect(reconstructed.placeKey, equals(photo.placeKey));
      expect(reconstructed.storagePath, equals(photo.storagePath));
      expect(reconstructed.url, equals(photo.url));
      expect(reconstructed.caption, equals(photo.caption));
      expect(reconstructed.uploadedBy, equals(photo.uploadedBy));
      expect(reconstructed.uploadedByName, equals(photo.uploadedByName));
      expect(reconstructed.takenAt, equals(taken));
      expect(reconstructed.createdAt, equals(now));
      expect(reconstructed.deletedAt, equals(deleted));
      expect(reconstructed.expireAt, equals(expire));
    });

    test('TripPhoto.create populates automatic defaults', () {
      final photo = TripPhoto.create(
        id: 'p_new',
        tripId: 't_new',
        storagePath: 'tripsV2/t_new/trip_photos/p_new.jpg',
        url: 'https://storage/p_new.jpg',
        uploadedBy: 'u_tester',
      );

      expect(photo.id, equals('p_new'));
      expect(photo.stopId, isNull);
      expect(photo.deletedAt, isNull);
      expect(photo.expireAt, isNull);
      expect(photo.createdAt, isNotNull);
      expect(photo.updatedAt, equals(photo.createdAt));
    });

    test('fromMap handles raw milliseconds and fallback dates gracefully', () {
      final nowMs = DateTime(2026, 11, 5).millisecondsSinceEpoch;
      final map = {
        'id': 'p_fallback',
        'tripId': 't_fallback',
        'storagePath': 'path',
        'url': 'url',
        'uploadedBy': 'u1',
        'createdAt': nowMs,
        'updatedAt': nowMs,
      };

      final photo = TripPhoto.fromMap(map);
      expect(photo.id, equals('p_fallback'));
      expect(photo.createdAt.millisecondsSinceEpoch, equals(nowMs));
      expect(photo.deletedAt, isNull);
    });
  });

  group('FirestoreSyncV2Service Photo Operations (Fake)', () {
    late _FakeFirestoreSyncV2Service fakeSync;

    setUp(() {
      fakeSync = _FakeFirestoreSyncV2Service();
    });

    test('recording, watching, soft-deleting and restoring trip photos', () async {
      final photo = TripPhoto.create(
        id: 'photo_azusa',
        tripId: 'trip_101',
        storagePath: 'tripsV2/trip_101/trip_photos/photo_azusa.jpg',
        url: 'https://storage/azusa.jpg',
        caption: 'Nakano Azusa shrine visit',
        uploadedBy: 'user_azusa',
      );

      // 1. Record photo
      await fakeSync.recordTripPhoto(photo);

      // Verify watched active photos
      final active1 = await fakeSync.watchTripPhotos('trip_101').first;
      expect(active1.length, equals(1));
      expect(active1.first.id, equals('photo_azusa'));

      // Verify trash is empty
      final trash1 = await fakeSync.watchTrashTripPhotos('trip_101').first;
      expect(trash1, isEmpty);

      // 2. Soft-delete photo
      final deleteTime = DateTime(2026, 11, 5, 16, 0, 0);
      await fakeSync.softDeleteTripPhoto(
        tripId: 'trip_101',
        photoId: 'photo_azusa',
        deletedAt: deleteTime,
      );

      // Active photos should now be empty
      final active2 = await fakeSync.watchTripPhotos('trip_101').first;
      expect(active2, isEmpty);

      // Trash should contain the photo with 30-day expireAt TTL
      final trash2 = await fakeSync.watchTrashTripPhotos('trip_101').first;
      expect(trash2.length, equals(1));
      expect(trash2.first.id, equals('photo_azusa'));
      expect(trash2.first.deletedAt, equals(deleteTime));
      expect(trash2.first.expireAt, equals(deleteTime.add(const Duration(days: 30))));

      // 3. Restore photo
      final restoreTime = DateTime(2026, 11, 5, 17, 0, 0);
      await fakeSync.restoreTripPhoto(
        tripId: 'trip_101',
        photoId: 'photo_azusa',
        restoredAt: restoreTime,
      );

      // Active photos should have the photo back, trash empty
      final active3 = await fakeSync.watchTripPhotos('trip_101').first;
      expect(active3.length, equals(1));
      expect(active3.first.deletedAt, isNull);
      expect(active3.first.expireAt, isNull);

      final trash3 = await fakeSync.watchTrashTripPhotos('trip_101').first;
      expect(trash3, isEmpty);
    });
  });
}

class _FakeFirestoreSyncV2Service implements FirestoreSyncV2Service {
  final Map<String, List<TripPhoto>> photos = {};

  @override
  Future<void> recordTripPhoto(TripPhoto photo) async {
    photos.putIfAbsent(photo.tripId, () => []).add(photo);
  }

  @override
  void buildTripPhotoBatchOperation(WriteBatch batch, TripPhoto photo) {
    recordTripPhoto(photo);
  }

  @override
  Future<void> softDeleteTripPhoto({
    required String tripId,
    required String photoId,
    DateTime? deletedAt,
  }) async {
    final list = photos[tripId] ?? [];
    final idx = list.indexWhere((p) => p.id == photoId);
    if (idx != -1) {
      final now = deletedAt ?? DateTime.now();
      list[idx] = TripPhoto(
        id: list[idx].id,
        tripId: list[idx].tripId,
        stopId: list[idx].stopId,
        placeKey: list[idx].placeKey,
        storagePath: list[idx].storagePath,
        url: list[idx].url,
        caption: list[idx].caption,
        uploadedBy: list[idx].uploadedBy,
        uploadedByName: list[idx].uploadedByName,
        takenAt: list[idx].takenAt,
        createdAt: list[idx].createdAt,
        updatedAt: now,
        deletedAt: now,
        expireAt: now.add(const Duration(days: 30)),
      );
    }
  }

  @override
  Future<void> restoreTripPhoto({
    required String tripId,
    required String photoId,
    DateTime? restoredAt,
  }) async {
    final list = photos[tripId] ?? [];
    final idx = list.indexWhere((p) => p.id == photoId);
    if (idx != -1) {
      final now = restoredAt ?? DateTime.now();
      list[idx] = TripPhoto(
        id: list[idx].id,
        tripId: list[idx].tripId,
        stopId: list[idx].stopId,
        placeKey: list[idx].placeKey,
        storagePath: list[idx].storagePath,
        url: list[idx].url,
        caption: list[idx].caption,
        uploadedBy: list[idx].uploadedBy,
        uploadedByName: list[idx].uploadedByName,
        takenAt: list[idx].takenAt,
        createdAt: list[idx].createdAt,
        updatedAt: now,
        deletedAt: null,
        expireAt: null,
      );
    }
  }

  @override
  Stream<List<TripPhoto>> watchTripPhotos(String tripId) {
    final list = photos[tripId] ?? [];
    return Stream.value(list.where((p) => p.deletedAt == null).toList());
  }

  @override
  Stream<List<TripPhoto>> watchTrashTripPhotos(String tripId) {
    final list = photos[tripId] ?? [];
    return Stream.value(list.where((p) => p.deletedAt != null).toList());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
