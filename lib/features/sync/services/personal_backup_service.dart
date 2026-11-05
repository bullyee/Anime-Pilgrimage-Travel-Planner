import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';

import '../../../core/database/database.dart';

/// Metadata summary of a completed personal library backup.
class BackupSummary {
  final DateTime lastBackupAt;
  final int placesCount;
  final int visitsCount;
  final int labelsCount;
  final int photosCount;
  final int refImagesCount;

  const BackupSummary({
    required this.lastBackupAt,
    required this.placesCount,
    required this.visitsCount,
    required this.labelsCount,
    required this.photosCount,
    required this.refImagesCount,
  });

  Map<String, dynamic> toMap() => {
        'lastBackupAt': Timestamp.fromDate(lastBackupAt),
        'placesCount': placesCount,
        'visitsCount': visitsCount,
        'labelsCount': labelsCount,
        'photosCount': photosCount,
        'refImagesCount': refImagesCount,
      };

  factory BackupSummary.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return BackupSummary(
      lastBackupAt: parseDateTime(map['lastBackupAt']),
      placesCount: (map['placesCount'] as num?)?.toInt() ?? 0,
      visitsCount: (map['visitsCount'] as num?)?.toInt() ?? 0,
      labelsCount: (map['labelsCount'] as num?)?.toInt() ?? 0,
      photosCount: (map['photosCount'] as num?)?.toInt() ?? 0,
      refImagesCount: (map['refImagesCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Summary of restored entities from cloud backup into local SQLite.
class RestoreSummary {
  final int restoredPlaces;
  final int restoredVisits;
  final int restoredLabels;
  final int restoredPhotos;
  final int restoredRefImages;

  const RestoreSummary({
    required this.restoredPlaces,
    required this.restoredVisits,
    required this.restoredLabels,
    required this.restoredPhotos,
    required this.restoredRefImages,
  });
}

/// Service managing private cloud backup and multi-device restoration of the Personal Layer
/// (`places`, `place_visits`, `labels`, `photos`, `reference_images`).
///
/// Backed by the private path `users/{userId}/{document=**}` in `firestore.rules`.
class PersonalBackupService {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  PersonalBackupService({
    required AppDatabase db,
    required FirebaseFirestore firestore,
  })  : _db = db,
        _firestore = firestore;

  /// Helper to commit multiple Firestore operations in chunks of 450 (below Firestore 500-op limit).
  Future<void> _commitBatches(
      List<void Function(WriteBatch batch)> operations) async {
    const chunkSize = 450;
    for (var i = 0; i < operations.length; i += chunkSize) {
      final batch = _firestore.batch();
      final chunk =
          operations.sublist(i, math.min(i + chunkSize, operations.length));
      for (final op in chunk) {
        op(batch);
      }
      await batch.commit();
    }
  }

  /// Back up the user's personal library to Firestore under `users/{userId}/`.
  ///
  /// Only backs up places with `visibility == 'saved'` (excluding internal `trip_only` transient places),
  /// along with all personal visits, labels, photo metadata, and reference images.
  Future<BackupSummary> backupPersonalLibrary({required String userId}) async {
    if (userId.trim().isEmpty || userId == 'guest') {
      throw ArgumentError('Cannot backup personal library for unauthenticated or guest user.');
    }

    final now = DateTime.now();

    // 1. Query personal places (visibility == 'saved')
    final places = await (_db.select(_db.places)
          ..where((p) => p.visibility.equals('saved')))
        .get();

    // 2. Query personal labels & place_labels
    final labels = await _db.select(_db.labels).get();
    final placeLabels = await _db.select(_db.placeLabels).get();

    // 3. Query personal visits
    final visits = await _db.select(_db.placeVisits).get();

    // 4. Query personal photos
    final photos = await _db.select(_db.photos).get();

    // 5. Query personal reference frames linked to places
    final refImages = await (_db.select(_db.newReferenceImages)
          ..where((r) => r.placeKey.isNotNull()))
        .get();

    final operations = <void Function(WriteBatch batch)>[];
    final userDoc = _firestore.collection('users').doc(userId);

    // Queue Place documents
    for (final p in places) {
      operations.add((batch) {
        final ref = userDoc.collection('places').doc(p.placeKey);
        batch.set(ref, {
          'placeKey': p.placeKey,
          'name': p.name,
          'lat': p.lat,
          'lng': p.lng,
          'description': p.description,
          'address': p.address,
          'businessHours': p.businessHours,
          'contactInfo': p.contactInfo,
          'accessTips': p.accessTips,
          'links': p.links,
          'coverRemoteUrl': p.coverRemoteUrl,
          'source': p.source,
          'sourceUrl': p.sourceUrl,
          'privateNote': p.privateNote,
          'visibility': p.visibility,
          'createdAt': Timestamp.fromDate(p.createdAt),
          'updatedAt': Timestamp.fromDate(p.updatedAt),
        });
      });
    }

    // Queue Label documents
    for (final l in labels) {
      operations.add((batch) {
        final ref = userDoc.collection('labels').doc(l.id);
        batch.set(ref, {
          'id': l.id,
          'kind': l.kind,
          'name': l.name,
          'bangumiId': l.bangumiId,
          'createdAt': Timestamp.fromDate(l.createdAt),
        });
      });
    }

    // Queue PlaceLabel documents
    for (final pl in placeLabels) {
      operations.add((batch) {
        final docKey = '${pl.placeKey}___${pl.labelId}';
        final ref = userDoc.collection('place_labels').doc(docKey);
        batch.set(ref, {
          'placeKey': pl.placeKey,
          'labelId': pl.labelId,
        });
      });
    }

    // Queue Visit documents
    for (final v in visits) {
      operations.add((batch) {
        final ref = userDoc.collection('visits').doc(v.id);
        batch.set(ref, {
          'id': v.id,
          'placeKey': v.placeKey,
          'date': v.date,
          'tripId': v.tripId,
          'createdAt': Timestamp.fromDate(v.createdAt),
        });
      });
    }

    // Queue Photo documents
    for (final ph in photos) {
      operations.add((batch) {
        final ref = userDoc.collection('photos').doc(ph.id);
        batch.set(ref, {
          'id': ph.id,
          'placeKey': ph.placeKey,
          'tripId': ph.tripId,
          'kind': ph.kind,
          'derivedFromId': ph.derivedFromId,
          'referenceImageId': ph.referenceImageId,
          'remoteUrl': ph.remoteUrl,
          'isShared': ph.isShared,
          'takenAt': ph.takenAt != null ? Timestamp.fromDate(ph.takenAt!) : null,
          'createdAt': Timestamp.fromDate(ph.createdAt),
        });
      });
    }

    // Queue Reference Image documents
    for (final r in refImages) {
      operations.add((batch) {
        final ref = userDoc.collection('reference_images').doc(r.id);
        batch.set(ref, {
          'id': r.id,
          'placeKey': r.placeKey,
          'remoteUrl': r.remoteUrl,
          'animeLabelId': r.animeLabelId,
          'episode': r.episode,
          'timestampS': r.timestampS,
          'source': r.source,
          'sourceUrl': r.sourceUrl,
          'createdAt': Timestamp.fromDate(r.createdAt),
        });
      });
    }

    // Queue Metadata document
    final summary = BackupSummary(
      lastBackupAt: now,
      placesCount: places.length,
      visitsCount: visits.length,
      labelsCount: labels.length,
      photosCount: photos.length,
      refImagesCount: refImages.length,
    );

    operations.add((batch) {
      final metaRef = userDoc.collection('meta').doc('backup');
      batch.set(metaRef, summary.toMap());
    });

    await _commitBatches(operations);
    return summary;
  }

  /// Restore the user's personal library from Firestore into local SQLite.
  ///
  /// Guarantees:
  /// - **Topological Ingestion Ordering**: Places & Labels inserted before PlaceLabels, Visits, Photos.
  /// - **Conflict & LWW Protection**: If local place row has a newer `updatedAt`, local edits are preserved.
  /// - **Zero Data Loss**: Local cover/photo file paths are never wiped by remote backup null values.
  Future<RestoreSummary> restorePersonalLibrary({required String userId}) async {
    if (userId.trim().isEmpty || userId == 'guest') {
      throw ArgumentError('Cannot restore personal library for unauthenticated or guest user.');
    }

    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final userDoc = _firestore.collection('users').doc(userId);

    // Fetch cloud documents
    final placesSnap = await userDoc.collection('places').get();
    final labelsSnap = await userDoc.collection('labels').get();
    final placeLabelsSnap = await userDoc.collection('place_labels').get();
    final visitsSnap = await userDoc.collection('visits').get();
    final photosSnap = await userDoc.collection('photos').get();
    final refImagesSnap = await userDoc.collection('reference_images').get();

    return _db.transaction(() async {
      int restoredPlaces = 0;
      int restoredLabels = 0;
      int restoredVisits = 0;
      int restoredPhotos = 0;
      int restoredRefImages = 0;

      // 1. Restore Places (Topological Parent)
      for (final doc in placesSnap.docs) {
        final data = doc.data();
        final placeKey = doc.id;
        final remoteUpdatedAt = parseDateTime(data['updatedAt']);

        final existing = await (_db.select(_db.places)
              ..where((p) => p.placeKey.equals(placeKey)))
            .getSingleOrNull();

        if (existing != null) {
          // If local has newer edits, keep local
          if (existing.updatedAt.isAfter(remoteUpdatedAt)) {
            continue;
          }

          // Targeted update with partial protection: preserve localCoverPath
          await (_db.update(_db.places)..where((p) => p.placeKey.equals(placeKey)))
              .write(
            PlacesCompanion(
              name: Value(data['name'] as String? ?? existing.name),
              lat: Value((data['lat'] as num?)?.toDouble() ?? existing.lat),
              lng: Value((data['lng'] as num?)?.toDouble() ?? existing.lng),
              description: Value(data['description'] as String? ?? existing.description),
              address: Value(data['address'] as String? ?? existing.address),
              businessHours: Value(data['businessHours'] as String? ?? existing.businessHours),
              contactInfo: Value(data['contactInfo'] as String? ?? existing.contactInfo),
              accessTips: Value(data['accessTips'] as String? ?? existing.accessTips),
              links: Value(data['links'] as String? ?? existing.links),
              coverLocalPath: Value(existing.coverLocalPath), // Never wipe local cover path!
              coverRemoteUrl: Value(data['coverRemoteUrl'] as String? ?? existing.coverRemoteUrl),
              source: Value(data['source'] as String? ?? existing.source),
              sourceUrl: Value(data['sourceUrl'] as String? ?? existing.sourceUrl),
              privateNote: Value(data['privateNote'] as String? ?? existing.privateNote),
              visibility: Value(data['visibility'] as String? ?? existing.visibility),
              updatedAt: Value(remoteUpdatedAt),
            ),
          );
        } else {
          await _db.into(_db.places).insert(
                PlacesCompanion.insert(
                  placeKey: placeKey,
                  name: data['name'] as String? ?? '',
                  lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
                  lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
                  description: Value(data['description'] as String?),
                  address: Value(data['address'] as String?),
                  businessHours: Value(data['businessHours'] as String?),
                  contactInfo: Value(data['contactInfo'] as String?),
                  accessTips: Value(data['accessTips'] as String?),
                  links: Value(data['links'] as String?),
                  coverRemoteUrl: Value(data['coverRemoteUrl'] as String?),
                  source: Value(data['source'] as String?),
                  sourceUrl: Value(data['sourceUrl'] as String?),
                  privateNote: Value(data['privateNote'] as String?),
                  visibility: Value(data['visibility'] as String? ?? 'saved'),
                  createdAt: Value(parseDateTime(data['createdAt'])),
                  updatedAt: Value(remoteUpdatedAt),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
        restoredPlaces++;
      }

      // 2. Restore Labels (Topological Parent)
      for (final doc in labelsSnap.docs) {
        final data = doc.data();
        await _db.into(_db.labels).insert(
              LabelsCompanion.insert(
                id: doc.id,
                kind: data['kind'] as String? ?? 'tag',
                name: data['name'] as String? ?? '',
                bangumiId: Value(data['bangumiId'] as String?),
                createdAt: Value(parseDateTime(data['createdAt'])),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        restoredLabels++;
      }

      // 3. Restore PlaceLabels (Junction Table)
      for (final doc in placeLabelsSnap.docs) {
        final data = doc.data();
        final placeKey = data['placeKey'] as String?;
        final labelId = data['labelId'] as String?;
        if (placeKey != null && labelId != null) {
          // Verify FK parents exist locally before inserting
          final pExists = await (_db.select(_db.places)..where((p) => p.placeKey.equals(placeKey))).getSingleOrNull();
          final lExists = await (_db.select(_db.labels)..where((l) => l.id.equals(labelId))).getSingleOrNull();
          if (pExists != null && lExists != null) {
            await _db.into(_db.placeLabels).insert(
                  PlaceLabelsCompanion.insert(
                    placeKey: placeKey,
                    labelId: labelId,
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
          }
        }
      }

      // 4. Restore PlaceVisits
      for (final doc in visitsSnap.docs) {
        final data = doc.data();
        final placeKey = data['placeKey'] as String?;
        if (placeKey != null) {
          final pExists = await (_db.select(_db.places)..where((p) => p.placeKey.equals(placeKey))).getSingleOrNull();
          if (pExists != null) {
            await _db.into(_db.placeVisits).insert(
                  PlaceVisitsCompanion.insert(
                    id: doc.id,
                    placeKey: placeKey,
                    date: data['date'] as String? ?? '',
                    tripId: Value(data['tripId'] as String?),
                    createdAt: Value(parseDateTime(data['createdAt'])),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
            restoredVisits++;
          }
        }
      }

      // 5. Restore Photos
      for (final doc in photosSnap.docs) {
        final data = doc.data();
        final placeKey = data['placeKey'] as String?;
        if (placeKey != null) {
          final pExists = await (_db.select(_db.places)..where((p) => p.placeKey.equals(placeKey))).getSingleOrNull();
          if (pExists != null) {
            final existingPhoto = await (_db.select(_db.photos)..where((ph) => ph.id.equals(doc.id))).getSingleOrNull();
            await _db.into(_db.photos).insert(
                  PhotosCompanion.insert(
                    id: doc.id,
                    placeKey: placeKey,
                    tripId: Value(data['tripId'] as String?),
                    kind: Value(data['kind'] as String? ?? 'original'),
                    derivedFromId: Value(data['derivedFromId'] as String?),
                    referenceImageId: Value(data['referenceImageId'] as String?),
                    localPath: existingPhoto?.localPath ?? '',
                    remoteUrl: Value(data['remoteUrl'] as String?),
                    isShared: Value(data['isShared'] as bool? ?? false),
                    takenAt: Value(data['takenAt'] != null ? parseDateTime(data['takenAt']) : null),
                    createdAt: Value(parseDateTime(data['createdAt'])),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
            restoredPhotos++;
          }
        }
      }

      // 6. Restore Reference Images
      for (final doc in refImagesSnap.docs) {
        final data = doc.data();
        final placeKey = data['placeKey'] as String?;
        if (placeKey != null) {
          final pExists = await (_db.select(_db.places)..where((p) => p.placeKey.equals(placeKey))).getSingleOrNull();
          if (pExists != null) {
            final existingRef = await (_db.select(_db.newReferenceImages)..where((r) => r.id.equals(doc.id))).getSingleOrNull();
            await _db.into(_db.newReferenceImages).insert(
                  NewReferenceImagesCompanion.insert(
                    id: doc.id,
                    placeKey: Value(placeKey),
                    localPath: Value(existingRef?.localPath),
                    remoteUrl: Value(data['remoteUrl'] as String?),
                    animeLabelId: Value(data['animeLabelId'] as String?),
                    episode: Value(data['episode'] as String?),
                    timestampS: Value((data['timestampS'] as num?)?.toInt()),
                    source: Value(data['source'] as String?),
                    sourceUrl: Value(data['sourceUrl'] as String?),
                    createdAt: Value(parseDateTime(data['createdAt'])),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
            restoredRefImages++;
          }
        }
      }

      return RestoreSummary(
        restoredPlaces: restoredPlaces,
        restoredVisits: restoredVisits,
        restoredLabels: restoredLabels,
        restoredPhotos: restoredPhotos,
        restoredRefImages: restoredRefImages,
      );
    });
  }

  /// Watch latest backup metadata for the given [userId].
  Stream<BackupSummary?> watchBackupMetadata(String userId) {
    if (userId.trim().isEmpty || userId == 'guest') {
      return Stream.value(null);
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('meta')
        .doc('backup')
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return BackupSummary.fromMap(snap.data()!);
    });
  }
}
