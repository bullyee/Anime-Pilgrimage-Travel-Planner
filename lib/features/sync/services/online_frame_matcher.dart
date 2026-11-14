import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../core/database/database.dart';
import 'trip_frame_downloader.dart' show isAnitabiUrl;

/// A 256-bit difference hash (dHash) of an image: 16 rows of 16 "is this
/// pixel brighter than its right neighbour" bits, from a 17x16 grayscale
/// thumbnail after trimming black letterbox bars. Two copies of the same
/// anime frame (other size, other JPEG quality, small crop) differ in a few
/// bits; different shots differ in 70 or more.
///
/// Kept as 8 x 32-bit words so it behaves the same on the web (no 64-bit ints).
@immutable
class FrameHash {
  static const bits = 256;
  final Uint32List words;

  const FrameHash(this.words);

  /// How many bits differ.
  int distance(FrameHash other) {
    var d = 0;
    for (var i = 0; i < words.length; i++) {
      d += _popCount(words[i] ^ other.words[i]);
    }
    return d;
  }

  static int _popCount(int v) {
    v = v - ((v >> 1) & 0x55555555);
    v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
    return (((v + (v >> 4)) & 0x0F0F0F0F) * 0x01010101 & 0xFFFFFFFF) >> 24;
  }

  /// Hashes encoded image [bytes], or null when they can't be decoded.
  static FrameHash? compute(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return ofImage(decoded);
    } catch (_) {
      return null;
    }
  }

  static FrameHash ofImage(img.Image image) {
    // Work on a small copy: trimming and the final resize don't need detail.
    var im = image.width > 256
        ? img.copyResize(image, width: 256, interpolation: img.Interpolation.average)
        : image;
    im = _trimLetterbox(im);
    final small = img.copyResize(im, width: 17, height: 16, interpolation: img.Interpolation.average);
    final words = Uint32List(8);
    var bit = 0;
    for (var y = 0; y < 16; y++) {
      var left = _luma(small.getPixel(0, y));
      for (var x = 0; x < 16; x++) {
        final right = _luma(small.getPixel(x + 1, y));
        if (left > right) words[bit >> 5] |= 1 << (31 - (bit & 31));
        left = right;
        bit++;
      }
    }
    return FrameHash(words);
  }

  static double _luma(img.Pixel p) => 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

  /// Crops black bars (rows and columns with nothing brighter than 16), as
  /// long as what is left is more than half of each side.
  static img.Image _trimLetterbox(img.Image im) {
    var minX = im.width, minY = im.height, maxX = -1, maxY = -1;
    for (var y = 0; y < im.height; y++) {
      for (var x = 0; x < im.width; x++) {
        if (_luma(im.getPixel(x, y)) > 16) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return im;
    final w = maxX - minX + 1, h = maxY - minY + 1;
    if (w == im.width && h == im.height) return im;
    if (w <= im.width / 2 || h <= im.height / 2) return im;
    return img.copyCrop(im, x: minX, y: minY, width: w, height: h);
  }

  /// Hashes each of [images] off the UI thread (on the web, in place).
  static Future<List<FrameHash?>> computeAll(List<Uint8List> images) {
    List<FrameHash?> run() => [for (final b in images) compute(b)];
    if (kIsWeb) return Future.value(run());
    return Isolate.run(run);
  }
}

/// A frame that is already online at an Anitabi image link, with where it is.
@immutable
class OnlineFrameCandidate {
  final NewReferenceImage frame;
  final double lat;
  final double lng;

  const OnlineFrameCandidate({required this.frame, required this.lat, required this.lng});

  String get url => frame.remoteUrl!.trim();
}

/// What [OnlineFrameMatcher.match] found.
@immutable
class OnlineFrameMatch {
  final OnlineFrameCandidate candidate;
  final int distance;

  const OnlineFrameMatch(this.candidate, this.distance);

  String get url => candidate.url;
}

typedef FrameBytesReader = Future<Uint8List?> Function(String path);
typedef FrameHasher = Future<List<FrameHash?>> Function(List<Uint8List> images);

/// Finds, for a frame that is only on this phone, the same image among the
/// frames already online at Anitabi (library frames of imported spots, and
/// the trip's own Anitabi stop frames), so it can take that link instead of
/// being uploaded to Google Drive.
///
/// A candidate must be near the stop ([radiusMeters]), of the same anime when
/// both say which, and have its image cached on this phone: matching never
/// downloads anything. It matches when the difference hashes are at most
/// [maxDistance] of 256 bits apart.
///
/// Measured on the 關西 trip's 405 frames (the user's own copies of scene
/// images) against the 2,344 cached Anitabi frames near its stops: 294 land
/// within 16 bits, and side by side those are the same frame (another size,
/// crop or subtitle). From about 20 bits up the pairs start to be the same
/// shot a moment earlier or later, so those are uploaded instead; most
/// unrelated frames are 75+ bits apart.
///
/// Anitabi's link serves its standard size (`?plan=h360`, about 640 × 360),
/// and Anitabi asks apps not to show its full-size images. So a frame larger
/// than [maxLinkedLongEdge] isn't swapped for the link: it's uploaded, so the
/// other members see it at the quality the user has.
class OnlineFrameMatcher {
  static const maxDistance = 16;
  static const radiusMeters = 500.0;

  /// Frames up to this long edge may use Anitabi's standard-size link.
  static const maxLinkedLongEdge = 800;

  final List<OnlineFrameCandidate> candidates;
  final FrameBytesReader _readFile;
  final FrameHasher _hashAll;
  final _hashes = <String, Future<FrameHash?>>{};

  OnlineFrameMatcher({
    required this.candidates,
    required FrameBytesReader readFile,
    FrameHasher? hashAll,
  })  : _readFile = readFile,
        _hashAll = hashAll ?? FrameHash.computeAll;

  /// Every frame with an Anitabi link and a cached image, from the library
  /// (located by its place) and from [stops] (located by the stop).
  static Future<OnlineFrameMatcher> forStops(
    AppDatabase db,
    List<Stop> stops, {
    required FrameBytesReader readFile,
    FrameHasher? hashAll,
  }) async {
    final rows = await (db.select(db.newReferenceImages)
          ..where((r) => r.remoteUrl.like('%anitabi.cn/%') & r.localPath.isNotNull()))
        .get();
    final stopById = {for (final s in stops) s.id: s};
    final placeKeys = {
      for (final r in rows)
        if (r.placeKey != null) r.placeKey!,
    };
    final places = placeKeys.isEmpty
        ? const <Place>[]
        : await (db.select(db.places)..where((p) => p.placeKey.isIn(placeKeys))).get();
    final placeByKey = {for (final p in places) p.placeKey: p};

    final candidates = <OnlineFrameCandidate>[];
    for (final r in rows) {
      final url = r.remoteUrl?.trim() ?? '';
      if (!isAnitabiUrl(url) || (r.localPath?.trim().isEmpty ?? true)) continue;
      final stop = r.stopId == null ? null : stopById[r.stopId];
      final place = r.placeKey == null ? null : placeByKey[r.placeKey];
      if (stop != null) {
        candidates.add(OnlineFrameCandidate(frame: r, lat: stop.lat, lng: stop.lng));
      } else if (place != null) {
        candidates.add(OnlineFrameCandidate(frame: r, lat: place.lat, lng: place.lng));
      }
    }
    return OnlineFrameMatcher(candidates: candidates, readFile: readFile, hashAll: hashAll);
  }

  /// The candidates [frame] on [stop] could be.
  List<OnlineFrameCandidate> candidatesFor(Stop stop, {String? animeLabelId}) => [
    for (final c in candidates)
      if ((animeLabelId == null || c.frame.animeLabelId == null || c.frame.animeLabelId == animeLabelId) &&
          distanceMeters(stop.lat, stop.lng, c.lat, c.lng) <= radiusMeters)
        c,
  ];

  /// The online copy of the image [bytes] (a frame on [stop]), or null.
  Future<OnlineFrameMatch?> match(Uint8List bytes, {required Stop stop, String? animeLabelId}) async {
    if (_tooLargeToLink(bytes)) return null;
    final near = candidatesFor(stop, animeLabelId: animeLabelId);
    if (near.isEmpty) return null;
    final mine = (await _hashAll([bytes])).single;
    if (mine == null) return null;
    final theirs = await _hashesOf(near);
    OnlineFrameMatch? best;
    for (var i = 0; i < near.length; i++) {
      final h = theirs[i];
      if (h == null) continue;
      final d = mine.distance(h);
      if (d <= maxDistance && (best == null || d < best.distance)) best = OnlineFrameMatch(near[i], d);
    }
    return best;
  }

  /// Whether the image is sharper than Anitabi's standard size, by its header.
  /// An unreadable header doesn't block matching.
  static bool _tooLargeToLink(Uint8List bytes) {
    try {
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);
      if (info == null) return false;
      return (info.width > info.height ? info.width : info.height) > maxLinkedLongEdge;
    } catch (_) {
      return false;
    }
  }

  /// Each candidate's hash, computed once per path (in one batch per call).
  Future<List<FrameHash?>> _hashesOf(List<OnlineFrameCandidate> list) async {
    final missing = <String, Completer<FrameHash?>>{};
    for (final c in list) {
      final path = c.frame.localPath!;
      if (_hashes.containsKey(path)) continue;
      final completer = Completer<FrameHash?>();
      missing[path] = completer;
      _hashes[path] = completer.future;
    }
    if (missing.isNotEmpty) {
      try {
        final paths = missing.keys.toList();
        final bytes = <Uint8List>[];
        final readable = <String>[];
        for (final path in paths) {
          final b = await _readFile(path);
          if (b == null || b.isEmpty) {
            missing[path]!.complete(null);
          } else {
            bytes.add(b);
            readable.add(path);
          }
        }
        if (bytes.isNotEmpty) {
          final hashes = await _hashAll(bytes);
          for (var i = 0; i < readable.length; i++) {
            missing[readable[i]]!.complete(hashes[i]);
          }
        }
      } catch (_) {
        for (final c in missing.values) {
          if (!c.isCompleted) c.complete(null);
        }
      }
    }
    return Future.wait([for (final c in list) _hashes[c.frame.localPath!]!]);
  }
}

/// Distance in metres between two points (equirectangular; fine at the
/// scale of a neighbourhood).
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0;
  final x = (lng2 - lng1) * math.pi / 180 * math.cos((lat1 + lat2) / 2 * math.pi / 180);
  final y = (lat2 - lat1) * math.pi / 180;
  return earth * math.sqrt(x * x + y * y);
}
