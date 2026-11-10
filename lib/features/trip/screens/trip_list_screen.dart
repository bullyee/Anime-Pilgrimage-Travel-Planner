import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../controllers/trips_controller.dart';
import '../models/trip_summary.dart';
import '../providers/trip_list_providers.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_form_sheet.dart';

/// The trip list: all trips, the shared ones or the private ones, under
/// sections that say whether each is under way, coming up, undated or over.
class TripListScreen extends ConsumerStatefulWidget {
  const TripListScreen({super.key});

  @override
  ConsumerState<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends ConsumerState<TripListScreen> {
  TripFilter _filter = TripFilter.all;

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(tripSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            tooltip: 'Join a trip',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => context.push('/join'),
          ),
        ],
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text("Couldn't load your trips: $e", textAlign: TextAlign.center),
          ),
        ),
        data: (trips) {
          if (trips.isEmpty) return _EmptyTrips(onCreate: () => _createTrip(context, ref));
          final shown = [for (final t in trips) if (_filter.matches(t.trip)) t];
          int count(TripFilter f) => trips.where((t) => f.matches(t.trip)).length;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<TripFilter>(
                        segments: [
                          for (final (filter, label) in const [
                            (TripFilter.all, 'All'),
                            (TripFilter.shared, 'Shared'),
                            (TripFilter.private, 'Private'),
                          ])
                            ButtonSegment(value: filter, label: _FilterLabel(label, count(filter))),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (picked) => setState(() => _filter = picked.first),
                      ),
                    ),
                  ),
                  Expanded(
                    child: shown.isEmpty
                        ? _EmptyFilter(filter: _filter)
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            children: [
                              for (final (section, items) in groupTripSummaries(shown)) ...[
                                _SectionHeader(section.title),
                                for (final t in items)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: TripCard(
                                      summary: t,
                                      onTap: () => context.push('/trips/${t.trip.id}'),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      // The empty state has its own button.
      floatingActionButton: (summaries.valueOrNull?.isEmpty ?? true)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createTrip(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New trip'),
            ),
    );
  }

  Future<void> _createTrip(BuildContext context, WidgetRef ref) async {
    final form = await showTripForm(context);
    if (form == null || !context.mounted) return;
    final result = await ref.read(tripsControllerProvider.notifier).createTrip(
          title: form.title,
          description: form.description,
          startDate: form.startDate,
          dayCount: form.dayCount,
        );
    if (!context.mounted) return;
    switch (result) {
      case Success(:final value):
        context.push('/trips/${value.id}');
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't create the trip: $error")),
        );
    }
  }
}

/// "Shared 2": a filter's name and how many trips it holds.
class _FilterLabel extends StatelessWidget {
  final String label;
  final int count;

  const _FilterLabel(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Text.rich(TextSpan(children: [
      TextSpan(text: '$label '),
      TextSpan(text: '$count', style: TextStyle(color: muted)),
    ]));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// A filter with nothing in it. The shared one offers to join a trip.
class _EmptyFilter extends StatelessWidget {
  final TripFilter filter;

  const _EmptyFilter({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, text) = switch (filter) {
      TripFilter.shared => (
          Icons.group_outlined,
          'No shared trips yet',
          'Trips you share with friends, or join from an invite, show up here.',
        ),
      _ => (
          Icons.lock_outline,
          'No private trips',
          'Trips only you can see show up here.',
        ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.trip.wisteriaSoft,
              child: Icon(icon, size: 30, color: theme.trip.wisteria),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (filter == TripFilter.shared) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => context.push('/join'),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Join a trip'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyTrips({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.luggage_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No trips yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Name your trip and pick the dates, then add the spots you want to visit.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('New trip'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/join'),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Join a trip with an invite'),
            ),
          ],
        ),
      ),
    );
  }
}
