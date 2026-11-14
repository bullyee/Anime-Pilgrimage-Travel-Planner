import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/drive_cleanup_journal.dart';
import '../services/drive_frame_cleanup.dart';
import '../services/frame_transfer_queue.dart';
import 'frame_transfer_providers.dart';

/// The user ID [currentUserIdProvider] gives when nobody is signed in.
const _guestUserId = 'guest_local_user';

/// What this user put on Drive, and the removals still to do (per user).
final driveCleanupJournalProvider = Provider<DriveCleanupJournal>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return uid == _guestUserId ? InMemoryDriveCleanupJournal() : FileDriveCleanupJournal(uid);
});

final driveFrameCleanupProvider = Provider<DriveFrameCleanup>(
  (ref) => DriveFrameCleanup(
    drive: ref.watch(googleDriveFrameServiceProvider),
    journal: ref.watch(driveCleanupJournalProvider),
  ),
);

Stream<void> _relevantChanges(AppDatabase db) =>
    db.tableUpdates(TableUpdateQuery.onAllTables([db.trips, db.stops, db.newReferenceImages])).map((_) {});

/// How many Drive removals are waiting (trips to take back, single files no
/// frame needs, a pending "remove all"): they finish by themselves when
/// Google Drive can be reached without asking the user. For Settings.
final driveRemovalsWaitingProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(databaseProvider);
  final cleanup = ref.watch(driveFrameCleanupProvider);
  final controller = StreamController<int>();
  var closed = false;
  Future<void> recount() async {
    try {
      final n = await cleanup.waitingCount(db);
      if (!closed) controller.add(n);
    } catch (e) {
      debugPrint('[driveRemovalsWaiting] $e');
    }
  }

  final subs = [
    _relevantChanges(db).listen((_) => recount()),
    cleanup.journal.changes.listen((_) => recount()),
  ];
  unawaited(recount());
  ref.onDispose(() {
    closed = true;
    for (final s in subs) {
      s.cancel();
    }
    controller.close();
  });
  return controller.stream;
});

/// Takes this user's Drive uploads back by itself when a frame no longer
/// needs them: the trip was deleted, unshared or left (here or by its owner),
/// or a stop or frame was removed. Runs [DriveFrameCleanup.sweep] on start,
/// [sweepDelay] after the trips, stops or frames change (long enough for an
/// Undo), and every [retryEvery] while something is waiting. Uploads for a
/// trip that is no longer shared are cancelled at once.
class DriveCleanupRunner {
  final Ref _ref;
  final Duration startDelay;
  final Duration sweepDelay;
  final Duration retryEvery;
  StreamSubscription<void>? _sub;
  Timer? _sweepTimer;
  Timer? _retryTimer;
  var _sweeping = false;
  var _again = false;

  DriveCleanupRunner(
    this._ref, {
    this.startDelay = const Duration(seconds: 5),
    this.sweepDelay = const Duration(seconds: 30),
    this.retryEvery = const Duration(minutes: 10),
  });

  void start() {
    final db = _ref.read(databaseProvider);
    _sub = _relevantChanges(db).listen((_) {
      unawaited(cancelUploadsOfUnsharedTrips());
      _schedule(sweepDelay);
    });
    _schedule(startDelay);
  }

  void dispose() {
    _sub?.cancel();
    _sweepTimer?.cancel();
    _retryTimer?.cancel();
  }

  void _schedule(Duration delay) {
    _sweepTimer?.cancel();
    _sweepTimer = Timer(delay, () => unawaited(sweep()));
  }

  /// Cancels queued and running uploads of trips that were deleted or are
  /// no longer shared.
  @visibleForTesting
  Future<void> cancelUploadsOfUnsharedTrips() async {
    try {
      final transfers = _ref.read(frameTransferQueueProvider);
      final tripIds = {
        for (final j in [?transfers.current, ...transfers.queued])
          if (j.kind.isUpload) j.tripId,
      };
      if (tripIds.isEmpty) return;
      final db = _ref.read(databaseProvider);
      final live = {
        for (final t in await (db.select(db.trips)
              ..where((t) => t.id.isIn(tripIds) & t.sharing.equals('group') & t.deletedAt.isNull()))
            .get())
          t.id,
      };
      final queue = _ref.read(frameTransferQueueProvider.notifier);
      for (final id in tripIds.difference(live)) {
        await queue.cancelUploads(tripId: id);
      }
    } catch (e) {
      debugPrint('[DriveCleanupRunner] $e');
    }
  }

  /// One silent cleanup pass.
  @visibleForTesting
  Future<DriveCleanupResult> sweep() async {
    if (_sweeping) {
      _again = true;
      return DriveCleanupResult.none;
    }
    _sweeping = true;
    try {
      if (_ref.read(currentUserIdProvider) == _guestUserId) return DriveCleanupResult.none;
      await cancelUploadsOfUnsharedTrips();
      final db = _ref.read(databaseProvider);
      final cleanup = _ref.read(driveFrameCleanupProvider);
      final result = await cleanup.sweep(db);
      _retryTimer?.cancel();
      if (await cleanup.waitingCount(db) > 0) {
        _retryTimer = Timer(retryEvery, () => unawaited(sweep()));
      }
      return result;
    } catch (e) {
      debugPrint('[DriveCleanupRunner] $e');
      return DriveCleanupResult.none;
    } finally {
      _sweeping = false;
      if (_again) {
        _again = false;
        _schedule(sweepDelay);
      }
    }
  }
}

final driveCleanupRunnerProvider = Provider<DriveCleanupRunner>((ref) {
  final runner = DriveCleanupRunner(ref)..start();
  ref.onDispose(runner.dispose);
  return runner;
});
