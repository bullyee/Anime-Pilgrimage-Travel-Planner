import 'package:flutter/foundation.dart' show kIsWeb;

/// What the photo editor's route (`/photo-edit`) carries in its query.
class PhotoEditArgs {
  /// The photo to edit. The editor never writes over it.
  final String path;

  /// The place the result is saved into; null saves it to the phone's
  /// gallery only.
  final String? placeKey;

  /// The trip the result is filed under. Null lets the save find the trip
  /// that has the place on the day the photo is taken.
  final String? tripId;

  /// The place photo being edited, which the result derives from.
  final String? photoId;

  /// The anime frame to compare against, and its id when it is one of a
  /// place's frames.
  final String? referencePath;
  final String? referenceImageId;

  /// Picked from the gallery rather than shot just now.
  final bool upload;

  /// Just shot with the Anime Camera, so not in the phone's gallery yet.
  final bool capture;

  const PhotoEditArgs({
    required this.path,
    this.placeKey,
    this.tripId,
    this.photoId,
    this.referencePath,
    this.referenceImageId,
    this.upload = false,
    this.capture = false,
  });

  /// Reads a `/photo-edit` query, or returns null without a `path` or `photoId`.
  /// [placeKey] comes from the old `/pois/:poiId/photo-edit` route.
  ///
  /// The router has decoded the values already, so they're used as they are.
  /// Decoding them again broke file names with a `%` in them (#84).
  static PhotoEditArgs? fromQuery(Map<String, String> query) {
    final path = query['path'];
    final photoId = query['photo'];
    if ((path == null || path.isEmpty) && (photoId == null || photoId.isEmpty)) return null;
    return PhotoEditArgs(
      path: path ?? '',
      placeKey: query['place'],
      tripId: query['trip'],
      photoId: photoId,
      referencePath: query['ref'],
      referenceImageId: query['refId'],
      upload: query['upload'] == '1',
      capture: query['capture'] == '1',
    );
  }

  /// The location that opens the editor with these arguments.
  /// Large `data:` URIs are omitted on Web and when [photoId] is present,
  /// keeping multi-megabyte payloads out of browser URLs and history.
  String get location {
    final isData = path.toLowerCase().startsWith('data:');
    final isRefData = referencePath?.toLowerCase().startsWith('data:') ?? false;
    final includePath = path.isNotEmpty && !isData && (photoId == null || !kIsWeb);
    return Uri(path: '/photo-edit', queryParameters: {
      if (includePath) 'path': path,
      if (placeKey != null) 'place': placeKey!,
      if (tripId != null) 'trip': tripId!,
      if (photoId != null) 'photo': photoId!,
      if (referencePath != null && !isRefData) 'ref': referencePath!,
      if (referenceImageId != null) 'refId': referenceImageId!,
      if (upload) 'upload': '1',
      if (capture) 'capture': '1',
    }).toString();
  }
}
