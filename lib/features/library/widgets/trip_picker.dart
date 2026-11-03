import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trip/models/trip_summary.dart';
import '../../trip/providers/trip_list_providers.dart';

/// Asks which trip to add places to. Trips in [full] already have all of
/// them: with [allowRepeat] they can still be picked, to add a second stop,
/// otherwise they are shown but can't be picked.
Future<TripSummary?> pickTripToAddTo(
  BuildContext context, {
  required Set<String> full,
  String? subtitle,
  bool allowRepeat = false,
}) {
  return showModalBottomSheet<TripSummary>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TripPicker(full: full, subtitle: subtitle, allowRepeat: allowRepeat),
  );
}

class _TripPicker extends ConsumerWidget {
  final Set<String> full;
  final String? subtitle;
  final bool allowRepeat;

  const _TripPicker({required this.full, required this.subtitle, required this.allowRepeat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trips = ref.watch(tripSummariesProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: trips.when(
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text("Couldn't load your trips: $e")),
          data: (all) => ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text('Add to a trip', style: theme.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  subtitle ?? 'It waits in the trip\'s backlog until you plan it.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              if (all.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Text('You have no trips yet. Create one in My Trips.'),
                ),
              for (final t in all)
                ListTile(
                  enabled: allowRepeat || !full.contains(t.trip.id),
                  leading: const Icon(Icons.flight_takeoff),
                  title: Text(t.trip.title),
                  subtitle: Text(full.contains(t.trip.id)
                      ? (allowRepeat ? 'Already in this trip. Pick it to add a second stop.' : 'Already in this trip')
                      : t.stopCount == 1
                          ? '1 stop'
                          : '${t.stopCount} stops'),
                  onTap: () => Navigator.pop(context, t),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
