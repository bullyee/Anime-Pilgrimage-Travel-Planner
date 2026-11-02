import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../planner/models/planner_view.dart';
import '../../planner/providers/planner_providers.dart';
import '../../planner/widgets/planner_sheets.dart';
import '../providers/trip_providers.dart';
import '../widgets/trip_card.dart';

/// The trip's front page: dates, status and days, with today's plan on top
/// while the trip is under way.
class TripOverviewTab extends ConsumerWidget {
  final Trip trip;
  final VoidCallback onShowPlan;

  const TripOverviewTab({super.key, required this.trip, required this.onShowPlan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocks = ref.watch(tripResolvedBlockDatesProvider(trip.id));
    final status = ref.watch(tripStatusProvider(trip.id));
    final stopCount = ref.watch(tripStopsProvider(trip.id)).valueOrNull?.length ?? 0;
    final view = ref.watch(plannerViewProvider(trip.id)).valueOrNull;
    final dated = blocks.where((b) => !b.isBackup && b.date != null).toList();
    final datedCount = blocks.where((b) => !b.isBackup).length;

    final today = normalizeDateOnly(DateTime.now());
    final todayDay = status == TripStatus.ongoing
        ? view?.datedDays.where((d) => d.date == today).firstOrNull
        : null;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
            const SizedBox(height: 4),
            Text(
              stopCount == 0 ? 'No stops yet' : stopCount == 1 ? '1 stop' : '$stopCount stops',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (trip.description != null && trip.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(trip.description!, style: theme.textTheme.bodyMedium),
            ],
            if (todayDay != null) ...[
              const SizedBox(height: 16),
              _TodayCard(tripId: trip.id, day: todayDay, onShowPlan: onShowPlan),
            ],
            const SizedBox(height: 24),
            Text('Days', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final b in blocks) _DayRow(block: b, today: b.date == today && !b.isBackup),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final String tripId;
  final PlannerDay day;
  final VoidCallback onShowPlan;

  const _TodayCard({required this.tripId, required this.day, required this.onShowPlan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final ink = theme.colorScheme.onSurface;
    final done = day.items.where((it) => it.done).length;
    return Card(
      elevation: 0,
      color: p.teaSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined, size: 20, color: p.tea),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Today · Day ${day.index + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(color: p.tea, fontWeight: FontWeight.w700),
                  ),
                ),
                if (day.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('$done of ${day.items.length} visited',
                        style: theme.textTheme.labelMedium?.copyWith(color: p.tea)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (day.items.isEmpty) Text('Nothing planned for today.', style: TextStyle(color: ink)),
            for (final it in day.items)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showPlannerStopSheet(context, tripId: tripId, stopId: it.stop.id, editing: false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(formatTimelineMinutes(it.startMinutes),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: p.tea, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                      Expanded(
                        child: Text(
                          it.stop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: it.done ? theme.colorScheme.onSurfaceVariant : ink,
                            decoration: it.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (it.done) Icon(Icons.check_circle, size: 18, color: p.tea),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onShowPlan,
                style: TextButton.styleFrom(foregroundColor: p.tea),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Open the plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final ResolvedBlockDate block;
  final bool today;

  const _DayRow({required this.block, required this.today});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final date = block.date;
    final (badgeBg, badgeFg) = block.isBackup
        ? (theme.colorScheme.surfaceContainerHighest, theme.colorScheme.onSurfaceVariant)
        : today
            ? (p.tea, theme.colorScheme.surface)
            : (p.teaSoft, p.tea);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(10)),
        child: block.isBackup
            ? Icon(Icons.inventory_2_outlined, size: 18, color: badgeFg)
            : Text('${block.index + 1}',
                style: theme.textTheme.titleSmall?.copyWith(color: badgeFg, fontWeight: FontWeight.w800)),
      ),
      title: Text(
        block.isBackup ? 'Backup' : today ? 'Day ${block.index + 1} · Today' : 'Day ${block.index + 1}',
        style: today ? TextStyle(color: p.tea, fontWeight: FontWeight.w700) : null,
      ),
      subtitle: Text(
        block.isBackup ? (block.block.title ?? 'No date') : date == null ? 'No date yet' : DateFormat.MMMEd().format(date),
      ),
      trailing: block.block.pinnedDate == null
          ? null
          : Icon(
              Icons.lock,
              size: 18,
              color: block.hasConflict ? theme.colorScheme.error : p.vermilion,
              semanticLabel: 'Pinned',
            ),
    );
  }
}
