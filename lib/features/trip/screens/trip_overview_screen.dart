import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../core/utils/schedule_logic.dart';
import '../controllers/trips_controller.dart';
import '../providers/trip_providers.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_form_sheet.dart';

/// A trip's front page: its dates and days, and the way into the planner and
/// the stop list.
class TripOverviewScreen extends ConsumerWidget {
  final String tripId;

  const TripOverviewScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));

    return tripAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text("Couldn't load this trip: $e"))),
      data: (trip) {
        if (trip == null || trip.deletedAt != null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('This trip was deleted.')));
        }
        return _Overview(trip: trip);
      },
    );
  }
}

class _Overview extends ConsumerWidget {
  final Trip trip;

  const _Overview({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocks = ref.watch(tripResolvedBlockDatesProvider(trip.id));
    final status = ref.watch(tripStatusProvider(trip.id));
    final stopCount = ref.watch(tripStopsProvider(trip.id)).valueOrNull?.length ?? 0;
    final dated = blocks.where((b) => !b.isBackup && b.date != null).toList();
    final datedCount = blocks.where((b) => !b.isBackup).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        actions: [
          IconButton(
            tooltip: 'Edit trip',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, ref),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete trip')),
            ],
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tripDateLine(
                        firstDate: dated.isEmpty ? null : dated.first.date,
                        lastDate: dated.isEmpty ? null : dated.last.date,
                        dayCount: blocks.isEmpty ? trip.dayCount : datedCount,
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TripStatusChip(status: status),
                ],
              ),
              if (trip.description != null && trip.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(trip.description!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.view_week_outlined,
                title: 'Plan',
                subtitle: 'Arrange your stops day by day',
              ),
              const SizedBox(height: 8),
              _SectionCard(
                icon: Icons.place_outlined,
                title: 'Stops',
                subtitle: stopCount == 0 ? 'No stops yet' : stopCount == 1 ? '1 stop' : '$stopCount stops',
              ),
              const SizedBox(height: 24),
              Text('Days', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final b in blocks) _DayRow(block: b),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final form = await showTripForm(context, editing: trip);
    if (form == null || !context.mounted) return;
    final result = await ref.read(tripsControllerProvider.notifier).updateTrip(
          tripId: trip.id,
          title: form.title,
          startDate: form.startDate,
        );
    if (!context.mounted) return;
    if (result case Failure(:final error)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${trip.title}”?'),
        content: const Text('Its days, stops and schedule are deleted too. You can\'t undo this yet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(tripsControllerProvider.notifier).deleteTrip(trip.id);
    if (!context.mounted) return;
    switch (result) {
      case Success():
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/trips');
        }
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't delete the trip: $error")));
    }
  }
}

/// An entry to one part of the trip. The planner and the stop list are being
/// built next, so for now the entries only show what's there.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        enabled: false,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Text('Coming next', style: theme.textTheme.labelSmall),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final ResolvedBlockDate block;

  const _DayRow({required this.block});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = block.date;
    final label = block.isBackup ? 'Backup' : 'Day ${block.index + 1}';
    final detail = block.isBackup
        ? (block.block.title ?? 'No date')
        : date == null
            ? 'No date yet'
            : DateFormat.MMMEd().format(date);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label),
      subtitle: Text(detail),
      trailing: block.block.pinnedDate == null
          ? null
          : Icon(
              Icons.lock,
              size: 18,
              color: block.hasConflict ? theme.colorScheme.error : theme.colorScheme.tertiary,
              semanticLabel: 'Pinned',
            ),
    );
  }
}
