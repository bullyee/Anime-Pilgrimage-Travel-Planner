import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../planner/models/planner_view.dart';
import '../../planner/providers/planner_providers.dart';
import '../../trip/models/trip_summary.dart';
import '../providers/home_providers.dart';
import 'home_mini_map.dart';

/// Home's top card on a day without a trip: the next trip on a small map,
/// with what's still to plan, or a way to start one.
class NextTripCard extends ConsumerWidget {
  final TripSummary? next;

  const NextTripCard({super.key, required this.next});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = this.next;
    return next == null ? const _NoTrip() : _NextTrip(summary: next);
  }
}

/// "Day 3, Days 7–11" for the unplanned day numbers [numbers], in order.
String describeDays(List<int> numbers) {
  final runs = <(int, int)>[];
  for (final n in numbers) {
    if (runs.isNotEmpty && runs.last.$2 == n - 1) {
      runs.last = (runs.last.$1, n);
    } else {
      runs.add((n, n));
    }
  }
  return runs.map((r) => r.$1 == r.$2 ? 'Day ${r.$1}' : 'Days ${r.$1}–${r.$2}').join(', ');
}

class _NextTrip extends ConsumerWidget {
  final TripSummary summary;

  const _NextTrip({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final today = normalizeDateOnly(ref.watch(homeClockProvider)());
    final first = summary.firstDate;
    final String when;
    if (first == null) {
      when = 'NEXT TRIP · NO DATES YET';
    } else {
      final days = first.difference(today).inDays;
      when = days == 1 ? 'NEXT TRIP · TOMORROW' : 'NEXT TRIP · IN $days DAYS';
    }
    final range = first == null
        ? null
        : summary.lastDate == null || summary.lastDate == first
            ? DateFormat('MMM d').format(first)
            : '${DateFormat('MMM d').format(first)} – ${DateFormat('MMM d').format(summary.lastDate!)}';
    final view = ref.watch(plannerViewProvider(summary.trip.id)).valueOrNull;
    final tripId = summary.trip.id;
    final days = view?.datedDays ?? const <PlannerDay>[];
    final stops = days.fold<int>(0, (n, d) => n + d.items.length);
    final unplanned = [for (final d in days) if (d.items.isEmpty) d.index + 1];
    final firstPlanned = days.where((d) => d.items.isNotEmpty).firstOrNull;

    return Card(
      key: const Key('homeNextTrip'),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: p.wisteriaSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(when,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: p.wisteria, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                ),
                if (range != null)
                  DecoratedBox(
                    decoration:
                        BoxDecoration(color: p.wisteria.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Text(range,
                          style: theme.textTheme.labelMedium?.copyWith(color: p.wisteria, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(summary.trip.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (stops > 0) ...[
              const SizedBox(height: 12),
              HomeMiniMap(
                key: const Key('homeTripMap'),
                color: p.wisteria,
                doneColor: theme.colorScheme.outline,
                openLabel: 'Open map',
                onOpen: () => context.push('/trips/$tripId/map?day=${Uri.encodeQueryComponent(firstPlanned!.day.id)}'),
                pins: [
                  for (final d in days)
                    for (final it in d.items) MiniPin(lat: it.stop.lat, lng: it.stop.lng, label: '${d.index + 1}', done: it.done),
                ],
              ),
            ],
            if (days.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${days.length == 1 ? '1 day' : '${days.length} days'} · ${stops == 1 ? '1 stop' : '$stops stops'}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  if (unplanned.isNotEmpty)
                    Expanded(
                      child: Text('${describeDays(unplanned)} not planned',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyMedium?.copyWith(color: p.vermilion, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: p.wisteria),
              onPressed: () => context.push('/trips/$tripId?tab=plan'),
              child: const Text('Continue planning'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoTrip extends StatelessWidget {
  const _NoTrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Card(
      key: const Key('homeNoTrip'),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: p.wisteriaSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Plan a pilgrimage', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Save the places from an anime to your library, then lay them out day by day.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => context.go('/trips'), child: const Text('Plan a trip')),
            const SizedBox(height: 4),
            TextButton(onPressed: () => context.push('/library/import'), child: const Text('Import from Anitabi')),
          ],
        ),
      ),
    );
  }
}
