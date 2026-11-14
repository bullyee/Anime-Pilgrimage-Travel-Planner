import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../auth/providers/auth_provider.dart' show AuthCancelledException;
import '../providers/drive_cleanup_providers.dart';
import '../services/drive_frame_cleanup.dart';
import '../services/frame_transfer_queue.dart';

/// Where the upload dialogs say the files can be removed again.
const driveRemovalHint =
    'The files stay in your Google Drive until you remove them: in the trip\'s Members tab '
    '(Remove my frames from Google Drive) or in Settings. Deleting, unsharing or leaving the trip '
    'removes them too.';

/// Asks, then deletes the frames this user put on Google Drive for [trip]
/// and sets them back to "only on this phone". Shows progress, then the outcome.
Future<void> confirmAndRemoveTripFrames(BuildContext context, WidgetRef ref, Trip trip) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove my frames from Google Drive?'),
      content: Text(
        'The frames you shared for "${trip.title}" are deleted from your Google Drive for good, '
        'and their links stop working.\n\n'
        'Other members lose those frames unless they downloaded them for offline. '
        'Your own copies stay on this phone, and you can share them again with Sync via my Google Drive.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  await _run(
    context,
    ref,
    cancelUploads: () => ref.read(frameTransferQueueProvider.notifier).cancelUploads(tripId: trip.id),
    remove: (cleanup, db) => cleanup.removeTripFramesFromDrive(db, trip.id, interactive: true),
    undoPending: (cleanup) => cleanup.journal.removePendingTrip(trip.id),
  );
}

/// Asks, then deletes everything Trip Planner put on this user's Google
/// Drive (every shared frame, the trip folders and the app's folder) and sets
/// those frames back to "only on this phone". Shows progress, then the outcome.
/// For Settings.
Future<void> confirmAndRemoveAllSharedFrames(BuildContext context, WidgetRef ref) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove all my shared frames?'),
      content: const Text(
        'Everything Trip Planner put on your Google Drive is deleted for good: the frames you shared '
        'for every trip and their folders. Their links stop working.\n\n'
        'Members of your shared trips lose those frames unless they downloaded them for offline. '
        'Your own copies stay on this phone, and you can share them again with Sync via my Google Drive.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove all')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  await _run(
    context,
    ref,
    cancelUploads: () => ref.read(frameTransferQueueProvider.notifier).cancelUploads(),
    remove: (cleanup, db) => cleanup.removeAllSharedFramesFromDrive(db, interactive: true),
    undoPending: (cleanup) => cleanup.journal.setPendingAll(false),
  );
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function() cancelUploads,
  required Future<DriveCleanupResult> Function(DriveFrameCleanup cleanup, AppDatabase db) remove,
  required Future<void> Function(DriveFrameCleanup cleanup) undoPending,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final cleanup = ref.read(driveFrameCleanupProvider);
  final db = ref.read(databaseProvider);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            SizedBox(width: 16),
            Expanded(child: Text('Removing frames from your Google Drive…')),
          ],
        ),
      ),
    ),
  );
  String message;
  try {
    // An upload still running would put files back; let it stop first.
    await cancelUploads();
    message = (await remove(cleanup, db)).text;
  } on AuthCancelledException {
    await undoPending(cleanup);
    message = 'Google sign-in was cancelled, so nothing was removed.';
  } catch (e) {
    message = "Couldn't finish removing the frames now ($e). It finishes by itself the next time "
        'Google Drive can be reached.';
  }
  navigator.pop();
  messenger?.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
}
