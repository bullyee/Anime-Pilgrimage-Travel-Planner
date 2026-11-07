import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/database/database.dart';
import '../../trip/models/trip_activity.dart';
import '../../trip/models/trip_photo.dart';

/// A snapshot of user trips from [FirestoreSyncV2Service], carrying whether it originated from local cache.
class UserTripsSnapshot {
  final List<Map<String, dynamic>> trips;
  final bool isFromCache;

  const UserTripsSnapshot({required this.trips, this.isFromCache = false});
}

/// Returns [data] with its `id` set to the Firestore document ID [docId].
///
/// The sync engine keys every local write on `data['id']`. That field is
/// client-written, so it must never be trusted: an editor of one trip could
/// otherwise set it to another trip's ID and make every member's engine
/// overwrite (or delete, or re-own) that other trip locally. The document
/// path is the only identity Firestore itself guarantees.
Map<String, dynamic> withDocumentId(String docId, Map<String, dynamic> data) =>
    {...data, 'id': docId};

/// Service responsible for communicating with Firestore under the new `/tripsV2/{tripId}` collection.
class FirestoreSyncV2Service {
  final FirebaseFirestore _db;

  FirestoreSyncV2Service(this._db);

  /// Check whether a trip exists in Firestore v2.
  Future<bool> tripExists(String tripId) async {
    final doc = await _db.collection('tripsV2').doc(tripId).get();
    return doc.exists;
  }

  /// Initialize a shared cloud trip document if not already existing.
  Future<void> initializeCloudTrip(Trip trip, String currentUserId) async {
    final docRef = _db.collection('tripsV2').doc(trip.id);
    final snapshot = await docRef.get();
    if (snapshot.exists) return;

    final batch = _db.batch();
    batch.set(docRef, {
      'id': trip.id,
      'title': trip.title,
      'description': trip.description,
      'ownerId': trip.ownerId,
      'sharing': trip.sharing,
      'startDate': trip.startDate,
      'dayCount': trip.dayCount,
      'members': [currentUserId],
      'createdAt': Timestamp.fromDate(trip.createdAt),
      'updatedAt': Timestamp.fromDate(trip.updatedAt),
      'updatedBy': trip.updatedBy ?? currentUserId,
      'deletedAt': null,
    });
    await batch.commit();
  }

  /// Create a Firestore WriteBatch.
  WriteBatch createBatch() => _db.batch();

  /// Commit a Firestore WriteBatch.
  Future<void> commitBatch(WriteBatch batch) => batch.commit();

  /// Build batch operation for a [Trip].
  void buildTripBatchOperations(WriteBatch batch, Trip trip) {
    final docRef = _db.collection('tripsV2').doc(trip.id);
    batch.set(
      docRef,
      {
        'id': trip.id,
        'title': trip.title,
        'description': trip.description,
        'ownerId': trip.ownerId,
        'sharing': trip.sharing,
        'startDate': trip.startDate,
        'dayCount': trip.dayCount,
        'members': FieldValue.arrayUnion([trip.ownerId]),
        'updatedAt': Timestamp.fromDate(trip.updatedAt),
        'updatedBy': trip.updatedBy,
        'deletedAt': trip.deletedAt != null ? Timestamp.fromDate(trip.deletedAt!) : null,
      },
      SetOptions(merge: true),
    );
  }

  /// Build batch operation for a [TripDay].
  void buildDayBatchOperations(WriteBatch batch, TripDay day) {
    final docRef = _db
        .collection('tripsV2')
        .doc(day.tripId)
        .collection('days')
        .doc(day.id);
    batch.set(
      docRef,
      {
        'id': day.id,
        'tripId': day.tripId,
        'sortKey': day.sortKey,
        'title': day.title,
        'pinnedDate': day.pinnedDate,
        'updatedAt': Timestamp.fromDate(day.updatedAt),
        'updatedBy': day.updatedBy,
        'deletedAt': day.deletedAt != null ? Timestamp.fromDate(day.deletedAt!) : null,
      },
      SetOptions(merge: true),
    );
  }

  /// Build batch operation for a [Stop] with its associated labels and URL-backed reference images.
  void buildStopBatchOperations(
    WriteBatch batch,
    Stop stop, {
    List<Label>? labels,
    List<NewReferenceImage>? referenceImages,
  }) {
    final docRef = _db
        .collection('tripsV2')
        .doc(stop.tripId)
        .collection('stops')
        .doc(stop.id);

    final data = <String, dynamic>{
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
      'updatedAt': Timestamp.fromDate(stop.updatedAt),
      'updatedBy': stop.updatedBy,
      'deletedAt': stop.deletedAt != null ? Timestamp.fromDate(stop.deletedAt!) : null,
    };

    if (labels != null) {
      data['labels'] = labels
          .map((l) => {
                'id': l.id,
                'kind': l.kind,
                'name': l.name,
                'bangumiId': l.bangumiId,
              })
          .toList();
    }

    if (referenceImages != null) {
      data['referenceImages'] = referenceImages
          .where((img) => img.remoteUrl != null && img.remoteUrl!.isNotEmpty)
          .map((img) => {
                'id': img.id,
                'remoteUrl': img.remoteUrl,
                'animeLabelId': img.animeLabelId,
                'episode': img.episode,
                'timestampS': img.timestampS,
                'source': img.source,
                'sourceUrl': img.sourceUrl,
              })
          .toList();
    }

    batch.set(docRef, data, SetOptions(merge: true));
  }

  /// Build batch operation for a [ScheduleItem].
  void buildScheduleItemBatchOperations(
    WriteBatch batch,
    ScheduleItem item,
  ) {
    final docRef = _db
        .collection('tripsV2')
        .doc(item.tripId)
        .collection('schedule_items')
        .doc(item.id);

    batch.set(
      docRef,
      {
        'id': item.id,
        'tripId': item.tripId,
        'stopId': item.stopId,
        'dayId': item.dayId,
        'sortKey': item.sortKey,
        'stayMinutes': item.stayMinutes,
        'transitMinutes': item.transitMinutes,
        'fixedTime': item.fixedTime,
        'status': item.status,
        'updatedAt': Timestamp.fromDate(item.updatedAt),
        'updatedBy': item.updatedBy,
        'deletedAt': item.deletedAt != null ? Timestamp.fromDate(item.deletedAt!) : null,
      },
      SetOptions(merge: true),
    );
  }

  /// Watch trips accessible to the given user.
  Stream<UserTripsSnapshot> watchUserTrips(String userId) {
    return _db
        .collection('tripsV2')
        .where('members', arrayContains: userId)
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => UserTripsSnapshot(
              trips: snapshot.docs.map((doc) => withDocumentId(doc.id, doc.data())).toList(),
              isFromCache: snapshot.metadata.isFromCache,
            ));
  }

  /// Watch a specific trip document.
  Stream<Map<String, dynamic>?> watchTrip(String tripId) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data == null ? null : withDocumentId(snapshot.id, data);
        });
  }

  /// Watch day blocks of a specific trip.
  Stream<List<Map<String, dynamic>>> watchTripDays(String tripId) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('days')
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => snapshot.docs.map((doc) => withDocumentId(doc.id, doc.data())).toList());
  }

  /// Watch stops of a specific trip.
  Stream<List<Map<String, dynamic>>> watchTripStops(String tripId) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('stops')
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => snapshot.docs.map((doc) => withDocumentId(doc.id, doc.data())).toList());
  }

  /// Watch schedule items of a specific trip.
  Stream<List<Map<String, dynamic>>> watchTripScheduleItems(String tripId) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('schedule_items')
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => snapshot.docs.map((doc) => withDocumentId(doc.id, doc.data())).toList());
  }

  /// Build batch operation for a [TripPhoto].
  void buildTripPhotoBatchOperation(WriteBatch batch, TripPhoto photo) {
    final docRef = _db
        .collection('tripsV2')
        .doc(photo.tripId)
        .collection('trip_photos')
        .doc(photo.id);
    batch.set(docRef, photo.toMap());
  }

  /// Record or update a shared pilgrimage photo in Firestore.
  Future<void> recordTripPhoto(TripPhoto photo) async {
    final docRef = _db
        .collection('tripsV2')
        .doc(photo.tripId)
        .collection('trip_photos')
        .doc(photo.id);
    await docRef.set(photo.toMap());
  }

  /// Soft-deletes a shared photo with automatic 30-day cloud TTL.
  Future<void> softDeleteTripPhoto({
    required String tripId,
    required String photoId,
    DateTime? deletedAt,
  }) async {
    final now = deletedAt ?? DateTime.now();
    final expireAt = now.add(const Duration(days: 30));
    final docRef = _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('trip_photos')
        .doc(photoId);

    await docRef.update({
      'deletedAt': Timestamp.fromDate(now),
      'expireAt': Timestamp.fromDate(expireAt),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Restores a soft-deleted shared photo, deleting the expireAt TTL field.
  Future<void> restoreTripPhoto({
    required String tripId,
    required String photoId,
    DateTime? restoredAt,
  }) async {
    final now = restoredAt ?? DateTime.now();
    final docRef = _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('trip_photos')
        .doc(photoId);

    await docRef.update({
      'deletedAt': null,
      'expireAt': FieldValue.delete(),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Watch active shared photos for a trip (excluding soft-deleted).
  Stream<List<TripPhoto>> watchTripPhotos(String tripId) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('trip_photos')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TripPhoto.fromMap(withDocumentId(doc.id, doc.data())))
          .where((p) => p.deletedAt == null)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Watch soft-deleted trash photos for a trip.
  Stream<List<TripPhoto>> watchTrashTripPhotos(String tripId) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('trip_photos')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TripPhoto.fromMap(withDocumentId(doc.id, doc.data())))
          .where((p) => p.deletedAt != null)
          .toList();
      list.sort((a, b) => (b.deletedAt ?? b.createdAt).compareTo(a.deletedAt ?? a.createdAt));
      return list;
    });
  }

  /// Build batch operation for a [TripActivity].
  void buildActivityBatchOperation(WriteBatch batch, TripActivity activity) {
    final docRef = _db
        .collection('tripsV2')
        .doc(activity.tripId)
        .collection('activity')
        .doc(activity.id);
    batch.set(docRef, activity.toMap());
  }

  /// Record an audit log entry for a trip.
  Future<void> recordActivity(TripActivity activity) async {
    final docRef = _db
        .collection('tripsV2')
        .doc(activity.tripId)
        .collection('activity')
        .doc(activity.id);
    await docRef.set(activity.toMap());
  }

  /// Watch recent activity logs for a trip, newest first.
  Stream<List<TripActivity>> watchTripActivity(String tripId, {int limit = 50}) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripActivity.fromMap(withDocumentId(doc.id, doc.data())))
            .toList());
  }
}
