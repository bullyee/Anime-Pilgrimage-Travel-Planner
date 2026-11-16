import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'anitabi_web_cache.dart';

/// One Anitabi work from the static map data.
class AnitabiStaticWork {
  /// Original (usually Japanese) title, falling back to the Chinese one.
  final String? title;

  /// Spots shaped like the open API's `/points/detail` rows — `id`, `name`,
  /// `cn`, `image`, `ep`, `s`, `geo`, `origin`, `originURL`, plus `mark`
  /// (the contributor's note) — so the importer can treat both alike.
  final List<Map<String, dynamic>> spots;

  const AnitabiStaticWork({required this.title, required this.spots});
}

/// Thrown when no static-data host answered with usable data.
class AnitabiStaticDataUnavailableException implements Exception {
  /// True when a host refused with HTTP 403/429 (Cloudflare blocking this
  /// network) rather than failing outright.
  final bool blocked;

  const AnitabiStaticDataUnavailableException({this.blocked = false});
  @override
  String toString() =>
      'AnitabiStaticDataUnavailableException(blocked: $blocked)';
}

/// Anitabi's full static map data — the files its website and its own iOS
/// app draw the map from: `g.json` (every work plus every spot's
/// coordinates) and `g0.json … gN.json` (spot details, `pageSize` works per
/// page, in index order).
///
/// The open API stopped returning spot coordinates in 2026, so this is the
/// only source that still has them. It isn't part of Anitabi's documented
/// API, so it is fetched sparingly: the index at most once per
/// [indexMaxAge], each detail page once per index version, all cached on
/// disk and sent through the caller's identifying client.
///
/// The approach follows MiriaGo (https://github.com/BilyHurington/MiriaGo,
/// MIT — see THIRD_PARTY_NOTICES.md).
class AnitabiStaticData {
  /// Hosts serving the data, tried in order. `www.anitabi.cn` stopped
  /// answering in Aug 2026; Anitabi's iOS app lists the same mirrors.
  static const List<String> defaultBaseUrls = [
    'https://w.junreimap.com/d',
    'https://ww.anitabi.cn/d',
    'https://www.anitabi.cn/d',
  ];
  static const Duration indexMaxAge = Duration(hours: 24);
  static const Duration _timeout = Duration(seconds: 60);

  /// Index into [baseUrls] of the host that last answered, so later
  /// downloads in this process skip hosts known to be dead.
  static int _preferredBase = 0;

  // In-memory cache used on Web where local filesystem caching is unavailable.
  static ({DateTime at, String body})? _memIndex;
  static final Map<String, String> _memPages = {};

  final http.Client client;
  final Future<Directory> Function() cacheDir;
  final List<String> baseUrls;
  final DateTime Function() _now;

  AnitabiStaticData({
    required this.client,
    required this.cacheDir,
    this.baseUrls = defaultBaseUrls,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @visibleForTesting
  static void resetPreferredHost() {
    _preferredBase = 0;
    _memIndex = null;
    _memPages.clear();
  }

  /// The work for [bangumiId] with its spots, or null when Anitabi has no
  /// such work. Throws [AnitabiStaticDataUnavailableException] when the data
  /// can't be fetched and nothing usable is cached.
  Future<AnitabiStaticWork?> work(String bangumiId) async {
    final id = int.tryParse(bangumiId);
    if (id == null) return null;
    final dir = kIsWeb ? null : await cacheDir();

    final indexBody = await _index(dir);
    final located = await compute(_locateWork, [indexBody, id]);
    if (located == null) return null;
    final (:workIndex, :workCount, :pageSize, :version, :title, :coords) =
        located;

    // Works are paged in index order, so the guess is normally right; scan
    // the other pages only if Anitabi reshuffled them.
    final pageCount = (workCount / pageSize).ceil();
    final guess = workIndex ~/ pageSize;
    for (final page in [
      guess,
      for (var i = 0; i < pageCount; i++)
        if (i != guess) i,
    ]) {
      final pageBody = await _page(dir, page, version);
      final rows = await compute(_workRows, [pageBody, id]);
      if (rows == null) continue;
      return AnitabiStaticWork(
        title: title,
        spots: [
          for (final row in rows) _spot(id, row, coords),
        ],
      );
    }
    return AnitabiStaticWork(title: title, spots: const []);
  }

  Future<String> _index(Directory? dir) async {
    if (dir == null) {
      final cached = _memIndex;
      if (cached != null && _now().difference(cached.at) < indexMaxAge) {
        return cached.body;
      }
      final webCachedBody = await AnitabiWebCache.get('g.json');
      final webCachedAt = await AnitabiWebCache.timestamp('g.json');
      if (webCachedBody != null && webCachedAt != null && _now().difference(webCachedAt) < indexMaxAge) {
        _memIndex = (at: webCachedAt, body: webCachedBody);
        return webCachedBody;
      }
      try {
        final body = await _download('g.json');
        final now = _now();
        _memIndex = (at: now, body: body);
        await AnitabiWebCache.put('g.json', body, now);
        return body;
      } on AnitabiStaticDataUnavailableException {
        if (cached != null) return cached.body;
        if (webCachedBody != null) return webCachedBody;
        rethrow;
      }
    }
    final file = File(p.join(dir.path, 'g.json'));
    if (await file.exists() &&
        _now().difference(await file.lastModified()) < indexMaxAge) {
      return file.readAsString();
    }
    try {
      final body = await _download('g.json');
      await file.writeAsString(body, flush: true);
      return body;
    } on AnitabiStaticDataUnavailableException {
      // A day-old index beats no import at all.
      if (await file.exists()) return file.readAsString();
      rethrow;
    }
  }

  /// Detail pages are cached per index version (`g1.<version>.json`), so a
  /// newer index re-fetches them once and older copies are dropped.
  Future<String> _page(Directory? dir, int page, String version) async {
    if (dir == null) {
      final key = '$page.$version';
      final cached = _memPages[key];
      if (cached != null) return cached;
      final webCached = await AnitabiWebCache.get(key);
      if (webCached != null) {
        _memPages[key] = webCached;
        return webCached;
      }
      final body = await _download('g$page.json');
      _memPages.removeWhere((k, _) => k.startsWith('$page.'));
      _memPages[key] = body;
      await AnitabiWebCache.put(key, body, _now());
      return body;
    }
    final file = File(p.join(dir.path, 'g$page.$version.json'));
    if (await file.exists()) return file.readAsString();
    final body = await _download('g$page.json');
    await for (final old in dir.list()) {
      final name = p.basename(old.path);
      if (old is File && name.startsWith('g$page.') && name.endsWith('.json')) {
        await old.delete();
      }
    }
    await file.writeAsString(body, flush: true);
    return body;
  }

  Future<String> _download(String fileName) async {
    var blocked = false;
    for (var i = 0; i < baseUrls.length; i++) {
      final index = (_preferredBase + i) % baseUrls.length;
      try {
        final response = await client
            .get(Uri.parse('${baseUrls[index]}/$fileName'))
            .timeout(_timeout);
        if (response.statusCode == 403 || response.statusCode == 429) {
          blocked = true;
          continue;
        }
        if (response.statusCode != 200) continue;
        final body = utf8.decode(response.bodyBytes);
        // A landing or error page in place of the data means this host no
        // longer serves it.
        final start = body.trimLeft();
        if (!start.startsWith('[') && !start.startsWith('{')) continue;
        _preferredBase = index;
        return body;
      } catch (e) {
        debugPrint('[AnitabiStaticData] ${baseUrls[index]}/$fileName: $e');
      }
    }
    throw AnitabiStaticDataUnavailableException(blocked: blocked);
  }

  static Map<String, dynamic> _spot(
    int bangumiId,
    List<dynamic> row,
    Map<String, List<double>> coords,
  ) {
    final id = row[0].toString();
    return {
      'id': id,
      'name': _text(_at(row, 1)),
      'cn': _text(_at(row, 2)),
      'image': _imageUrl(_text(_at(row, 6))),
      'ep': _text(_at(row, 8)),
      's': _at(row, 9),
      'geo': coords[id],
      'mark': _text(_at(row, 10)),
      'origin': _text(_at(row, 11)) ?? 'Anitabi',
      'originURL': _text(_at(row, 12)) ??
          'https://anitabi.cn/map?bangumiId=$bangumiId&pid=$id',
    };
  }

  static dynamic _at(List<dynamic> row, int i) => i < row.length ? row[i] : null;

  /// The data writes absent values as `0`, `false`, or `''`.
  static String? _text(dynamic value) {
    if (value == null || value == 0 || value == false) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Image paths are `/images/<path>` on Anitabi's image host. Thumbnail
  /// size, as the open API returns them.
  static String? _imageUrl(String? path) {
    if (path == null) return null;
    if (path.startsWith('/images/')) {
      return 'https://image.anitabi.cn${path.substring('/images'.length)}'
          '?plan=h160';
    }
    return path.startsWith('https://') ? path : null;
  }
}

/// Runs off the UI isolate: the index is ~2 MB of JSON, and only one work
/// of it is needed. Index layout: `[works, pageSize, version]`; a work is
/// `[0]` bangumi id, `[1]` Chinese title, `[3]` original title, `[12]` its
/// spots as a flat `[id, lat, lng, priority, …]` list.
({
  int workIndex,
  int workCount,
  int pageSize,
  String version,
  String? title,
  Map<String, List<double>> coords,
})? _locateWork(List<Object> args) {
  final index = jsonDecode(args[0] as String) as List<dynamic>;
  final id = args[1] as int;
  final works = index[0] as List<dynamic>;
  for (var i = 0; i < works.length; i++) {
    final work = works[i];
    if (work is! List || work.isEmpty || work[0] != id) continue;
    final coords = <String, List<double>>{};
    final flat = work.length > 12 && work[12] is List
        ? work[12] as List<dynamic>
        : const [];
    for (var j = 0; j + 2 < flat.length; j += 4) {
      final lat = flat[j + 1];
      final lng = flat[j + 2];
      if (lat is num && lng is num && (lat != 0 || lng != 0)) {
        coords[flat[j].toString()] = [lat.toDouble(), lng.toDouble()];
      }
    }
    String? text(int k) {
      final v = k < work.length ? work[k] : null;
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return (
      workIndex: i,
      workCount: works.length,
      pageSize: (index[1] as num).toInt(),
      version: index.length > 2 ? index[2].toString() : '0',
      title: text(3) ?? text(1),
      coords: coords,
    );
  }
  return null;
}

/// A detail page is a list of `[bangumiId, …, spotRows, modified]`.
List<dynamic>? _workRows(List<Object> args) {
  final page = jsonDecode(args[0] as String) as List<dynamic>;
  final id = args[1] as int;
  for (final entry in page) {
    if (entry is List && entry.length > 2 && entry[0] == id) {
      return (entry[2] as List<dynamic>).whereType<List<dynamic>>().toList();
    }
  }
  return null;
}
