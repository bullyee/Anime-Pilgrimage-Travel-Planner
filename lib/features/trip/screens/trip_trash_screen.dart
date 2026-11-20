import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../providers/plan_together_providers.dart';
import '../providers/trip_providers.dart';
import '../../../shared/widgets/up_button.dart';

/// "today", "yesterday", "3 days ago", or the date.
String deletedWhen(DateTime at, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final days = today.difference(DateUtils.dateOnly(at)).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  return 'on ${DateFormat.MMMd().format(at)}';
}

/// A trip's trash: the days and stops deleted in the last 30 days, with who
/// deleted them and when, and **Restore** for the people who can edit the
/// trip. Opened from the trip's ⋮ menu.
class TripTrashScreen extends ConsumerWidget {
  final String tripId;

  const TripTrashScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trash = ref.watch(tripTrashProvider(tripId));
    final canEdit = ref.watch(canEditTripProvider(tripId));
    final trip = ref.watch(tripDetailProvider(tripId)).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        leading: UpButton.ifAlone(context, fallback: '/trips/$tripId'),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Recently deleted'),
            if (trip != null)
              Text(trip.title,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load the deleted items: $e")),
        data: (entries) {
          if (entries.isEmpty) {
            return const _Empty(
              icon: Icons.delete_outline,
              text: 'Nothing deleted in the last 30 days.\nDeleted days and stops wait here for 30 days.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  canEdit
                      ? 'Deleted days and stops stay here for 30 days. Restore puts them back where they were, with their schedule.'
                      : 'Deleted days and stops stay here for 30 days. People who can edit the trip can restore them.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              for (final entry in entries) _TrashTile(entry: entry, canRestore: canEdit),
            ],
          );
        },
      ),
    );
  }
}

class _TrashTile extends ConsumerStatefulWidget {
  final TrashEntry entry;
  final bool canRestore;

  const _TrashTile({required this.entry, required this.canRestore});

  @override
  ConsumerState<_TrashTile> createState() => _TrashTileState();
}

class _TrashTileState extends ConsumerState<_TrashTile> {
  bool _busy = false;

  Future<void> _restore() async {
    final entry = widget.entry;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(tripRepositoryProvider);
      if (entry.kind == 'day') {
        await repo.restoreDayBlock(entry.id, window: trashWindow);
      } else {
        await repo.restoreStop(entry.id, window: trashWindow);
      }
      messenger.showSnackBar(SnackBar(content: Text('Restored ${entry.kind == 'day' ? 'the day' : entry.title}.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't restore it: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final who = ref.watch(memberNameProvider((tripId: entry.tripId, userId: entry.deletedBy)));
    final left = entry.daysLeft(DateTime.now());
    final lines = [
      if (entry.detail != null && entry.detail!.isNotEmpty) entry.detail!,
      '$who deleted it ${deletedWhen(entry.deletedAt)} · ${left == 1 ? '1 day' : '$left days'} left',
    ];
    return ListTile(
      key: Key('trash_${entry.id}'),
      leading: Icon(entry.kind == 'day' ? Icons.calendar_today_outlined : Icons.place_outlined),
      title: Text(entry.kind == 'day' ? 'Day: ${entry.title}' : entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(lines.join('\n'), style: theme.textTheme.bodySmall),
      isThreeLine: lines.length > 1,
      trailing: widget.canRestore
          ? (_busy
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(onPressed: _restore, child: const Text('Restore')))
          : null,
    );
  }
}

/// Trips the user deleted in the last 30 days, with **Restore**. Opened from
/// My Trips when there are any.
class DeletedTripsScreen extends ConsumerWidget {
  const DeletedTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trips = ref.watch(deletedTripsProvider);
    return Scaffold(
      appBar: AppBar(leading: UpButton.ifAlone(context, fallback: '/trips'), title: const Text('Recently deleted trips')),
      body: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load the deleted trips: $e")),
        data: (list) {
          if (list.isEmpty) {
            return const _Empty(icon: Icons.delete_outline, text: 'No trips deleted in the last 30 days.');
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'A deleted trip stays here for 30 days. Restoring a shared trip brings it back for everyone in it.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              for (final trip in list) _DeletedTripTile(trip: trip),
            ],
          );
        },
      ),
    );
  }
}

class _DeletedTripTile extends ConsumerStatefulWidget {
  final Trip trip;

  const _DeletedTripTile({required this.trip});

  @override
  ConsumerState<_DeletedTripTile> createState() => _DeletedTripTileState();
}

class _DeletedTripTileState extends ConsumerState<_DeletedTripTile> {
  bool _busy = false;

  Future<void> _restore() async {
    final trip = widget.trip;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(tripRepositoryProvider).restoreTrip(trip.id, window: trashWindow);
      messenger.showSnackBar(SnackBar(
        content: Text('Restored “${trip.title}”.'),
        action: SnackBarAction(label: 'Open', onPressed: () => router.push('/trips/${trip.id}')),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't restore the trip: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final left = deletedTripDaysLeft(trip, DateTime.now());
    final shared = trip.sharing == 'group';
    return ListTile(
      key: Key('deletedTrip_${trip.id}'),
      leading: Icon(shared ? Icons.group_outlined : Icons.luggage_outlined),
      title: Text(trip.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Deleted ${deletedWhen(trip.deletedAt!)} · ${left == 1 ? '1 day' : '$left days'} left${shared ? ' · Shared' : ''}',
      ),
      trailing: _busy
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(onPressed: _restore, child: const Text('Restore')),
    );
  }
}

int deletedTripDaysLeft(Trip trip, DateTime now) {
  final left = trip.deletedAt!.add(trashWindow).difference(now);
  return left.isNegative ? 0 : (left.inHours / 24).ceil();
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
