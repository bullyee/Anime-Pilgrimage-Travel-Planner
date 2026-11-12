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

  String? _cachedToken;
  String? _cachedFolderId;

  GoogleDriveFrameService({
    http.Client? client,
    required DriveTokenFetcher getToken,
    DriveImageCompressor? compress,
    DriveFileReader? readFile,
  })  : _client = client ?? http.Client(),
        _getToken = getToken,
        _compress = compress ?? compressForDriveUpload,
        _readFile = readFile ?? _defaultReadFile;

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
    final plan = await _buildSyncPlan(db, tripId);
    return plan.pendingCount;
  }

  /// Uploads [rawBytes] into the app's Google Drive folder, shares it read-only by
  /// link so trip collaborators can download it, and returns the resulting file metadata.
  Future<GoogleDriveUploadedFile> uploadImageBytes({
    required Uint8List rawBytes,
    required String frameId,
    String? tripId,
    String? stopId,
  }) async {
    final jpegBytes = await _compress(rawBytes);
    final token = await _ensureToken(interactive: true);
    return _runWithAuthRetry(token, (activeToken) async {
      final folderId = await _ensureFolderId(activeToken);
      final fileId = await _multipartUpload(
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
        await _grantAnyoneReaderPermission(activeToken, fileId);
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
  }) async {
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
    );

    final now = DateTime.now();
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
    return (await (db.select(db.newReferenceImages)..where((r) => r.id.equals(frameId))).getSingle());
  }

  /// Uploads all local-only frames on [tripId]'s live stops to the current user's
  /// Google Drive, writes back `remoteUrl`, and marks affected stops dirty so
  /// collaborators receive them on Firestore sync.
  ///
  /// Frames backed by identical image bytes are uploaded once and reused across
  /// matching rows. Each finished stop commits incrementally so cancelling mid-way
  /// preserves completed uploads.
  Future<DriveSyncSummary> syncTripLocalFrames(
    AppDatabase db, {
    required String tripId,
    BackupProgress? onProgress,
    BackupCancel? cancel,
  }) async {
    final plan = await _buildSyncPlan(db, tripId);
    if (plan.pendingCount == 0) {
      return const DriveSyncSummary(uploaded: 0, reused: 0, updatedStops: 0, skippedMissing: 0);
    }

    // Request Drive OAuth consent upfront before starting progress work.
    await _ensureToken(interactive: true);

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
          final res = await uploadImageBytes(
            rawBytes: bytes,
            frameId: task.frame.id,
            tripId: tripId,
            stopId: task.stop.id,
          );
          url = res.downloadUrl;
          hashToUrl[hash] = url;
          uploaded++;
        }
        pathToUrl[localPath] = url;
      } else {
        reused++;
      }

      if (cancel?.isCancelled ?? false) throw const BackupCancelled();

      final remoteUrl = url;
      final now = DateTime.now();
      await db.transaction(() async {
        final stopStillLive = await (db.select(db.stops)
              ..where((s) => s.id.equals(task.stop.id) & s.tripId.equals(tripId) & s.deletedAt.isNull()))
            .getSingleOrNull();
        if (stopStillLive == null) return;

        // Targeted update preserves all other columns (localPath, episode, timestamps, etc.).
        await (db.update(db.newReferenceImages)..where((r) => r.id.equals(task.frame.id))).write(
          NewReferenceImagesCompanion(remoteUrl: Value(remoteUrl)),
        );

        // If this frame originated only on the user's Place, also ensure the stop owns a
        // URL-backed row so Firestore pushes it to collaborators.
        if (task.frame.stopId == null) {
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
      });

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

  Future<_TripDriveSyncPlan> _buildSyncPlan(AppDatabase db, String tripId) async {
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
    void recordKnownUrl(NewReferenceImage f) {
      final path = f.localPath;
      final url = f.remoteUrl;
      if (path != null && path.isNotEmpty && url != null && url.isNotEmpty) {
        existingUrlByPath.putIfAbsent(path, () => url);
      }
    }

    for (final f in stopFrames) {
      recordKnownUrl(f);
    }
    for (final f in placeFrames) {
      recordKnownUrl(f);
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
      final refreshed = await _getToken(interactive: false);
      _cachedToken = refreshed;
      return op(refreshed);
    }
  }

  Future<String> _ensureFolderId(String token) async {
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
    final searchRes = await _client
        .get(searchUri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));
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

    final createRes = await _client
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
        .timeout(const Duration(seconds: 15));
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

    final res = await _client
        .post(
          Uri.parse('$_driveUploadApi/files?uploadType=multipart&fields=id'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: builder.takeBytes(),
        )
        .timeout(const Duration(seconds: 30));
    _throwIfError(res, 'Failed to upload frame image to Google Drive');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final id = body['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const GoogleDriveUploadException('Google Drive upload returned no file ID.');
    }
    return id;
  }

  Future<void> _grantAnyoneReaderPermission(String token, String fileId) async {
    final res = await _client
        .post(
          Uri.parse('$_driveApi/files/$fileId/permissions'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode({'role': 'reader', 'type': 'anyone'}),
        )
        .timeout(const Duration(seconds: 15));
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
