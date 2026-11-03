import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/providers/sync_v2_providers.dart';
import '../../sync/services/sync_engine_service_v2.dart';

/// How long a shared trip's changes may take to reach the cloud before the
/// trip shows as not synced, so an ordinary sync doesn't flash the icon.
const syncPendingGrace = Duration(seconds: 3);

/// What a trip's sync icon shows: [tripSyncStatusProvider], except that
/// pending only comes through once it has lasted [syncPendingGrace].
final tripSyncIconStatusProvider = StreamProvider.autoDispose.family<TripSyncStatus, String>((ref, tripId) {
  final statuses = StreamController<TripSyncStatus>();
  Timer? grace;
  ref.onDispose(() {
    grace?.cancel();
    statuses.close();
  });
  ref.listen(tripSyncStatusProvider(tripId), (_, next) {
    final status = next.valueOrNull;
    if (status == null) return;
    grace?.cancel();
    if (status == TripSyncStatus.pending) {
      grace = Timer(syncPendingGrace, () => statuses.add(status));
    } else {
      statuses.add(status);
    }
  }, fireImmediately: true);
  return statuses.stream;
});

/// A small cloud by a shared trip's title while its changes haven't reached
/// the cloud: not synced yet, offline, or refused. Nothing shows while the
/// trip is in sync. Private trips stay on this phone, so they don't get one.
class TripSyncIcon extends ConsumerWidget {
  final String tripId;

  /// Around the icon, only while it shows.
  final EdgeInsetsGeometry padding;

  const TripSyncIcon({super.key, required this.tripId, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.outline;
    final shown = switch (ref.watch(tripSyncIconStatusProvider(tripId)).valueOrNull) {
      TripSyncStatus.pending => (Icons.cloud_upload_outlined, muted, 'Not synced yet'),
      TripSyncStatus.offline => (Icons.cloud_off_outlined, muted, "Offline. Changes sync once you're back online"),
      TripSyncStatus.error => (
          Icons.sync_problem,
          theme.colorScheme.error,
          "Couldn't sync this trip. Your changes are kept on this phone",
        ),
      TripSyncStatus.synced || null => null,
    };
    if (shown == null) return const SizedBox.shrink();
    final (icon, color, message) = shown;
    return Padding(
      padding: padding,
      child: Tooltip(
        message: message,
        triggerMode: TooltipTriggerMode.tap,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
