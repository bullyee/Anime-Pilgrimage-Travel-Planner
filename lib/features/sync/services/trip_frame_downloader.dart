import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/services/thumbnail_cache_service.dart';
import '../../../core/utils/archive_isolate.dart';

/// What a frames download did.
class FrameDownloadSummary {
  final int downloaded;
  final int failed;

  /// Anitabi images not tried because Anitabi refused (403/429) earlier: the
  /// cache stops asking it, by the rules in CLAUDE.md.
  final int skippedBlocked;

  const FrameDownloadSummary({required this.downloaded, required this.failed, required this.skippedBlocked});

  String get text {
    final parts = <String>[
      downloaded == 0
          ? 'No frames downloaded.'
          : 'Downloaded $downloaded ${downloaded == 1 ? 'frame' : 'frames'} for offline.',
      if (failed > 0) "$failed ${failed == 1 ? "frame couldn't" : "frames couldn't"} be downloaded.",
      if (skippedBlocked > 0)
        'Anitabi is refusing requests for now, so $skippedBlocked of its ${skippedBlocked == 1 ? 'image was' : 'images were'} skipped.',
    ];
    return parts.join(' ');
  }
}

/// Whether [url] is one of Anitabi's image hosts.
bool isAnitabiUrl(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host == 'anitabi.cn' || host.endsWith('.anitabi.cn');
}

/// Whether [url] is a Google Drive / googleusercontent link.
bool isGoogleDriveUrl(String url) => ThumbnailCacheService.extractGoogleDriveFileId(url) != null;

typedef DownloadSleep = Future<void> Function(Duration delay);

/// Brings a trip's linked frames (a stop frame with a `remoteUrl` and no file
/// on this phone) into the thumbnail cache, so the trip works offline.
///
/// All requests go through [ThumbnailCacheService], so its Anitabi rules hold:
/// its User-Agent, one request at a time, and no request at all to Anitabi
/// once it answered 403/429. Only Google Drive links get retried here, after
/// a failure, with backoff.
class TripFrameDownloader {
  final ThumbnailCacheService cache;
  final DownloadSleep _sleep;
  final List<Duration> driveRetryDelays;

  TripFrameDownloader(
    this.cache, {
    DownloadSleep? sleep,
    this.driveRetryDelays = const [Duration(seconds: 3), Duration(seconds: 10)],
  }) : _sleep = sleep ?? Future<void>.delayed;

  /// The links on [tripId]'s live stops that aren't on this phone yet, in
  /// stop order, each once. [include] narrows them (e.g. Drive links only).
  Future<List<String>> pendingUrls(AppDatabase db, String tripId, {bool Function(String url)? include}) async {
    final stops =
        await (db.select(db.stops)
              ..where((s) => s.tripId.equals(tripId) & s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
            .get();
    if (stops.isEmpty) return const [];
    final order = {for (var i = 0; i < stops.length; i++) stops[i].id: i};
    final frames = await (db.select(db.newReferenceImages)..where((r) => r.stopId.isIn(order.keys))).get();
    frames.sort((a, b) => (order[a.stopId] ?? 0).compareTo(order[b.stopId] ?? 0));

    final seen = <String>{};
    final urls = <String>[];
    for (final f in frames) {
      final url = f.remoteUrl?.trim() ?? '';
      if (url.isEmpty || !seen.add(url)) continue;
      if (include != null && !include(url)) continue;
      final local = f.localPath;
      if (local != null && local.isNotEmpty && await File(local).exists()) continue;
      if (await (await cache.getCacheFile(url)).exists()) continue;
      urls.add(url);
    }
    return urls;
  }

  /// Downloads [urls] one at a time, reporting progress and stopping at
  /// [cancel] between frames.
  Future<FrameDownloadSummary> download(List<String> urls, {BackupProgress? onProgress, BackupCancel? cancel}) async {
    var downloaded = 0;
    var failed = 0;
    var skippedBlocked = 0;
    var done = 0;
    onProgress?.call(0, urls.length);
    for (final url in urls) {
      if (cancel?.isCancelled ?? false) throw const BackupCancelled();
      final anitabi = isAnitabiUrl(url);
      if (anitabi && cache.isRateLimitedOrBlocked) {
        skippedBlocked++;
      } else {
        var path = await cache.getOrFetchThumbnail(url);
        // Drive only: a dropped connection is worth another try. Never
        // Anitabi (no retries there, especially not after 403/429).
        if (path == null && !anitabi && isGoogleDriveUrl(url)) {
          for (final delay in driveRetryDelays) {
            if (cancel?.isCancelled ?? false) throw const BackupCancelled();
            await _sleep(delay);
            if (cancel?.isCancelled ?? false) throw const BackupCancelled();
            path = await cache.getOrFetchThumbnail(url);
            if (path != null) break;
          }
        }
        if (path != null) {
          downloaded++;
        } else if (anitabi && cache.isRateLimitedOrBlocked) {
          skippedBlocked++;
        } else {
          failed++;
        }
      }
      done++;
      onProgress?.call(done, urls.length);
    }
    return FrameDownloadSummary(downloaded: downloaded, failed: failed, skippedBlocked: skippedBlocked);
  }
}
