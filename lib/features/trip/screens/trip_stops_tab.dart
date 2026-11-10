import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_result.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/name_dialog.dart';
import '../../library/widgets/spot_thumb.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../controllers/trip_stops_controller.dart';
import '../models/stop_group.dart';
import '../providers/trip_stop_providers.dart';

/// Offers the two ways to add stops: from the library, or a new spot.
void openAddStopsSheet(BuildContext context, String tripId) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.collections_bookmark_outlined),
            title: const Text('From my library'),
            subtitle: const Text('Places you have saved'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/trips/$tripId/stops/add');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text('New spot'),
            subtitle: const Text('Pick it on the map'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/trips/$tripId/stops/new');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// The Stops tab: the trip's stops, what's planned on which day, and what
/// isn't yet. A group's stops show as one row that opens. People who can edit
/// the trip hold a stop to select stops and group them. The tab's add button
/// lives on the trip screen.
class TripStopsTab extends ConsumerStatefulWidget {
  final String tripId;

  const TripStopsTab({super.key, required this.tripId});

  @override
  ConsumerState<TripStopsTab> createState() => _TripStopsTabState();
}

class _TripStopsTabState extends ConsumerState<TripStopsTab> {
  final _search = TextEditingController();
  String _query = '';
  StopOrder _order = StopOrder.plan;

  /// The selected stops' ids, in the order they were picked.
  final _selected = <String>{};

  /// The groups that are open.
  final _open = <String>{};

  TripStopsController get _controller => ref.read(tripStopsControllerProvider.notifier);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _report(AppResult<dynamic> result, String ok) {
    if (!mounted) return;
    final message = switch (result) {
      Failure(:final error) => error,
      Success() => ok,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggle(Iterable<String> ids) => setState(() {
        if (ids.every(_selected.contains)) {
          _selected.removeAll(ids);
        } else {
          _selected.addAll(ids);
        }
      });

  Future<void> _group(List<TripStopEntry> picked) async {
    final names = picked.map((e) => e.stop.name).toSet();
    final name = await askName(
      context,
      title: 'Group ${stopCount(picked.length)}',
      action: 'Group',
      initial: names.length == 1 ? names.single : picked.first.stop.name,
      maxLength: maxGroupNameLength,
      message: 'For different spots close together. They stay together on each day of the plan.',
    );
    if (name == null || !mounted) return;
    final result = await _controller.groupStops(
      tripId: widget.tripId,
      stopIds: [for (final e in picked) e.stop.id],
      name: name,
    );
    _report(result, 'Grouped ${stopCount(picked.length)} as ${name.trim()}.');
    if (result is Success && mounted) setState(_selected.clear);
  }

  Future<void> _merge(List<TripStopEntry> picked) async {
    final keep = await showModalBottomSheet<TripStopEntry>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MergeSheet(picked: picked, initial: stopToKeep(picked)),
    );
    if (keep == null || !mounted) return;
    final result = await _controller.mergeStops(keepId: keep.stop.id, stopIds: [for (final e in picked) e.stop.id]);
    _report(result, 'Merged ${stopCount(picked.length)} into ${keep.stop.name}.');
    if (result is Success && mounted) setState(_selected.clear);
  }

  Future<void> _ungroupSelected(List<TripStopEntry> picked) async {
    final result = await _controller.ungroupStops(tripId: widget.tripId, stopIds: [for (final e in picked) e.stop.id]);
    _report(result, 'Took ${stopCount(picked.length)} out of their groups.');
    if (result is Success && mounted) setState(_selected.clear);
  }

  Future<void> _renameGroup(String group) async {
    final name = await askName(
      context,
      title: 'Rename the group',
      action: 'Save',
      initial: group,
      maxLength: maxGroupNameLength,
    );
    if (name == null || !mounted) return;
    final result = await _controller.renameGroup(tripId: widget.tripId, from: group, to: name);
    if (result is Success && _open.remove(group)) _open.add(name.trim());
    _report(result, 'Renamed the group to ${name.trim()}.');
  }

  Future<void> _ungroup(String group) async =>
      _report(await _controller.ungroup(tripId: widget.tripId, name: group), 'Ungrouped $group.');

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(tripStopEntriesProvider(widget.tripId));
    final canEdit = ref.watch(canEditTripProvider(widget.tripId));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Couldn't load the stops: $e")),
      data: (entries) {
        if (entries.isEmpty) {
          return _EmptyStops(onAdd: canEdit ? () => openAddStopsSheet(context, widget.tripId) : null);
        }
        // Stops removed meanwhile, or a role that changed, leave the selection.
        final byId = {for (final e in entries) e.stop.id: e};
        if (!canEdit) _selected.clear();
        _selected.removeWhere((id) => !byId.containsKey(id));
        final picked = [for (final id in _selected) byId[id]!];
        final selecting = picked.isNotEmpty;

        final q = _query.trim().toLowerCase();
        bool matches(TripStopEntry e) =>
            e.stop.name.toLowerCase().contains(q) ||
            (e.stop.address?.toLowerCase().contains(q) ?? false) ||
            (stopGroup(e.stop)?.toLowerCase().contains(q) ?? false);
        final rows = stopListRows(orderStopEntries(entries, _order));
        final shown = q.isEmpty ? rows : rows.where((r) => r.entries.any(matches)).toList();

        void openStop(TripStopEntry e) => context.push('/trips/${widget.tripId}/stops/${e.stop.id}');
        Widget stopTile(TripStopEntry e, {bool inGroup = false}) => _StopTile(
              entry: e,
              inGroup: inGroup,
              selecting: selecting,
              selected: _selected.contains(e.stop.id),
              onTap: selecting ? () => _toggle([e.stop.id]) : () => openStop(e),
              onLongPress: canEdit && !selecting ? () => _toggle([e.stop.id]) : null,
            );
        final tiles = <Widget>[
          for (final row in shown)
            if (row.group case final group?) ...[
              _GroupTile(
                name: group,
                entries: row.entries,
                open: _open.contains(group) || q.isNotEmpty,
                selecting: selecting,
                selected: row.entries.where((e) => _selected.contains(e.stop.id)).length,
                onTap: selecting
                    ? () => _toggle([for (final e in row.entries) e.stop.id])
                    : () => setState(() => _open.contains(group) ? _open.remove(group) : _open.add(group)),
                onLongPress: canEdit && !selecting ? () => _toggle([for (final e in row.entries) e.stop.id]) : null,
                onRename: canEdit ? () => _renameGroup(group) : null,
                onUngroup: canEdit ? () => _ungroup(group) : null,
              ),
              if (_open.contains(group) || q.isNotEmpty)
                for (final e in row.entries) stopTile(e, inGroup: true),
            ] else
              stopTile(row.entries.single),
        ];

        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(_selected.clear);
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  if (selecting)
                    _SelectionBar(
                      count: picked.length,
                      onCancel: () => setState(_selected.clear),
                      onGroup: picked.length < 2 ? null : () => _group(picked),
                      onMerge: picked.length < 2 ? null : () => _merge(picked),
                      onUngroup: picked.every((e) => stopGroup(e.stop) != null) ? () => _ungroupSelected(picked) : null,
                    )
                  else
                    _searchRow(entries.length),
                  Expanded(
                    child: shown.isEmpty
                        ? const Center(child: Text('No stops match your search.'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: tiles.length,
                            itemBuilder: (context, i) => tiles[i],
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

  Widget _searchRow(int count) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search $count stops',
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            PopupMenuButton<StopOrder>(
              tooltip: 'Sort stops',
              icon: const Icon(Icons.sort),
              onSelected: (order) => setState(() => _order = order),
              itemBuilder: (context) => [
                for (final order in StopOrder.values)
                  CheckedPopupMenuItem(value: order, checked: order == _order, child: Text(order.label)),
              ],
            ),
          ],
        ),
      );
}

/// In place of the search while stops are selected: how many, and what can
/// be done with them.
class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onCancel;

  /// Null when fewer than two stops are selected.
  final VoidCallback? onGroup;

  /// Null unless every selected stop is in a group.
  final VoidCallback? onUngroup;

  /// Null when fewer than two stops are selected.
  final VoidCallback? onMerge;

  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.onGroup,
    required this.onUngroup,
    required this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.trip.teaSoft,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      height: 56,
      child: Row(
        children: [
          IconButton(tooltip: 'Cancel', icon: const Icon(Icons.close), onPressed: onCancel),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$count selected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (onUngroup != null)
            IconButton(tooltip: 'Ungroup', icon: const Icon(Icons.layers_clear_outlined), onPressed: onUngroup),
          IconButton(tooltip: 'Group', icon: const Icon(Icons.layers_outlined), onPressed: onGroup),
          IconButton(tooltip: 'Merge', icon: const Icon(Icons.merge), onPressed: onMerge),
        ],
      ),
    );
  }
}

/// Asks which of the [picked] stops a merge keeps, starting from [initial].
class _MergeSheet extends StatefulWidget {
  final List<TripStopEntry> picked;
  final TripStopEntry initial;

  const _MergeSheet({required this.picked, required this.initial});

  @override
  State<_MergeSheet> createState() => _MergeSheetState();
}

class _MergeSheetState extends State<_MergeSheet> {
  late TripStopEntry _keep = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Merge ${stopCount(widget.picked.length)}', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'For one spot that is in this trip more than once. Pick the stop to keep: its name and facts stay. '
                'The others\' notes, labels, frames and days move to it, and they leave the trip. '
                'Your library is not changed.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in widget.picked)
                    ListTile(
                      leading: Icon(
                        e == _keep ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: e == _keep ? theme.trip.tea : theme.colorScheme.outline,
                      ),
                      title: Text(e.stop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(stopWhenLine(e)),
                      trailing: e == _keep ? const Text('Keep') : null,
                      onTap: () => setState(() => _keep = e),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () => Navigator.pop(context, _keep), child: const Text('Merge')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Day 2 · 10:20", "Backup day · 13:00" or "Not on a day yet".
String stopWhenLine(TripStopEntry e) {
  if (!e.isPlanned) return 'Not on a day yet';
  final day = e.onBackupDay ? 'Backup day' : 'Day ${e.dayIndex! + 1}';
  return e.startMinutes == null ? day : '$day · ${formatTimelineMinutes(e.startMinutes!)}';
}

class _StopTile extends StatelessWidget {
  final TripStopEntry entry;

  /// Shown inside its open group, indented.
  final bool inGroup;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StopTile({
    required this.entry,
    required this.onTap,
    this.inGroup = false,
    this.selecting = false,
    this.selected = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final fromAnitabi = entry.stop.source == 'Anitabi';
    // Tea for stops on a trip day, wisteria on a backup day, grey otherwise.
    final (background, foreground) = !entry.isPlanned
        ? (theme.colorScheme.surfaceContainerHighest, theme.colorScheme.onSurfaceVariant)
        : entry.onBackupDay
            ? (p.wisteriaSoft, p.wisteria)
            : (p.teaSoft, p.tea);
    return ListTile(
      contentPadding: EdgeInsets.only(left: inGroup ? 40 : 16, right: 16),
      selected: selected,
      leading: SpotThumb(
        placeKey: entry.stop.placeKey,
        extraCover: entry.stop.coverLocalPath,
        fallback: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
          child: Icon(fromAnitabi ? Icons.photo_camera_outlined : Icons.place_outlined, size: 20, color: foreground),
        ),
      ),
      title: Text(entry.stop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        stopWhenLine(entry),
        style: entry.isPlanned ? TextStyle(color: foreground, fontWeight: FontWeight.w600) : null,
      ),
      trailing: selecting ? Checkbox(value: selected, onChanged: (_) => onTap()) : const Icon(Icons.chevron_right),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// A group's row: its name and how many stops it has. It opens to show
/// them; for people who can edit the trip, its menu renames or ends it.
class _GroupTile extends StatelessWidget {
  final String name;
  final List<TripStopEntry> entries;
  final bool open;
  final bool selecting;

  /// How many of its stops are selected.
  final int selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Null for people who can't edit the trip.
  final VoidCallback? onRename;
  final VoidCallback? onUngroup;

  const _GroupTile({
    required this.name,
    required this.entries,
    required this.open,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onRename,
    required this.onUngroup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final planned = entries.any((e) => e.isPlanned);
    return ListTile(
      selected: selecting && selected == entries.length,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: planned ? p.teaSoft : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.layers_outlined, size: 22, color: planned ? p.tea : theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(stopCount(entries.length)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selecting)
            Checkbox(
              tristate: true,
              value: selected == 0 ? false : (selected == entries.length ? true : null),
              onChanged: (_) => onTap(),
            )
          else ...[
            if (onRename != null)
              PopupMenuButton<String>(
                tooltip: 'Group options',
                onSelected: (value) => value == 'rename' ? onRename!() : onUngroup!(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'ungroup', child: Text('Ungroup')),
                ],
              ),
            Icon(open ? Icons.expand_less : Icons.expand_more),
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _EmptyStops extends StatelessWidget {
  /// Null for a viewer, who can't add stops.
  final VoidCallback? onAdd;

  const _EmptyStops({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No stops yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              onAdd == null
                  ? 'Stops show up here once someone who can edit the trip adds them.'
                  : 'Add places from your library, or pick a new spot on the map. You can arrange them by day afterwards.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add stops')),
            ],
          ],
        ),
      ),
    );
  }
}
