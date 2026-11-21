import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/database/database.dart';
import '../models/shooting_core_models.dart';
import 'pilgrimage_shooting_service.dart';

/// When the JPEG in [bytes] was taken, from its EXIF (DateTimeOriginal, else
/// DateTime), as local time; null when it doesn't say or isn't a JPEG.
DateTime? exifTakenAt(Uint8List bytes) {
  try {
    final exif = img.decodeJpgExif(bytes);
    if (exif == null) return null;
    final raw = (exif.exifIfd['DateTimeOriginal'] ?? exif.imageIfd['DateTime'])?.toString().trim();
    final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(raw ?? '');
    if (m == null) return null;
    final parts = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    if (parts[0] < 1900 || parts[1] < 1 || parts[1] > 12 || parts[2] < 1) return null;
    return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
  } catch (_) {
    return null;
  }
}

/// Saves a photo the user picked from the gallery for [frameId] (a place
/// page's frame, "Pick from gallery") as their shot of that frame, the way a
/// kept shot is saved ([PilgrimageShootingService.recordShot]): a copy in
/// the app, a row in [placeKey]'s photos with the frame, filed under
/// [tripId], and the day's visit. So the frame counts as shot, like one shot
/// with the camera. It's taken when its EXIF says ([bytes]), else now.
Future<ShotRecordResult> recordPickedShot(
  AppDatabase db, {
  required String path,
  Uint8List? bytes,
  required String placeKey,
  String? tripId,
  required String frameId,
  PilgrimageShootingService shooting = const PilgrimageShootingService(),
}) =>
    shooting.recordShot(
      db,
      sourceImagePath: path,
      placeKey: placeKey,
      tripId: tripId,
      referenceImageId: frameId,
      takenAt: bytes == null ? null : exifTakenAt(bytes),
    );
