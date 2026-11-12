import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/archive_isolate.dart';
import '../../library/models/frames.dart';

/// Metadata describing a trip local-frames pack, shown before exporting or importing.
class TripFramesPackContents {
  final String tripId;
  final String tripTitle;
  final int stops;
  final int frames;
  final int bytes;
  final DateTime? exportedAt;

  const TripFramesPackContents({
    required this.tripId,
    required this.tripTitle,
    required this.stops,
    required this.frames,
    required this.bytes,
    this.exportedAt,
  });

  Map<String, dynamic> toJson() => {
        'stops': stops,
        'frames': frames,
        'bytes': bytes,
      };

  factory TripFramesPackContents.fromManifest(Map<String, dynamic> manifest) {
    final c = (manifest['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    int n(String k) => (c[k] as num?)?.toInt() ?? 0;
    return TripFramesPackContents(
      tripId: manifest['tripId'] as String? ?? '',
      tripTitle: manifest['tripTitle'] as String? ?? 'Shared trip',
      stops: n('stops'),
      frames: n('frames'),
      bytes: n('bytes'),
      exportedAt: DateTime.tryParse(manifest['exportedAt'] as String? ?? ''),
    );
  }
}

/// Summary of what importing a trip frames pack changed on this device.
class TripFramesImportSummary {
  final int framesAdded;
  final int alreadyPresent;
  final int unmatchedStops;
  final String? foreignTripTitle;

  const TripFramesImportSummary({
    required this.framesAdded,
    required this.alreadyPresent,
    required this.unmatchedStops,
    this.foreignTripTitle,
  });
}

/// Exports and imports a trip's local-only reference frames as a compact `.pilgrimage-frames`
/// zip archive so collaborators can share custom gallery frames directly without cloud storage.
class TripFramesPackService {
  const TripFramesPackService();

  static const format = 'anime_pilgrimage_trip_frames';
  static const version = 1;
  static const fileExtension = 'pilgrimage-frames';
  static const _uuid = Uuid();

  /// Returns counts and total size of local-only frames available to export for [tripId].
  Future<TripFramesPackContents> describeExport(AppDatabase db, String tripId) async =>
      (await _collect(db, tripId)).contents;

  /// Writes the local-only frames for [tripId] to [targetPath] and returns the archive file.
  Future<File> exportFramesPack(
    AppDatabase db, {
    required String tripId,
    required String targetPath,
    BackupProgress? onProgress,
    BackupCancel? cancel,
  }) async {
    final snap = await _collect(db, tripId);
    final manifest = {
      'format': format,
      'version': version,
      'tripId': snap.contents.tripId,
      'tripTitle': snap.contents.tripTitle,
      'exportedAt': DateTime.now().toIso8601String(),
      'counts': snap.contents.toJson(),
    };
    final out = File(targetPath);
    await out.parent.create(recursive: true);
    try {
      await runArchiveIsolate(
        zipStreamWorker,
        [
          targetPath,
          {'manifest.json': jsonEncode(manifest), 'frames.json': jsonEncode(snap.payload)},
          snap.files,
        ],
        onProgress: onProgress,
        cancel: cancel,
      );
    } catch (_) {
      if (await out.exists()) await out.delete();
      rethrow;
    }
    return out;
  }

  /// Reads and validates a frame pack's manifest without extracting media files.
  Future<TripFramesPackContents> readContents(File zip) async {
    final entries = await readZipEntriesInIsolate(zip.path, const ['manifest.json']);
    return TripFramesPackContents.fromManifest(_checkManifest(entries['manifest.json']));
  }

  /// Imports local frames from [zip] onto matching live stops of [tripId].
  ///
  /// Frames already present on a stop (matching ID or file digest) are skipped,
  /// and entries that belong to stops not in [tripId] are ignored.
  Future<TripFramesImportSummary> importFramesPack(
    AppDatabase db, {
    required String tripId,
    required File zip,
    Directory? baseStorageDir,
    BackupProgress? onProgress,
    BackupCancel? cancel,
  }) async {
    final entries = await readZipEntriesInIsolate(zip.path, const ['manifest.json', 'frames.json']);
    final manifest = _checkManifest(entries['manifest.json']);
    final rawFrames = entries['frames.json'];
    if (rawFrames == null) {
      throw const BackupFormatException('This frame pack is damaged: its frame list is missing.');
    }

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(rawFrames) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupFormatException('This frame pack is damaged: its frame list is unreadable.');
    }

    final sourceTripId = manifest['tripId'] as String? ?? '';
    final sourceTripTitle = manifest['tripTitle'] as String?;
    final foreignTripTitle =
        sourceTripId.isNotEmpty && sourceTripId != tripId ? (sourceTripTitle ?? 'another trip') : null;

    final liveStops = await (db.select(db.stops)
          ..where((s) => s.tripId.equals(tripId) & s.deletedAt.isNull()))
        .get();
    final stopsById = {for (final s in liveStops) s.id: s};
    final stopsByPlaceKey = <String, Stop>{};
    for (final s in liveStops) {
      stopsByPlaceKey.putIfAbsent(s.placeKey, () => s);
    }

    final rawItems = [
      for (final item in (payload['items'] as List? ?? const []))
        if (item is Map) Map<String, dynamic>.from(item),
    ];

    final matchedStopIds = <String>{};
    final resolvedTargets = <(Map<String, dynamic> item, String targetStopId)>[];
    var unmatchedStops = 0;
    for (final item in rawItems) {
      final stopId = item['stopId'] as String?;
      final placeKey = item['placeKey'] as String?;
      final target = (stopId != null ? stopsById[stopId] : null) ??
          (placeKey != null ? stopsByPlaceKey[placeKey] : null);
      if (target == null) {
        unmatchedStops++;
        continue;
      }
      matchedStopIds.add(target.id);
      resolvedTargets.add((item, target.id));
    }

    final existingIdsByStop = <String, Set<String>>{};
    final existingHashesByStop = <String, Set<String>>{};
    if (matchedStopIds.isNotEmpty) {
      final existingFrames = await (db.select(db.newReferenceImages)
            ..where((r) => r.stopId.isIn(matchedStopIds)))
          .get();
      for (final f in existingFrames) {
        final sid = f.stopId;
        if (sid == null) continue;
        existingIdsByStop.putIfAbsent(sid, () => {}).add(f.id);
        final path = f.localPath;
        if (path != null && path.isNotEmpty) {
          final hash = await _fileMd5(path);
          if (hash != null) {
            existingHashesByStop.putIfAbsent(sid, () => {}).add(hash);
          }
        }
      }
    }

    final toInsert = <(Map<String, dynamic> item, String targetStopId)>[];
    var alreadyPresent = 0;
    for (final (item, targetStopId) in resolvedTargets) {
      final entry = item['entry'] as String?;
      if (entry == null || entry.isEmpty) continue;
      final frameId = item['id'] as String?;
      final fileHash = item['fileHash'] as String?;
      final ids = existingIdsByStop.putIfAbsent(targetStopId, () => {});
      final hashes = existingHashesByStop.putIfAbsent(targetStopId, () => {});
      if ((frameId != null && ids.contains(frameId)) ||
          (fileHash != null && hashes.contains(fileHash))) {
        alreadyPresent++;
        continue;
      }
      if (frameId != null) ids.add(frameId);
      if (fileHash != null) hashes.add(fileHash);
      toInsert.add((item, targetStopId));
    }

    if (toInsert.isEmpty) {
      return TripFramesImportSummary(
        framesAdded: 0,
        alreadyPresent: alreadyPresent,
        unmatchedStops: unmatchedStops,
        foreignTripTitle: foreignTripTitle,
      );
    }

    final docs = baseStorageDir ?? await _docsDir();
    final refDir = Directory(p.join(docs.path, 'reference_images'));
    final restoredByEntry = <String, String>{};
    final jobs = <List<String>>[];
    final taken = <String>{};
    for (final (item, _) in toInsert) {
      final entry = item['entry'] as String;
      if (restoredByEntry.containsKey(entry)) continue;
      final fileName = p.basename(entry);
      final target = freeArchivePath(refDir, fileName, taken);
      taken.add(target);
      restoredByEntry[entry] = target;
      jobs.add([entry, target]);
    }

    try {
      await runArchiveIsolate(unzipStreamWorker, [zip.path, jobs], onProgress: onProgress, cancel: cancel);
    } catch (_) {
      await deleteFilesQuietly(restoredByEntry.values);
      rethrow;
    }

    try {
      final added = await db.transaction(() async {
        final localLabels = await db.select(db.labels).get();
        final validLabelIds = {for (final l in localLabels) l.id};
        final existingAllIds = {
          for (final row
              in await (db.selectOnly(db.newReferenceImages)..addColumns([db.newReferenceImages.id])).get())
            row.read(db.newReferenceImages.id)!,
        };

        var count = 0;
        for (final (item, targetStopId) in toInsert) {
          final stopStillLive = await (db.select(db.stops)
                ..where((s) => s.id.equals(targetStopId) & s.tripId.equals(tripId) & s.deletedAt.isNull()))
              .getSingleOrNull();
          if (stopStillLive == null) continue;

          final rawId = item['id'] as String?;
          final id = (rawId != null && rawId.isNotEmpty && !existingAllIds.contains(rawId))
              ? rawId
              : _uuid.v4();
          existingAllIds.add(id);

          final rawLabelId = item['animeLabelId'] as String?;
          final resolvedLabelId =
              (rawLabelId != null && validLabelIds.contains(rawLabelId)) ? rawLabelId : null;
          final localPath = restoredByEntry[item['entry'] as String]!;

          await db.into(db.newReferenceImages).insert(
                NewReferenceImagesCompanion.insert(
                  id: id,
                  placeKey: const Value(null),
                  stopId: Value(targetStopId),
                  localPath: Value(localPath),
                  remoteUrl: const Value(null),
                  animeLabelId: Value(resolvedLabelId),
                  episode: Value(item['episode'] as String?),
                  timestampS: Value((item['timestampS'] as num?)?.toInt()),
                  source: Value(item['source'] as String? ?? 'You'),
                  sourceUrl: Value(item['sourceUrl'] as String?),
                ),
              );
          count++;
        }
        return count;
      });

      return TripFramesImportSummary(
        framesAdded: added,
        alreadyPresent: alreadyPresent,
        unmatchedStops: unmatchedStops,
        foreignTripTitle: foreignTripTitle,
      );
    } catch (_) {
      await deleteFilesQuietly(restoredByEntry.values);
      rethrow;
    }
  }

  Future<_FramesSnapshot> _collect(AppDatabase db, String tripId) async {
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null || trip.deletedAt != null) {
      throw const BackupFormatException('This trip is no longer available.');
    }

    final liveStops = await (db.select(db.stops)
          ..where((s) => s.tripId.equals(tripId) & s.deletedAt.isNull()))
        .get();
    final stopIds = {for (final s in liveStops) s.id};
    final placeKeys = {for (final s in liveStops) s.placeKey};

    final stopFrames = stopIds.isEmpty
        ? const <NewReferenceImage>[]
        : await (db.select(db.newReferenceImages)..where((f) => f.stopId.isIn(stopIds))).get();
    final placeFrames = placeKeys.isEmpty
        ? const <NewReferenceImage>[]
        : await (db.select(db.newReferenceImages)..where((f) => f.placeKey.isIn(placeKeys))).get();

    final framesByStop = <String, List<NewReferenceImage>>{};
    for (final f in stopFrames) {
      if (f.stopId != null && isLocalOnlyFrame(f)) {
        framesByStop.putIfAbsent(f.stopId!, () => []).add(f);
      }
    }
    final framesByPlace = <String, List<NewReferenceImage>>{};
    for (final f in placeFrames) {
      if (f.placeKey != null && isLocalOnlyFrame(f)) {
        framesByPlace.putIfAbsent(f.placeKey!, () => []).add(f);
      }
    }

    final files = <String, String>{};
    final hashes = <String, String>{};
    final jobs = <List<String>>[];
    var totalBytes = 0;

    Future<String?> registerFile(String path) async {
      if (files.containsKey(path)) return files[path];
      final file = File(path);
      if (!await file.exists()) return null;
      final digest = await md5.bind(file.openRead()).first;
      final entry = 'files/${files.length}_${p.basename(path)}';
      files[path] = entry;
      hashes[path] = digest.toString();
      jobs.add([path, entry]);
      totalBytes += await file.length();
      return entry;
    }

    final items = <Map<String, dynamic>>[];
    final exportedStopIds = <String>{};
    for (final stop in liveStops) {
      final perStopCandidates = [
        ...?framesByStop[stop.id],
        ...?framesByPlace[stop.placeKey],
      ];
      final seenPathsForStop = <String>{};
      final seenHashesForStop = <String>{};
      for (final f in perStopCandidates) {
        final path = f.localPath!;
        if (!seenPathsForStop.add(path)) continue;
        final entry = await registerFile(path);
        if (entry == null) continue;
        final fileHash = hashes[path]!;
        if (!seenHashesForStop.add(fileHash)) continue;

        exportedStopIds.add(stop.id);
        items.add({
          'id': f.id,
          'stopId': stop.id,
          'placeKey': stop.placeKey,
          'stopName': stop.name,
          'animeLabelId': f.animeLabelId,
          'episode': f.episode,
          'timestampS': f.timestampS,
          'source': f.source,
          'sourceUrl': f.sourceUrl,
          'entry': entry,
          'fileHash': fileHash,
        });
      }
    }

    return _FramesSnapshot(
      contents: TripFramesPackContents(
        tripId: trip.id,
        tripTitle: trip.title,
        stops: exportedStopIds.length,
        frames: items.length,
        bytes: totalBytes,
      ),
      payload: {'items': items},
      files: jobs,
    );
  }

  Map<String, dynamic> _checkManifest(String? raw) {
    if (raw == null) throw const BackupFormatException("This file isn't a trip frames pack from this app.");
    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupFormatException("This file isn't a trip frames pack from this app.");
    }
    if (manifest['format'] != format) {
      throw const BackupFormatException("This file isn't a trip frames pack from this app.");
    }
    final v = (manifest['version'] as num?)?.toInt() ?? 0;
    if (v > version) {
      throw const BackupFormatException(
        'This frame pack is from a newer version of the app. Update the app, then try again.',
      );
    }
    if (v < 1) {
      throw const BackupFormatException("This file isn't a valid trip frames pack.");
    }
    return manifest;
  }

  Future<String?> _fileMd5(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return (await md5.bind(file.openRead()).first).toString();
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _docsDir() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }
}

class _FramesSnapshot {
  final TripFramesPackContents contents;
  final Map<String, dynamic> payload;
  final List<List<String>> files;

  const _FramesSnapshot({
    required this.contents,
    required this.payload,
    required this.files,
  });
}
