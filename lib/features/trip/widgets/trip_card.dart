import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/trip_summary.dart';

/// "Apr 29 – May 4 · 6 days", or "No dates yet · 3 days". The year is added
/// when the trip isn't in the current year.
String tripDateLine({
  required DateTime? firstDate,
  required DateTime? lastDate,
  required int dayCount,
  DateTime? now,
}) {
  final days = dayCount == 1 ? '1 day' : '$dayCount days';
  if (firstDate == null || lastDate == null) return 'No dates yet · $days';
  final thisYear = (now ?? DateTime.now()).year;
  final md = DateFormat.MMMd();
  final range = firstDate == lastDate
      ? md.format(firstDate)
      : '${md.format(firstDate)} – ${md.format(lastDate)}';
  final year = lastDate.year == thisYear && firstDate.year == thisYear ? '' : ', ${lastDate.year}';
  return '$range$year · $days';
}

class TripCard extends StatelessWidget {
  final TripSummary summary;
  final VoidCallback onTap;

  const TripCard({super.key, required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stops = summary.stopCount;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBadge(date: summary.firstDate, status: summary.status),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            summary.trip.title,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TripStatusChip(status: summary.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tripDateLine(
                        firstDate: summary.firstDate,
                        lastDate: summary.lastDate,
                        dayCount: summary.dayCount,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stops == 0 ? 'No stops yet' : stops == 1 ? '1 stop' : '$stops stops',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
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

/// The trip's first date as a small calendar leaf, or a suitcase when it has
/// no dates yet.
class _DateBadge extends StatelessWidget {
  final DateTime? date;
  final TripStatus status;

  const _DateBadge({required this.date, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = tripStatusColors(theme, status);
    final d = date;
    return Container(
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
                  style: theme.textTheme.labelSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                Text(
                  '${d.day}',
                  style: theme.textTheme.titleLarge?.copyWith(color: foreground, fontWeight: FontWeight.w800, height: 1.1),
                ),
              ],
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
