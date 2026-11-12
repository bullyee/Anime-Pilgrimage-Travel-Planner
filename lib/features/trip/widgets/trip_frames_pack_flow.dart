import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/archive_isolate.dart';
import '../../auth/providers/auth_provider.dart';
import '../../library/providers/place_providers.dart' show placeRepositoryProvider;
import '../../library/widgets/library_backup_flow.dart';
import '../../sharing/providers/group_sharing_providers.dart' show canEditTripProvider, guestUserId;
import '../../sync/services/google_drive_frame_service.dart';
import '../services/trip_frames_pack_service.dart';

final tripFramesPackServiceProvider = Provider<TripFramesPackService>((ref) => const TripFramesPackService());

final googleDriveFrameServiceProvider = Provider<GoogleDriveFrameService>((ref) {
  ref.watch(currentUserIdProvider);
  return GoogleDriveFrameService(
    getToken: ref.watch(driveAccessTokenProvider),
  );
});

/// Members tab → Share local frames: exports only the local-only stop frames in [trip]
/// into a `.pilgrimage-frames` file and hands it to the system share sheet.
Future<void> shareTripLocalFrames(BuildContext context, WidgetRef ref, Trip trip) async {
  final svc = ref.read(tripFramesPackServiceProvider);
  final db = ref.read(databaseProvider);
  final TripFramesPackContents contents;
  try {
    contents = await svc.describeExport(db, trip.id);
  } on BackupFormatException catch (e) {
    if (context.mounted) await tellArchiveMessage(context, "Can't prepare frames pack", e.message);
    return;
  }
  if (!context.mounted) return;
  if (contents.frames == 0) {
    await tellArchiveMessage(
      context,
      'No local-only frames',
      'Every frame in "${trip.title}" already has an image link or is not on this device.',
    );
    return;
  }

  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Share local frames'),
      content: Text(
        '${contents.frames} ${contents.frames == 1 ? 'frame' : 'frames'} across '
        '${contents.stops} ${contents.stops == 1 ? 'stop' : 'stops'}, about ${formatBytes(contents.bytes)}.\n\n'
        'Only frames stored on this device without an image link are included. '
        'Send the file to your trip members so they can import them.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Export & share')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  final dir = await ref.read(backupFolderProvider)();
  for (final old in dir.listSync().whereType<File>()) {
    try {
      old.deleteSync();
    } catch (_) {}
  }
  final slug = _safeFileSlug(trip.title);
  final name = '$slug-frames.${TripFramesPackService.fileExtension}';
  if (!context.mounted) return;
  final file = await runArchiveWithProgress<File>(
    context,
    title: 'Packing frames',
    failure: "Couldn't export frames",
    run: (onProgress, cancel) => svc.exportFramesPack(
      db,
      tripId: trip.id,
      targetPath: p.join(dir.path, name),
      onProgress: onProgress,
      cancel: cancel,
    ),
  );
  if (file == null) return;
  await ref.read(shareBackupFileProvider)(file.path);
}

/// Members tab → Import local frames: picks a `.pilgrimage-frames` file and attaches
/// its frames to matching stops of [trip].
Future<void> importTripLocalFrames(BuildContext context, WidgetRef ref, Trip trip) async {
  final svc = ref.read(tripFramesPackServiceProvider);
  final path = await ref.read(pickBackupFileProvider)();
  if (path == null || !context.mounted) return;
  final TripFramesPackContents contents;
  try {
    contents = await svc.readContents(File(path));
  } on BackupFormatException catch (e) {
    if (context.mounted) await tellArchiveMessage(context, "Can't read this frame pack", e.message);
    return;
  }
  if (!context.mounted) return;

  final otherTrip = contents.tripId.isNotEmpty && contents.tripId != trip.id;
  final when = contents.exportedAt;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Import local frames?'),
      content: Text(
        '${when == null ? 'From' : 'Exported on ${MaterialLocalizations.of(context).formatMediumDate(when)}, ${when.year} from'} '
        '"${contents.tripTitle}": ${contents.frames} ${contents.frames == 1 ? 'frame' : 'frames'} '
        'for ${contents.stops} ${contents.stops == 1 ? 'stop' : 'stops'}.\n\n'
        '${otherTrip ? 'Note: this pack was exported from a different trip; only matching spots in "${trip.title}" will be updated.\n\n' : ''}'
        'Existing frames stay untouched and duplicates are skipped.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  final db = ref.read(databaseProvider);
  final summary = await runArchiveWithProgress<TripFramesImportSummary>(
    context,
    title: 'Importing frames',
    failure: "Couldn't import frames",
    run: (onProgress, cancel) => svc.importFramesPack(
      db,
      tripId: trip.id,
      zip: File(path),
      onProgress: onProgress,
      cancel: cancel,
    ),
  );
  if (summary == null || !context.mounted) return;
  await tellArchiveMessage(context, 'Frames imported', tripFramesImportSummaryText(summary));
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

/// Syncs all local-only frames on [trip] through the signed-in user's Google Drive
/// (`drive.file`), writes back `remoteUrl`, and marks stops dirty for Firestore sync.
Future<void> syncTripLocalFramesViaDrive(BuildContext context, WidgetRef ref, Trip trip) async {
  if (trip.sharing != 'group' || !ref.read(canEditTripProvider(trip.id))) {
    await tellArchiveMessage(
      context,
      'Cannot sync to trip',
      'Only owners and editors of a shared trip can sync frames via Google Drive.',
    );
    return;
  }
  if (ref.read(currentUserIdProvider) == guestUserId) {
    await tellArchiveMessage(
      context,
      'Sign in required',
      'Please sign in with Google before syncing frames through Google Drive.',
    );
    return;
  }
  final db = ref.read(databaseProvider);
  final svc = ref.read(googleDriveFrameServiceProvider);
  final count = await svc.countTripLocalFrames(db, trip.id);
  if (!context.mounted) return;
  if (count == 0) {
    await tellArchiveMessage(
      context,
      'All frames synced',
      'Every frame in "${trip.title}" already has an image link or is not on this device.',
    );
    return;
  }

  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sync via my Google Drive'),
      content: Text(
        '$count local ${count == 1 ? 'frame' : 'frames'} in "${trip.title}" will be resized (max 1280px JPEG) '
        'and uploaded to "${GoogleDriveFrameService.appFolderName}" in your own Google Drive with '
        '"anyone with the link can view" permission so trip members can load them.\n\n'
        'Anyone holding the URL can view the image. Trip Planner uses the drive.file permission and only accesses files it creates.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upload & sync')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  final summary = await runArchiveWithProgress<DriveSyncSummary>(
    context,
    title: 'Uploading to Google Drive',
    failure: "Couldn't upload frames to Google Drive",
    run: (onProgress, cancel) async {
      try {
        return await svc.syncTripLocalFrames(
          db,
          tripId: trip.id,
          onProgress: onProgress,
          cancel: cancel,
        );
      } on AuthCancelledException {
        throw const BackupCancelled();
      }
    },
  );
  if (summary == null || !context.mounted) return;
  await tellArchiveMessage(context, 'Google Drive sync complete', driveSyncSummaryText(summary));
}

/// Picks gallery photos and stores copies locally on [stopId] without uploading
/// to the cloud. Returns how many frames were added.
Future<int> addLocalStopFrames(BuildContext context, WidgetRef ref, {required String stopId}) async {
  final picked = await ImagePicker().pickMultiImage();
  if (picked.isEmpty) return 0;
  final repo = ref.read(placeRepositoryProvider);
  final docsDir = await getApplicationDocumentsDirectory();
  final refDir = Directory(p.join(docsDir.path, 'reference_images'));
  if (!await refDir.exists()) await refDir.create(recursive: true);

  const uuid = Uuid();
  var count = 0;
  for (final file in picked) {
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final targetPath = p.join(refDir.path, 'ref_${uuid.v4()}$ext');
    await File(file.path).copy(targetPath);
    try {
      await repo.addReferenceImage(stopId: stopId, localPath: targetPath, source: 'You');
    } catch (_) {
      try {
        await File(targetPath).delete();
      } catch (_) {}
      rethrow;
    }
    count++;
  }
  return count;
}

/// Picks gallery photos and uploads them to the user's Google Drive, attaching synced
/// frames onto [stopId] of a shared trip. Returns how many frames were uploaded (0 if cancelled).
Future<int> uploadStopGalleryFramesViaDrive(
  BuildContext context,
  WidgetRef ref, {
  required Trip trip,
  required String stopId,
}) async {
  if (trip.sharing != 'group' || !ref.read(canEditTripProvider(trip.id))) {
    await tellArchiveMessage(
      context,
      'Cannot upload to trip',
      'Only owners and editors of a shared trip can upload frames via Google Drive.',
    );
    return 0;
  }
  if (ref.read(currentUserIdProvider) == guestUserId) {
    await tellArchiveMessage(
      context,
      'Sign in required',
      'Please sign in with Google before uploading frames to Google Drive.',
    );
    return 0;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Upload via my Google Drive'),
      content: const Text(
        'Selected photos will be resized (max 1280px JPEG) and uploaded to "${GoogleDriveFrameService.appFolderName}" '
        'in your own Google Drive with "anyone with the link can view" permission so trip members can see them.\n\n'
        'Anyone holding the URL can view the uploaded image. Trip Planner uses drive.file and only accesses files it creates.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Choose photos')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return 0;

  final picked = await ImagePicker().pickMultiImage();
  if (picked.isEmpty || !context.mounted) return 0;

  final db = ref.read(databaseProvider);
  final svc = ref.read(googleDriveFrameServiceProvider);
  final docsDir = await getApplicationDocumentsDirectory();
  final refDir = Directory(p.join(docsDir.path, 'reference_images'));
  if (!await refDir.exists()) await refDir.create(recursive: true);

  if (!context.mounted) return 0;
  final uploadedCount = await runArchiveWithProgress<int>(
    context,
    title: 'Uploading to Google Drive',
    failure: "Couldn't upload frame",
    run: (onProgress, cancel) async {
      const uuid = Uuid();
      var count = 0;
      onProgress(0, picked.length);
      for (final file in picked) {
        if (cancel.isCancelled) throw const BackupCancelled();
        final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
        final targetPath = p.join(refDir.path, 'ref_${uuid.v4()}$ext');
        await File(file.path).copy(targetPath);
        try {
          try {
            await svc.uploadNewStopFrame(db, tripId: trip.id, stopId: stopId, localPath: targetPath);
          } on AuthCancelledException {
            throw const BackupCancelled();
          }
        } catch (_) {
          // Clean up local copy if DB row wasn't persisted.
          try {
            await File(targetPath).delete();
          } catch (_) {}
          rethrow;
        }
        count++;
        onProgress(count, picked.length);
      }
      return count;
    },
  );
  return uploadedCount ?? 0;
}

String driveSyncSummaryText(DriveSyncSummary s) {
  final parts = <String>[
    if (s.uploaded > 0) 'Uploaded ${s.uploaded} ${s.uploaded == 1 ? 'frame' : 'frames'} to Google Drive.',
    if (s.reused > 0) 'Reused ${s.reused} already-uploaded ${s.reused == 1 ? 'image' : 'images'}.',
    if (s.updatedStops > 0)
      'Updated ${s.updatedStops} ${s.updatedStops == 1 ? 'stop' : 'stops'} for group sync.',
    if (s.skippedMissing > 0)
      '${s.skippedMissing} ${s.skippedMissing == 1 ? 'frame was' : 'frames were'} skipped because the file is missing on this phone.',
  ];
  return parts.isEmpty ? 'No frames needed uploading.' : parts.join(' ');
}

String _safeFileSlug(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty ? 'trip' : cleaned.toLowerCase();
}
