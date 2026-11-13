import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data' show BytesBuilder;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/archive_isolate.dart';
import '../../library/models/frames.dart';
import 'drive_cleanup_journal.dart';
import 'drive_upload_quality.dart';
import 'online_frame_matcher.dart';

/// Thrown when a Google Drive upload or permission operation fails.
class GoogleDriveUploadException implements Exception {
  final String message;
  final int? statusCode;

  const GoogleDriveUploadException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Thrown when Google Drive needs the user again: the access token expired
/// and could not be refreshed without showing Google's sign-in, which only
/// works while the app is on screen.
class DriveAuthRequiredException implements Exception {
  final Object? cause;

  const DriveAuthRequiredException([this.cause]);

  @override
  String toString() => 'Google Drive needs you to sign in again${cause == null ? '' : ' ($cause)'}.';
}

/// Result of uploading a reference image to the user's Google Drive (`drive.file`).
class GoogleDriveUploadedFile {
  final String fileId;
  final String downloadUrl;

  const GoogleDriveUploadedFile({
    required this.fileId,
    required this.downloadUrl,
  });
}

/// Outcome of syncing a trip's local-only frames through Google Drive.
class DriveSyncSummary {
  final int uploaded;
  final int reused;
  final int updatedStops;
  final int skippedMissing;

  /// Frames that took the link of the same image already online at Anitabi
  /// instead of being uploaded.
  final int linkedOnline;

  const DriveSyncSummary({
    required this.uploaded,
    required this.reused,
    required this.updatedStops,
    required this.skippedMissing,
    this.linkedOnline = 0,
  });
}

/// A file or folder the app created in the user's Drive, as listed by
/// [GoogleDriveFrameService.listAppFiles].
@immutable
class DriveAppFile {
  final String id;
  final String name;
  final bool isFolder;

  /// The `tripId` / `frameId` app properties the app set, if any.
  final String? tripId;
  final String? frameId;

  const DriveAppFile({required this.id, required this.name, required this.isFolder, this.tripId, this.frameId});

  /// The top folder ([GoogleDriveFrameService.appFolderName]).
  bool get isAppFolder => isFolder && tripId == null && name == GoogleDriveFrameService.appFolderName;
}

/// How a delete went.
enum DriveDeleteOutcome {
  deleted,

  /// Already gone (deleted by hand, or never visible to this app).
  notFound,

  /// Drive refused: not this user's file.
  forbidden,
}

typedef DriveTokenFetcher = Future<String> Function({bool interactive});
typedef DriveImageCompressor = Future<Uint8List> Function(Uint8List rawBytes);
typedef DriveFileReader = Future<Uint8List?> Function(String path);
typedef DriveSleep = Future<void> Function(Duration delay);

/// Uploads local-only anime reference frames to the signed-in user's own Google
/// Drive using the non-sensitive `drive.file` scope, grants link-read access so
/// trip collaborators can cache them, and writes back `remoteUrl` without using
/// Firebase Storage or Blaze billing.
///
/// A trip's frames go into a folder of their own inside [appFolderName],
/// shared once as "anyone with the link can view"; files created in it
/// inherit that, so a frame needs one request (the upload) instead of two.
/// Frames uploaded before that (directly in [appFolderName], each shared on
/// its own) keep working as they are.
class GoogleDriveFrameService {
  static const appFolderName = 'Trip Planner Shared Frames';
  /// How many frames [syncTripLocalFrames] works on at once.
  static const uploadConcurrency = 3;

  static const _driveApi = 'https://www.googleapis.com/drive/v3';
  static const _driveUploadApi = 'https://www.googleapis.com/upload/drive/v3';
  static const _folderMime = 'application/vnd.google-apps.folder';
  static const _uuid = Uuid();

  final http.Client _client;
  final DriveTokenFetcher _getToken;
  final DriveImageCompressor _compress;
  final DriveFileReader _readFile;
  final DriveSleep _sleep;
  final FrameHasher _hashFrames;

  /// Remembers what this user uploads, so it can be removed again
  /// (`DriveFrameCleanup`).
  final DriveCleanupJournal? _journal;

  /// Waits between attempts when a Google endpoint drops the connection or
  /// answers 429/5xx; one retry per entry. (Google only: never applied to
  /// Anitabi.)
  final List<Duration> retryDelays;

  String? _cachedToken;
  Future<String>? _refreshingToken;

  /// Folder lookups in flight or done, shared by concurrent uploads so a
  /// folder is looked up (or created) once.
  Future<String>? _rootFolder;
  final _tripFolders = <String, Future<String>>{};

  GoogleDriveFrameService({
    http.Client? client,
    required DriveTokenFetcher getToken,
    DriveImageCompressor? compress,
    DriveFileReader? readFile,
    DriveSleep? sleep,
    FrameHasher? hashFrames,
    DriveCleanupJournal? journal,
    Future<DriveUploadQuality> Function()? uploadQuality,
    this.retryDelays = const [Duration(seconds: 2), Duration(seconds: 6), Duration(seconds: 15)],
  })  : _client = client ?? http.Client(),
        _getToken = getToken,
        _compress = compress ?? _compressAt(uploadQuality),
        _readFile = readFile ?? _defaultReadFile,
        _sleep = sleep ?? Future<void>.delayed,
        _hashFrames = hashFrames ?? FrameHash.computeAll,
        _journal = journal;

  /// Canonical direct-download URL stored on synced `NewReferenceImages.remoteUrl`.
  static String downloadUrlForFileId(String fileId) =>
      'https://drive.google.com/uc?export=download&id=$fileId';

  /// Compresses with the quality the user chose when the upload runs.
  static DriveImageCompressor _compressAt(Future<DriveUploadQuality> Function()? uploadQuality) =>
      (rawBytes) async => compressForDriveUpload(
            rawBytes,
            quality: uploadQuality == null ? DriveUploadQuality.original : await uploadQuality(),
          );

  /// What goes to Drive for a frame: the file itself, untouched, when its
  /// longest edge is at most [quality]'s `maxEdge` (no second round of JPEG
  /// loss, and a PNG stays lossless); otherwise a copy scaled down to that
  /// size as a JPEG at its `jpegQuality`. Undecodable bytes go as they are.
  static Future<Uint8List> compressForDriveUpload(
    Uint8List rawBytes, {
    DriveUploadQuality quality = DriveUploadQuality.original,
  }) {
    final maxEdge = quality.maxEdge;
    final jpegQuality = quality.jpegQuality;
    if (kIsWeb) {
      return Future.value(_encodeDriveJpeg(rawBytes, maxEdge, jpegQuality));
    }
    return Isolate.run(() => _encodeDriveJpeg(rawBytes, maxEdge, jpegQuality));
  }

  static Uint8List _encodeDriveJpeg(Uint8List rawBytes, int maxUploadDimension, int jpegQuality) {
    // The header is enough to know whether the file can go as it is.
    final info = _imageInfo(rawBytes);
    if (info != null && math.max(info.$1, info.$2) <= maxUploadDimension) return rawBytes;
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      return rawBytes;
    }
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest <= maxUploadDimension) return rawBytes;
    final resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxUploadDimension, interpolation: img.Interpolation.average)
        : img.copyResize(decoded, height: maxUploadDimension, interpolation: img.Interpolation.average);
    return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
  }

  /// Width and height from an image's header, without decoding it.
  static (int, int)? _imageInfo(Uint8List bytes) {
    try {
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) return null;
      return (info.width, info.height);
    } catch (_) {
      return null;
    }
  }

  /// The MIME type and file extension of an image file, from its first bytes.
  /// Frames that go up as they are keep their own format.
  static (String, String) uploadType(Uint8List b) {
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return ('image/png', 'png');
    if (b.length >= 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return ('image/webp', 'webp');
    }
    if (b.length >= 6 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return ('image/gif', 'gif');
    return ('image/jpeg', 'jpg');
  }

  static Future<Uint8List?> _defaultReadFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Counts local-only frames on [tripId]'s live stops (including place frames not
  /// yet copied with a URL) that have not been synced with a `remoteUrl` yet.
  Future<int> countTripLocalFrames(AppDatabase db, String tripId) async {
    final plan = await _buildSyncPlan(db, tripId, hashSynced: false);
    return plan.pendingCount;
  }

  /// Gets a Drive access token now, showing Google's consent if needed. Call
  /// it while the app is on screen before queueing a background upload, so
  /// the upload itself never has to prompt.
  Future<void> prepareToken() => _ensureToken(interactive: true);

  /// Uploads [rawBytes] to the user's Google Drive, readable by anyone with
  /// the link so trip collaborators can download it, and returns the
  /// resulting file metadata.
  ///
  /// With a [tripId] the file goes into the trip's link-shared folder (named
  /// after [tripTitle]) and inherits its sharing; it is shared on its own only
  /// if Drive doesn't report that. Without one it goes into [appFolderName]
  /// and is shared on its own.
  Future<GoogleDriveUploadedFile> uploadImageBytes({
    required Uint8List rawBytes,
    required String frameId,
    String? tripId,
    String? tripTitle,
    String? stopId,
    bool interactive = true,
    BackupCancel? cancel,
  }) async {
    final jpegBytes = await _compress(rawBytes);
    final String token;
    if (interactive) {
      token = await _ensureToken(interactive: true);
    } else {
      try {
        token = await _ensureToken(interactive: false);
      } catch (e) {
        throw DriveAuthRequiredException(e);
      }
    }
    return _runWithAuthRetry(token, (activeToken) async {
      final folderId = tripId == null
          ? await _ensureFolderId(activeToken, cancel: cancel)
          : await _ensureTripFolderId(activeToken, tripId, tripTitle, cancel: cancel);
      final (fileId: fileId, linkShared: linkShared) = await _multipartUpload(
        cancel: cancel,
        token: activeToken,
        folderId: folderId,
        fileName: 'frame_$frameId.${uploadType(jpegBytes).$2}',
        bytes: jpegBytes,
        appProperties: {
          'tripId': ?tripId,
          'stopId': ?stopId,
          'frameId': frameId,
        },
      );
      if (!linkShared) {
        try {
          await _grantAnyoneReaderPermission(activeToken, fileId, cancel: cancel);
        } catch (e) {
          // Avoid leaving private unshareable orphan files in Drive on permission failure.
          await _deleteDriveFileQuietly(activeToken, fileId);
          rethrow;
        }
      }
      return GoogleDriveUploadedFile(
        fileId: fileId,
        downloadUrl: downloadUrlForFileId(fileId),
      );
    });
  }

  /// Reads [localPath], uploads compressed JPEG bytes to Google Drive, and attaches
  /// a synced `remoteUrl` row on [stopId] while marking the stop dirty.
  Future<NewReferenceImage> uploadNewStopFrame(
    AppDatabase db, {
    required String tripId,
    required String stopId,
    required String localPath,
    String? episode,
    bool interactive = true,
  }) async {
    final initialStop = await (db.select(db.stops)
          ..where((s) => s.id.equals(stopId) & s.tripId.equals(tripId) & s.deletedAt.isNull()))
        .getSingleOrNull();
    if (initialStop == null) {
      throw StateError('Stop not found or deleted: $stopId');
    }

    final bytes = await _readFile(localPath);
    if (bytes == null || bytes.isEmpty) {
      throw const GoogleDriveUploadException('Could not read the selected image file.');
    }
    final frameId = _uuid.v4();
    final uploaded = await uploadImageBytes(
      rawBytes: bytes,
      frameId: frameId,
      tripId: tripId,
      tripTitle: await _tripTitle(db, tripId),
      stopId: stopId,
      interactive: interactive,
    );

    final now = DateTime.now();
    try {
      await db.transaction(() async {
        final stop = await (db.select(db.stops)
              ..where((s) => s.id.equals(stopId) & s.tripId.equals(tripId) & s.deletedAt.isNull()))
            .getSingleOrNull();
        if (stop == null) {
          throw StateError('Stop not found or deleted: $stopId');
        }
        await db.into(db.newReferenceImages).insert(
              NewReferenceImagesCompanion.insert(
                id: frameId,
                placeKey: const Value(null),
                stopId: Value(stopId),
                localPath: Value(localPath),
                remoteUrl: Value(uploaded.downloadUrl),
                episode: Value(episode),
                source: const Value('Google Drive'),
                sourceUrl: Value(uploaded.downloadUrl),
              ),
            );
        await (db.update(db.stops)..where((s) => s.id.equals(stopId) & s.tripId.equals(tripId))).write(
          StopsCompanion(
            updatedAt: Value(now),
            syncStatus: const Value(1),
          ),
        );
      });
    } catch (_) {
      final tok = _cachedToken;
      if (tok != null) {
        await _deleteDriveFileQuietly(tok, uploaded.fileId);
      }
      rethrow;
    }
    await _journal?.recordFile(uploaded.fileId, tripId);
    return (await (db.select(db.newReferenceImages)..where((r) => r.id.equals(frameId))).getSingle());
  }

  /// Uploads all local-only frames on [tripId]'s live stops to the current user's
  /// Google Drive, writes back `remoteUrl`, and marks affected stops dirty so
  /// collaborators receive them on Firestore sync.
  ///
  /// When a local frame originates from a library place (`stopId == null`), the
  /// personal library row is left untouched and only a stop-scoped copy receives
  /// the link. Frames backed by identical image bytes upload once and reuse
  /// the link within the trip. A frame that is the same image as one already
  /// online at Anitabi ([OnlineFrameMatcher]) takes that link, with Anitabi's
  /// attribution, and isn't uploaded.
  ///
  /// Works on [uploadConcurrency] frames at a time. Each frame commits as soon
  /// as its link is known; on cancel or on the first error no new frame is
  /// started, the ones in flight finish and commit, and then it throws, so
  /// already-uploaded Drive files are never orphaned. A file uploaded for a
  /// stop deleted meanwhile, and used by no other frame, is deleted again.
  ///
  /// With [interactive] false (a background run, token fetched beforehand with
  /// [prepareToken]) it never shows Google's sign-in: an expired token that
  /// can't be refreshed silently throws [DriveAuthRequiredException].
  Future<DriveSyncSummary> syncTripLocalFrames(
    AppDatabase db, {
    required String tripId,
    BackupProgress? onProgress,
    BackupCancel? cancel,
    bool interactive = true,
  }) async {
    final plan = await _buildSyncPlan(db, tripId);
    if (plan.pendingCount == 0) {
      return const DriveSyncSummary(uploaded: 0, reused: 0, updatedStops: 0, skippedMissing: 0);
    }

    // Request Drive OAuth consent upfront before starting progress work.
    if (interactive) {
      await _ensureToken(interactive: true);
    } else {
      try {
        await _ensureToken(interactive: false);
      } catch (e) {
        throw DriveAuthRequiredException(e);
      }
    }

    final tripTitle = await _tripTitle(db, tripId);
    final matcher = await OnlineFrameMatcher.forStops(db, plan.stops, readFile: _readFile, hashAll: _hashFrames);

    var reused = 0;
    var linkedOnline = 0;
    var skippedMissing = 0;
    var done = 0;
    final touchedStopIds = <String>{};

    /// Links some frame was committed with, and Drive files uploaded in this
    /// run (link → file ID): a file whose link nobody committed is deleted.
    final committedUrls = <String>{};
    final uploadedFiles = <String, String>{};

    /// Links found online in this run → the Anitabi frame they belong to.
    final onlineSources = <String, OnlineFrameCandidate>{};

    /// The link for each image content and each file, known or on its way,
    /// so concurrent frames with the same image wait for one upload.
    final byHash = <String, Future<String>>{
      for (final e in plan.existingUrlByHash.entries) e.key: Future.value(e.value),
    };
    final byPath = <String, Future<_Resolved?>>{
      for (final e in plan.existingUrlByPath.entries) e.key: Future.value(_Resolved(e.value, _How.reused)),
    };

    _How howOf(String url) => onlineSources.containsKey(url) ? _How.online : _How.reused;

    Future<_Resolved?> resolve(_DriveFrameTask task) async {
      final bytes = await _readFile(task.frame.localPath!);
      if (bytes == null || bytes.isEmpty) return null;
      final hash = md5.convert(bytes).toString();
      final known = byHash[hash];
      if (known != null) {
        final url = await known;
        return _Resolved(url, howOf(url));
      }
      final completer = Completer<String>();
      completer.future.ignore();
      byHash[hash] = completer.future;
      try {
        final match = await matcher.match(bytes, stop: task.stop, animeLabelId: task.frame.animeLabelId);
        final _Resolved resolved;
        if (match != null) {
          onlineSources[match.url] = match.candidate;
          resolved = _Resolved(match.url, _How.online);
        } else {
          if (cancel?.isCancelled ?? false) throw const BackupCancelled();
          final res = await uploadImageBytes(
            rawBytes: bytes,
            frameId: task.frame.id,
            tripId: tripId,
            tripTitle: tripTitle,
            stopId: task.stop.id,
            interactive: interactive,
            cancel: cancel,
          );
          uploadedFiles[res.downloadUrl] = res.fileId;
          resolved = _Resolved(res.downloadUrl, _How.uploaded);
        }
        completer.complete(resolved.url);
        return resolved;
      } catch (e, st) {
        completer.completeError(e, st);
        rethrow;
      }
    }

    Future<bool> stopIsLive(String stopId) async =>
        await (db.select(db.stops)..where((s) => s.id.equals(stopId) & s.tripId.equals(tripId) & s.deletedAt.isNull()))
            .getSingleOrNull() !=
        null;

    Future<void> runTask(_DriveFrameTask task) async {
      if (!await stopIsLive(task.stop.id)) return;
      final localPath = task.frame.localPath!;
      final _Resolved? resolved;
      final pending = byPath[localPath];
      if (pending != null) {
        final r = await pending;
        // Another frame did the work for this file.
        resolved = r == null ? null : _Resolved(r.url, howOf(r.url));
      } else {
        final mine = resolve(task);
        byPath[localPath] = mine;
        resolved = await mine;
      }
      if (resolved == null) {
        skippedMissing++;
        return;
      }

      final remoteUrl = resolved.url;
      final online = onlineSources[remoteUrl]?.frame;
      final now = DateTime.now();
      final committed = await db.transaction(() async {
        if (!await stopIsLive(task.stop.id)) return false;

        if (task.frame.stopId != null) {
          // Stop-owned frame: targeted update preserves localPath and metadata.
          // A link from Anitabi brings Anitabi's attribution (CC BY-NC-SA)
          // when the frame doesn't say where it's from.
          final takeAttribution =
              online != null && (task.frame.source?.trim().isEmpty ?? true) && (task.frame.sourceUrl?.trim().isEmpty ?? true);
          await (db.update(db.newReferenceImages)..where((r) => r.id.equals(task.frame.id))).write(
            NewReferenceImagesCompanion(
              remoteUrl: Value(remoteUrl),
              source: takeAttribution ? Value(online.source ?? 'Anitabi') : const Value.absent(),
              sourceUrl: takeAttribution ? Value(online.sourceUrl) : const Value.absent(),
            ),
          );
        } else {
          // Place-owned frame: leave the personal library row untouched; insert
          // a URL-backed copy scoped strictly to this trip stop.
          final stopRows = await (db.select(db.newReferenceImages)
                ..where((r) => r.stopId.equals(task.stop.id)))
              .get();
          final alreadyOnStop = stopRows.any(
            (r) => r.remoteUrl == remoteUrl || (r.localPath == localPath && localPath.isNotEmpty),
          );
          if (!alreadyOnStop) {
            await db.into(db.newReferenceImages).insert(
                  NewReferenceImagesCompanion.insert(
                    id: _uuid.v4(),
                    placeKey: const Value(null),
                    stopId: Value(task.stop.id),
                    localPath: Value(localPath),
                    remoteUrl: Value(remoteUrl),
                    animeLabelId: Value(task.frame.animeLabelId),
                    episode: Value(task.frame.episode),
                    timestampS: Value(task.frame.timestampS),
                    source: Value(task.frame.source ?? online?.source ?? (online != null ? 'Anitabi' : 'Google Drive')),
                    sourceUrl: Value(task.frame.sourceUrl ?? online?.sourceUrl ?? remoteUrl),
                  ),
                );
          }
        }

        await (db.update(db.stops)..where((s) => s.id.equals(task.stop.id) & s.tripId.equals(tripId))).write(
          StopsCompanion(
            updatedAt: Value(now),
            syncStatus: const Value(1),
          ),
        );
        return true;
      });
      if (!committed) return;

      committedUrls.add(remoteUrl);
      final uploadedFileId = uploadedFiles[remoteUrl];
      if (uploadedFileId != null) await _journal?.recordFile(uploadedFileId, tripId);
      touchedStopIds.add(task.stop.id);
      switch (resolved.how) {
        case _How.online:
          linkedOnline++;
        case _How.reused:
          reused++;
        case _How.uploaded:
          break; // counted from uploadedFiles at the end
      }
    }

    onProgress?.call(0, plan.pendingCount);

    var next = 0;
    Object? failure;
    StackTrace? failureStack;
    bool cancelled() => cancel?.isCancelled ?? false;

    Future<void> worker() async {
      while (failure == null && !cancelled() && next < plan.tasks.length) {
        final task = plan.tasks[next++];
        try {
          await runTask(task);
        } catch (e, st) {
          failure ??= e;
          failureStack ??= st;
          return;
        }
        done++;
        onProgress?.call(done, plan.pendingCount);
      }
    }

    try {
      await Future.wait([
        for (var i = 0; i < math.min(uploadConcurrency, plan.tasks.length); i++) worker(),
      ]);
    } finally {
      // Uploaded for a stop deleted meanwhile (or a commit that failed), and
      // used by no other frame.
      final tok = _cachedToken;
      for (final e in uploadedFiles.entries) {
        if (!committedUrls.contains(e.key) && tok != null) await _deleteDriveFileQuietly(tok, e.value);
      }
    }

    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    if (cancelled() && next < plan.tasks.length) throw const BackupCancelled();

    return DriveSyncSummary(
      uploaded: uploadedFiles.keys.where(committedUrls.contains).length,
      reused: reused,
      updatedStops: touchedStopIds.length,
      skippedMissing: skippedMissing,
      linkedOnline: linkedOnline,
    );
  }

  Future<String?> _tripTitle(AppDatabase db, String tripId) async =>
      (await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull())?.title;

  /// [hashSynced] reads every already-synced file to find identical bytes;
  /// counting doesn't need that.
  Future<_TripDriveSyncPlan> _buildSyncPlan(AppDatabase db, String tripId, {bool hashSynced = true}) async {
    final liveStops = await (db.select(db.stops)
          ..where((s) => s.tripId.equals(tripId) & s.deletedAt.isNull()))
        .get();
    if (liveStops.isEmpty) {
      return const _TripDriveSyncPlan(stops: [], tasks: [], existingUrlByPath: {}, existingUrlByHash: {});
    }

    final stopIds = {for (final s in liveStops) s.id};
    final placeKeys = {for (final s in liveStops) s.placeKey};

    final stopFrames = await (db.select(db.newReferenceImages)..where((r) => r.stopId.isIn(stopIds))).get();
    final placeFrames = await (db.select(db.newReferenceImages)..where((r) => r.placeKey.isIn(placeKeys))).get();

    final existingUrlByPath = <String, String>{};
    final existingUrlByHash = <String, String>{};
    final hashedPaths = <String>{};
    for (final f in stopFrames) {
      final path = f.localPath;
      final url = f.remoteUrl;
      if (path != null && path.isNotEmpty && url != null && url.isNotEmpty) {
        existingUrlByPath.putIfAbsent(path, () => url);
        if (hashSynced && hashedPaths.add(path)) {
          final bytes = await _readFile(path);
          if (bytes != null && bytes.isNotEmpty) {
            final hash = md5.convert(bytes).toString();
            existingUrlByHash.putIfAbsent(hash, () => url);
          }
        }
      }
    }

    final framesByStop = <String, List<NewReferenceImage>>{};
    final syncedPathsByStop = <String, Set<String>>{};
    for (final f in stopFrames) {
      final sid = f.stopId;
      if (sid == null) continue;
      if (isLocalOnlyFrame(f)) {
        framesByStop.putIfAbsent(sid, () => []).add(f);
      } else if (f.localPath != null && f.localPath!.isNotEmpty && (f.remoteUrl?.isNotEmpty ?? false)) {
        syncedPathsByStop.putIfAbsent(sid, () => {}).add(f.localPath!);
      }
    }

    final placeFramesByKey = <String, List<NewReferenceImage>>{};
    for (final f in placeFrames) {
      if (f.placeKey != null && isLocalOnlyFrame(f)) {
        placeFramesByKey.putIfAbsent(f.placeKey!, () => []).add(f);
      }
    }

    final tasks = <_DriveFrameTask>[];
    for (final stop in liveStops) {
      final seenLocalPaths = <String>{...?syncedPathsByStop[stop.id]};
      for (final f in [...?framesByStop[stop.id], ...?placeFramesByKey[stop.placeKey]]) {
        final path = f.localPath!;
        if (f.stopId == null && seenLocalPaths.contains(path)) continue;
        seenLocalPaths.add(path);
        tasks.add(_DriveFrameTask(stop: stop, frame: f));
      }
    }

    return _TripDriveSyncPlan(
      stops: liveStops,
      tasks: tasks,
      existingUrlByPath: existingUrlByPath,
      existingUrlByHash: existingUrlByHash,
    );
  }

  /// The files and folders the app created in this user's Drive, trashed ones
  /// included (a trashed file stays readable by link until it is deleted),
  /// optionally only those for [tripId]. With `drive.file` Drive lists only
  /// files this app created or opened; anything else that shows up is skipped
  /// unless it carries the app's own markers (a frame ID or trip ID app
  /// property, or the top folder's name).
  Future<List<DriveAppFile>> listAppFiles({String? tripId, bool interactive = false, BackupCancel? cancel}) async {
    final token = await _tokenFor(interactive: interactive);
    return _runWithAuthRetry(token, (activeToken) async {
      final out = <DriveAppFile>[];
      String? pageToken;
      do {
        final uri = Uri.parse('$_driveApi/files').replace(
          queryParameters: {
            if (tripId != null) 'q': "appProperties has { key='tripId' and value='${_quote(tripId)}' }",
            'fields': 'nextPageToken,files(id,name,mimeType,appProperties)',
            'spaces': 'drive',
            'pageSize': '1000',
            'pageToken': ?pageToken,
          },
        );
        final res = await _sendWithRetry(
          () => _client.get(uri, headers: {'Authorization': 'Bearer $activeToken'}).timeout(const Duration(seconds: 20)),
          cancel: cancel,
        );
        _throwIfError(res, 'Failed to list the frames on Google Drive');
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        for (final raw in (json['files'] as List?) ?? const []) {
          if (raw is! Map) continue;
          final id = raw['id'] as String?;
          if (id == null || id.isEmpty) continue;
          final props = raw['appProperties'] is Map ? raw['appProperties'] as Map : const {};
          final file = DriveAppFile(
            id: id,
            name: raw['name'] as String? ?? '',
            isFolder: raw['mimeType'] == _folderMime,
            tripId: props['tripId'] as String?,
            frameId: props['frameId'] as String?,
          );
          if (file.frameId != null || (file.isFolder && (file.tripId != null || file.isAppFolder))) out.add(file);
        }
        pageToken = json['nextPageToken'] as String?;
      } while (pageToken != null && pageToken.isNotEmpty);
      return out;
    });
  }

  /// Whether [fileId]'s link is gone for everyone: Drive answers 404 (or
  /// 410) to an anonymous request for it. Only the first byte is asked for.
  /// Anything else, such as the image, a quota page, or no network, counts
  /// as still there.
  Future<bool> isPublicLinkGone(String fileId) async {
    try {
      final req = http.Request('GET', Uri.parse(downloadUrlForFileId(fileId)))..headers['Range'] = 'bytes=0-0';
      final res = await _client.send(req).timeout(const Duration(seconds: 15));
      unawaited(res.stream.listen(null).cancel());
      return res.statusCode == 404 || res.statusCode == 410;
    } catch (_) {
      return false;
    }
  }

  /// Permanently deletes [fileId] (a folder with everything of this user's
  /// in it). Not trashed: Drive keeps a trashed file readable by everyone it
  /// was shared with until it is deleted for good.
  Future<DriveDeleteOutcome> deleteDriveFile(String fileId, {bool interactive = false, BackupCancel? cancel}) async {
    final token = await _tokenFor(interactive: interactive);
    return _runWithAuthRetry(token, (activeToken) async {
      final res = await _sendWithRetry(
        () => _client
            .delete(Uri.parse('$_driveApi/files/$fileId'), headers: {'Authorization': 'Bearer $activeToken'})
            .timeout(const Duration(seconds: 15)),
        cancel: cancel,
      );
      if (res.statusCode == 404) return DriveDeleteOutcome.notFound;
      if (res.statusCode == 403 && !_isRateLimit(res)) return DriveDeleteOutcome.forbidden;
      _throwIfError(res, 'Failed to delete a frame from Google Drive');
      return DriveDeleteOutcome.deleted;
    });
  }

  /// A 403 that means "slow down" rather than "not allowed".
  static bool _isRateLimit(http.Response res) =>
      res.body.contains('rateLimitExceeded') || res.body.contains('userRateLimitExceeded');

  /// A token for a call; without [interactive], one that never shows
  /// Google's sign-in (else [DriveAuthRequiredException]).
  Future<String> _tokenFor({required bool interactive}) async {
    if (interactive) return _ensureToken(interactive: true);
    try {
      return await _ensureToken(interactive: false);
    } on DriveAuthRequiredException {
      rethrow;
    } catch (e) {
      throw DriveAuthRequiredException(e);
    }
  }

  Future<String> _ensureToken({required bool interactive}) async {
    final refreshing = _refreshingToken;
    if (refreshing != null) return refreshing;
    final token = _cachedToken ?? await _getToken(interactive: interactive);
    _cachedToken = token;
    return token;
  }

  /// A new token after [staleToken] got a 401, fetched once for all the
  /// uploads in flight: whoever comes second gets the same one.
  Future<String> _refreshAfter401(String staleToken) {
    final current = _cachedToken;
    if (current != null && current != staleToken) return Future.value(current);
    return _refreshingToken ??= () async {
      try {
        _cachedToken = null;
        // Possibly another account now: look its folders up again.
        _rootFolder = null;
        _tripFolders.clear();
        final String refreshed;
        try {
          refreshed = await _getToken(interactive: false);
        } catch (refreshError) {
          throw DriveAuthRequiredException(refreshError);
        }
        _cachedToken = refreshed;
        return refreshed;
      } finally {
        _refreshingToken = null;
      }
    }();
  }

  Future<T> _runWithAuthRetry<T>(String initialToken, Future<T> Function(String token) op) async {
    try {
      return await op(initialToken);
    } on GoogleDriveUploadException catch (e) {
      if (e.statusCode != 401) rethrow;
      final refreshed = await _refreshAfter401(initialToken);
      try {
        return await op(refreshed);
      } on GoogleDriveUploadException catch (again) {
        if (again.statusCode == 401) {
          _cachedToken = null;
          throw DriveAuthRequiredException(again);
        }
        rethrow;
      }
    }
  }

  static bool _isRetryableStatus(int code) => code == 429 || code == 500 || code == 502 || code == 503 || code == 504;

  static bool _isNetworkError(Object e) => e is IOException || e is http.ClientException || e is TimeoutException;

  /// Sends a request to a Google endpoint, retrying after [retryDelays] when
  /// the connection drops (e.g. "Software caused connection abort" as the
  /// phone sleeps) or Google answers 429/5xx.
  Future<http.Response> _sendWithRetry(Future<http.Response> Function() send, {BackupCancel? cancel}) async {
    for (var attempt = 0;; attempt++) {
      final canRetry = attempt < retryDelays.length;
      try {
        final res = await send();
        if (!canRetry || !_isRetryableStatus(res.statusCode)) return res;
        debugPrint('[GoogleDriveFrameService] HTTP ${res.statusCode}; retrying');
      } catch (e) {
        if (!canRetry || !_isNetworkError(e)) rethrow;
        debugPrint('[GoogleDriveFrameService] $e; retrying');
      }
      if (cancel?.isCancelled ?? false) throw const BackupCancelled();
      await _sleep(retryDelays[attempt]);
      if (cancel?.isCancelled ?? false) throw const BackupCancelled();
    }
  }

  /// The app's top folder, [appFolderName] (looked up or created once).
  Future<String> _ensureFolderId(String token, {BackupCancel? cancel}) {
    final known = _rootFolder;
    if (known != null) return known;
    final lookup = _findOrCreateRootFolder(token, cancel: cancel);
    _rootFolder = lookup;
    lookup.then((_) {}, onError: (Object _) {
      if (identical(_rootFolder, lookup)) _rootFolder = null;
    });
    return lookup;
  }

  /// [tripId]'s folder inside the app's folder, shared "anyone with the link
  /// can view" (looked up or created once).
  Future<String> _ensureTripFolderId(String token, String tripId, String? tripTitle, {BackupCancel? cancel}) {
    final known = _tripFolders[tripId];
    if (known != null) return known;
    final lookup = _findOrCreateTripFolder(token, tripId, tripTitle, cancel: cancel);
    _tripFolders[tripId] = lookup;
    lookup.then((_) {}, onError: (Object _) {
      if (identical(_tripFolders[tripId], lookup)) _tripFolders.remove(tripId);
    });
    return lookup;
  }

  Future<String> _findOrCreateRootFolder(String token, {BackupCancel? cancel}) async {
    const query = "name = '$appFolderName' and mimeType = '$_folderMime' and trashed = false";
    final found = await _findFolder(token, query, cancel: cancel);
    if (found != null) return found.id;
    return _createFolder(token, {'name': appFolderName, 'mimeType': _folderMime}, cancel: cancel);
  }

  /// Found by its `tripId` app property, so renaming the trip (or the folder)
  /// doesn't matter. `drive.file` lets the app see and share the folders and
  /// files it created, on any of the user's devices.
  Future<String> _findOrCreateTripFolder(String token, String tripId, String? tripTitle, {BackupCancel? cancel}) async {
    final rootId = await _ensureFolderId(token, cancel: cancel);
    final query = "'${_quote(rootId)}' in parents and mimeType = '$_folderMime' and "
        "appProperties has { key='tripId' and value='${_quote(tripId)}' } and trashed = false";
    final found = await _findFolder(token, query, cancel: cancel);
    if (found != null) {
      // Created by an earlier run whose sharing step failed, or unshared by
      // hand: share it (again).
      if (!found.linkShared) await _grantAnyoneReaderPermission(token, found.id, cancel: cancel);
      await _journal?.recordFolder(found.id, tripId);
      return found.id;
    }
    final title = tripTitle?.trim() ?? '';
    final name = title.isEmpty || title == appFolderName ? 'Trip $tripId' : title;
    final folderId = await _createFolder(
      token,
      {
        'name': name,
        'mimeType': _folderMime,
        'parents': [rootId],
        'appProperties': {'tripId': tripId},
      },
      cancel: cancel,
    );
    try {
      await _grantAnyoneReaderPermission(token, folderId, cancel: cancel);
    } catch (_) {
      // An unshared trip folder would make every upload into it unreadable.
      await _deleteDriveFileQuietly(token, folderId);
      rethrow;
    }
    await _journal?.recordFolder(folderId, tripId);
    return folderId;
  }

  /// Escapes [value] for a single-quoted string in a Drive search query.
  static String _quote(String value) => value.replaceAll(r'\', r'\').replaceAll("'", r"\'");

  Future<({String id, bool linkShared})?> _findFolder(String token, String query, {BackupCancel? cancel}) async {
    final searchUri = Uri.parse('$_driveApi/files').replace(
      queryParameters: {
        'q': query,
        'fields': 'files(id,permissions(type,role))',
        'spaces': 'drive',
        'pageSize': '1',
      },
    );
    final searchRes = await _sendWithRetry(
      () => _client.get(searchUri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15)),
      cancel: cancel,
    );
    _throwIfError(searchRes, 'Failed to look up Google Drive folder');
    final searchJson = jsonDecode(searchRes.body) as Map<String, dynamic>;
    final files = (searchJson['files'] as List?) ?? const [];
    if (files.isEmpty) return null;
    final file = files.first as Map;
    final id = file['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return (id: id, linkShared: _anyoneCanRead(file['permissions']));
  }

  Future<String> _createFolder(String token, Map<String, Object> metadata, {BackupCancel? cancel}) async {
    final createRes = await _sendWithRetry(
      () => _client
          .post(
            Uri.parse('$_driveApi/files?fields=id'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(metadata),
          )
          .timeout(const Duration(seconds: 15)),
      cancel: cancel,
    );
    _throwIfError(createRes, 'Failed to create Google Drive folder');
    final createJson = jsonDecode(createRes.body) as Map<String, dynamic>;
    final folderId = createJson['id'] as String?;
    if (folderId == null || folderId.isEmpty) {
      throw const GoogleDriveUploadException('Google Drive returned an empty folder ID.');
    }
    return folderId;
  }

  /// Whether a Drive `permissions` list lets anyone with the link read.
  static bool _anyoneCanRead(Object? permissions) =>
      permissions is List &&
      permissions.any(
        (p) => p is Map && p['type'] == 'anyone' && const {'reader', 'commenter', 'writer'}.contains(p['role']),
      );

  /// Uploads [bytes] as a new file in [folderId]. [linkShared] tells whether
  /// Drive reports the file readable by anyone with the link already
  /// (inherited from the folder); if not, the caller shares it on its own.
  Future<({String fileId, bool linkShared})> _multipartUpload({
    BackupCancel? cancel,
    required String token,
    required String folderId,
    required String fileName,
    required Uint8List bytes,
    required Map<String, String> appProperties,
  }) async {
    final boundary = 'trip_planner_${_uuid.v4().replaceAll('-', '')}';
    final metaJson = jsonEncode({
      'name': fileName,
      'parents': [folderId],
      'appProperties': appProperties,
    });

    final builder = BytesBuilder(copy: false)
      ..add(utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'))
      ..add(utf8.encode(metaJson))
      ..add(utf8.encode('\r\n--$boundary\r\nContent-Type: ${uploadType(bytes).$1}\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final payload = builder.takeBytes();

    final res = await _sendWithRetry(
      () => _client
          .post(
            Uri.parse('$_driveUploadApi/files?uploadType=multipart&fields=id,permissions(type,role)'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'multipart/related; boundary=$boundary',
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 30)),
      cancel: cancel,
    );
    _throwIfError(res, 'Failed to upload frame image to Google Drive');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final id = body['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const GoogleDriveUploadException('Google Drive upload returned no file ID.');
    }
    return (fileId: id, linkShared: _anyoneCanRead(body['permissions']));
  }

  Future<void> _grantAnyoneReaderPermission(String token, String fileId, {BackupCancel? cancel}) async {
    final res = await _sendWithRetry(
      () => _client
          .post(
            Uri.parse('$_driveApi/files/$fileId/permissions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode({'role': 'reader', 'type': 'anyone'}),
          )
          .timeout(const Duration(seconds: 15)),
      cancel: cancel,
    );
    _throwIfError(res, 'Failed to create a shareable link in Google Drive');
  }

  Future<void> _deleteDriveFileQuietly(String token, String fileId) async {
    try {
      await _client
          .delete(
            Uri.parse('$_driveApi/files/$fileId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  void _throwIfError(http.Response res, String action) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw GoogleDriveUploadException('$action (HTTP ${res.statusCode}).', statusCode: res.statusCode);
  }
}

class _TripDriveSyncPlan {
  final List<Stop> stops;
  final List<_DriveFrameTask> tasks;
  final Map<String, String> existingUrlByPath;
  final Map<String, String> existingUrlByHash;

  const _TripDriveSyncPlan({
    required this.stops,
    required this.tasks,
    required this.existingUrlByPath,
    required this.existingUrlByHash,
  });

  int get pendingCount => tasks.length;
}

class _DriveFrameTask {
  final Stop stop;
  final NewReferenceImage frame;

  const _DriveFrameTask({
    required this.stop,
    required this.frame,
  });
}

enum _How { uploaded, reused, online }

/// The link a frame gets, and how it came by it.
class _Resolved {
  final String url;
  final _How how;

  const _Resolved(this.url, this.how);
}
