import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/database/database.dart';

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

/// The most `frameShots` entries one stop doc carries; the Firestore rules
/// refuse a bigger map, and with it the rest of the trip's upload.
const maxFrameShots = 300;

/// The `frameShots` map of a stop doc: where each of [frames] is shot from
/// (`lat`, `lng`, `note`, `heading`), by frame id, for the frames that have
/// any of them; null values are left out.
///
/// It is a map of its own beside `referenceImages` rather than keys inside
/// that array because a phone on an older version rebuilds the array without
/// keys it doesn't know whenever it uploads the stop, while a top-level field
/// it doesn't write survives its merge. It covers local-only frames too
/// (keyed by their id, which a frames pack keeps on the phones it reaches).
Map<String, Map<String, Object>> frameShotsOf(Iterable<NewReferenceImage> frames) {
  final out = SplayTreeMap<String, Map<String, Object>>();
  for (final f in frames) {
    final shot = <String, Object>{
      if (f.lat != null) 'lat': f.lat!,
      if (f.lng != null) 'lng': f.lng!,
      if (f.note?.trim().isNotEmpty ?? false) 'note': f.note!,
      if (f.heading != null) 'heading': f.heading!,
    };
    if (shot.isNotEmpty) out[f.id] = shot;
  }
  return Map.fromEntries(out.entries.take(maxFrameShots));
}

/// Service responsible for communicating with Firestore under the new `/tripsV2/{tripId}` collection.
/// The documents of one trip subcollection, as a list, plus whether the
/// snapshot came from the local cache. A snapshot from the server is the whole
/// collection, which is what lets the sync engine notice rows that are gone
/// (tombstones Firestore purged after 30 days).
class RemoteDocList extends ListBase<Map<String, dynamic>> {
  final List<Map<String, dynamic>> _docs;
  final bool isFromCache;

  RemoteDocList(this._docs, {required this.isFromCache});

  @override
  int get length => _docs.length;

  @override
  set length(int value) => _docs.length = value;

  @override
  Map<String, dynamic> operator [](int index) => _docs[index];

  @override
  void operator []=(int index, Map<String, dynamic> value) => _docs[index] = value;
}

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

  /// How long Firestore keeps a deleted row (a tombstone) after it was last
  /// pushed. A TTL policy on `expireAt` (days, stops, schedule_items, tripsV2,
  /// set up in the Firebase Console) removes it after that; the app's trash
  /// offers Restore for the same 30 days.
  static const tombstoneLifetime = Duration(days: 30);

  /// `expireAt` for a row: 30 days from now when it is deleted, null (no TTL)
  /// when it is live, so a restore clears it again.
  static Timestamp? tombstoneExpiry(DateTime? deletedAt, {DateTime? now}) =>
      deletedAt == null ? null : Timestamp.fromDate((now ?? DateTime.now()).add(tombstoneLifetime));

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
        'expireAt': tombstoneExpiry(trip.deletedAt),
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
        'expireAt': tombstoneExpiry(day.deletedAt),
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
      'mergedInto': stop.mergedInto,
      'addedBy': stop.addedBy,
      'updatedAt': Timestamp.fromDate(stop.updatedAt),
      'updatedBy': stop.updatedBy,
      'deletedAt': stop.deletedAt != null ? Timestamp.fromDate(stop.deletedAt!) : null,
        'expireAt': tombstoneExpiry(stop.deletedAt),
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
      // A merge keeps the doc's other entries (frames only another phone
      // has); a value this phone cleared is deleted rather than left out, or
      // the merge would keep the old one.
      final shots = frameShotsOf(referenceImages);
      if (shots.isNotEmpty) {
        data['frameShots'] = {
          for (final MapEntry(key: id, value: shot) in shots.entries)
            id: {for (final k in const ['lat', 'lng', 'note', 'heading']) k: shot[k] ?? FieldValue.delete()},
        };
      }
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
        'expireAt': tombstoneExpiry(item.deletedAt),
      },
      SetOptions(merge: true),
    );
  }

  /// Build batch operation for one activity log entry (What changed).
  /// Entries are append-only: a plain set of a new document id.
  void buildActivityBatchOperation(WriteBatch batch, TripActivity entry) {
    final docRef = _db
        .collection('tripsV2')
        .doc(entry.tripId)
        .collection('activity')
        .doc(entry.id);
    batch.set(docRef, {
      'id': entry.id,
      'tripId': entry.tripId,
      'actorId': entry.actorId,
      'action': entry.action,
      'entityType': entry.entityType,
      'entityId': entry.entityId,
      'summary': entry.summary,
      'createdAt': Timestamp.fromDate(entry.createdAt),
      'expireAt': Timestamp.fromDate(entry.createdAt.add(tombstoneLifetime)),
    });
  }

  /// Watch a trip's newest activity entries.
  Stream<List<Map<String, dynamic>>> watchTripActivity(String tripId, {int limit = 200}) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => RemoteDocList(
              snapshot.docs.map((doc) => withDocumentId(doc.id, doc.data())).toList(),
              isFromCache: snapshot.metadata.isFromCache,
            ));
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
        .map((snapshot) => RemoteDocList(
              snapshot.docs.map((doc) => withDocumentId(doc.id, doc.data())).toList(),
              isFromCache: snapshot.metadata.isFromCache,
            ));
  }

  /// Watch stops of a specific trip.
  Stream<List<Map<String, dynamic>>> watchTripStops(String tripId) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('stops')
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => RemoteDocList(
              snapshot.docs.map((doc) => withDocumentId(doc.id, doc.data())).toList(),
              isFromCache: snapshot.metadata.isFromCache,
            ));
  }

  /// Watch schedule items of a specific trip.
  Stream<List<Map<String, dynamic>>> watchTripScheduleItems(String tripId) {
    return _db
        .collection('tripsV2')
        .doc(tripId)
        .collection('schedule_items')
        .snapshots(includeMetadataChanges: true)
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map((snapshot) => RemoteDocList(
              snapshot.docs.map((doc) => withDocumentId(doc.id, doc.data())).toList(),
              isFromCache: snapshot.metadata.isFromCache,
            ));
  }
}
