import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/planner_view.dart';
import 'day_card.dart' show dayLabel, freeDaysLabel;

/// All days at once, two to a row. While editing, a day is held and dropped
/// on another to swap them, or on the add tiles to move it across the
/// divider between trip days and backup days.
class PlannerGrid extends StatelessWidget {
  final PlannerView view;
  final bool editing;
  final String? currentDayId;
  final void Function(PlannerDay day) onOpenDay;
  final VoidCallback onOpenBacklog;
  final void Function(PlannerDay dragged, PlannerDay target) onSwap;
  final void Function(PlannerDay day) onMoveToTrip;
  final void Function(PlannerDay day) onMoveToBackup;
  final VoidCallback onAddDay;
  final VoidCallback onAddBackup;
  final void Function(String message) onNotice;

  const PlannerGrid({
    super.key,
    required this.view,
    required this.editing,
    required this.currentDayId,
    required this.onOpenDay,
    required this.onOpenBacklog,
    required this.onSwap,
    required this.onMoveToTrip,
    required this.onMoveToBackup,
    required this.onAddDay,
    required this.onAddBackup,
    required this.onNotice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = view.nextDayDate;

    Widget grid(List<Widget> children) => GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: children,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (editing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Hold a day and drop it on another to swap them. The dates stay with their places. Pinned days stay where they are.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        grid([
          for (final d in view.datedDays) _block(context, d),
          if (editing)
            _AddTile(
              key: const Key('addDayTile'),
              label: 'Add Day ${view.datedDays.length + 1}',
              detail: next == null ? 'No date yet' : DateFormat.MMMEd().format(next),
              dropHint: 'Drop to add it to the trip',
              accepts: (id) => view.dayById(id)?.isBackup ?? false,
              onDrop: (id) => onMoveToTrip(view.dayById(id)!),
              onTap: onAddDay,
            ),
        ]),
        _Divider(label: 'Backup days'),
        if (!editing && view.backupDays.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('No backup days.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          )
        else
          grid([
            for (final d in view.backupDays) _block(context, d),
            if (editing)
              _AddTile(
                key: const Key('addBackupTile'),
                label: 'Add a backup day',
                detail: 'No date',
                dropHint: 'Drop to make it a backup day',
                accepts: (id) {
                  final d = view.dayById(id);
                  return d != null && !d.isBackup && !d.isPinned;
                },
                onDrop: (id) => onMoveToBackup(view.dayById(id)!),
                onTap: onAddBackup,
              ),
          ]),
        _Divider(label: 'Backlog'),
        grid([
          _Tile(
            dashed: true,
            current: false,
            onTap: onOpenBacklog,
            child: _Summary(
              title: 'Backlog',
              detail: view.backlog.isEmpty ? 'All planned' : '${view.backlog.length} not planned',
              lines: [for (final s in view.backlog) s.name],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _block(BuildContext context, PlannerDay day) {
    final date = day.date;
    final summary = _Summary(
      title: day.isBackup ? 'Backup' : dayLabel(day),
      detail: day.isBackup
          ? (day.day.title ?? 'No date')
          : [date == null ? 'No date yet' : DateFormat.MMMEd().format(date), ?day.day.title].join(' · '),
      note: freeDaysLabel(day),
      pinned: day.isPinned,
      pinConflict: day.pinConflict,
      lines: [for (final it in day.items) it.stop.name],
    );
    final tile = _Tile(
      dashed: day.isBackup,
      current: day.day.id == currentDayId,
      pinned: day.isPinned,
      today: !day.isBackup && date == normalizeDateOnly(DateTime.now()),
      onTap: () => onOpenDay(day),
      onLongPress: editing && day.isPinned
          ? () => onNotice('Pinned days stay in place. Unpin it in the day view to move it.')
          : null,
      child: summary,
    );
    if (!editing || day.isPinned) return tile;

    return LayoutBuilder(
      builder: (context, constraints) => DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final other = view.dayById(details.data);
          return other != null && other.day.id != day.day.id && !other.isPinned;
        },
        onAcceptWithDetails: (details) => onSwap(view.dayById(details.data)!, day),
        builder: (context, candidates, _) => LongPressDraggable<String>(
          data: day.day.id,
          delay: const Duration(milliseconds: 350),
          hapticFeedbackOnStart: true,
          feedback: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              child: _Tile(dashed: day.isBackup, current: false, child: summary),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: tile),
          child: candidates.isEmpty
              ? tile
              : DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                  ),
                  child: tile,
                ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String title;
  final String detail;
  final String? note;
  final bool pinned;
  final bool pinConflict;
  final List<String> lines;

  const _Summary({
    required this.title,
    required this.detail,
    required this.lines,
    this.note,
    this.pinned = false,
    this.pinConflict = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            if (pinned) Icon(Icons.lock, size: 16, color: pinConflict ? theme.colorScheme.error : p.vermilion),
          ],
        ),
        Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        if (note != null) Text(note!, style: theme.textTheme.bodySmall?.copyWith(color: p.vermilion)),
        const SizedBox(height: 6),
        if (lines.isEmpty) Text('Nothing planned', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        for (final line in lines.take(2))
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: p.tea, shape: BoxShape.circle),
              ),
              Expanded(child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium)),
            ],
          ),
        if (lines.length > 2) Text('+${lines.length - 2} more', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final bool dashed;
  final bool current;
  final bool pinned;
  final bool today;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _Tile({
    required this.dashed,
    required this.current,
    required this.child,
    this.pinned = false,
    this.today = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = theme.trip;
    return Material(
      color: today ? p.teaSoft : dashed ? scheme.surfaceContainerLow : scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: current
            ? BorderSide(color: p.tea, width: 2)
            : pinned
                ? BorderSide(color: p.vermilion.withValues(alpha: 0.5), width: 1.5)
                : BorderSide(color: scheme.outlineVariant, width: dashed ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final String label;
  final String detail;
  final String dropHint;
  final bool Function(String dayId) accepts;
  final void Function(String dayId) onDrop;
  final VoidCallback onTap;

  const _AddTile({
    super.key,
    required this.label,
    required this.detail,
    required this.dropHint,
    required this.accepts,
    required this.onDrop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final p = theme.trip;
        return Material(
          color: hovering ? p.teaSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: p.tea.withValues(alpha: hovering ? 1 : 0.5), width: hovering ? 2 : 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: p.teaSoft, shape: BoxShape.circle),
                    child: Icon(Icons.add, size: 20, color: p.tea),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hovering ? dropHint : label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(color: p.tea, fontWeight: FontWeight.w700),
                  ),
                  if (!hovering)
                    Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  final String label;

  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.1, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
        ],
      ),
    );
  }
}
