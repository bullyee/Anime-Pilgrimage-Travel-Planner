import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
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

  const DriveSyncSummary({
    required this.uploaded,
    required this.reused,
    required this.updatedStops,
    required this.skippedMissing,
  });
}

typedef DriveTokenFetcher = Future<String> Function({bool interactive});
typedef DriveImageCompressor = Future<Uint8List> Function(Uint8List rawBytes);
typedef DriveFileReader = Future<Uint8List?> Function(String path);
typedef DriveSleep = Future<void> Function(Duration delay);

/// Uploads local-only anime reference frames to the signed-in user's own Google
/// Drive using the non-sensitive `drive.file` scope, grants link-read access so
/// trip collaborators can cache them, and writes back `remoteUrl` without using
/// Firebase Storage or Blaze billing.
class GoogleDriveFrameService {
  static const appFolderName = 'Trip Planner Shared Frames';
  static const maxUploadDimension = 1280;
  static const jpegQuality = 82;
  static const _driveApi = 'https://www.googleapis.com/drive/v3';
  static const _driveUploadApi = 'https://www.googleapis.com/upload/drive/v3';
  static const _uuid = Uuid();

  final http.Client _client;
  final DriveTokenFetcher _getToken;
  final DriveImageCompressor _compress;
  final DriveFileReader _readFile;
  final DriveSleep _sleep;

  /// Waits between attempts when a Google endpoint drops the connection or
  /// answers 429/5xx; one retry per entry. (Google only: never applied to
  /// Anitabi.)
  final List<Duration> retryDelays;

  String? _cachedToken;
  String? _cachedFolderId;

  GoogleDriveFrameService({
    http.Client? client,
    required DriveTokenFetcher getToken,
    DriveImageCompressor? compress,
    DriveFileReader? readFile,
    DriveSleep? sleep,
    this.retryDelays = const [Duration(seconds: 2), Duration(seconds: 6), Duration(seconds: 15)],
  })  : _client = client ?? http.Client(),
        _getToken = getToken,
        _compress = compress ?? compressForDriveUpload,
        _readFile = readFile ?? _defaultReadFile,
        _sleep = sleep ?? Future<void>.delayed;

  /// Canonical direct-download URL stored on synced `NewReferenceImages.remoteUrl`.
  static String downloadUrlForFileId(String fileId) =>
      'https://drive.google.com/uc?export=download&id=$fileId';

  /// Compresses and resizes an image to a lightweight JPEG (max [maxUploadDimension]
  /// on its longest edge) so uploads stay fast and modest in Google Drive quota.
  static Future<Uint8List> compressForDriveUpload(Uint8List rawBytes) {
    if (kIsWeb) {
      return Future.value(_encodeDriveJpeg(rawBytes));
    }
    return Isolate.run(() => _encodeDriveJpeg(rawBytes));
  }

  static Uint8List _encodeDriveJpeg(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      return rawBytes;
    }
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = longest > maxUploadDimension
        ? (decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxUploadDimension, interpolation: img.Interpolation.average)
            : img.copyResize(decoded, height: maxUploadDimension, interpolation: img.Interpolation.average))
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
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

  /// Uploads [rawBytes] into the app's Google Drive folder, shares it read-only by
  /// link so trip collaborators can download it, and returns the resulting file metadata.
  Future<GoogleDriveUploadedFile> uploadImageBytes({
    required Uint8List rawBytes,
    required String frameId,
    String? tripId,
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
      final folderId = await _ensureFolderId(activeToken, cancel: cancel);
      final fileId = await _multipartUpload(
        cancel: cancel,
        token: activeToken,
        folderId: folderId,
        fileName: 'frame_$frameId.jpg',
        bytes: jpegBytes,
        appProperties: {
          'tripId': ?tripId,
          'stopId': ?stopId,
          'frameId': frameId,
        },
      );
      try {
        await _grantAnyoneReaderPermission(activeToken, fileId, cancel: cancel);
      } catch (e) {
        // Avoid leaving private unshareable orphan files in Drive on permission failure.
        await _deleteDriveFileQuietly(activeToken, fileId);
        rethrow;
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
    return (await (db.select(db.newReferenceImages)..where((r) => r.id.equals(frameId))).getSingle());
  }

  /// Uploads all local-only frames on [tripId]'s live stops to the current user's
  /// Google Drive, writes back `remoteUrl`, and marks affected stops dirty so
  /// collaborators receive them on Firestore sync.
  ///
  /// When a local frame originates from a library place (`stopId == null`), the
  /// personal library row is left untouched and only a stop-scoped copy receives
  /// the Drive link. Frames backed by identical image bytes upload once and reuse
  /// the link within the trip. Each finished stop commits before checking cancel
  /// for the next upload so already-uploaded Drive files are never orphaned.
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

    var uploaded = 0;
    var reused = 0;
    var skippedMissing = 0;
    var done = 0;
    final touchedStopIds = <String>{};
    final hashToUrl = Map<String, String>.from(plan.existingUrlByHash);
    final pathToUrl = Map<String, String>.from(plan.existingUrlByPath);

    onProgress?.call(0, plan.pendingCount);

    for (final task in plan.tasks) {
      if (cancel?.isCancelled ?? false) throw const BackupCancelled();

      final localPath = task.frame.localPath!;
      String? url = pathToUrl[localPath];
      String? newlyUploadedFileId;
      var countedAsUpload = false;

      if (url == null) {
        final bytes = await _readFile(localPath);
        if (bytes == null || bytes.isEmpty) {
          skippedMissing++;
          done++;
          onProgress?.call(done, plan.pendingCount);
          continue;
        }
        final hash = md5.convert(bytes).toString();
        url = hashToUrl[hash];
        if (url != null) {
          reused++;
        } else {
          final stopBeforeUpload = await (db.select(db.stops)
                ..where((s) => s.id.equals(task.stop.id) & s.tripId.equals(tripId) & s.deletedAt.isNull()))
              .getSingleOrNull();
          if (stopBeforeUpload == null) {
            done++;
            onProgress?.call(done, plan.pendingCount);
            continue;
          }
          final res = await uploadImageBytes(
            rawBytes: bytes,
            frameId: task.frame.id,
            tripId: tripId,
            stopId: task.stop.id,
            interactive: interactive,
            cancel: cancel,
          );
          url = res.downloadUrl;
          newlyUploadedFileId = res.fileId;
          hashToUrl[hash] = url;
          countedAsUpload = true;
          uploaded++;
        }
        pathToUrl[localPath] = url;
      } else {
        reused++;
      }

      final remoteUrl = url;
      final now = DateTime.now();
      final committed = await db.transaction(() async {
        final stopStillLive = await (db.select(db.stops)
              ..where((s) => s.id.equals(task.stop.id) & s.tripId.equals(tripId) & s.deletedAt.isNull()))
            .getSingleOrNull();
        if (stopStillLive == null) return false;

        if (task.frame.stopId != null) {
          // Stop-owned frame: targeted update preserves localPath and metadata.
          await (db.update(db.newReferenceImages)..where((r) => r.id.equals(task.frame.id))).write(
            NewReferenceImagesCompanion(remoteUrl: Value(remoteUrl)),
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
                    source: Value(task.frame.source ?? 'Google Drive'),
                    sourceUrl: Value(task.frame.sourceUrl ?? remoteUrl),
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

      if (!committed) {
        if (newlyUploadedFileId != null) {
          final tok = _cachedToken;
          if (tok != null) await _deleteDriveFileQuietly(tok, newlyUploadedFileId);
          if (countedAsUpload) uploaded--;
        }
        done++;
        onProgress?.call(done, plan.pendingCount);
        continue;
      }

      touchedStopIds.add(task.stop.id);
      done++;
      onProgress?.call(done, plan.pendingCount);
    }

    return DriveSyncSummary(
      uploaded: uploaded,
      reused: reused,
      updatedStops: touchedStopIds.length,
      skippedMissing: skippedMissing,
    );
  }

  /// [hashSynced] reads every already-synced file to find identical bytes;
  /// counting doesn't need that.
  Future<_TripDriveSyncPlan> _buildSyncPlan(AppDatabase db, String tripId, {bool hashSynced = true}) async {
    final liveStops = await (db.select(db.stops)
          ..where((s) => s.tripId.equals(tripId) & s.deletedAt.isNull()))
        .get();
    if (liveStops.isEmpty) {
      return const _TripDriveSyncPlan(tasks: [], existingUrlByPath: {}, existingUrlByHash: {});
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
      tasks: tasks,
      existingUrlByPath: existingUrlByPath,
      existingUrlByHash: existingUrlByHash,
    );
  }

  Future<String> _ensureToken({required bool interactive}) async {
    final token = _cachedToken ?? await _getToken(interactive: interactive);
    _cachedToken = token;
    return token;
  }

  Future<T> _runWithAuthRetry<T>(String initialToken, Future<T> Function(String token) op) async {
    try {
      return await op(initialToken);
    } on GoogleDriveUploadException catch (e) {
      if (e.statusCode != 401) rethrow;
      _cachedToken = null;
      _cachedFolderId = null;
      final String refreshed;
      try {
        refreshed = await _getToken(interactive: false);
      } catch (refreshError) {
        throw DriveAuthRequiredException(refreshError);
      }
      _cachedToken = refreshed;
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

  Future<String> _ensureFolderId(String token, {BackupCancel? cancel}) async {
    if (_cachedFolderId != null) return _cachedFolderId!;
    const query =
        "name = '$appFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final searchUri = Uri.parse('$_driveApi/files').replace(
      queryParameters: {
        'q': query,
        'fields': 'files(id)',
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
    if (files.isNotEmpty) {
      final id = (files.first as Map)['id'] as String?;
      if (id != null && id.isNotEmpty) {
        _cachedFolderId = id;
        return id;
      }
    }

    final createRes = await _sendWithRetry(
      () => _client
          .post(
            Uri.parse('$_driveApi/files?fields=id'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode({
              'name': appFolderName,
              'mimeType': 'application/vnd.google-apps.folder',
            }),
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
    _cachedFolderId = folderId;
    return folderId;
  }

  Future<String> _multipartUpload({
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
      ..add(utf8.encode('\r\n--$boundary\r\nContent-Type: image/jpeg\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final payload = builder.takeBytes();

    final res = await _sendWithRetry(
      () => _client
          .post(
            Uri.parse('$_driveUploadApi/files?uploadType=multipart&fields=id'),
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
    return id;
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
    _throwIfError(res, 'Uploaded file, but failed to create a shareable link in Google Drive');
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
  final List<_DriveFrameTask> tasks;
  final Map<String, String> existingUrlByPath;
  final Map<String, String> existingUrlByHash;

  const _TripDriveSyncPlan({
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
