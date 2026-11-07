/// Extracted EXIF metadata from a pilgrimage photograph.
class PhotoExifData {
  final DateTime? capturedAt;
  final double? lat;
  final double? lng;
  final double? altitude;
  final int orientation;

  const PhotoExifData({
    this.capturedAt,
    this.lat,
    this.lng,
    this.altitude,
    this.orientation = 1,
  });

  bool get hasGps => lat != null && lng != null;

  @override
  String toString() =>
      'PhotoExifData(capturedAt: $capturedAt, pos: ($lat, $lng), orientation: $orientation)';
}

/// A candidate pilgrimage stop / anime scene matching a photograph.
class PhotoMatchCandidate {
  final String stopId;
  final String placeKey;
  final String stopName;
  final String? animeTitle;
  final String? referenceImageId;
  final double? distanceMeters;
  final double confidence; // 0.0 to 1.0
  final String matchReason;

  const PhotoMatchCandidate({
    required this.stopId,
    required this.placeKey,
    required this.stopName,
    this.animeTitle,
    this.referenceImageId,
    this.distanceMeters,
    required this.confidence,
    required this.matchReason,
  });

  @override
  String toString() =>
      'PhotoMatchCandidate($stopName, confidence: ${(confidence * 100).toStringAsFixed(1)}%, dist: ${distanceMeters?.toStringAsFixed(1)}m)';
}

/// Input representation of a photo to be matched.
class PhotoInput {
  final String id;
  final String? localPath;
  final List<int>? bytes;
  final PhotoExifData? explicitExif;

  const PhotoInput({
    required this.id,
    this.localPath,
    this.bytes,
    this.explicitExif,
  });
}

/// The outcome of evaluating a photograph against candidate pilgrimage stops.
class PhotoMatchResult {
  final String photoId;
  final String? localPath;
  final PhotoExifData exif;
  final PhotoMatchCandidate? bestMatch;
  final List<PhotoMatchCandidate> allCandidates;
  final bool isAmbiguous;

  const PhotoMatchResult({
    required this.photoId,
    this.localPath,
    required this.exif,
    this.bestMatch,
    required this.allCandidates,
    this.isAmbiguous = false,
  });

  /// True if a match was identified with high confidence (>= 0.70).
  bool get isConfident => bestMatch != null && bestMatch!.confidence >= 0.70;

  /// True if a match was identified with at least moderate confidence (>= 0.50).
  bool get hasMatch => bestMatch != null && bestMatch!.confidence >= 0.50;

  @override
  String toString() =>
      'PhotoMatchResult($photoId, best: ${bestMatch?.stopName}, confidence: ${bestMatch?.confidence})';
}
