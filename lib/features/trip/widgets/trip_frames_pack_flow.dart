import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/archive_isolate.dart';
import '../../library/widgets/library_backup_flow.dart';
import '../services/trip_frames_pack_service.dart';

final tripFramesPackServiceProvider = Provider<TripFramesPackService>((ref) => const TripFramesPackService());

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

String _safeFileSlug(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty ? 'trip' : cleaned.toLowerCase();
}
