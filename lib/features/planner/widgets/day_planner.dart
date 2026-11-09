import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_result.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/name_dialog.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../../trip/providers/trip_providers.dart';
import '../../trip/screens/trip_stops_screen.dart' show openAddStopsSheet;
import '../controllers/day_planner_controller.dart';
import '../models/planner_view.dart';
import '../providers/planner_providers.dart';
import 'day_card.dart';
import 'planner_drag.dart';
import 'planner_grid.dart';
import 'planner_sheets.dart';

/// Asks a [DayPlanner] to show a stop: the carousel pages to its day, or to
/// the backlog when it's on no day.
class PlannerJump extends ChangeNotifier {
  String? _stopId;

  void toStop(String stopId) {
    _stopId = stopId;
    notifyListeners();
  }

  String? _take() {
    final id = _stopId;
    _stopId = null;
    return id;
  }
}

/// The trip's plan: one day at a time in a carousel, or all days in a grid,
/// with the backlog last. [editing] is on for the people who can change the
/// trip; without it nothing can be changed or dragged.
class DayPlanner extends ConsumerStatefulWidget {
  final String tripId;
  final bool grid;
  final bool editing;
  final ValueChanged<bool> onGridChanged;
  final PlannerJump? jump;

  const DayPlanner({
    super.key,
    required this.tripId,
    required this.grid,
    required this.editing,
    required this.onGridChanged,
    this.jump,
  });

  @override
  ConsumerState<DayPlanner> createState() => _DayPlannerState();
}

class _DayPlannerState extends ConsumerState<DayPlanner> {
  static const _tickEvery = Duration(milliseconds: 16);
  static const _edgeWidth = 32.0;
  static const _edgeDelay = Duration(milliseconds: 550);

  final _drag = PlannerDragState();
  final _lists = <String, ListHandle>{};
  PageController _pages = PageController(viewportFraction: 0.88);
  Timer? _ticker;
  int _edgeDir = 0;
  Duration _edgeHeld = Duration.zero;

  /// The page shown in the carousel, kept across grid round trips.
  int _page = 0;
  bool _startPicked = false;

  /// A day to show once it appears, after it was just added or opened from the grid.
  String? _focusDayId;
  bool _focusBacklog = false;

  /// A stop to show, from [DayPlanner.jump], once the plan is loaded.
  String? _jumpStopId;

  final _pointers = <int, Offset>{};
  double? _pinchStart;
  bool _pinchDone = false;

  DayPlannerController get _controller => ref.read(dayPlannerControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _drag.addListener(_onDragChanged);
    widget.jump?.addListener(_onJump);
    // Asked for before this planner was built.
    _jumpStopId = widget.jump?._take();
  }

  void _onJump() {
    final stopId = widget.jump?._take();
    if (stopId != null) setState(() => _jumpStopId = stopId);
  }

  @override
  void didUpdateWidget(DayPlanner old) {
    super.didUpdateWidget(old);
    if (old.jump != widget.jump) {
      old.jump?.removeListener(_onJump);
      widget.jump?.addListener(_onJump);
    }
    if (old.grid && !widget.grid) {
      // Coming back from the grid: the carousel is rebuilt at the remembered page.
      _pages.dispose();
      _pages = PageController(viewportFraction: 0.88, initialPage: _page);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.jump?.removeListener(_onJump);
    _drag.removeListener(_onDragChanged);
    _drag.dispose();
    _pages.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dragging: edge paging and scrolling the list under the finger.

  void _onDragChanged() {
    if (_drag.active != null) {
      _ticker ??= Timer.periodic(_tickEvery, (_) => _tick());
    } else {
      _ticker?.cancel();
      _ticker = null;
      _edgeDir = 0;
      _edgeHeld = Duration.zero;
    }
  }

  void _tick() {
    final pointer = _drag.pointer;
    final box = context.findRenderObject() as RenderBox?;
    if (pointer == null || box == null || !mounted || widget.grid) return;
    final local = box.globalToLocal(pointer);

    final dir = local.dx < _edgeWidth ? -1 : (local.dx > box.size.width - _edgeWidth ? 1 : 0);
    if (dir != _edgeDir) {
      _edgeDir = dir;
      _edgeHeld = Duration.zero;
    } else if (dir != 0) {
      _edgeHeld += _tickEvery;
      if (_edgeHeld >= _edgeDelay && _pages.hasClients) {
        _edgeHeld = -const Duration(milliseconds: 250);
        final target = (_pages.page?.round() ?? _page) + dir;
        if (target >= 0) _pages.animateToPage(target, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
      }
    }

    for (final handle in _lists.values) {
      final rect = handle.globalRect;
      if (rect == null || !rect.contains(pointer) || !handle.controller.hasClients) continue;
      const zone = 56.0;
      double delta = 0;
      if (pointer.dy < rect.top + zone) delta = -(rect.top + zone - pointer.dy) / 4;
      if (pointer.dy > rect.bottom - zone) delta = (pointer.dy - (rect.bottom - zone)) / 4;
      if (delta == 0) continue;
      final position = handle.controller.position;
      handle.controller.jumpTo((position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent));
    }
  }

  // ---------------------------------------------------------------------------
  // Pinch: fingers apart shows one day, together shows all days. Listening to
  // raw pointers keeps the carousel's own swiping working.

  double _spread() {
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _pinchStart = _spread();
      _pinchDone = false;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    // The dragged row reports moves only while it exists; once the carousel
    // pages past its day it's disposed, so follow the finger from here too.
    if (_drag.active != null && _pointers.length == 1) _drag.move(e.position);
    final start = _pinchStart;
    if (_pointers.length != 2 || start == null || start == 0 || _pinchDone || _drag.active != null) return;
    final ratio = _spread() / start;
    if (!widget.grid && ratio < 0.72) {
      _pinchDone = true;
      widget.onGridChanged(true);
    } else if (widget.grid && ratio > 1.38) {
      _pinchDone = true;
      widget.onGridChanged(false);
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStart = null;
  }

  // ---------------------------------------------------------------------------
  // Changes.

  void _report(AppResult<dynamic> result, {String? ok, SnackBarAction? action}) =>
      reportResult(context, result, ok: ok, action: action);

  Future<void> _dropOnDay(PlannerDrag drag, DropSlot slot) async {
    final result = switch (drag) {
      ItemDrag(:final itemId) =>
        await _controller.moveItem(itemId: itemId, toDayId: slot.dayId, beforeItemId: slot.beforeItemId),
      BacklogDrag(:final stopId) => await _controller.scheduleStop(
          tripId: widget.tripId,
          stopId: stopId,
          dayId: slot.dayId,
          beforeItemId: slot.beforeItemId,
        ),
    };
    _report(result);
  }

  Future<void> _toBacklog(ItemDrag drag, String name) async {
    final result = await _controller.unschedule(drag.itemId);
    _report(result,
        ok: 'Moved $name to the backlog.',
        action: SnackBarAction(label: 'Undo', onPressed: () => _controller.restoreItem(drag.itemId)));
  }

  Future<void> _dropOnNewDay(PlannerDrag drag) async {
    final added = await _controller.addDay(widget.tripId, backup: false);
    if (added case Success(:final value)) {
      _focusDayId = value;
      await _dropOnDay(drag, DropSlot(value, null));
    } else {
      _report(added);
    }
  }

  Future<void> _addDay({required bool backup}) async {
    final added = await _controller.addDay(widget.tripId, backup: backup);
    if (added case Success(:final value)) {
      setState(() => _focusDayId = value);
    } else {
      _report(added);
    }
  }

  Future<void> _removeDay(PlannerDay day) async {
    if (day.items.isNotEmpty) {
      _report(const Failure('Move this day\'s stops first, or put them back in the backlog.'));
      return;
    }
    _report(await _controller.removeDay(widget.tripId, day.day.id), ok: 'Removed ${dayLabel(day)}.');
  }

  void _showDayFromGrid(PlannerView view, {PlannerDay? day, bool backlog = false}) {
    _focusDayId = day?.day.id;
    _focusBacklog = backlog;
    _page = backlog ? view.days.length + (widget.editing ? 1 : 0) : (day?.index ?? _page);
    widget.onGridChanged(false);
  }

  /// Opens on today's day while the trip is under way. Usually runs before
  /// the carousel is first built, so its controller can still be swapped;
  /// when the days came in after it was built, it jumps there instead.
  void _startAtToday(PlannerView view) {
    final today = normalizeDateOnly(DateTime.now());
    final day = view.datedDays.where((d) => d.date == today).firstOrNull;
    if (day == null || day.index == _page) return;
    final page = _page = day.index;
    if (_pages.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients) _pages.jumpToPage(page);
      });
      return;
    }
    _pages.dispose();
    _pages = PageController(viewportFraction: 0.88, initialPage: _page);
  }

  /// Turns a stop asked for by [DayPlanner.jump] into its day, or the
  /// backlog, to page to; from the grid, it goes back to one day at a time.
  void _resolveJump(PlannerView view) {
    final stopId = _jumpStopId;
    // Until the days, stops and their places on the days have all loaded, a
    // stop could look like it's in the backlog.
    if (stopId == null || !_loaded) return;
    _jumpStopId = null;
    final day = view.days.where((d) => d.items.any((it) => it.stop.id == stopId)).firstOrNull;
    if (day != null) {
      _focusDayId = day.day.id;
      _page = day.index;
    } else if (view.backlog.any((s) => s.id == stopId)) {
      _focusBacklog = true;
      _page = view.days.length + (widget.editing ? 1 : 0);
    } else {
      return;
    }
    if (widget.grid) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onGridChanged(false));
  }

  bool get _loaded =>
      ref.read(tripDaysProvider(widget.tripId)).hasValue &&
      ref.read(tripStopsProvider(widget.tripId)).hasValue &&
      ref.read(scheduleItemsForTripProvider(widget.tripId)).hasValue;

  /// Moves the carousel to a day that was just added or opened, once it's there.
  void _applyFocus(PlannerView view) {
    final pageCount = view.days.length + (widget.editing ? 2 : 1);
    int? target;
    if (_focusBacklog) {
      target = pageCount - 1;
    } else if (_focusDayId != null) {
      target = view.dayById(_focusDayId!)?.index;
    }
    if (target == null) return;
    _focusDayId = null;
    _focusBacklog = false;
    final page = target;
    _page = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pages.hasClients) _pages.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewAsync = ref.watch(plannerViewProvider(widget.tripId));
    return viewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Couldn't load the plan: $e")),
      data: (view) {
        if (view == null) return const Center(child: Text('This trip was deleted.'));
        // The trip loads before its days, so wait for them.
        if (!_startPicked && view.days.isNotEmpty) {
          _startPicked = true;
          // A stop asked for wins over today.
          if (_jumpStopId == null) _startAtToday(view);
        }
        _resolveJump(view);
        if (!widget.grid) _applyFocus(view);
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          child: widget.grid ? _grid(view) : _single(view),
        );
      },
    );
  }

  Widget _grid(PlannerView view) {
    final current = _page < view.days.length ? view.days[_page].day.id : null;
    return PlannerGrid(
      view: view,
      editing: widget.editing,
      currentDayId: current,
      onOpenDay: (day) => _showDayFromGrid(view, day: day),
      onOpenBacklog: () => _showDayFromGrid(view, backlog: true),
      onSwap: (dragged, target) async =>
          _report(await _controller.swapDays(a: dragged.day, b: target.day), ok: 'Swapped ${dayLabel(dragged)} and ${dayLabel(target)}.'),
      onMoveToTrip: (day) async =>
          _report(await _controller.moveDayToTrip(widget.tripId, day.day), ok: 'Added the backup day to the trip.'),
      onMoveToBackup: (day) async =>
          _report(await _controller.moveDayToBackup(widget.tripId, day.day), ok: 'Moved ${dayLabel(day)} to the backup days.'),
      onAddDay: () => _addDay(backup: false),
      onAddBackup: () => _addDay(backup: true),
      onNotice: (message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))),
    );
  }

  Widget _single(PlannerView view) {
    final actions = DayCardActions(
      onDrop: _dropOnDay,
      onOpenStop: (item) => showPlannerStopSheet(context, tripId: widget.tripId, stopId: item.stop.id, editing: widget.editing),
      onToggleVisited: ref.watch(canEditTripProvider(widget.tripId))
          ? (item) async => _report(await _controller.setVisited(item.item.id, !item.done))
          : null,
      onPin: (day) => showPinSheet(context, ref, view, day),
      onAddFromBacklog: (day) => showAddFromBacklogSheet(context, tripId: widget.tripId, day: day),
      onMoveToBackup: (day) async =>
          _report(await _controller.moveDayToBackup(widget.tripId, day.day), ok: 'Moved ${dayLabel(day)} to the backup days.'),
      onMoveToTrip: (day) async =>
          _report(await _controller.moveDayToTrip(widget.tripId, day.day), ok: 'Added the backup day to the trip.'),
      onRemove: _removeDay,
      onRename: (day) async {
        final title = await askName(
          context,
          title: day.day.title == null ? 'Name ${dayLabel(day)}' : 'Rename ${dayLabel(day)}',
          action: 'Save',
          initial: day.day.title ?? '',
          allowEmpty: true,
          message: 'For example "Uji" or "Rainy day". Leave it empty to take the name off.',
        );
        if (title == null) return;
        _report(await _controller.setDayTitle(day.day.id, title));
      },
      onOpenMap: (day) => context.push('/trips/${widget.tripId}/map?day=${Uri.encodeQueryComponent(day.day.id)}'),
      onAddStops: () => openAddStopsSheet(context, widget.tripId),
      hasBacklog: view.backlog.isNotEmpty,
      onZoomOut: () => widget.onGridChanged(true),
      registerList: (id, handle) => _lists[id] = handle,
      unregisterList: (id, handle) {
        if (_lists[id] == handle) _lists.remove(id);
      },
    );
    final pageCount = view.days.length + (widget.editing ? 2 : 1);

    return Stack(
      children: [
        PageView.builder(
          controller: _pages,
          itemCount: pageCount,
          onPageChanged: (i) => _page = i,
          itemBuilder: (context, i) {
            final Widget page;
            if (i < view.days.length) {
              page = DayCard(day: view.days[i], editing: widget.editing, drag: _drag, actions: actions);
            } else if (widget.editing && i == view.days.length) {
              page = _AddDayPage(view: view, onAddDay: () => _addDay(backup: false), onAddBackup: () => _addDay(backup: true), onDrop: _dropOnNewDay);
            } else {
              page = _BacklogPage(view: view, tripId: widget.tripId, editing: widget.editing, drag: _drag, onDrop: _toBacklog);
            }
            return Padding(padding: const EdgeInsets.fromLTRB(5, 12, 5, 16), child: page);
          },
        ),
        ListenableBuilder(
          listenable: _drag,
          builder: (context, _) {
            final drag = _drag.active;
            if (drag is! ItemDrag) return const SizedBox.shrink();
            final name = view.days.expand((d) => d.items).where((it) => it.item.id == drag.itemId).firstOrNull?.stop.name ?? 'the stop';
            return Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _DropBar(onDrop: (d) => _toBacklog(d, name)),
            );
          },
        ),
      ],
    );
  }
}

/// Shown at the bottom while a stop is dragged: drop it here to take it off
/// its day without paging to the backlog.
class _DropBar extends StatelessWidget {
  final void Function(ItemDrag drag) onDrop;

  const _DropBar({required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = theme.trip;
    return DragTarget<PlannerDrag>(
      onWillAcceptWithDetails: (details) => details.data is ItemDrag,
      onAcceptWithDetails: (details) => onDrop(details.data as ItemDrag),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final foreground = hovering ? scheme.surface : p.tea;
        return Material(
          elevation: 6,
          color: hovering ? p.tea : p.teaSoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: p.tea, width: 1.5),
          ),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, color: foreground),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Drop here to move it to the backlog',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The page after the last day while editing: add a day or a backup day, or
/// drop a stop here to start a new day with it.
class _AddDayPage extends StatelessWidget {
  final PlannerView view;
  final VoidCallback onAddDay;
  final VoidCallback onAddBackup;
  final void Function(PlannerDrag drag) onDrop;

  const _AddDayPage({required this.view, required this.onAddDay, required this.onAddBackup, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final next = view.nextDayDate;
    return DragTarget<PlannerDrag>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => Card(
        margin: EdgeInsets.zero,
        color: candidates.isNotEmpty ? p.teaSoft : theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.tea.withValues(alpha: candidates.isNotEmpty ? 1 : 0.45), width: 1.5),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: p.teaSoft, shape: BoxShape.circle),
                  child: Icon(Icons.add, size: 40, color: p.tea),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('addDayButton'),
                  onPressed: onAddDay,
                  style: FilledButton.styleFrom(backgroundColor: p.tea, foregroundColor: theme.colorScheme.surface),
                  child: Text('Add Day ${view.datedDays.length + 1}'),
                ),
                const SizedBox(height: 6),
                Text(
                  next == null ? 'It gets a date once the trip has a start date.' : 'It would be ${DateFormat.MMMEd().format(next)}.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: onAddBackup, child: const Text('Add a backup day')),
                const SizedBox(height: 20),
                Text(
                  'Or drop a stop here to start a new day with it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The trip's stops that are on no day. While editing, they are dragged onto
/// days from here, and stops dropped here leave their day.
class _BacklogPage extends StatelessWidget {
  final PlannerView view;
  final String tripId;
  final bool editing;
  final PlannerDragState drag;
  final void Function(ItemDrag drag, String name) onDrop;

  const _BacklogPage({required this.view, required this.tripId, required this.editing, required this.drag, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<PlannerDrag>(
      onWillAcceptWithDetails: (details) => editing && details.data is ItemDrag,
      onAcceptWithDetails: (details) {
        final d = details.data as ItemDrag;
        final name = view.days.expand((day) => day.items).where((it) => it.item.id == d.itemId).firstOrNull?.stop.name ?? 'the stop';
        onDrop(d, name);
      },
      builder: (context, candidates, _) => Card(
        margin: EdgeInsets.zero,
        color: candidates.isNotEmpty ? theme.trip.teaSoft : theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: candidates.isNotEmpty ? BorderSide(color: theme.trip.tea, width: 2) : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Row(
                children: [
                  Icon(Icons.inbox_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('BACKLOG',
                      style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                view.backlog.isEmpty ? 'All planned' : '${view.backlog.length} not planned',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                editing && view.backlog.isNotEmpty
                    ? 'Hold a stop and drag it onto a day.'
                    : 'Stops in this trip that are not on a day yet.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () => openAddStopsSheet(context, tripId),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add stops'),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
                children: [
                  for (final s in view.backlog) _backlogRow(context, s.id, s.name),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backlogRow(BuildContext context, String stopId, String name) {
    final row = ListTile(
      leading: Icon(Icons.place_outlined, color: Theme.of(context).trip.tea),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => showPlannerStopSheet(context, tripId: tripId, stopId: stopId, editing: editing),
    );
    if (!editing) return row;
    final data = BacklogDrag(stopId: stopId);
    return LongPressDraggable<PlannerDrag>(
      data: data,
      delay: const Duration(milliseconds: 350),
      hapticFeedbackOnStart: true,
      onDragStarted: () => drag.start(data),
      onDragUpdate: (details) => drag.move(details.globalPosition),
      // Not onDragEnd, which is skipped once this row is disposed (see StopRow).
      onDragCompleted: drag.end,
      onDraggableCanceled: (_, _) => drag.end(),
      feedback: DragFeedbackCard(title: name),
      childWhenDragging: Opacity(opacity: 0.3, child: row),
      child: row,
    );
  }
}
