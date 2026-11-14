import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/database.dart';
import '../../../core/services/thumbnail_cache_service.dart';
import 'drive_cleanup_journal.dart';
import 'google_drive_frame_service.dart';

/// What a cleanup did.
@immutable
class DriveCleanupResult {
  /// Files and folders deleted from Drive for good.
  final int deleted;

  /// Files left because a frame still needs them (another shared trip, or
  /// the library, shows the same image).
  final int keptInUse;

  /// Frames set back to "only on this phone".
  final int framesReset;

  /// Files that were already gone (or never this user's).
  final int alreadyGone;

  const DriveCleanupResult({this.deleted = 0, this.keptInUse = 0, this.framesReset = 0, this.alreadyGone = 0});

  static const none = DriveCleanupResult();

  DriveCleanupResult operator +(DriveCleanupResult o) => DriveCleanupResult(
    deleted: deleted + o.deleted,
    keptInUse: keptInUse + o.keptInUse,
    framesReset: framesReset + o.framesReset,
    alreadyGone: alreadyGone + o.alreadyGone,
  );

  /// The files counted are the frame images; folders are counted too.
  String get text {
    final parts = <String>[
      deleted == 0
          ? 'Nothing was left to remove from your Google Drive.'
          : 'Removed $deleted ${deleted == 1 ? 'item' : 'items'} from your Google Drive.',
      if (framesReset > 0)
        '$framesReset ${framesReset == 1 ? 'frame is' : 'frames are'} now only on this phone.',
      if (keptInUse > 0)
        '$keptInUse ${keptInUse == 1 ? 'image was' : 'images were'} kept because another shared trip uses ${keptInUse == 1 ? 'it' : 'them'}.',
    ];
    return parts.join(' ');
  }
}

/// Takes frames shared through Google Drive back: deletes the files this
/// user uploaded (and the trip folders shared by link) and sets the frames
/// that pointed at them back to local-only.
///
/// Deletes for good rather than trashing: per Google's Drive docs, other
/// users can still open a file in the owner's trash until it is permanently
/// deleted; after that, "anyone you've shared the file with loses access".
///
/// Automatic cleanup ([sweep]) works from [DriveCleanupJournal], which lists
/// only files this user uploaded; it never asks Drive to find files, so a
/// fresh install (empty database, empty journal) can't delete anything a
/// trip still uses. The explicit removals also ask Drive, which with
/// `drive.file` lists only the app's own files, so they also find uploads
/// made before the journal existed.
class DriveFrameCleanup {
  /// How many deletes run at once.
  static const concurrency = 3;

  final GoogleDriveFrameService drive;
  final DriveCleanupJournal journal;

  DriveFrameCleanup({required this.drive, required this.journal});

  static String? _fileIdOf(String? url) =>
      (url == null || url.trim().isEmpty) ? null : ThumbnailCacheService.extractGoogleDriveFileId(url.trim());

  /// Drive file IDs some frame still needs shared: a frame on a live stop of
  /// a live shared trip (other than [exceptTripId]), or a library frame.
  /// Each maps to a trip that needs it (null: the library).
  Future<Map<String, String?>> _neededFileIds(AppDatabase db, {String? exceptTripId}) async {
    final trips = await (db.select(db.trips)..where((t) => t.sharing.equals('group') & t.deletedAt.isNull())).get();
    final tripIds = {
      for (final t in trips)
        if (t.id != exceptTripId) t.id,
    };
    final tripOfStop = tripIds.isEmpty
        ? <String, String>{}
        : {
            for (final s in await (db.select(db.stops)..where((s) => s.tripId.isIn(tripIds) & s.deletedAt.isNull())).get())
              s.id: s.tripId,
          };
    final rows = await (db.select(db.newReferenceImages)..where((r) => r.remoteUrl.isNotNull())).get();
    final needed = <String, String?>{};
    for (final r in rows) {
      final id = _fileIdOf(r.remoteUrl);
      if (id == null) continue;
      if (r.stopId == null) {
        if (r.placeKey != null) needed.putIfAbsent(id, () => null);
      } else if (tripOfStop[r.stopId] case final trip?) {
        needed[id] = trip;
      }
    }
    return needed;
  }

  /// Sets every frame pointing at one of [gone] back to local-only (or, with
  /// no file on this phone, leaves it be: it has nothing else to show). Stops
  /// of live shared trips are marked for sync so members drop those frames.
  Future<int> _resetFrames(AppDatabase db, Set<String> gone) async {
    if (gone.isEmpty) return 0;
    final rows = await (db.select(db.newReferenceImages)..where((r) => r.remoteUrl.isNotNull())).get();
    final hits = [
      for (final r in rows)
        if (gone.contains(_fileIdOf(r.remoteUrl)) && (r.localPath?.trim().isNotEmpty ?? false)) r,
    ];
    if (hits.isEmpty) return 0;
    final stopIds = {
      for (final r in hits)
        if (r.stopId != null) r.stopId!,
    };
    await db.transaction(() async {
      for (final r in hits) {
        final url = r.remoteUrl!.trim();
        await (db.update(db.newReferenceImages)..where((t) => t.id.equals(r.id))).write(
          NewReferenceImagesCompanion(
            remoteUrl: const Value(null),
            source: r.source == 'Google Drive' ? const Value(null) : const Value.absent(),
            sourceUrl: r.sourceUrl?.trim() == url ? const Value(null) : const Value.absent(),
          ),
        );
      }
      if (stopIds.isNotEmpty) {
        final shared = {
          for (final t in await (db.select(db.trips)..where((t) => t.sharing.equals('group') & t.deletedAt.isNull())).get())
            t.id,
        };
        final now = DateTime.now();
        await (db.update(db.stops)
              ..where((s) => s.id.isIn(stopIds) & s.tripId.isIn(shared) & s.deletedAt.isNull()))
            .write(StopsCompanion(updatedAt: Value(now), syncStatus: const Value(1)));
      }
    });
    return hits.length;
  }

  /// Drive links on [tripId]'s live stops worth checking before an upload:
  /// frames with their image on this phone whose file this user isn't known
  /// to have uploaded (not in the journal). Uploads made before the journal
  /// existed, or files removed by hand in Drive, show up here.
  Future<Set<String>> linksToCheck(AppDatabase db, String tripId) async {
    final state = await journal.read();
    final stopIds = [
      for (final s in await (db.select(db.stops)..where((s) => s.tripId.equals(tripId) & s.deletedAt.isNull())).get()) s.id,
    ];
    if (stopIds.isEmpty) return {};
    final rows = await (db.select(db.newReferenceImages)
          ..where((r) => r.stopId.isIn(stopIds) & r.remoteUrl.isNotNull()))
        .get();
    final out = <String>{};
    for (final r in rows) {
      final id = _fileIdOf(r.remoteUrl);
      final path = r.localPath?.trim() ?? '';
      if (id == null || path.isEmpty || state.files.containsKey(id) || out.contains(id)) continue;
      if (await _exists(path)) out.add(id);
    }
    return out;
  }

  static Future<bool> _exists(String path) async {
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  /// Checks [ids] ([checkConcurrency] at a time) and sets the frames whose
  /// link is gone for everyone back to local-only, so the next upload sends
  /// them again. A link that still opens (a teammate's, say) is left alone.
  /// Returns how many frames were reset.
  Future<int> resetGoneLinks(AppDatabase db, Set<String> ids, {void Function(int done, int total)? onProgress}) async {
    final queue = ids.toList();
    final total = queue.length;
    final gone = <String>{};
    var done = 0;
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        if (await drive.isPublicLinkGone(id)) gone.add(id);
        onProgress?.call(++done, total);
      }
    }

    await Future.wait([for (var i = 0; i < math.min(checkConcurrency, total); i++) worker()]);
    return _resetFrames(db, gone);
  }

  /// How many links [resetGoneLinks] checks at once.
  static const checkConcurrency = 6;

  /// Deletes [ids] (files first, [concurrency] at a time). Returns what was
  /// deleted, what was already gone, and what Drive refused. Stops at the
  /// first failure (offline, sign-in needed) after recording what's done.
  Future<({Set<String> deleted, Set<String> notFound, Set<String> forbidden})> _deleteAll(
    List<String> ids, {
    required bool interactive,
  }) async {
    final deleted = <String>{}, notFound = <String>{}, forbidden = <String>{};
    var next = 0;
    Object? failure;
    StackTrace? failureStack;
    Future<void> worker() async {
      while (failure == null && next < ids.length) {
        final id = ids[next++];
        try {
          switch (await drive.deleteDriveFile(id, interactive: interactive)) {
            case DriveDeleteOutcome.deleted:
              deleted.add(id);
            case DriveDeleteOutcome.notFound:
              notFound.add(id);
            case DriveDeleteOutcome.forbidden:
              forbidden.add(id);
          }
        } catch (e, st) {
          failure ??= e;
          failureStack ??= st;
        }
      }
    }

    await Future.wait([for (var i = 0; i < math.min(concurrency, ids.length); i++) worker()]);
    if (failure != null) {
      await journal.forget({...deleted, ...notFound, ...forbidden});
      throw _PartialFailure(deleted: deleted, notFound: notFound, cause: failure!, stack: failureStack!);
    }
    return (deleted: deleted, notFound: notFound, forbidden: forbidden);
  }

  /// Deletes the Drive files this user uploaded for [tripId] (its shared
  /// folder, the files in it, and older uploads for it in the top folder),
  /// except images a frame elsewhere still needs, and sets the frames that
  /// pointed at them back to local-only: they're offered for upload again
  /// only if the user syncs the trip again.
  ///
  /// On failure (offline, or Google needs the user) the removal stays
  /// pending in [journal] for [sweep] to finish, and the error is rethrown.
  Future<DriveCleanupResult> removeTripFramesFromDrive(
    AppDatabase db,
    String tripId, {
    bool interactive = false,
  }) async {
    await journal.addPendingTrip(tripId);
    try {
      final state = await journal.read();
      final listed = await drive.listAppFiles(tripId: tripId, interactive: interactive);
      final files = <String>{
        for (final f in listed)
          if (!f.isFolder) f.id,
        for (final e in state.files.entries)
          if (e.value == tripId) e.key,
      };
      final folders = <String>{
        for (final f in listed)
          if (f.isFolder && !f.isAppFolder) f.id,
        for (final e in state.folders.entries)
          if (e.value == tripId) e.key,
      };
      final result = await _removeFiles(db, files, folders, exceptTripId: tripId, interactive: interactive);
      await journal.removePendingTrip(tripId);
      return result;
    } on _PartialFailure catch (f) {
      await _resetFrames(db, {...f.deleted, ...f.notFound});
      Error.throwWithStackTrace(f.cause, f.stack);
    }
  }

  /// Deletes [files] that nothing else needs, then [folders] if all their
  /// files went, resets the frames, and forgets them in the journal.
  Future<DriveCleanupResult> _removeFiles(
    AppDatabase db,
    Set<String> files,
    Set<String> folders, {
    String? exceptTripId,
    bool keepNeeded = true,
    required bool interactive,
  }) async {
    final needed = keepNeeded ? await _neededFileIds(db, exceptTripId: exceptTripId) : const <String, String?>{};
    final kept = files.where(needed.containsKey).toSet();
    final toDelete = files.difference(kept).toList();
    final first = await _deleteAll(toDelete, interactive: interactive);
    final reset = await _resetFrames(db, {...first.deleted, ...first.notFound});
    await journal.forget({...first.deleted, ...first.notFound, ...first.forbidden});
    // A folder is deleted with everything of this user's in it, so only when
    // no file in it is being kept.
    final second = kept.isEmpty ? await _deleteAll(folders.toList(), interactive: interactive) : null;
    if (second != null) await journal.forget({...second.deleted, ...second.notFound, ...second.forbidden});
    if (kept.isNotEmpty) await _handOver(kept, folders, needed);
    return DriveCleanupResult(
      deleted: first.deleted.length + (second?.deleted.length ?? 0),
      keptInUse: kept.length,
      framesReset: reset,
      alreadyGone: first.notFound.length + (second?.notFound.length ?? 0),
    );
  }

  /// Kept files now belong to the trip that still needs them, so they go
  /// when that trip does; one kept for the library alone is no longer
  /// tracked. Their folder stays (they inherit their link sharing from it)
  /// and is no longer tracked either: deleting it would take every file in
  /// it along. "Remove all" still finds it.
  Future<void> _handOver(Set<String> kept, Set<String> folders, Map<String, String?> needed) async {
    await journal.update((s) {
      final files = {...s.files};
      for (final id in kept) {
        final trip = needed[id];
        if (trip == null) {
          files.remove(id);
        } else {
          files[id] = trip;
        }
      }
      final folderMap = {...s.folders}..removeWhere((id, _) => folders.contains(id));
      return s.copyWith(files: files, folders: folderMap);
    });
  }

  /// Deletes everything the app created in this user's Drive (every frame,
  /// every trip folder and the top folder, trashed ones too) and sets every
  /// frame that pointed at them back to local-only. Members of still-shared
  /// trips lose those frames unless they downloaded them.
  Future<DriveCleanupResult> removeAllSharedFramesFromDrive(AppDatabase db, {bool interactive = false}) async {
    await journal.setPendingAll(true);
    try {
      final state = await journal.read();
      final listed = await drive.listAppFiles(interactive: interactive);
      final files = <String>{
        for (final f in listed)
          if (!f.isFolder) f.id,
        ...state.files.keys,
      };
      final tripFolders = <String>{
        for (final f in listed)
          if (f.isFolder && !f.isAppFolder) f.id,
        ...state.folders.keys,
      };
      final appFolders = [
        for (final f in listed)
          if (f.isAppFolder) f.id,
      ];
      var result = await _removeFiles(db, files, tripFolders, keepNeeded: false, interactive: interactive);
      final top = await _deleteAll(appFolders, interactive: interactive);
      result += DriveCleanupResult(deleted: top.deleted.length, alreadyGone: top.notFound.length);
      await journal.update((s) => s.copyWith(files: const {}, folders: const {}, pendingTrips: const [], pendingAll: false));
      return result;
    } on _PartialFailure catch (f) {
      await _resetFrames(db, {...f.deleted, ...f.notFound});
      Error.throwWithStackTrace(f.cause, f.stack);
    }
  }

  /// Uploads of this user that no frame needs shared any more: on a trip
  /// that was deleted, unshared or left (or is gone), or whose stop or frame
  /// was removed. Grouped by trip; a trip that isn't live and shared any more
  /// goes as a whole (its folder too).
  Future<({List<String> trips, Set<String> files})> _waiting(AppDatabase db, DriveCleanupState state) async {
    final tripIds = {...state.files.values, ...state.folders.values};
    if (tripIds.isEmpty) return (trips: const <String>[], files: const <String>{});
    final live = {
      for (final t in await (db.select(db.trips)
            ..where((t) => t.id.isIn(tripIds) & t.sharing.equals('group') & t.deletedAt.isNull()))
          .get())
        t.id,
    };
    final needed = (await _neededFileIds(db)).keys.toSet();
    return (
      trips: [
        for (final t in tripIds)
          if (!live.contains(t)) t,
      ],
      files: {
        for (final e in state.files.entries)
          if (live.contains(e.value) && !needed.contains(e.key)) e.key,
      },
    );
  }

  /// How many removals are waiting: trips to take back and single files no
  /// frame needs, plus a pending "remove all".
  Future<int> waitingCount(AppDatabase db) async {
    final state = await journal.read();
    final w = await _waiting(db, state);
    final trips = {...w.trips, ...state.pendingTrips};
    return trips.length + w.files.length + (state.pendingAll ? 1 : 0);
  }

  /// Finishes what's waiting, silently (never shows Google's sign-in):
  /// a pending "remove all", pending trip removals, trips that aren't live
  /// and shared any more, and files no frame needs. Whatever fails (offline,
  /// sign-in needed) stays waiting for the next time.
  Future<DriveCleanupResult> sweep(AppDatabase db) async {
    var state = await journal.read();
    if (state.isEmpty) return DriveCleanupResult.none;
    var total = DriveCleanupResult.none;
    try {
      if (state.pendingAll) {
        return await removeAllSharedFramesFromDrive(db);
      }
      final waiting = await _waiting(db, state);
      for (final tripId in {...state.pendingTrips, ...waiting.trips}) {
        total += await removeTripFramesFromDrive(db, tripId);
      }
      state = await journal.read();
      final again = await _waiting(db, state);
      if (again.files.isNotEmpty) {
        total += await _removeFiles(db, again.files, const {}, interactive: false);
      }
    } on _PartialFailure catch (f) {
      await _resetFrames(db, {...f.deleted, ...f.notFound});
      debugPrint('[DriveFrameCleanup] will retry: ${f.cause}');
    } catch (e) {
      debugPrint('[DriveFrameCleanup] will retry: $e');
    }
    return total;
  }
}

/// Some deletes went through before one failed.
class _PartialFailure implements Exception {
  final Set<String> deleted;
  final Set<String> notFound;
  final Object cause;
  final StackTrace stack;

  _PartialFailure({required this.deleted, required this.notFound, required this.cause, required this.stack});

  @override
  String toString() => '$cause';
}
