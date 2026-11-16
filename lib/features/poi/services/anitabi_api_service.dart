import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:trip_planner/core/utils/image_storage.dart';

/// Thrown when Anitabi can't be reached (network error or repeated
/// timeouts), as distinct from a subject that simply has no POIs. Lets the
/// UI tell "check your connection" apart from "this anime has none".
class AnitabiUnavailableException implements Exception {
  final String message;

  /// True when Anitabi's Cloudflare front refused the request (HTTP 403 or
  /// 429): this network's IP is temporarily blocked, so "check your
  /// connection" would mislead and retrying right away prolongs the block.
  final bool blocked;

  const AnitabiUnavailableException({
    this.message = 'Anitabi is unreachable',
    this.blocked = false,
  });
  @override
  String toString() => 'AnitabiUnavailableException: $message';
}

/// How the app talks to Anitabi: who it says it is, and how it downloads
/// images. The import's data comes from `AnitabiStaticData`.
class AnitabiApiService {
  /// Sent on every Anitabi request, cover downloads included. Anitabi's
  /// maintainers ask clients to identify themselves; anonymous library UAs
  /// look like scrapers to their Cloudflare rules.
  static const String userAgent =
      'trip_planner (+https://github.com/bullyee/trip_planner)';

  /// A client that sends [userAgent] on every request, as Anitabi asks.
  static http.Client identifiedClient([http.Client? inner]) => _UserAgentClient(inner ?? http.Client());

  /// Where Anitabi's static map data is cached.
  static Future<Directory> staticDataCacheDir() => _defaultCacheDir();

  /// Downloads an Anitabi image into the app's reference images, trying the
  /// image mirror when the official host refuses. Null when neither works;
  /// it never retries a refusal.
  static Future<String?> downloadReferenceImage(String url, http.Client client) async {
    if (kIsWeb) return null;
    return await downloadCoverImage(url, subdir: 'reference_images', client: client) ??
        await _downloadFromImageMirror(url, client);
  }

  static Future<Directory> _defaultCacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'anitabi_static'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Anitabi's image mirror. The official image host sits behind the same
  /// Cloudflare block as the rest of Anitabi, so a refused cover is retried
  /// here; the reference image keeps the official URL either way.
  static const String _imageMirrorHost = 'img-tc.anitabi.cn';

  static Future<String?> _downloadFromImageMirror(
    String url,
    http.Client client,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'image.anitabi.cn') return null;
    return downloadCoverImage(
      uri.replace(host: _imageMirrorHost).toString(),
      subdir: 'reference_images',
      client: client,
    );
  }
}

/// Stamps every request with [AnitabiApiService.userAgent]: the data
/// downloads and the image downloads that share the client.
class _UserAgentClient extends http.BaseClient {
  final http.Client _inner;

  _UserAgentClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Browsers forbid setting custom User-Agent headers on XHR/fetch requests.
    if (!kIsWeb) request.headers['User-Agent'] = AnitabiApiService.userAgent;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
