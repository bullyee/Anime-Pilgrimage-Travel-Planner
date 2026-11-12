import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/poi/services/anitabi_api_service.dart';

/// Service responsible for downloading, deduplicating, and locally caching
/// reference image thumbnails on disk for offline use.
///
/// Follows the Anitabi rules in `CLAUDE.md`:
/// - Sends [AnitabiApiService.userAgent] on every request.
/// - Never retries after receiving HTTP 403 or 429 (`isRateLimitedOrBlocked`).
/// - Keeps downloads sequential and rare (default concurrency = 1).
class ThumbnailCacheService {
  final http.Client _client;
  final Directory? _overrideCacheDir; // For testing
  final Map<String, Future<String?>> _inFlightFetches = {};

  /// Set to `true` when any request receives HTTP 403 or 429 so we stop issuing
  /// further network requests rather than hammering a rate-limited/blocked host.
  bool _isRateLimitedOrBlocked = false;

  bool get isRateLimitedOrBlocked => _isRateLimitedOrBlocked;

  ThumbnailCacheService({
    http.Client? client,
    Directory? overrideCacheDir,
  })  : _client = client ?? http.Client(),
        _overrideCacheDir = overrideCacheDir;

  static const Map<String, String> _headers = {
    'User-Agent': AnitabiApiService.userAgent,
  };

  /// Resets the blocked state (e.g. when user manually retries later).
  void resetBlockedState() {
    _isRateLimitedOrBlocked = false;
  }

  /// Returns a deterministic cache file path for the given [url].
  Future<File> getCacheFile(String url) async {
    final dir = _overrideCacheDir ?? await getApplicationSupportDirectory();
    final thumbDir = Directory(p.join(dir.path, 'reference_thumbnails'));
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }

    final hash = md5.convert(utf8.encode(url)).toString();
    final ext = _extensionFromUrl(url);
    final filePath = p.join(thumbDir.path, '$hash$ext');
    return File(filePath);
  }

  /// Get a cached local [File] for [url], downloading and caching if needed.
  /// Returns null if offline, blocked (403/429), or download fails.
  Future<File?> getThumbnail(String url) async {
    final path = await getOrFetchThumbnail(url);
    return path != null ? File(path) : null;
  }

  /// Get a cached local file path for [url].
  /// If already downloaded, returns local path immediately.
  /// If not, downloads and caches the file, then returns the path.
  /// Returns null if offline, blocked (403/429), or download fails.
  Future<String?> getOrFetchThumbnail(String url) async {
    if (url.trim().isEmpty) return null;

    final targetFile = await getCacheFile(url);
    if (await targetFile.exists()) {
      return targetFile.path;
    }

    if (_isRateLimitedOrBlocked) {
      return null;
    }

    // Deduplicate in-flight requests for the same URL
    if (_inFlightFetches.containsKey(url)) {
      return _inFlightFetches[url];
    }

    final fetchFuture = _downloadAndSave(url, targetFile);
    _inFlightFetches[url] = fetchFuture;

    try {
      final result = await fetchFuture;
      return result;
    } finally {
      _inFlightFetches.remove(url);
    }
  }

  Future<String?> _downloadAndSave(String url, File targetFile) async {
    for (final candidate in _imageCandidates(url)) {
      final isAnitabi = candidate.contains('anitabi.cn');
      if (isAnitabi && _isRateLimitedOrBlocked) return null;
      try {
        final response = await _client
            .get(Uri.parse(candidate), headers: _headers)
            .timeout(const Duration(seconds: 15));

        // Never retry on 403 or 429 for Anitabi endpoints per CLAUDE.md
        if (response.statusCode == 403 || response.statusCode == 429) {
          if (isAnitabi) {
            _isRateLimitedOrBlocked = true;
            debugPrint(
              '[ThumbnailCacheService] Received HTTP ${response.statusCode} for $candidate; halting Anitabi thumbnail downloads.',
            );
            return null;
          }
          continue;
        }

        final contentType = response.headers['content-type']?.toLowerCase() ?? '';
        if (contentType.startsWith('text/html')) {
          debugPrint('[ThumbnailCacheService] Skipping non-image HTML response for $candidate');
          continue;
        }

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final tempFile = File('${targetFile.path}.tmp');
          await tempFile.writeAsBytes(response.bodyBytes, flush: true);
          await tempFile.rename(targetFile.path);
          return targetFile.path;
        }
      } catch (e) {
        debugPrint('[ThumbnailCacheService] Failed to cache thumbnail for $candidate: $e');
      }
    }
    return null;
  }

  static List<String> _imageCandidates(String url) {
    const primary = 'https://image.anitabi.cn/';
    const mirror = 'https://img-tc.anitabi.cn/';
    if (url.startsWith(primary)) {
      return [url, mirror + url.substring(primary.length)];
    }
    final driveId = extractGoogleDriveFileId(url);
    if (driveId != null) {
      return [
        'https://drive.google.com/uc?export=download&id=$driveId',
        'https://lh3.googleusercontent.com/d/$driveId=w1280',
      ];
    }
    return [url];
  }

  /// Extracts a Google Drive file ID from supported share/download URLs, or null.
  static String? extractGoogleDriveFileId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (uri.host == 'drive.google.com') {
      final qId = uri.queryParameters['id'];
      if (qId != null && qId.isNotEmpty) return qId;
      final segs = uri.pathSegments;
      final dIndex = segs.indexOf('d');
      if (dIndex >= 0 && dIndex + 1 < segs.length && segs[dIndex + 1].isNotEmpty) {
        return segs[dIndex + 1];
      }
    }
    if (uri.host == 'lh3.googleusercontent.com' && uri.pathSegments.length >= 2 && uri.pathSegments.first == 'd') {
      final raw = uri.pathSegments[1];
      final eq = raw.indexOf('=');
      return eq > 0 ? raw.substring(0, eq) : raw;
    }
    return null;
  }

  /// Prefetch multiple thumbnails sequentially by default (concurrency = 1)
  /// to keep Anitabi image requests rare and gentle. Stops immediately if
  /// HTTP 403 or 429 is encountered.
  Future<void> prefetchThumbnails(List<String> urls, {int concurrency = 1}) async {
    final queue = List<String>.from(urls.where((u) => u.trim().isNotEmpty));
    if (queue.isEmpty) return;

    Future<void> worker() async {
      while (queue.isNotEmpty && !_isRateLimitedOrBlocked) {
        final url = queue.removeAt(0);
        await getOrFetchThumbnail(url);
      }
    }

    final workers = List.generate(
      concurrency.clamp(1, queue.length),
      (_) => worker(),
    );

    await Future.wait(workers);
  }

  /// Calculate total size of cached thumbnails in bytes.
  Future<int> getCacheSizeBytes() async {
    try {
      final dir = _overrideCacheDir ?? await getApplicationSupportDirectory();
      final thumbDir = Directory(p.join(dir.path, 'reference_thumbnails'));
      if (!await thumbDir.exists()) return 0;

      int total = 0;
      await for (final entity in thumbDir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Clear the thumbnail cache from disk.
  Future<void> clearCache() async {
    try {
      final dir = _overrideCacheDir ?? await getApplicationSupportDirectory();
      final thumbDir = Directory(p.join(dir.path, 'reference_thumbnails'));
      if (await thumbDir.exists()) {
        await thumbDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  static String _extensionFromUrl(String url) {
    try {
      final pathOnly = Uri.parse(url).path;
      final ext = p.extension(pathOnly).toLowerCase();
      const known = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};
      if (known.contains(ext)) return ext;
    } catch (_) {}
    return '.jpg';
  }
}
