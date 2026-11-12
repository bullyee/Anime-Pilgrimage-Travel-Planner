import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/archive_isolate.dart';

export '../../../core/utils/archive_isolate.dart'
    show BackupCancel, BackupCancelled, BackupFormatException, BackupProgress;

/// What a backup file holds, from its manifest: shown before exporting and
/// before importing.
class BackupContents {
  /// Places shown in the library (not the hidden ones kept for trips).
  final int places;
  final int privateTrips;
  final int photos;
  final int frames;

  /// The size of the files inside (photos, frames and covers).
  final int bytes;
  final DateTime? exportedAt;

  const BackupContents({
    required this.places,
    required this.privateTrips,
    required this.photos,
    required this.frames,
    required this.bytes,
    this.exportedAt,
  });

  Map<String, dynamic> toJson() => {
        'places': places,
        'privateTrips': privateTrips,
        'photos': photos,
        'frames': frames,
        'bytes': bytes,
      };

  factory BackupContents.fromManifest(Map<String, dynamic> manifest) {
    final c = (manifest['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    int n(String k) => (c[k] as num?)?.toInt() ?? 0;
    return BackupContents(
      places: n('places'),
      privateTrips: n('privateTrips'),
      photos: n('photos'),
      frames: n('frames'),
      bytes: n('bytes'),
      exportedAt: DateTime.tryParse(manifest['exportedAt'] as String? ?? ''),
    );
  }
}

/// What an import added. What was already on the phone is kept as it is and
/// counted in [alreadyHere].
class LibraryImportSummary {
  final int places;
  final int privateTrips;
  final int photos;
  final int frames;

  /// Places and trips skipped because the phone already had them.
  final int alreadyHere;

  const LibraryImportSummary({
    required this.places,
    required this.privateTrips,
    required this.photos,
    required this.frames,
    required this.alreadyHere,
  });
}

/// Exports and imports everything on this phone that isn't in the cloud, as
/// one `.pilgrimage` file (a zip), to move to another phone (#78).
///
/// The rule (2026-11-11): what's shared goes to the cloud, the rest moves by
/// file. So the file holds:
/// - the library: places, labels, visits, photos and the places' frames;
/// - private trips, which never sync, in full: days, stops, stop labels,
///   schedule items and the stops' frames;
/// - from shared trips, only the frames that don't sync (no `remoteUrl`,
///   #152). The trips themselves come back by signing in, and the frames find
///   their stops then, since `stopId` has no foreign key.
///
/// Importing keeps what's already on the phone and adds what's missing, so an
/// old backup never overwrites newer edits (#151).
///
/// Files are zipped and unzipped one at a time in a background isolate, so
/// neither memory nor the UI depends on the library's size (#149).
class LibraryBackupService {
  const LibraryBackupService();

  static const format = 'anime_pilgrimage_library';

  /// 2 since the scope above; 1 (#135) was never offered in the app.
  static const version = 2;

  static const fileExtension = 'pilgrimage';

  /// The contents an export would have now, for the confirm dialog.
  Future<BackupContents> describeExport(AppDatabase db) async => (await _collect(db)).contents;

  /// Writes the backup to [targetPath] and returns it.
  Future<File> exportLibraryArchive(
    AppDatabase db, {
    required String targetPath,
    BackupProgress? onProgress,
    BackupCancel? cancel,
  }) async {
    final snap = await _collect(db);
    final manifest = {
      'format': format,
      'version': version,
      'schemaVersion': db.schemaVersion,
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
          {'manifest.json': jsonEncode(manifest), 'library.json': jsonEncode(snap.payload)},
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

  /// Reads a backup's manifest, refusing a file this app can't import.
  Future<BackupContents> readContents(File zip) async {
    final manifest = await readZipEntriesInIsolate(zip.path, const ['manifest.json']);
    return BackupContents.fromManifest(_checkManifest(manifest['manifest.json']));
  }

  /// Adds what [zip] holds and this phone doesn't have yet.
  ///
  /// [baseStorageDir] is where files go (`reference_images/` for frames and
  /// covers, `app_photos/` for photos); the app's documents folder by default.
  Future<LibraryImportSummary> importLibraryArchive(
    AppDatabase db,
    File zip, {
    Directory? baseStorageDir,
    BackupProgress? onProgress,
    BackupCancel? cancel,
  }) async {
    final entries = await readZipEntriesInIsolate(zip.path, const ['manifest.json', 'library.json']);
    _checkManifest(entries['manifest.json']);
    final library = entries['library.json'];
    if (library == null) throw const BackupFormatException('This backup is damaged: its list of places is missing.');
    final payload = jsonDecode(library) as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(String key) =>
        [for (final r in (payload[key] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
    final files = (payload['files'] as Map?)?.cast<String, String>() ?? const <String, String>{};

    // 1. Decide what to add: only rows the phone doesn't have.
    Future<Set<String>> existing(ResultSetImplementation<HasResultSet, dynamic> table, GeneratedColumn<String> key,
        Iterable<String> ids) async {
      final list = ids.toSet().toList();
      final found = <String>{};
      for (var i = 0; i < list.length; i += 500) {
        final chunk = list.sublist(i, i + 500 > list.length ? list.length : i + 500);
        final q = db.selectOnly(table)
          ..addColumns([key])
          ..where(key.isIn(chunk));
        found.addAll((await q.get()).map((r) => r.read(key)!));
      }
      return found;
    }

    final places = rows('places');
    final havePlaces = await existing(db.places, db.places.placeKey, places.map((r) => r['placeKey'] as String));
    final newPlaces = [for (final r in places) if (!havePlaces.contains(r['placeKey'])) r];

    final trips = rows('trips');
    final haveTrips = await existing(db.trips, db.trips.id, trips.map((r) => r['id'] as String));
    final newTrips = [for (final r in trips) if (!haveTrips.contains(r['id'])) r];
    final newTripIds = {for (final r in newTrips) r['id'] as String};
    List<Map<String, dynamic>> ofNewTrips(String key) => [for (final r in rows(key)) if (newTripIds.contains(r['tripId'])) r];
    final newDays = ofNewTrips('tripDays');
    final newStops = ofNewTrips('stops');
    final newItems = ofNewTrips('scheduleItems');
    final newStopIds = {for (final r in newStops) r['id'] as String};
    final newStopLabels = [for (final r in rows('stopLabels')) if (newStopIds.contains(r['stopId'])) r];

    final photos = rows('photos');
    final havePhotos = await existing(db.photos, db.photos.id, photos.map((r) => r['id'] as String));
    final newPhotos = [for (final r in photos) if (!havePhotos.contains(r['id']) && files.containsKey(r['localPath'])) r];

    final frames = rows('referenceImages');
    final haveFrames = await existing(db.newReferenceImages, db.newReferenceImages.id, frames.map((r) => r['id'] as String));
    final newFrames = [for (final r in frames) if (!haveFrames.contains(r['id'])) r];

    final visits = rows('visits');
    final haveVisits = await existing(db.placeVisits, db.placeVisits.id, visits.map((r) => r['id'] as String));
    final newVisits = [for (final r in visits) if (!haveVisits.contains(r['id'])) r];

    // 2. Unzip only the files the new rows use.
    final docs = baseStorageDir ?? await _docsDir();
    final photoPaths = {for (final r in newPhotos) r['localPath'] as String};
    final usedPaths = <String>{
      ...photoPaths,
      for (final r in newPlaces) ?r['coverLocalPath'] as String?,
      for (final r in newStops) ?r['coverLocalPath'] as String?,
      for (final r in newFrames) ?r['localPath'] as String?,
    }.where(files.containsKey);
    final restored = <String, String>{}; // original path -> new path
    final jobs = <List<String>>[];
    final taken = <String>{};
    for (final original in usedPaths) {
      final dir = Directory(p.join(docs.path, photoPaths.contains(original) ? 'app_photos' : 'reference_images'));
      final target = freeArchivePath(dir, p.basename(original), taken);
      taken.add(target);
      restored[original] = target;
      jobs.add([files[original]!, target]);
    }
    try {
      await runArchiveIsolate(unzipStreamWorker, [zip.path, jobs], onProgress: onProgress, cancel: cancel);
    } catch (_) {
      await deleteFilesQuietly(restored.values);
      rethrow;
    }
    String? moved(String? path) => path == null ? null : restored[path];

    // 3. Add the rows, parents first.
    try {
      return await db.transaction(() async {
        Future<void> add<T extends Table, R>(TableInfo<T, R> table, Insertable<R> row) =>
            db.into(table).insert(row, mode: InsertMode.insertOrIgnore);

        for (final r in newPlaces) {
          final place = Place.fromJson(r);
          await add(db.places, place.copyWith(coverLocalPath: Value(moved(place.coverLocalPath))).toCompanion(true));
        }

        // Labels: one the phone has (same id, Bangumi id, or tag/region name)
        // is used as it is; the backup's copy is dropped.
        final local = await db.select(db.labels).get();
        final byId = {for (final l in local) l.id: l};
        final byBangumi = {for (final l in local) if (l.bangumiId?.isNotEmpty ?? false) l.bangumiId!: l};
        final byName = {for (final l in local) if (l.kind != 'anime') (l.kind, l.name): l};
        final labelId = <String, String>{};
        for (final r in rows('labels')) {
          final label = Label.fromJson(r);
          final match = byId[label.id] ??
              ((label.bangumiId?.isNotEmpty ?? false) ? byBangumi[label.bangumiId!] : null) ??
              (label.kind != 'anime' ? byName[(label.kind, label.name)] : null);
          if (match != null) {
            labelId[label.id] = match.id;
            continue;
          }
          await add(db.labels, label.toCompanion(true));
          labelId[label.id] = label.id;
          byId[label.id] = label;
          if (label.bangumiId?.isNotEmpty ?? false) byBangumi[label.bangumiId!] = label;
          if (label.kind != 'anime') byName[(label.kind, label.name)] = label;
        }
        String mapLabel(String id) => labelId[id] ?? id;
        final allLabelIds = {for (final l in byId.values) l.id};

        for (final r in rows('placeLabels')) {
          final pl = PlaceLabel.fromJson(r);
          final id = mapLabel(pl.labelId);
          if (allLabelIds.contains(id)) await add(db.placeLabels, pl.copyWith(labelId: id).toCompanion(true));
        }
        for (final r in newVisits) {
          await add(db.placeVisits, PlaceVisit.fromJson(r).toCompanion(true));
        }
        for (final r in newTrips) {
          await add(db.trips, Trip.fromJson(r).toCompanion(true));
        }
        for (final r in newDays) {
          await add(db.tripDays, TripDay.fromJson(r).toCompanion(true));
        }
        for (final r in newStops) {
          final stop = Stop.fromJson(r);
          await add(db.stops, stop.copyWith(coverLocalPath: Value(moved(stop.coverLocalPath))).toCompanion(true));
        }
        for (final r in newStopLabels) {
          final sl = StopLabel.fromJson(r);
          final id = mapLabel(sl.labelId);
          if (allLabelIds.contains(id)) await add(db.stopLabels, sl.copyWith(labelId: id).toCompanion(true));
        }
        for (final r in newItems) {
          await add(db.scheduleItems, ScheduleItem.fromJson(r).toCompanion(true));
        }
        for (final r in newPhotos) {
          final photo = Photo.fromJson(r);
          await add(db.photos, photo.copyWith(localPath: restored[photo.localPath]!).toCompanion(true));
        }
        var frameCount = 0;
        for (final r in newFrames) {
          final frame = NewReferenceImage.fromJson(r);
          final path = moved(frame.localPath);
          if (path == null && (frame.remoteUrl?.isEmpty ?? true)) continue; // nothing to show
          await add(
            db.newReferenceImages,
            frame
                .copyWith(
                  localPath: Value(path),
                  animeLabelId: Value(frame.animeLabelId == null ? null : mapLabel(frame.animeLabelId!)),
                )
                .toCompanion(true),
          );
          frameCount++;
        }
        return LibraryImportSummary(
          places: newPlaces.where((r) => r['visibility'] != 'trip_only').length,
          privateTrips: newTrips.length,
          photos: newPhotos.length,
          frames: frameCount,
          alreadyHere: places.where((r) => havePlaces.contains(r['placeKey']) && r['visibility'] != 'trip_only').length +
              haveTrips.length,
        );
      });
    } catch (_) {
      await deleteFilesQuietly(restored.values);
      rethrow;
    }
  }

  /// The rows and files an export holds now.
  Future<_Snapshot> _collect(AppDatabase db) async {
    final allTrips = await (db.select(db.trips)..where((t) => t.deletedAt.isNull())).get();
    final privateIds = {for (final t in allTrips) if (t.sharing == 'private') t.id};
    final sharedIds = {for (final t in allTrips) if (t.sharing != 'private') t.id};

    final days = await (db.select(db.tripDays)..where((d) => d.tripId.isIn(privateIds) & d.deletedAt.isNull())).get();
    final liveStops = await (db.select(db.stops)..where((s) => s.deletedAt.isNull())).get();
    final stops = [for (final s in liveStops) if (privateIds.contains(s.tripId)) s];
    final stopIds = {for (final s in stops) s.id};
    final dayIds = {for (final d in days) d.id};
    final sharedStopIds = {for (final s in liveStops) if (sharedIds.contains(s.tripId)) s.id};
    final items = [
      for (final i in await (db.select(db.scheduleItems)..where((i) => i.deletedAt.isNull())).get())
        if (stopIds.contains(i.stopId) && dayIds.contains(i.dayId)) i,
    ];
    final stopLabels = [for (final sl in await db.select(db.stopLabels).get()) if (stopIds.contains(sl.stopId)) sl];

    final photos = await db.select(db.photos).get();
    final visits = await db.select(db.placeVisits).get();
    final wanted = {
      for (final s in stops) s.placeKey,
      for (final ph in photos) ph.placeKey,
      for (final v in visits) v.placeKey,
    };
    final places = [
      for (final pl in await db.select(db.places).get())
        if (pl.visibility != 'trip_only' || wanted.contains(pl.placeKey)) pl,
    ];
    final placeKeys = {for (final pl in places) pl.placeKey};
    final placeLabels = [for (final pl in await db.select(db.placeLabels).get()) if (placeKeys.contains(pl.placeKey)) pl];
    final frames = [
      for (final f in await db.select(db.newReferenceImages).get())
        if ((f.placeKey != null && placeKeys.contains(f.placeKey)) ||
            (f.stopId != null && stopIds.contains(f.stopId)) ||
            (f.stopId != null &&
                sharedStopIds.contains(f.stopId) &&
                (f.remoteUrl?.isEmpty ?? true) &&
                (f.localPath?.isNotEmpty ?? false)))
          f,
    ];
    final labels = await db.select(db.labels).get();

    // Each file once, even when a cover is also a frame.
    final files = <String, String>{}; // original path -> entry in the zip
    final jobs = <List<String>>[];
    var bytes = 0;
    Future<void> addFile(String? path) async {
      if (path == null || path.isEmpty || files.containsKey(path)) return;
      final f = File(path);
      if (!await f.exists()) return;
      final entry = 'files/${files.length}_${p.basename(path)}';
      files[path] = entry;
      jobs.add([path, entry]);
      bytes += await f.length();
    }

    for (final pl in places) {
      await addFile(pl.coverLocalPath);
    }
    for (final s in stops) {
      await addFile(s.coverLocalPath);
    }
    for (final ph in photos) {
      await addFile(ph.localPath);
    }
    for (final f in frames) {
      await addFile(f.localPath);
    }
    final keptPhotos = [for (final ph in photos) if (files.containsKey(ph.localPath)) ph];

    return _Snapshot(
      contents: BackupContents(
        places: places.where((pl) => pl.visibility != 'trip_only').length,
        privateTrips: privateIds.length,
        photos: keptPhotos.length,
        frames: frames.length,
        bytes: bytes,
      ),
      payload: {
        'places': [for (final x in places) x.toJson()],
        'labels': [for (final x in labels) x.toJson()],
        'placeLabels': [for (final x in placeLabels) x.toJson()],
        'visits': [for (final x in visits) x.toJson()],
        'photos': [for (final x in keptPhotos) x.toJson()],
        'referenceImages': [for (final x in frames) x.toJson()],
        'trips': [for (final x in allTrips) if (privateIds.contains(x.id)) x.toJson()],
        'tripDays': [for (final x in days) x.toJson()],
        'stops': [for (final x in stops) x.toJson()],
        'stopLabels': [for (final x in stopLabels) x.toJson()],
        'scheduleItems': [for (final x in items) x.toJson()],
        'files': files,
      },
      files: jobs,
    );
  }

  Map<String, dynamic> _checkManifest(String? raw) {
    if (raw == null) throw const BackupFormatException("This file isn't a backup from this app.");
    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupFormatException("This file isn't a backup from this app.");
    }
    if (manifest['format'] != format) throw const BackupFormatException("This file isn't a backup from this app.");
    final v = (manifest['version'] as num?)?.toInt() ?? 0;
    if (v > version) {
      throw const BackupFormatException('This backup is from a newer version of the app. Update the app, then try again.');
    }
    if (v < version) {
      throw const BackupFormatException('This backup is from a test version of the app and can no longer be read.');
    }
    return manifest;
  }

  Future<Directory> _docsDir() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }
}

class _Snapshot {
  final BackupContents contents;
  final Map<String, dynamic> payload;

  /// [source path, entry name] for each file to zip.
  final List<List<String>> files;

  const _Snapshot({required this.contents, required this.payload, required this.files});
}
