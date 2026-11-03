import 'dart:io';

import 'package:flutter/foundation.dart'; // ADDED: for debugPrint
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';
import '../../library/repositories/place_repository.dart';

/// Copies [source] into the app's permanent `camera_photos` directory
/// (filename derived from a unique UUID) and adds it to [placeKey]'s photos.
///
/// [kind] is `original`, `edited`, `composite` or `comparison`;
/// [derivedFromId] is the place photo it was edited from, and [tripId] the
/// trip it was taken on.
///
/// Returns `true` on success, `false` on any I/O or database failure
/// — callers decide whether to surface that via a SnackBar.
Future<bool> persistPlacePhoto({
  required PlaceRepository places,
  required File source,
  required String placeKey,
  String? referenceImageId,
  String kind = 'original',
  String? derivedFromId,
  String? tripId,
  DateTime? takenAt,
}) async {
  try {
    // Checked first, so a photo for a missing place leaves no copy behind.
    if (await places.getPlace(placeKey) == null) throw StateError('$placeKey is not a place');

    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'camera_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final photoId = const Uuid().v4();
    final extension =
        p.extension(source.path).isEmpty ? '.jpg' : p.extension(source.path);
    final savedPath = p.join(photosDir.path, 'photo_$photoId$extension');
    await source.copy(savedPath);

    await places.upsertPhoto(PhotosCompanion.insert(
      id: photoId,
      placeKey: placeKey,
      tripId: Value(tripId),
      kind: Value(kind),
      derivedFromId: Value(derivedFromId),
      referenceImageId: Value(referenceImageId),
      localPath: savedPath,
      takenAt: Value(takenAt ?? DateTime.now()),
    ));
    return true;
  } catch (e, st) {
    // CRITICAL FIX: Stop silent failures. Log the exact I/O or DB error.
    debugPrint('[MediaAssetService] Failed to persist the photo: $e\n$st');
    return false;
  }
}
