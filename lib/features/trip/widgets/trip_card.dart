import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/schedule_logic.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
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
              const SizedBox(height: 6),
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
      ),
    );
  }
}

class TripStatusChip extends StatelessWidget {
  final TripStatus status;

  const TripStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (status) {
      TripStatus.ongoing => ('Ongoing', scheme.primary, scheme.onPrimary),
      TripStatus.planning => ('Planning', scheme.secondaryContainer, scheme.onSecondaryContainer),
      TripStatus.finished => ('Finished', scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}
