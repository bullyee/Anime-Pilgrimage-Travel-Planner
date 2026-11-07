import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/photo_exif_models.dart';

/// Service responsible for extracting GPS coordinates, timestamps, and orientation
/// from raw image bytes and file headers.
class PhotoExifExtractor {
  const PhotoExifExtractor._();

  /// Extracts [PhotoExifData] from in-memory [bytes].
  ///
  /// Never throws on corrupted, malformed, or missing EXIF data.
  static PhotoExifData extractFromBytes(List<int> bytes) {
    if (bytes.length < 16) {
      return const PhotoExifData();
    }

    try {
      final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      final exif = img.decodeJpgExif(uint8);
      if (exif == null) {
        return const PhotoExifData();
      }

      final orientation = exif.imageIfd.orientation ?? 1;
      final capturedAt = _parseDateTime(exif);
      final (lat, lng) = _parseGpsCoordinates(exif);
      final altitude = _parseAltitude(exif);

      return PhotoExifData(
        capturedAt: capturedAt,
        lat: lat,
        lng: lng,
        altitude: altitude,
        orientation: orientation,
      );
    } catch (_) {
      // Graceful fallback for non-JPEG or corrupted EXIF segments
      return const PhotoExifData();
    }
  }

  /// Extracts [PhotoExifData] from a local physical [file].
  ///
  /// Uses file modification time as a fallback for [capturedAt] if EXIF timestamp is absent.
  static Future<PhotoExifData> extractFromFile(File file) async {
    if (!await file.exists()) {
      return const PhotoExifData();
    }

    try {
      final bytes = await file.readAsBytes();
      final exif = extractFromBytes(bytes);
      if (exif.capturedAt == null) {
        final stat = await file.stat();
        return PhotoExifData(
          capturedAt: stat.modified,
          lat: exif.lat,
          lng: exif.lng,
          altitude: exif.altitude,
          orientation: exif.orientation,
        );
      }
      return exif;
    } catch (_) {
      return const PhotoExifData();
    }
  }

  static DateTime? _parseDateTime(img.ExifData exif) {
    // 0x9003 = DateTimeOriginal, 0x0132 = DateTime
    final rawDate = exif.exifIfd[0x9003]?.toString() ??
        exif.imageIfd[0x0132]?.toString();

    if (rawDate == null || rawDate.isEmpty) return null;

    final trimmed = rawDate.trim();
    // Typical EXIF format: "YYYY:MM:DD HH:MM:SS"
    final regex = RegExp(r'^(\d{4})[:\-](\d{2})[:\-](\d{2})\s+(\d{2}):(\d{2}):(\d{2})');
    final match = regex.firstMatch(trimmed);
    if (match != null) {
      final y = int.tryParse(match.group(1)!) ?? 1970;
      final m = int.tryParse(match.group(2)!) ?? 1;
      final d = int.tryParse(match.group(3)!) ?? 1;
      final h = int.tryParse(match.group(4)!) ?? 0;
      final min = int.tryParse(match.group(5)!) ?? 0;
      final s = int.tryParse(match.group(6)!) ?? 0;
      return DateTime(y, m, d, h, min, s);
    }

    return DateTime.tryParse(trimmed);
  }

  static (double?, double?) _parseGpsCoordinates(img.ExifData exif) {
    try {
      final gps = exif.gpsIfd;
      // 0x0001 = GPSLatitudeRef, 0x0002 = GPSLatitude
      // 0x0003 = GPSLongitudeRef, 0x0004 = GPSLongitude
      final latVal = gps[0x0002];
      final latRef = gps[0x0001]?.toString().trim().toUpperCase();

      final lngVal = gps[0x0004];
      final lngRef = gps[0x0003]?.toString().trim().toUpperCase();

      if (latVal == null || lngVal == null) {
        return (null, null);
      }

      final lat = _rationalToDegrees(latVal);
      final lng = _rationalToDegrees(lngVal);

      if (lat == null || lng == null) {
        return (null, null);
      }

      final signedLat = (latRef == 'S') ? -lat.abs() : lat.abs();
      final signedLng = (lngRef == 'W') ? -lng.abs() : lng.abs();

      return (signedLat, signedLng);
    } catch (_) {
      return (null, null);
    }
  }

  static double? _parseAltitude(img.ExifData exif) {
    try {
      // 0x0006 = GPSAltitude
      final altVal = exif.gpsIfd[0x0006];
      if (altVal == null) return null;
      return altVal.toDouble();
    } catch (_) {
      return null;
    }
  }

  static double? _rationalToDegrees(dynamic val) {
    try {
      if (val is List && val.length >= 3) {
        final deg = (val[0] as num).toDouble();
        final min = (val[1] as num).toDouble();
        final sec = (val[2] as num).toDouble();
        return deg + (min / 60.0) + (sec / 3600.0);
      }

      // If already a single scalar numeric value
      if (val is num) return val.toDouble();

      // If it has a toList() or array-like accessor
      final list = val.toList();
      if (list is List && list.length >= 3) {
        final deg = _toNum(list[0]);
        final min = _toNum(list[1]);
        final sec = _toNum(list[2]);
        if (deg != null && min != null && sec != null) {
          return deg + (min / 60.0) + (sec / 3600.0);
        }
      }
    } catch (_) {
      // Fallback: parse string like "[34/1, 59/1, 9/1]"
      final str = val.toString();
      final rationalMatch = RegExp(r'(\d+)(?:/(\d+))?').allMatches(str).toList();
      if (rationalMatch.length >= 3) {
        final deg = _parseFraction(rationalMatch[0]);
        final min = _parseFraction(rationalMatch[1]);
        final sec = _parseFraction(rationalMatch[2]);
        return deg + (min / 60.0) + (sec / 3600.0);
      }
    }
    return null;
  }

  static double? _toNum(dynamic item) {
    if (item is num) return item.toDouble();
    if (item != null) {
      try {
        return (item.toDouble() as num).toDouble();
      } catch (_) {
        return double.tryParse(item.toString());
      }
    }
    return null;
  }

  static double _parseFraction(Match match) {
    final num = double.tryParse(match.group(1) ?? '0') ?? 0.0;
    final den = double.tryParse(match.group(2) ?? '1') ?? 1.0;
    return den != 0 ? num / den : num;
  }
}
