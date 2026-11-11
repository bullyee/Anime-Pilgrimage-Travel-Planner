import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../trip/models/stop_group.dart';
import '../models/planner_view.dart';
import 'planner_drag.dart';

/// Callbacks a day card hands back to the planner.
class DayCardActions {
  final void Function(PlannerDrag drag, DropSlot slot) onDrop;
  final void Function(PlannerItem item) onOpenStop;
  /// Null when the user can only view the trip.
  final void Function(PlannerItem item)? onToggleVisited;
  final void Function(PlannerDay day) onPin;
  final void Function(PlannerDay day) onAddFromBacklog;
  final void Function(PlannerDay day) onMoveToBackup;
  final void Function(PlannerDay day) onMoveToTrip;
  final void Function(PlannerDay day) onRemove;
  final void Function(PlannerDay day) onRename;
  final VoidCallback onZoomOut;
  final void Function(String dayId, ListHandle handle) registerList;
  final void Function(String dayId, ListHandle handle) unregisterList;

  /// Whether a group's block is open, by [groupKey]. The planner keeps this
  /// while it is shown; it isn't stored.
  final bool Function(String key) isGroupExpanded;
  final void Function(String key) onToggleGroup;

  const DayCardActions({
    required this.onDrop,
    required this.onOpenStop,
    this.onToggleVisited,
    required this.onPin,
    required this.onAddFromBacklog,
    required this.onMoveToBackup,
    required this.onMoveToTrip,
    required this.onRemove,
    required this.onRename,
    required this.onZoomOut,
    required this.registerList,
    required this.unregisterList,
    required this.isGroupExpanded,
    required this.onToggleGroup,
  });
}

/// What a group's block on a day is known by while it is open.
String groupKey(String dayId, String group) => '$dayId/$group';

/// "Day 2", or "Backup day".
String dayLabel(PlannerDay day) => day.isBackup ? 'Backup day' : 'Day ${day.index + 1}';

/// [dayLabel] with the day's title when it has one: "Day 2 · Uji", or
/// "Backup · Rainy day", so backup days can be told apart.
String dayName(PlannerDay day) {
  final title = day.day.title?.trim() ?? '';
  if (title.isEmpty) return dayLabel(day);
  return day.isBackup ? 'Backup · $title' : '${dayLabel(day)} · $title';
}

/// "Day 2 · Wed, Nov 4 · Uji": the day, its date and its title, as far as known.
String dayWithDate(PlannerDay day) => [
      dayLabel(day),
      if (day.date != null) DateFormat.MMMEd().format(day.date!),
      if (day.day.title?.trim().isNotEmpty ?? false) day.day.title!.trim(),
    ].join(' · ');

/// Notes the free dates a pin left before [day], or null when there are none.
String? freeDaysLabel(PlannerDay day) => switch (day.freeDaysBefore) {
      <= 0 => null,
      1 => 'After 1 free day',
      final n => 'After $n free days',
    };

/// One day of the single-day view: its date, its stops with times, and, while
/// editing, the ways to change it.
class DayCard extends StatefulWidget {
  final PlannerDay day;
  final bool editing;
  final PlannerDragState drag;
  final DayCardActions actions;

  const DayCard({super.key, required this.day, required this.editing, required this.drag, required this.actions});

  @override
  State<DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<DayCard> {
  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  final _rowKeys = <String, GlobalKey>{};
  late final ListHandle _handle = ListHandle(_listKey, _scroll);

  String get _dayId => widget.day.day.id;

  @override
  void initState() {
    super.initState();
    widget.actions.registerList(_dayId, _handle);
  }

  @override
  void didUpdateWidget(DayCard old) {
    super.didUpdateWidget(old);
    if (old.day.day.id != _dayId) {
      old.actions.unregisterList(old.day.day.id, _handle);
      widget.actions.registerList(_dayId, _handle);
    }
  }

  @override
  void dispose() {
    widget.actions.unregisterList(_dayId, _handle);
    _scroll.dispose();
    super.dispose();
  }

  /// The ids of the items being dragged, if they are on a day.
  Set<String> get _draggedIds => switch (widget.drag.active) {
        ItemDrag(:final itemId) => {itemId},
        GroupDrag(:final itemIds) => itemIds.toSet(),
        _ => const {},
      };

  /// The slot under [global]: before the first block whose middle is below
  /// it. A group's block takes nothing in between its stops.
  DropSlot _slotAt(Offset global) {
    final dragged = _draggedIds;
    for (final block in widget.day.blocks) {
      final id = block.first.item.id;
      if (dragged.contains(id)) continue;
      final box = _rowKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (global.dy < top + box.size.height / 2) return DropSlot(_dayId, id);
    }
    return DropSlot(_dayId, null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.day;
    final first = d.items.isEmpty ? null : d.items.first;
    final last = d.items.isEmpty ? null : d.items.last;
    final meta = first == null
        ? 'Nothing planned yet'
        : '${d.items.length == 1 ? '1 stop' : '${d.items.length} stops'} · '
            '${formatTimelineMinutes(first.startMinutes)}–${formatTimelineMinutes(last!.endMinutes)}';

    final today = !d.isBackup && d.date == normalizeDateOnly(DateTime.now());
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: d.isBackup ? theme.colorScheme.surfaceContainerLow : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: d.isBackup
            ? BorderSide(color: theme.colorScheme.outlineVariant, width: 1.5)
            : today
                ? BorderSide(color: theme.trip.tea, width: 2)
                : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DayHeader(day: d, editing: widget.editing, actions: widget.actions),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: DragTarget<PlannerDrag>(
              onWillAcceptWithDetails: (_) => widget.editing,
              onMove: (_) {
                final p = widget.drag.pointer;
                if (p != null) widget.drag.slot = _slotAt(p);
              },
              onLeave: (_) {
                if (widget.drag.slot?.dayId == _dayId) widget.drag.slot = null;
              },
              onAcceptWithDetails: (details) {
                final p = widget.drag.pointer;
                widget.actions.onDrop(details.data, p == null ? DropSlot(_dayId, null) : _slotAt(p));
              },
              builder: (context, _, _) => ListenableBuilder(
                listenable: widget.drag,
                builder: (context, _) => _list(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.day;
    final slot = widget.drag.slot;
    final dragging = widget.drag.active;
    final draggedIds = _draggedIds;
    final here = dragging != null && slot != null && slot.dayId == _dayId;

    Widget between(PlannerItem previous) => previous.item.transitMinutes > 0
        ? _TravelLine(minutes: previous.item.transitMinutes)
        : Divider(height: 1, indent: 72, endIndent: 12, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5));
    // A group's stops are dragged with their group, not on their own.
    StopRow stopRow(PlannerItem it, {required bool inGroup}) => StopRow(
          item: it,
          dayId: _dayId,
          editing: widget.editing && !inGroup,
          dimmed: !inGroup && draggedIds.contains(it.item.id),
          drag: widget.drag,
          group: inGroup ? null : it.group,
          onTap: () => widget.actions.onOpenStop(it),
          onToggleVisited: switch (widget.actions.onToggleVisited) {
            final toggle? => () => toggle(it),
            null => null,
          },
        );

    final rows = <Widget>[];
    PlannerItem? previous;
    for (final block in d.blocks) {
      if (here && slot.beforeItemId == block.first.item.id) rows.add(const _InsertLine());
      if (previous != null) rows.add(between(previous));
      previous = block.items.last;
      final Widget child;
      if (block.group case final group?) {
        final key = groupKey(_dayId, group);
        child = GroupBlock(
          block: block,
          dayId: _dayId,
          editing: widget.editing,
          expanded: widget.actions.isGroupExpanded(key),
          dimmed: draggedIds.contains(block.first.item.id),
          drag: widget.drag,
          onToggle: () => widget.actions.onToggleGroup(key),
          rows: [
            for (final (i, it) in block.items.indexed) ...[
              if (i > 0) between(block.items[i - 1]),
              stopRow(it, inGroup: true),
            ],
          ],
        );
      } else {
        child = stopRow(block.first, inGroup: false);
      }
      rows.add(KeyedSubtree(key: _rowKeys.putIfAbsent(block.first.item.id, GlobalKey.new), child: child));
    }
    if (here && slot.beforeItemId == null) rows.add(const _InsertLine());

    if (widget.editing) {
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          onPressed: () => widget.actions.onAddFromBacklog(d),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.trip.tea,
            side: BorderSide(color: theme.trip.tea.withValues(alpha: 0.6), width: 1.5),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add from backlog'),
        ),
      ));
      if (d.items.isEmpty) {
        rows.add(TextButton(
          onPressed: () => widget.actions.onRemove(d),
          child: const Text('Remove this day'),
        ));
      }
    } else if (d.items.isEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Tap the pencil to plan this day.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ));
    }

    return ListView(
      key: _listKey,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
      children: rows,
    );
  }
}

class _DayHeader extends StatelessWidget {
  final PlannerDay day;
  final bool editing;
  final DayCardActions actions;

  const _DayHeader({required this.day, required this.editing, required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = day.date;
    final heading = day.isBackup
        ? (day.day.title ?? 'Backup')
        : date == null
            ? 'No date yet'
            : DateFormat.MMMEd().format(date);
    final title = !day.isBackup && day.day.title != null ? day.day.title! : null;
    final p = theme.trip;
    final today = !day.isBackup && date == normalizeDateOnly(DateTime.now());

    return GestureDetector(
      // Holding the date shows all days, where days are rearranged.
      onLongPress: actions.onZoomOut,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dayLabel(day).toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: day.isBackup ? theme.colorScheme.onSurfaceVariant : p.tea,
                        ),
                      ),
                      if (today) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: p.tea, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            'TODAY',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.surface, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(heading, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (freeDaysLabel(day) case final free?)
                    Text(free, style: theme.textTheme.labelLarge?.copyWith(color: p.vermilion)),
                  if (title != null)
                    Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (!day.isBackup && (editing || day.isPinned))
              IconButton(
                tooltip: day.isPinned ? 'Pinned date' : 'Pin this day to a date',
                onPressed: editing ? () => actions.onPin(day) : null,
                style: day.isPinned ? IconButton.styleFrom(backgroundColor: p.vermilionSoft) : null,
                icon: Icon(
                  day.isPinned ? Icons.lock : Icons.lock_open_outlined,
                  color: day.isPinned
                      ? (day.pinConflict ? theme.colorScheme.error : p.vermilion)
                      : theme.colorScheme.outline,
                ),
              ),
            if (editing)
              PopupMenuButton<String>(
                tooltip: 'Day options',
                onSelected: (value) {
                  switch (value) {
                    case 'backup':
                      actions.onMoveToBackup(day);
                    case 'trip':
                      actions.onMoveToTrip(day);
                    case 'remove':
                      actions.onRemove(day);
                    case 'rename':
                      actions.onRename(day);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rename', child: Text(day.day.title == null ? 'Name this day' : 'Rename this day')),
                  if (!day.isBackup)
                    PopupMenuItem(
                      value: 'backup',
                      enabled: !day.isPinned,
                      child: const Text('Move to backup days'),
                    ),
                  if (day.isBackup) const PopupMenuItem(value: 'trip', child: Text('Add to the trip as its last day')),
                  PopupMenuItem(
                    value: 'remove',
                    enabled: day.items.isEmpty,
                    child: Text(day.items.isEmpty ? 'Remove this day' : 'Remove this day (move its stops first)'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A stop on a day: start time, name, and whether it was visited.
class StopRow extends StatelessWidget {
  final PlannerItem item;
  final String dayId;
  final bool editing;
  final bool dimmed;
  final PlannerDragState drag;
  final VoidCallback onTap;

  /// The group to note under the name, for a stop of a group that has no
  /// other stop next to it on the day.
  final String? group;

  /// Null when the user can only view the trip: the circle then only shows
  /// whether the stop was visited.
  final VoidCallback? onToggleVisited;

  const StopRow({
    super.key,
    required this.item,
    required this.dayId,
    required this.editing,
    required this.dimmed,
    required this.drag,
    required this.onTap,
    required this.onToggleVisited,
    this.group,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = _row(theme);
    if (!editing) return row;
    final data = ItemDrag(itemId: item.item.id, stopId: item.stop.id, fromDayId: dayId);
    return LongPressDraggable<PlannerDrag>(
      data: data,
      delay: const Duration(milliseconds: 350),
      hapticFeedbackOnStart: true,
      onDragStarted: () {
        // An Undo from the last move would cover the backlog bar.
        ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
        drag.start(data);
      },
      onDragUpdate: (details) => drag.move(details.globalPosition),
      // Not onDragEnd: it's skipped once this row is disposed, which happens
      // when the carousel pages past its day mid-drag. These two still run.
      onDragCompleted: drag.end,
      onDraggableCanceled: (_, _) => drag.end(),
      feedback: DragFeedbackCard(
        title: item.stop.name,
        subtitle: formatTimelineMinutes(item.startMinutes),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: row),
      child: dimmed ? Opacity(opacity: 0.3, child: row) : row,
    );
  }

  Widget _row(ThemeData theme) {
    final done = item.done;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.fixed)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Icon(Icons.schedule, size: 14, color: theme.trip.tea),
                      ),
                    Text(
                      formatTimelineMinutes(item.startMinutes),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        color: item.conflict
                            ? theme.trip.vermilion
                            : item.fixed
                                ? theme.trip.tea
                                : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.stop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? theme.colorScheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (group case final group?) GroupChip(name: group),
                  ],
                ),
              ),
              IconButton(
                tooltip: done ? 'Mark as not visited' : 'Mark as visited',
                onPressed: onToggleVisited,
                icon: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? theme.trip.tea : theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A group's stops that follow each other on a day, as one slot: the time
/// they take, the group's name and how many were visited. It opens to show
/// its stops; while editing, the header drags the whole group.
class GroupBlock extends StatelessWidget {
  final PlannerBlock block;
  final String dayId;
  final bool editing;
  final bool expanded;
  final bool dimmed;
  final PlannerDragState drag;
  final VoidCallback onToggle;

  /// The group's stops, shown when [expanded].
  final List<Widget> rows;

  const GroupBlock({
    super.key,
    required this.block,
    required this.dayId,
    required this.editing,
    required this.expanded,
    required this.dimmed,
    required this.drag,
    required this.onToggle,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = _header(theme);
    final data = GroupDrag(
      itemIds: [for (final it in block.items) it.item.id],
      group: block.group!,
      fromDayId: dayId,
    );
    final top = !editing
        ? header
        : LongPressDraggable<PlannerDrag>(
            data: data,
            delay: const Duration(milliseconds: 350),
            hapticFeedbackOnStart: true,
            onDragStarted: () => drag.start(data),
            onDragUpdate: (details) => drag.move(details.globalPosition),
            // Not onDragEnd, which is skipped once this row is disposed (see StopRow).
            onDragCompleted: drag.end,
            onDraggableCanceled: (_, _) => drag.end(),
            feedback: DragFeedbackCard(title: block.group!, subtitle: stopCount(block.items.length)),
            child: header,
          );
    final box = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: theme.trip.teaSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          top,
          if (expanded) Padding(padding: const EdgeInsets.only(left: 12, bottom: 4), child: Column(children: rows)),
        ],
      ),
    );
    return dimmed ? Opacity(opacity: 0.3, child: box) : box;
  }

  Widget _header(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final visited = block.visited;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatTimelineMinutes(block.startMinutes),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                      Text(
                        '–${formatTimelineMinutes(block.endMinutes)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.layers_outlined, size: 16, color: theme.trip.tea),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            block.group!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${stopCount(block.items.length)} · $visited visited',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: visited == block.items.length ? theme.trip.tea : muted),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 40,
                child: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  semanticLabel: expanded ? 'Hide its stops' : 'Show its stops',
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small note of the group a stop is in.
class GroupChip extends StatelessWidget {
  final String name;

  const GroupChip({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: p.teaSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: 12, color: p.tea),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: p.tea),
            ),
          ),
        ],
      ),
    );
  }
}

/// What follows the finger while a stop is dragged.
class DragFeedbackCard extends StatelessWidget {
  final String title;
  final String? subtitle;

  const DragFeedbackCard({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      color: theme.trip.teaSoft,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.drag_indicator, size: 18, color: theme.trip.tea),
            const SizedBox(width: 8),
            if (subtitle != null) ...[
              Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.trip.tea, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall)),
          ],
        ),
      ),
    );
  }
}

/// The travel time between two stops, in place of the line between them.
class _TravelLine extends StatelessWidget {
  final int minutes;

  const _TravelLine({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: 72, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(Icons.directions_walk, size: 14, color: muted),
          const SizedBox(width: 4),
          Text('$minutes min', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

class _InsertLine extends StatelessWidget {
  const _InsertLine();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).trip.tea;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Expanded(child: Container(height: 3, color: color)),
        ],
      ),
    );
  }
}
