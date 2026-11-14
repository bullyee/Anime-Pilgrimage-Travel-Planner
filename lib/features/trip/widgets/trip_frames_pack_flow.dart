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
import '../../sync/providers/frame_transfer_providers.dart';
import '../../sync/services/frame_transfer_jobs.dart';
import '../../sync/services/frame_transfer_queue.dart';
import '../../sync/services/google_drive_frame_service.dart';
import '../services/trip_frames_pack_service.dart';

export '../../sync/providers/frame_transfer_providers.dart'
    show googleDriveFrameServiceProvider, tripFramesPackServiceProvider;
export '../../sync/services/frame_transfer_jobs.dart' show driveSyncSummaryText, tripFramesImportSummaryText;

/// Says that a transfer went to the background, where the user can see it.
void _tellQueued(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}

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
  ref.read(frameTransferQueueProvider.notifier).enqueue(
        framesPackImportJob(db: db, packs: svc, trip: trip, zip: File(path)),
      );
  _tellQueued(context, 'Importing ${contents.frames} ${contents.frames == 1 ? 'frame' : 'frames'} in the background.');
}

/// Uploads all local-only frames on [trip] through the signed-in user's Google
/// Drive (`drive.file`) in the background: writes back `remoteUrl` and marks
/// stops dirty for Firestore sync. The Drive token is fetched here, while the
/// screen is up, so the background run never has to show Google's sign-in.
///
/// [confirm] false skips the explanation (Resume after an interrupted run).
Future<void> syncTripLocalFramesViaDrive(BuildContext context, WidgetRef ref, Trip trip, {bool confirm = true}) async {
  final canEdit = ref.read(canEditTripProvider(trip.id));
  if (!canUploadTripFramesToDrive(trip, canEdit: canEdit)) {
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
  if (ref.read(frameTransferQueueProvider).jobFor(trip.id, TransferKind.driveUpload) != null) {
    _tellQueued(context, 'Already uploading the frames of "${trip.title}".');
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

  if (confirm) {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync via my Google Drive'),
        content: Text(
          '$count local ${count == 1 ? 'frame' : 'frames'} in "${trip.title}" will be resized (max 1280px JPEG) '
          'and uploaded to "${GoogleDriveFrameService.appFolderName}" in your own Google Drive with '
          '"anyone with the link can view" permission so trip members can load them.\n\n'
          'Anyone holding the URL can view the image. Trip Planner uses the drive.file permission and only accesses files it creates.\n\n'
          'The upload runs in the background: you can keep using the app, switch apps or turn the screen off.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upload & sync')),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
  }

  // Google's consent (if any) has to happen now, with the app on screen.
  try {
    await svc.prepareToken();
  } on AuthCancelledException {
    return;
  } catch (e) {
    if (context.mounted) await tellArchiveMessage(context, "Couldn't connect to Google Drive", '$e');
    return;
  }
  if (!context.mounted) return;
  ref.read(frameTransferQueueProvider.notifier).enqueue(
        driveUploadJob(db: db, drive: svc, trip: trip, canEdit: canEdit),
      );
  _tellQueued(context, 'Uploading $count ${count == 1 ? 'frame' : 'frames'} to Google Drive in the background.');
}

/// Members tab → Download frames for offline: brings every linked frame of
/// [trip] that isn't on this phone into the cache, in the background.
Future<void> downloadTripFramesForOffline(BuildContext context, WidgetRef ref, Trip trip) async {
  final queue = ref.read(frameTransferQueueProvider.notifier);
  if (ref.read(frameTransferQueueProvider).jobFor(trip.id, TransferKind.download) != null) {
    _tellQueued(context, 'Already downloading the frames of "${trip.title}".');
    return;
  }
  final db = ref.read(databaseProvider);
  final downloader = ref.read(tripFrameDownloaderProvider);
  final urls = await downloader.pendingUrls(db, trip.id);
  if (!context.mounted) return;
  if (urls.isEmpty) {
    _tellQueued(context, 'Every frame in "${trip.title}" is already on this phone.');
    return;
  }
  queue.enqueue(frameDownloadJob(db: db, downloader: downloader, tripId: trip.id, tripTitle: trip.title));
  ref.invalidate(pendingFrameDownloadCountProvider(trip.id));
  _tellQueued(context, 'Downloading ${urls.length} ${urls.length == 1 ? 'frame' : 'frames'} in the background.');
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

/// Picks gallery photos and uploads them to the user's Google Drive in the
/// background, attaching synced frames onto [stopId] of a shared trip.
/// Returns how many photos were queued (0 if cancelled).
Future<int> uploadStopGalleryFramesViaDrive(
  BuildContext context,
  WidgetRef ref, {
  required Trip trip,
  required String stopId,
}) async {
  final canEdit = ref.read(canEditTripProvider(trip.id));
  if (!canUploadTripFramesToDrive(trip, canEdit: canEdit)) {
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
  try {
    await svc.prepareToken();
  } on AuthCancelledException {
    return 0;
  } catch (e) {
    if (context.mounted) await tellArchiveMessage(context, "Couldn't connect to Google Drive", '$e');
    return 0;
  }

  final docsDir = await getApplicationDocumentsDirectory();
  final refDir = Directory(p.join(docsDir.path, 'reference_images'));
  if (!await refDir.exists()) await refDir.create(recursive: true);
  const uuid = Uuid();
  final paths = <String>[];
  for (final file in picked) {
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final targetPath = p.join(refDir.path, 'ref_${uuid.v4()}$ext');
    await File(file.path).copy(targetPath);
    paths.add(targetPath);
  }
  if (!context.mounted) {
    for (final path in paths) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    return 0;
  }
  ref.read(frameTransferQueueProvider.notifier).enqueue(
        stopUploadJob(db: db, drive: svc, trip: trip, canEdit: canEdit, stopId: stopId, localPaths: paths),
      );
  return paths.length;
}

String _safeFileSlug(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty ? 'trip' : cleaned.toLowerCase();
}
