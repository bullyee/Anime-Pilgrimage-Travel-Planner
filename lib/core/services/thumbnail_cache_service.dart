import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service responsible for downloading, deduplicating, and locally caching
/// reference image thumbnails on disk for offline use.
class ThumbnailCacheService {
  final http.Client _client;
  final Directory? _overrideCacheDir; // For testing
  final Map<String, Future<String?>> _inFlightFetches = {};

  ThumbnailCacheService({
    http.Client? client,
    Directory? overrideCacheDir,
  })  : _client = client ?? http.Client(),
        _overrideCacheDir = overrideCacheDir;

  /// Returns a deterministic cache file path for the given [url].
  Future<File> getCacheFile(String url) async {
    final dir = _overrideCacheDir ?? await getApplicationCacheDirectory();
    final thumbDir = Directory(p.join(dir.path, 'reference_thumbnails'));
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }

    final hash = md5.convert(utf8.encode(url)).toString();
    final ext = _extensionFromUrl(url);
    final filePath = p.join(thumbDir.path, '$hash$ext');
    return File(filePath);
  }

  /// Get a cached local file path for [url].
  /// If already downloaded, returns local path immediately.
  /// If not, downloads and caches the file, then returns the path.
  /// Returns null if offline or download fails.
  Future<String?> getOrFetchThumbnail(String url) async {
    if (url.trim().isEmpty) return null;

    final targetFile = await getCacheFile(url);
    if (await targetFile.exists()) {
      return targetFile.path;
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
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      await targetFile.writeAsBytes(response.bodyBytes, flush: true);
      return targetFile.path;
    } catch (e) {
      debugPrint('[ThumbnailCacheService] Failed to cache thumbnail for $url: $e');
      return null;
    }
  }

  /// Prefetch multiple thumbnails in parallel with bounded concurrency.
  Future<void> prefetchThumbnails(List<String> urls, {int concurrency = 4}) async {
    final queue = List<String>.from(urls.where((u) => u.trim().isNotEmpty));
    if (queue.isEmpty) return;

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final url = queue.removeLast();
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
      final dir = _overrideCacheDir ?? await getApplicationCacheDirectory();
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
      final dir = _overrideCacheDir ?? await getApplicationCacheDirectory();
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

