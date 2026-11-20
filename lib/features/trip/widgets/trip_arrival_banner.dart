import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../sync/providers/frame_transfer_providers.dart';
import '../../sync/providers/trip_arrival_providers.dart';
import '../../sync/services/frame_transfer_jobs.dart';
import '../../sync/services/frame_transfer_queue.dart';
import '../../sync/services/trip_frame_downloader.dart';

/// Above a shared trip's tabs: while a just-joined trip's plan is still
/// coming down, says so; then, when others put frames on Google Drive that
/// aren't on this phone, offers to download them.
class TripArrivalBanner extends ConsumerWidget {
  final Trip trip;

  const TripArrivalBanner({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final arriving = ref.watch(tripArrivingProvider(trip.id)).valueOrNull ?? false;
    if (arriving) {
      return const _Strip(
        key: ValueKey('arriving'),
        leading: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        text: "Getting this trip's days and stops…",
        bottom: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (kIsWeb) return const SizedBox.shrink();
    final dismissed = ref.watch(drivePromptDismissedProvider).contains(trip.id);
    final downloading = ref.watch(frameTransferQueueProvider).jobFor(trip.id, TransferKind.download) != null;
    final count = ref.watch(pendingDriveFrameDownloadCountProvider(trip.id)).valueOrNull ?? 0;
    if (dismissed || downloading || count == 0) return const SizedBox.shrink();
    return _Strip(
      key: const ValueKey('drive'),
      leading: Icon(Icons.cloud_download_outlined, size: 20, color: theme.colorScheme.primary),
      text: count == 1
          ? "1 frame shared on Google Drive isn't on this phone yet. Download it?"
          : "$count frames shared on Google Drive aren't on this phone yet. Download them?",
      actions: [
        TextButton(
          onPressed: () => ref.read(drivePromptDismissedProvider.notifier).update((s) => {...s, trip.id}),
          child: const Text('Not now'),
        ),
        FilledButton.tonal(onPressed: () => _download(context, ref), child: const Text('Download')),
      ],
    );
  }

  void _download(BuildContext context, WidgetRef ref) {
    ref.read(frameTransferQueueProvider.notifier).enqueue(frameDownloadJob(
          db: ref.read(databaseProvider),
          downloader: ref.read(tripFrameDownloaderProvider),
          tripId: trip.id,
          tripTitle: trip.title,
          include: isGoogleDriveUrl,
        ));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Downloading the frames in the background. The Members tab shows how far it is.')),
    );
  }
}

class _Strip extends StatelessWidget {
  final Widget leading;
  final String text;
  final List<Widget> actions;
  final Widget? bottom;

  const _Strip({super.key, required this.leading, required this.text, this.actions = const [], this.bottom});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, actions.isEmpty ? 16 : 8, actions.isEmpty ? 10 : 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
                  ],
                ),
                if (actions.isNotEmpty) Wrap(spacing: 4, children: actions),
              ],
            ),
          ),
          ?bottom,
        ],
      ),
    );
  }
}
