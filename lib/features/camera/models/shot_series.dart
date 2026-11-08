import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// One shot of a [ShotSeries]: its file, inside the series' folder, and when
/// it came back from the camera.
class SeriesShot {
  final String path;
  final DateTime takenAt;

  const SeriesShot(this.path, this.takenAt);

  Map<String, Object?> toJson() => {'path': path, 'takenAt': takenAt.toIso8601String()};

  static SeriesShot? fromJson(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final takenAt = DateTime.tryParse('${json['takenAt']}');
    if (path is! String || takenAt == null) return null;
    return SeriesShot(path, takenAt);
  }
}

/// The shots taken against one frame, before the user picks the ones to
/// keep. Android may kill the app while the camera is open for one of them:
/// each series lives in its own folder with a `series.json`, so the next
/// launch finds it ([ShotSeriesStore.latest]) and opens the picker again.
class ShotSeries {
  final String id;

  /// The place the kept shots are saved to; null saves them to the phone's
  /// gallery only.
  final String? placeKey;

  /// The trip they're filed under; null lets the save find the trip that has
  /// the place on the day.
  final String? tripId;

  /// The frame they were shot against, and its id when it's one of a
  /// place's frames.
  final String? referencePath;
  final String? referenceImageId;

  final DateTime createdAt;
  final List<SeriesShot> shots;

  /// The paths of the shots the user has picked so far, so the picks
  /// survive Android killing the app too.
  final Set<String> kept;

  const ShotSeries({
    required this.id,
    required this.createdAt,
    this.placeKey,
    this.tripId,
    this.referencePath,
    this.referenceImageId,
    this.shots = const [],
    this.kept = const {},
  });

  ShotSeries withShots(List<SeriesShot> shots) => _copy(shots: shots);

  ShotSeries withKept(Iterable<String> kept) => _copy(kept: kept);

  ShotSeries _copy({List<SeriesShot>? shots, Iterable<String>? kept}) {
    final allShots = List<SeriesShot>.unmodifiable(shots ?? this.shots);
    final paths = {for (final shot in allShots) shot.path};
    return ShotSeries(
      id: id,
      createdAt: createdAt,
      placeKey: placeKey,
      tripId: tripId,
      referencePath: referencePath,
      referenceImageId: referenceImageId,
      shots: allShots,
      kept: Set.unmodifiable((kept ?? this.kept).where(paths.contains)),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'placeKey': placeKey,
        'tripId': tripId,
        'referencePath': referencePath,
        'referenceImageId': referenceImageId,
        'shots': [for (final shot in shots) shot.toJson()],
        'kept': kept.toList(),
      };

  static ShotSeries? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    if (id is! String || createdAt == null) return null;
    String? text(String key) => json[key] is String ? json[key] as String : null;
    final shots = json['shots'];
    final kept = json['kept'];
    return ShotSeries(
      id: id,
      createdAt: createdAt,
      placeKey: text('placeKey'),
      tripId: text('tripId'),
      referencePath: text('referencePath'),
      referenceImageId: text('referenceImageId'),
    ).withShots([
      if (shots is List)
        for (final shot in shots.map(SeriesShot.fromJson))
          if (shot != null) shot,
    ]).withKept([
      if (kept is List)
        for (final path in kept)
          if (path is String) path,
    ]);
  }
}

/// Keeps [ShotSeries] on disk: one folder per series under [root] (the app's
/// support folder, `shot_series/`), holding its shots and `series.json`.
class ShotSeriesStore {
  ShotSeriesStore({Future<Directory> Function()? root}) : _root = root ?? _defaultRoot;

  final Future<Directory> Function() _root;

  static Future<Directory> _defaultRoot() async =>
      Directory(p.join((await getApplicationSupportDirectory()).path, 'shot_series'));

  static const _file = 'series.json';
  static const _uuid = Uuid();

  Future<Directory> _folder(String id) async => Directory(p.join((await _root()).path, id));

  /// Starts an empty series and writes it, so it can be found again even
  /// before its first shot.
  Future<ShotSeries> create({
    String? placeKey,
    String? tripId,
    String? referencePath,
    String? referenceImageId,
    DateTime? now,
  }) async {
    final series = ShotSeries(
      id: _uuid.v4(),
      createdAt: now ?? DateTime.now(),
      placeKey: placeKey,
      tripId: tripId,
      referencePath: referencePath,
      referenceImageId: referenceImageId,
    );
    await _write(series);
    return series;
  }

  /// The series, without any shot whose file has gone missing.
  Future<ShotSeries?> load(String id) async {
    final file = File(p.join((await _folder(id)).path, _file));
    final ShotSeries? series;
    try {
      series = ShotSeries.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
    if (series == null) return null;
    final present = [
      for (final shot in series.shots)
        if (await File(shot.path).exists()) shot,
    ];
    return present.length == series.shots.length ? series : series.withShots(present);
  }

  /// Moves the camera's file at [sourcePath] into the series' folder, so it
  /// outlives the camera's temporary file, and records it.
  Future<ShotSeries> addShot(ShotSeries series, String sourcePath, {DateTime? takenAt}) async {
    final folder = await _folder(series.id);
    await folder.create(recursive: true);
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(folder.path, 'shot_${_uuid.v4()}$ext');
    final source = File(sourcePath);
    try {
      await source.rename(target);
    } on FileSystemException {
      // A different file system: copy, then drop the camera's copy.
      await source.copy(target);
      try {
        await source.delete();
      } catch (_) {}
    }
    final updated = series.withShots([...series.shots, SeriesShot(target, takenAt ?? DateTime.now())]);
    await _write(updated);
    return updated;
  }

  /// Records which shots the user has picked so far.
  Future<ShotSeries> saveKept(ShotSeries series, Iterable<String> kept) async {
    final updated = series.withKept(kept);
    await _write(updated);
    return updated;
  }

  /// Deletes the series with every shot still in it.
  Future<void> discard(String id) async {
    final folder = await _folder(id);
    try {
      if (await folder.exists()) await folder.delete(recursive: true);
    } catch (_) {
      // What's left only costs space; the next launch tries again.
    }
  }

  /// The most recently started series still on disk, if any. Folders that
  /// can't be read are deleted on the way.
  Future<ShotSeries?> latest() async {
    final root = await _root();
    if (!await root.exists()) return null;
    ShotSeries? newest;
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final series = await load(p.basename(entry.path));
      if (series == null) {
        await discard(p.basename(entry.path));
        continue;
      }
      if (newest == null || series.createdAt.isAfter(newest.createdAt)) newest = series;
    }
    return newest;
  }

  /// Writes `series.json` through a temporary file, so a kill mid-write
  /// leaves the previous version rather than half a file.
  Future<void> _write(ShotSeries series) async {
    final folder = await _folder(series.id);
    await folder.create(recursive: true);
    final temp = File(p.join(folder.path, '$_file.tmp'));
    await temp.writeAsString(jsonEncode(series.toJson()), flush: true);
    await temp.rename(p.join(folder.path, _file));
  }
}
