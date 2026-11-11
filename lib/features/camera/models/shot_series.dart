import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// One of the frames a series floats over the camera: the image on the
/// device, and its id when it's one of a place's frames (a reference picked
/// from the gallery has none).
class SeriesFrame {
  final String path;
  final String? imageId;

  const SeriesFrame(this.path, {this.imageId});

  Map<String, Object?> toJson() => {'path': path, 'imageId': imageId};

  static SeriesFrame? fromJson(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final imageId = json['imageId'];
    if (path is! String) return null;
    return SeriesFrame(path, imageId: imageId is String ? imageId : null);
  }

  @override
  bool operator ==(Object other) => other is SeriesFrame && other.path == path && other.imageId == imageId;

  @override
  int get hashCode => Object.hash(path, imageId);

  @override
  String toString() => 'SeriesFrame($path, $imageId)';
}

/// One shot of a [ShotSeries]: its file, inside the series' folder, when it
/// came back from the camera, and the frame that was floating then.
class SeriesShot {
  final String path;
  final DateTime takenAt;

  /// The frame showing in the floating window when the shot came back from
  /// the camera. Null in a series written before frames could be switched,
  /// which had one frame: the series' ([ShotSeries.frameOf] falls back to
  /// it).
  final SeriesFrame? frame;

  const SeriesShot(this.path, this.takenAt, {this.frame});

  Map<String, Object?> toJson() => {
        'path': path,
        'takenAt': takenAt.toIso8601String(),
        if (frame != null) 'referencePath': frame!.path,
        if (frame != null) 'referenceImageId': frame!.imageId,
      };

  static SeriesShot? fromJson(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final takenAt = DateTime.tryParse('${json['takenAt']}');
    if (path is! String || takenAt == null) return null;
    final framePath = json['referencePath'];
    final frameId = json['referenceImageId'];
    return SeriesShot(
      path,
      takenAt,
      frame: framePath is String ? SeriesFrame(framePath, imageId: frameId is String ? frameId : null) : null,
    );
  }
}

/// The shots taken in a row at one spot, before the user picks the ones to
/// keep. The camera opens again after every shot, so a series can take a
/// while, and Android may kill the app meanwhile: each series lives in its
/// own folder with a `series.json`, so the next launch finds it
/// ([ShotSeriesStore.latest]) and opens the picker again.
///
/// A spot can have several frames: the floating window switches between
/// [frames] in place, [frameIndex] is the one showing, and each shot
/// remembers the frame it was taken with.
class ShotSeries {
  final String id;

  /// The place the kept shots are saved to; null saves them to the phone's
  /// gallery only.
  final String? placeKey;

  /// The trip they're filed under; null lets the save find the trip that has
  /// the place on the day.
  final String? tripId;

  /// The frames to shoot against, in the order the place shows them; empty
  /// when shooting without a reference.
  final List<SeriesFrame> frames;

  /// The frame showing now, an index into [frames]; the camera reopens on it.
  final int frameIndex;

  final DateTime createdAt;
  final List<SeriesShot> shots;

  /// The paths of the shots the user has picked so far, so the picks
  /// survive Android killing the app too.
  final Set<String> kept;

  ShotSeries({
    required this.id,
    required this.createdAt,
    this.placeKey,
    this.tripId,
    List<SeriesFrame> frames = const [],
    int frameIndex = 0,
    this.shots = const [],
    this.kept = const {},
  })  : frames = List.unmodifiable(frames),
        frameIndex = frames.isEmpty ? 0 : frameIndex.clamp(0, frames.length - 1);

  /// The frame showing now; null without a reference.
  SeriesFrame? get frame => frames.isEmpty ? null : frames[frameIndex];

  String? get referencePath => frame?.path;
  String? get referenceImageId => frame?.imageId;

  /// The frame [shot] was taken with.
  SeriesFrame? frameOf(SeriesShot shot) => shot.frame ?? (frames.isEmpty ? null : frames.first);

  ShotSeries withShots(List<SeriesShot> shots) => _copy(shots: shots);

  /// Adds a shot taken with the frame showing now.
  ShotSeries withShot(String path, DateTime takenAt) =>
      _copy(shots: [...shots, SeriesShot(path, takenAt, frame: frame)]);

  ShotSeries withKept(Iterable<String> kept) => _copy(kept: kept);

  ShotSeries withFrameIndex(int index) => _copy(frameIndex: index);

  ShotSeries _copy({List<SeriesShot>? shots, Iterable<String>? kept, int? frameIndex}) {
    final allShots = List<SeriesShot>.unmodifiable(shots ?? this.shots);
    final paths = {for (final shot in allShots) shot.path};
    return ShotSeries(
      id: id,
      createdAt: createdAt,
      placeKey: placeKey,
      tripId: tripId,
      frames: frames,
      frameIndex: frameIndex ?? this.frameIndex,
      shots: allShots,
      kept: Set.unmodifiable((kept ?? this.kept).where(paths.contains)),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'placeKey': placeKey,
        'tripId': tripId,
        // The frame showing, where files from before frame switching kept
        // their one frame.
        'referencePath': referencePath,
        'referenceImageId': referenceImageId,
        'frames': [for (final frame in frames) frame.toJson()],
        'frameIndex': frameIndex,
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
    final frameList = json['frames'];
    final frameIndex = json['frameIndex'];
    var frames = <SeriesFrame>[
      if (frameList is List)
        for (final frame in frameList.map(SeriesFrame.fromJson))
          if (frame != null) frame,
    ];
    // A file from before frame switching: one frame, the series' reference.
    final legacyPath = text('referencePath');
    if (frames.isEmpty && legacyPath != null) {
      frames = [SeriesFrame(legacyPath, imageId: text('referenceImageId'))];
    }
    return ShotSeries(
      id: id,
      createdAt: createdAt,
      placeKey: text('placeKey'),
      tripId: text('tripId'),
      frames: frames,
      frameIndex: frameIndex is int ? frameIndex : 0,
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
  /// before its first shot. The camera starts on [frames]' [frameIndex].
  Future<ShotSeries> create({
    String? placeKey,
    String? tripId,
    List<SeriesFrame> frames = const [],
    int frameIndex = 0,
    DateTime? now,
  }) async {
    final series = ShotSeries(
      id: _uuid.v4(),
      createdAt: now ?? DateTime.now(),
      placeKey: placeKey,
      tripId: tripId,
      frames: frames,
      frameIndex: frameIndex,
    );
    await save(series);
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
  /// outlives the camera's temporary file, and records it with the frame
  /// showing now.
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
    final updated = series.withShot(target, takenAt ?? DateTime.now());
    await save(updated);
    return updated;
  }

  /// Records which shots the user has picked so far.
  Future<ShotSeries> saveKept(ShotSeries series, Iterable<String> kept) async {
    final updated = series.withKept(kept);
    await save(updated);
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
  /// leaves the previous version rather than half a file. One write at a
  /// time per series: the caller waits for the last before the next.
  Future<void> save(ShotSeries series) async {
    final folder = await _folder(series.id);
    await folder.create(recursive: true);
    final temp = File(p.join(folder.path, '$_file.tmp'));
    await temp.writeAsString(jsonEncode(series.toJson()), flush: true);
    await temp.rename(p.join(folder.path, _file));
  }
}
