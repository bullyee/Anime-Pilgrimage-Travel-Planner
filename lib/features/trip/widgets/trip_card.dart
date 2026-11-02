import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/trip_summary.dart';

/// "Apr 29 – May 4", or "No dates yet". The year is added when the trip
/// isn't in the current year.
String tripDateLine({
  required DateTime? firstDate,
  required DateTime? lastDate,
  DateTime? now,
}) {
  if (firstDate == null || lastDate == null) return 'No dates yet';
  final thisYear = (now ?? DateTime.now()).year;
  final md = DateFormat.MMMd();
  final range = firstDate == lastDate
      ? md.format(firstDate)
      : '${md.format(firstDate)} – ${md.format(lastDate)}';
  final year = lastDate.year == thisYear && firstDate.year == thisYear ? '' : ', ${lastDate.year}';
  return '$range$year';
}

/// A trip in the list: its first date and its title, plus a line when it's
/// shared. The section it's listed under says whether it's under way,
/// coming up or over, so the card doesn't repeat that.
class TripCard extends StatelessWidget {
  final TripSummary summary;
  final VoidCallback onTap;

  const TripCard({super.key, required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shared = summary.trip.sharing == 'group';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _DateBadge(date: summary.firstDate, status: summary.status),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      summary.trip.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Who it's shared with comes with the member list
                    // (stage 4); until then the line just says it's shared.
                    if (shared) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.group_outlined, size: 18, color: theme.trip.wisteria),
                          const SizedBox(width: 6),
                          Text(
                            'Shared',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.trip.wisteria),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The colors a trip's status is shown in: tea while it's under way,
/// wisteria while it's still being planned, grey once it's over.
(Color background, Color foreground) tripStatusColors(ThemeData theme, TripStatus status) {
  final p = theme.trip;
  return switch (status) {
    TripStatus.ongoing => (p.teaSoft, p.tea),
    TripStatus.planning => (p.wisteriaSoft, p.wisteria),
    TripStatus.finished => (theme.colorScheme.surfaceContainerHighest, theme.colorScheme.onSurfaceVariant),
  };
}

/// The trip's first date as a small calendar leaf, with the year when it
/// isn't this year, or a suitcase when the trip has no dates yet.
class _DateBadge extends StatelessWidget {
  final DateTime? date;
  final TripStatus status;

  const _DateBadge({required this.date, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = tripStatusColors(theme, status);
    final d = date;
    final otherYear = d != null && d.year != DateTime.now().year;
    return Semantics(
      label: d == null ? 'No dates yet' : 'Starts ${DateFormat.yMMMd().format(d)}',
      excludeSemantics: true,
      child: Container(
        width: 54,
        height: 58,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: d == null
            ? Icon(Icons.luggage_outlined, color: foreground)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.MMM().format(d).toUpperCase(),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: foreground, fontWeight: FontWeight.w700, letterSpacing: 1, height: 1.1),
                  ),
                  Text(
                    '${d.day}',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: foreground, fontWeight: FontWeight.w800, height: 1.05),
                  ),
                  if (otherYear)
                    Text(
                      '${d.year}',
                      style: theme.textTheme.labelSmall?.copyWith(color: foreground, fontSize: 10, height: 1.1),
                    ),
                ],
              ),
      ),
    );
  }
}

class TripStatusChip extends StatelessWidget {
  final TripStatus status;

  const TripStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = tripStatusColors(theme, status);
    final label = switch (status) {
      TripStatus.ongoing => 'Ongoing',
      TripStatus.planning => 'Planning',
      TripStatus.finished => 'Finished',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}
