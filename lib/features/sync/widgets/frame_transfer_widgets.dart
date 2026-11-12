import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../services/frame_transfer_queue.dart';

IconData _iconFor(TransferKind kind) => switch (kind) {
  TransferKind.driveUpload || TransferKind.stopUpload => Icons.cloud_upload_outlined,
  TransferKind.download => Icons.cloud_download_outlined,
  TransferKind.packImport => Icons.file_download_outlined,
};

/// A running or queued transfer, inline (the Members tab's frames card):
/// what it does, how far it is, and Cancel. Not modal; the app stays usable.
class TransferJobStrip extends ConsumerWidget {
  final TransferJobView job;
  final bool queued;

  const TransferJobStrip({super.key, required this.job, this.queued = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_iconFor(job.kind), size: 18, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  queued ? '${job.kind.headline} · waiting' : job.kind.headline,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: job.cancelling ? null : () => ref.read(frameTransferQueueProvider.notifier).cancel(job.id),
                child: Text(job.cancelling ? 'Cancelling…' : 'Cancel'),
              ),
            ],
          ),
          if (!queued) ...[
            LinearProgressIndicator(value: job.fraction),
            const SizedBox(height: 4),
            Text(job.countText, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ],
        ],
      ),
    );
  }
}

/// A finished transfer's outcome, until dismissed; failures show their cause.
class TransferNoticeTile extends ConsumerWidget {
  final TransferNotice notice;

  /// Shown for a run that stopped for the user (sign in again) or was cut
  /// short, e.g. "Resume".
  final VoidCallback? onResume;

  const TransferNoticeTile({super.key, required this.notice, this.onResume});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final color = notice.isError ? p.vermilion : (notice.offersResume ? p.wisteria : p.tea);
    final icon = notice.isError
        ? Icons.error_outline
        : notice.offersResume
        ? Icons.pause_circle_outline
        : (notice.type == TransferNoticeType.cancelled ? Icons.block : Icons.check_circle_outline);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(notice.message, style: theme.textTheme.bodySmall)),
          if (onResume != null && notice.offersResume) TextButton(onPressed: onResume, child: const Text('Resume')),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(frameTransferQueueProvider.notifier).dismissNotice(notice.id),
          ),
        ],
      ),
    );
  }
}

/// Every screen's small transfer indicator, under the app: the running
/// transfer with Cancel, or a transfer that needs attention (failed, or
/// waiting to be resumed). Finished ones show once as a snack bar.
class TransferStatusOverlay extends ConsumerWidget {
  final Widget child;

  const TransferStatusOverlay({super.key, required this.child});

  static bool _attention(TransferNotice n) => n.isError || n.offersResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<FrameTransferState>(frameTransferQueueProvider, (prev, next) {
      final seen = {for (final n in prev?.notices ?? const <TransferNotice>[]) n.id};
      for (final n in next.notices) {
        if (seen.contains(n.id) || _attention(n)) continue;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(n.message)));
      }
    });
    final state = ref.watch(frameTransferQueueProvider);
    final job = state.current;
    final notice = job == null ? state.notices.where(_attention).lastOrNull : null;
    if (job == null && notice == null) return child;
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(context: context, removeBottom: true, child: child),
        ),
        _StatusBar(job: job, notice: notice, more: state.queued.length),
      ],
    );
  }
}

class _StatusBar extends ConsumerWidget {
  final TransferJobView? job;
  final TransferNotice? notice;
  final int more;

  const _StatusBar({required this.job, required this.notice, required this.more});

  void _openTrip(WidgetRef ref, String tripId) {
    ref.read(routerProvider).push('/trips/$tripId?tab=members');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final queue = ref.read(frameTransferQueueProvider.notifier);
    final job = this.job;
    final notice = this.notice;
    final Widget content;
    if (job != null) {
      content = InkWell(
        onTap: () => _openTrip(ref, job.tripId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
          child: Row(
            children: [
              Icon(_iconFor(job.kind), size: 18, color: muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  [job.kind.headline, job.countText, if (more > 0) '+$more more'].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: job.cancelling ? null : queue.cancelCurrent,
                child: Text(job.cancelling ? 'Cancelling…' : 'Cancel'),
              ),
            ],
          ),
        ),
      );
    } else {
      final n = notice!;
      content = Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
        child: Row(
          children: [
            Icon(
              n.isError ? Icons.error_outline : Icons.pause_circle_outline,
              size: 18,
              color: n.isError ? theme.trip.vermilion : theme.trip.wisteria,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(n.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            ),
            TextButton(onPressed: () => _openTrip(ref, n.tripId), child: Text(n.offersResume ? 'Resume' : 'Open')),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => queue.dismissNotice(n.id),
            ),
          ],
        ),
      );
    }
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (job != null) LinearProgressIndicator(value: job.fraction, minHeight: 2) else const SizedBox(height: 2),
            SizedBox(height: 44, child: content),
          ],
        ),
      ),
    );
  }
}
