import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/place_diff.dart';

/// The differences the user answered with **Keep mine**, so their hint
/// doesn't come back. Each is remembered with the other side's value at the
/// time: if that side changes again, the difference shows again.
///
/// Kept on the device only; it is the user's own choice, like My note.
class PlaceCompareKept {
  const PlaceCompareKept._();

  /// Anitabi against a library place ([PlaceDiff.placeKey]).
  static const anitabi = 'anitabi';

  /// The library against a trip's stop (the stop's id).
  static const library = 'library';

  static String key(String kind, String entityId, PlaceFieldType field) => '$kind|$entityId|${field.name}';

  /// [diff] without the differences kept under [kind] for [entityId], or
  /// null when none is left. [otherValue] picks the other side's value from
  /// a difference.
  static PlaceDiff? withoutKept(
    PlaceDiff? diff,
    Map<String, String> kept, {
    required String kind,
    required String entityId,
    required String? Function(PlaceFieldDiff d) otherValue,
  }) {
    if (diff == null) return null;
    final left = [
      for (final d in diff.differences)
        if (kept[key(kind, entityId, d.field)] != (otherValue(d) ?? '')) d,
    ];
    if (left.isEmpty) return null;
    return PlaceDiff(
      placeKey: diff.placeKey,
      localName: diff.localName,
      remoteName: diff.remoteName,
      targetEntityId: diff.targetEntityId,
      targetSource: diff.targetSource,
      differences: left,
    );
  }
}

/// Where the kept differences are stored.
abstract class PlaceCompareKeptStore {
  Future<Map<String, String>> read();
  Future<void> write(Map<String, String> kept);
}

/// A small JSON file in the app's support folder.
class FilePlaceCompareKeptStore implements PlaceCompareKeptStore {
  FilePlaceCompareKeptStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File(p.join((await _directory()).path, 'place_compare_kept.json'));

  @override
  Future<Map<String, String>> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      final json = jsonDecode(await f.readAsString());
      return json is Map ? {for (final e in json.entries) '${e.key}': '${e.value}'} : {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> write(Map<String, String> kept) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(kept), flush: true);
  }
}

/// For tests and the web, where nothing is written to files.
class InMemoryPlaceCompareKeptStore implements PlaceCompareKeptStore {
  InMemoryPlaceCompareKeptStore([Map<String, String>? kept]) : kept = {...?kept};

  final Map<String, String> kept;

  @override
  Future<Map<String, String>> read() async => {...kept};

  @override
  Future<void> write(Map<String, String> value) async {
    kept
      ..clear()
      ..addAll(value);
  }
}
