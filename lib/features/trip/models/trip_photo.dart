import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a shared anime pilgrimage photo in `tripsV2/{tripId}/trip_photos/{photoId}` (Phase 3).
class TripPhoto {
  final String id;
  final String tripId;
  final String? stopId;
  final String? placeKey;
  final String storagePath;
  final String url;
  final String? caption;
  final String uploadedBy;
  final String? uploadedByName;
  final DateTime? takenAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? expireAt;

  const TripPhoto({
    required this.id,
    required this.tripId,
    this.stopId,
    this.placeKey,
    required this.storagePath,
    required this.url,
    this.caption,
    required this.uploadedBy,
    this.uploadedByName,
    this.takenAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.expireAt,
  });

  /// Factory to construct a new shared photo.
  factory TripPhoto.create({
    required String id,
    required String tripId,
    String? stopId,
    String? placeKey,
    required String storagePath,
    required String url,
    String? caption,
    required String uploadedBy,
    String? uploadedByName,
    DateTime? takenAt,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return TripPhoto(
      id: id,
      tripId: tripId,
      stopId: stopId,
      placeKey: placeKey,
      storagePath: storagePath,
      url: url,
      caption: caption,
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      takenAt: takenAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      if (stopId != null) 'stopId': stopId,
      if (placeKey != null) 'placeKey': placeKey,
      'storagePath': storagePath,
      'url': url,
      if (caption != null) 'caption': caption,
      'uploadedBy': uploadedBy,
      if (uploadedByName != null) 'uploadedByName': uploadedByName,
      if (takenAt != null) 'takenAt': Timestamp.fromDate(takenAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
      if (expireAt != null) 'expireAt': Timestamp.fromDate(expireAt!),
    };
  }

  factory TripPhoto.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, {DateTime? fallback}) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    final createdAt = parseDate(map['createdAt']);
    final updatedAt = parseDate(map['updatedAt'], fallback: createdAt);
    final takenAt = map['takenAt'] != null ? parseDate(map['takenAt']) : null;
    final deletedAt = map['deletedAt'] != null ? parseDate(map['deletedAt']) : null;
    final expireAt = map['expireAt'] != null ? parseDate(map['expireAt']) : null;

    return TripPhoto(
      id: map['id'] as String? ?? '',
      tripId: map['tripId'] as String? ?? '',
      stopId: map['stopId'] as String?,
      placeKey: map['placeKey'] as String?,
      storagePath: map['storagePath'] as String? ?? '',
      url: map['url'] as String? ?? '',
      caption: map['caption'] as String?,
      uploadedBy: map['uploadedBy'] as String? ?? '',
      uploadedByName: map['uploadedByName'] as String?,
      takenAt: takenAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      expireAt: expireAt,
    );
  }
}
