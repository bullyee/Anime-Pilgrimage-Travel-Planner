import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/thumbnail_cache_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trip/services/trip_frames_pack_service.dart';
import '../services/frame_transfer_jobs.dart';
import '../services/frame_transfer_queue.dart';
import '../services/google_drive_frame_service.dart';
import '../services/transfer_foreground_service.dart';
import '../services/trip_frame_downloader.dart';

final tripFramesPackServiceProvider = Provider<TripFramesPackService>((ref) => const TripFramesPackService());

final googleDriveFrameServiceProvider = Provider<GoogleDriveFrameService>((ref) {
  ref.watch(currentUserIdProvider);
  return GoogleDriveFrameService(getToken: ref.watch(driveAccessTokenProvider));
});

final tripFrameDownloaderProvider = Provider<TripFrameDownloader>(
  (ref) => TripFrameDownloader(ref.watch(thumbnailCacheServiceProvider)),
);

/// Fires whenever a trip's stops or frames change.
Stream<void> _framesChanged(AppDatabase db) =>
    db.tableUpdates(TableUpdateQuery.onAllTables([db.newReferenceImages, db.stops])).map((_) {});

Stream<T> _recountOnChange<T>(AppDatabase db, Future<T> Function() count) async* {
  yield await count();
  await for (final _ in _framesChanged(db)) {
    yield await count();
  }
}

/// How many of [tripId]'s frames are only on this phone (no Drive link yet).
final pendingDriveUploadCountProvider = StreamProvider.autoDispose.family<int, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  final drive = ref.watch(googleDriveFrameServiceProvider);
  return _recountOnChange(db, () => drive.countTripLocalFrames(db, tripId));
});

/// How many of [tripId]'s linked frames aren't on this phone yet.
final pendingFrameDownloadCountProvider = StreamProvider.autoDispose.family<int, String>((ref, tripId) {
  final db = ref.watch(databaseProvider);
  final downloader = ref.watch(tripFrameDownloaderProvider);
  // Recount whenever a transfer job for this trip finishes or changes queue status.
  ref.watch(frameTransferQueueProvider.select((q) => q.jobsForTrip(tripId).length));
  return _recountOnChange(db, () async => (await downloader.pendingUrls(db, tripId)).length);
});

/// After a sync pull brings frames a teammate put on Drive to a shared trip,
/// downloads them for offline in the background, on an unmetered network.
///
/// Drive links only: Anitabi images load as they're viewed, as before, so
/// this never adds Anitabi requests. Each link is tried at most once a
/// session here; "Download frames for offline" in the Members tab tries
/// again and takes every link.
class FrameAutoDownloader {
  final Ref _ref;
  final Duration debounce;
  final _attempted = <String>{};
  StreamSubscription<void>? _sub;
  Timer? _timer;
  var _checking = false;

  FrameAutoDownloader(this._ref, {this.debounce = const Duration(seconds: 5)});

  void start() {
    final db = _ref.read(databaseProvider);
    _sub = _framesChanged(db).listen((_) => _schedule());
    _schedule();
  }

  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(check()));
  }

  bool _include(String url) => isGoogleDriveUrl(url) && !_attempted.contains(url);

  /// Queues a download for each shared trip with new Drive frames.
  @visibleForTesting
  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      final db = _ref.read(databaseProvider);
      final trips = await (db.select(db.trips)..where((t) => t.sharing.equals('group') & t.deletedAt.isNull())).get();
      if (trips.isEmpty) return;
      final downloader = _ref.read(tripFrameDownloaderProvider);
      final queue = _ref.read(frameTransferQueueProvider.notifier);
      bool? unmetered;
      for (final trip in trips) {
        if (_ref.read(frameTransferQueueProvider).jobFor(trip.id, TransferKind.download) != null) continue;
        final urls = await downloader.pendingUrls(db, trip.id, include: _include);
        if (urls.isEmpty) continue;
        unmetered ??= await _ref.read(transferForegroundServiceProvider).isUnmeteredNetwork();
        if (!unmetered) return;
        queue.enqueue(
          frameDownloadJob(
            db: db,
            downloader: downloader,
            tripId: trip.id,
            tripTitle: trip.title,
            include: _include,
            onUrls: _attempted.addAll,
            journaled: false,
            quiet: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('[FrameAutoDownloader] $e');
    } finally {
      _checking = false;
    }
  }
}

final frameAutoDownloaderProvider = Provider<FrameAutoDownloader>((ref) {
  final auto = FrameAutoDownloader(ref)..start();
  ref.onDispose(auto.dispose);
  return auto;
});

/// On start: the jobs the system cut short last time. Downloads simply run
/// again; uploads need a Google token, so they become "N frames left to
/// upload · Resume" instead of starting by themselves.
final frameTransferResumeProvider = FutureProvider<void>((ref) async {
  final queue = ref.read(frameTransferQueueProvider.notifier);
  final entries = await ref.read(transferJournalProvider).read();
  if (entries.isEmpty) return;
  final db = ref.read(databaseProvider);
  for (final entry in entries) {
    try {
      final trip = await (db.select(db.trips)..where((t) => t.id.equals(entry.tripId))).getSingleOrNull();
      if (trip == null || trip.deletedAt != null) {
        await queue.forgetJournaled(entry.kind, entry.tripId);
        continue;
      }
      switch (entry.kind) {
        case TransferKind.driveUpload:
          final left = trip.sharing == 'group'
              ? await ref.read(googleDriveFrameServiceProvider).countTripLocalFrames(db, trip.id)
              : 0;
          if (left == 0) {
            await queue.forgetJournaled(entry.kind, entry.tripId);
          } else {
            queue.addNotice(
              kind: TransferKind.driveUpload,
              tripId: trip.id,
              tripTitle: trip.title,
              type: TransferNoticeType.resumable,
              message: '$left ${left == 1 ? 'frame' : 'frames'} left to upload to Google Drive.',
            );
          }
        case TransferKind.download:
          queue.enqueue(
            frameDownloadJob(
              db: db,
              downloader: ref.read(tripFrameDownloaderProvider),
              tripId: trip.id,
              tripTitle: trip.title,
            ),
          );
        case TransferKind.stopUpload || TransferKind.packImport:
          await queue.forgetJournaled(entry.kind, entry.tripId);
      }
    } catch (e) {
      debugPrint('[frameTransferResume] ${entry.kind.name} ${entry.tripId}: $e');
    }
  }
});
