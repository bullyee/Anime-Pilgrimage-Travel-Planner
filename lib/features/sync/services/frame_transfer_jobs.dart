import 'dart:io';

import '../../../core/database/database.dart';
import '../../../core/utils/archive_isolate.dart';
import '../../auth/providers/auth_provider.dart' show AuthCancelledException;
import '../../trip/services/trip_frames_pack_service.dart';
import 'frame_transfer_queue.dart';
import 'google_drive_frame_service.dart';
import 'trip_frame_downloader.dart';

/// #158's rule: only a shared trip's owner and editors put frames on Drive
/// for it (a viewer's stop changes would never sync, and a private trip has
/// nobody to share them with).
bool canUploadTripFramesToDrive(Trip trip, {required bool canEdit}) => trip.sharing == 'group' && canEdit;

void _checkCanUpload(Trip trip, bool canEdit) {
  if (!canUploadTripFramesToDrive(trip, canEdit: canEdit)) {
    throw StateError('Only owners and editors of a shared trip can upload frames via Google Drive.');
  }
}

const _needsSignIn = 'Google Drive needs you to sign in again. Open the trip and tap Resume to continue.';

/// Runs [attempt]; when Drive needs the user again, asks Google once more
/// while the app is on screen, else ends the job for the user to resume.
Future<T> _withDriveAuth<T>(GoogleDriveFrameService drive, TransferContext ctx, Future<T> Function() attempt) async {
  try {
    return await attempt();
  } on DriveAuthRequiredException catch (e) {
    if (!ctx.isAppVisible()) throw TransferNeedsUserException(_needsSignIn, cause: e);
    try {
      await drive.prepareToken();
    } on AuthCancelledException {
      throw const BackupCancelled();
    } catch (authError) {
      throw TransferNeedsUserException(_needsSignIn, cause: authError);
    }
    try {
      return await attempt();
    } on DriveAuthRequiredException catch (again) {
      throw TransferNeedsUserException(_needsSignIn, cause: again);
    }
  }
}

/// Uploads [trip]'s local-only frames to the user's Google Drive
/// ([GoogleDriveFrameService.syncTripLocalFrames]: library rows stay as they
/// are, links go on stop-scoped rows). Get the token with
/// [GoogleDriveFrameService.prepareToken] before queueing it.
TransferJobSpec driveUploadJob({
  required AppDatabase db,
  required GoogleDriveFrameService drive,
  required Trip trip,
  required bool canEdit,
}) {
  _checkCanUpload(trip, canEdit);
  return TransferJobSpec(
    kind: TransferKind.driveUpload,
    tripId: trip.id,
    tripTitle: trip.title,
    journaled: true,
    run: (ctx) async {
      final summary = await _withDriveAuth(
        drive,
        ctx,
        () => drive.syncTripLocalFrames(
          db,
          tripId: trip.id,
          onProgress: ctx.progress,
          cancel: ctx.cancel,
          interactive: false,
        ),
      );
      return driveSyncSummaryText(summary);
    },
  );
}

/// Uploads photos already copied to [localPaths] onto [stopId]. A file not
/// uploaded (failure or cancel) has its local copy deleted, as before.
TransferJobSpec stopUploadJob({
  required AppDatabase db,
  required GoogleDriveFrameService drive,
  required Trip trip,
  required bool canEdit,
  required String stopId,
  required List<String> localPaths,
}) {
  _checkCanUpload(trip, canEdit);
  return TransferJobSpec(
    kind: TransferKind.stopUpload,
    tripId: trip.id,
    tripTitle: trip.title,
    dedupe: false,
    run: (ctx) async {
      var count = 0;
      ctx.progress(0, localPaths.length);
      try {
        for (final path in localPaths) {
          if (ctx.cancel.isCancelled) throw const BackupCancelled();
          await _withDriveAuth(
            drive,
            ctx,
            () => drive.uploadNewStopFrame(db, tripId: trip.id, stopId: stopId, localPath: path, interactive: false),
          );
          count++;
          ctx.progress(count, localPaths.length);
        }
      } finally {
        for (final path in localPaths.skip(count)) {
          try {
            await File(path).delete();
          } catch (_) {}
        }
      }
      return 'Uploaded $count ${count == 1 ? 'frame' : 'frames'} to Google Drive and queued for sync.';
    },
  );
}

/// Downloads [tripId]'s linked frames that aren't on this phone into the
/// thumbnail cache. [include] narrows the links (automatic runs take Drive
/// links only); [onUrls] sees the list before it starts.
TransferJobSpec frameDownloadJob({
  required AppDatabase db,
  required TripFrameDownloader downloader,
  required String tripId,
  required String tripTitle,
  bool Function(String url)? include,
  void Function(List<String> urls)? onUrls,
  bool journaled = true,
  bool quiet = false,
}) {
  return TransferJobSpec(
    kind: TransferKind.download,
    tripId: tripId,
    tripTitle: tripTitle,
    journaled: journaled,
    quiet: quiet,
    run: (ctx) async {
      final urls = await downloader.pendingUrls(db, tripId, include: include);
      onUrls?.call(urls);
      if (urls.isEmpty) return 'Every frame in "$tripTitle" is already on this phone.';
      final summary = await downloader.download(urls, onProgress: ctx.progress, cancel: ctx.cancel);
      return summary.text;
    },
  );
}

/// Imports a `.pilgrimage-frames` pack onto [trip].
TransferJobSpec framesPackImportJob({
  required AppDatabase db,
  required TripFramesPackService packs,
  required Trip trip,
  required File zip,
}) {
  return TransferJobSpec(
    kind: TransferKind.packImport,
    tripId: trip.id,
    tripTitle: trip.title,
    dedupe: false,
    run: (ctx) async {
      final summary = await packs.importFramesPack(
        db,
        tripId: trip.id,
        zip: zip,
        onProgress: ctx.progress,
        cancel: ctx.cancel,
      );
      return tripFramesImportSummaryText(summary);
    },
  );
}

String tripFramesImportSummaryText(TripFramesImportSummary s) {
  final parts = <String>[
    s.framesAdded == 0
        ? 'No new frames added.'
        : 'Added ${s.framesAdded} ${s.framesAdded == 1 ? 'frame' : 'frames'} to this trip.',
    if (s.alreadyPresent > 0)
      '${s.alreadyPresent} ${s.alreadyPresent == 1 ? 'frame was' : 'frames were'} already here.',
    if (s.unmatchedStops > 0)
      '${s.unmatchedStops} ${s.unmatchedStops == 1 ? 'entry' : 'entries'} skipped because the stop is not in this trip.',
  ];
  return parts.join(' ');
}

String driveSyncSummaryText(DriveSyncSummary s) {
  final parts = <String>[
    if (s.uploaded > 0) 'Uploaded ${s.uploaded} ${s.uploaded == 1 ? 'frame' : 'frames'} to Google Drive.',
    if (s.reused > 0) 'Reused ${s.reused} already-uploaded ${s.reused == 1 ? 'image' : 'images'}.',
    if (s.updatedStops > 0) 'Updated ${s.updatedStops} ${s.updatedStops == 1 ? 'stop' : 'stops'} for group sync.',
    if (s.skippedMissing > 0)
      '${s.skippedMissing} ${s.skippedMissing == 1 ? 'frame was' : 'frames were'} skipped because the file is missing on this phone.',
  ];
  return parts.isEmpty ? 'No frames needed uploading.' : parts.join(' ');
}
