import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../shared/map/app_map.dart';
import '../../../shared/theme/app_theme.dart';
import '../../trip/controllers/trip_stops_controller.dart';
import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../providers/library_providers.dart';
import '../providers/place_providers.dart';
import '../widgets/label_widgets.dart';
import '../widgets/library_backup_flow.dart';
import '../widgets/spot_thumb.dart';
import '../widgets/trip_picker.dart';

/// The personal library: saved places as a list or on a map, narrowed by a
/// search and by labels.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _search = TextEditingController();
  LibraryFilter _filter = const LibraryFilter();
  bool _map = false;

  /// Places picked for a bulk action. Holding a place starts picking.
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String placeKey) => setState(() => _selected.contains(placeKey) ? _selected.remove(placeKey) : _selected.add(placeKey));

  List<LibraryEntry> _picked(List<LibraryEntry> all) => [for (final e in all) if (_selected.contains(e.place.placeKey)) e];

  void _report(AppResult<dynamic> result, String ok) {
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case Failure(:final error):
        messenger.showSnackBar(SnackBar(content: Text(error)));
      case Success():
        messenger.showSnackBar(SnackBar(content: Text(ok)));
    }
  }

  Future<void> _bulkAddToTrip(List<LibraryEntry> picked) async {
    // Trips that already have every picked place can't take any of them.
    final full = picked.map((e) => e.tripIds).reduce((a, b) => a.intersection(b));
    final trip = await pickTripToAddTo(
      context,
      full: full,
      subtitle: 'Places already in the trip are skipped. The rest wait in its backlog.',
    );
    if (trip == null || !mounted) return;
    final result = await ref
        .read(tripStopsControllerProvider.notifier)
        .addFromLibrary(tripId: trip.trip.id, placeKeys: [for (final e in picked) e.place.placeKey]);
    if (!mounted) return;
    if (result case Success(:final value)) {
      final skipped = picked.length - value;
      _report(result, 'Added ${_placesText(value)} to ${trip.trip.title}${skipped > 0 ? ' ($skipped already there)' : ''}.');
      setState(_selected.clear);
    } else {
      _report(result, '');
    }
  }

  Future<void> _bulkMerge(List<LibraryEntry> picked) async {
    final keep = await showModalBottomSheet<LibraryEntry>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text('Merge ${_placesText(picked.length)}', style: Theme.of(context).textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'For one spot saved more than once. Pick the one to keep: its name and facts stay. '
                  'The others\' labels, frames, photos and visits move to it, their notes are added to its note, '
                  'and trips that used them switch to it.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              for (final e in picked)
                ListTile(
                  leading: PlaceThumb(entry: e),
                  title: Text(e.place.name),
                  subtitle: Text([
                    if (e.place.address?.isNotEmpty ?? false) e.place.address!,
                    if (e.labels.isNotEmpty) e.labels.map((l) => l.name).join(' · '),
                  ].join('\n'), maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Text('Keep'),
                  onTap: () => Navigator.pop(context, e),
                ),
            ],
          ),
        ),
      ),
    );
    if (keep == null || !mounted) return;
    final result = await ref.read(libraryControllerProvider.notifier).mergePlaces(
          keep: keep.place.placeKey,
          others: [for (final e in picked) e.place.placeKey],
        );
    if (!mounted) return;
    _report(result, 'Merged ${_placesText(picked.length)} into ${keep.place.name}.');
    if (result is Success) setState(_selected.clear);
  }

  Future<void> _bulkRemove(List<LibraryEntry> picked) async {
    final inTrips = picked.where((e) => e.tripIds.isNotEmpty).length;
    final free = picked.length - inTrips;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${_placesText(picked.length)} from your library?'),
        content: Text([
          if (free > 0) '${free == 1 ? 'One is' : '$free are'} deleted, with ${free == 1 ? 'its' : 'their'} notes and photos.',
          if (inTrips > 0)
            '${inTrips == 1 ? 'One is' : '$inTrips are'} in trips, so ${inTrips == 1 ? 'it stays there and is' : 'they stay there and are'} only hidden here.',
        ].join(' ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref.read(libraryControllerProvider.notifier).removeManyFromLibrary(picked);
    if (!mounted) return;
    if (result case Success(value: (final hidden, final deleted))) {
      _report(result, [if (deleted > 0) 'Deleted ${_placesText(deleted)}.', if (hidden > 0) 'Hid ${_placesText(hidden)} that ${hidden == 1 ? 'is' : 'are'} in trips.'].join(' '));
      setState(_selected.clear);
    } else {
      _report(result, '');
    }
  }

  Future<void> _pickLabels(String kind, List<Label> labels) async {
    final ofKind = labels.where((l) => l.kind == kind).toList();
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LabelFilterSheet(
        kind: kind,
        labels: ofKind,
        selected: _filter.labelIds.intersection(ofKind.map((l) => l.id).toSet()),
      ),
    );
    if (picked == null) return;
    final others = _filter.labelIds.difference(ofKind.map((l) => l.id).toSet());
    setState(() => _filter = _filter.copyWith(labelIds: {...others, ...picked}));
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(libraryEntriesProvider);
    final labels = ref.watch(labelsListProvider(null)).valueOrNull ?? const <Label>[];
    final all = entriesAsync.valueOrNull ?? const <LibraryEntry>[];
    // Drop picks that left the library meanwhile.
    _selected.retainAll(all.map((e) => e.place.placeKey));
    final picked = _picked(all);
    final selecting = picked.isNotEmpty;
    final shownKeys = [for (final e in filterLibrary(all, _filter, labels)) e.place.placeKey];

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
      appBar: selecting
          ? AppBar(
              leading: IconButton(
                tooltip: 'Stop selecting',
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              ),
              title: Text('${picked.length} selected'),
              actions: [
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() => _selected.addAll(shownKeys)),
                ),
                IconButton(
                  tooltip: 'Edit labels',
                  icon: const Icon(Icons.label_outline),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (_) => _BulkLabelSheet(placeKeys: [for (final e in picked) e.place.placeKey]),
                  ),
                ),
                IconButton(
                  tooltip: 'Add to a trip',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: () => _bulkAddToTrip(picked),
                ),
                IconButton(
                  tooltip: 'Merge places',
                  icon: const Icon(Icons.merge),
                  onPressed: picked.length < 2 ? null : () => _bulkMerge(picked),
                ),
                IconButton(
                  tooltip: 'Remove from library',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _bulkRemove(picked),
                ),
              ],
            )
          : AppBar(
              title: const Text('Library'),
              actions: [
                IconButton(
                  tooltip: 'Import from Anitabi',
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => context.push('/library/import'),
                ),
                IconButton(
                  tooltip: _map ? 'Show as a list' : 'Show on a map',
                  icon: Icon(_map ? Icons.view_list_outlined : Icons.map_outlined),
                  onPressed: () => setState(() => _map = !_map),
                ),
                IconButton(
                  tooltip: 'Labels',
                  icon: const Icon(Icons.label_outline),
                  onPressed: () => context.push('/library/labels'),
                ),
                PopupMenuButton<void Function()>(
                  tooltip: 'More',
                  onSelected: (action) => action(),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: () => backUpLibrary(this.context, ref),
                      child: const ListTile(leading: Icon(Icons.save_alt), title: Text('Back up to a file')),
                    ),
                    PopupMenuItem(
                      value: () => restoreLibrary(this.context, ref),
                      child: const ListTile(leading: Icon(Icons.restore), title: Text('Restore from a file')),
                    ),
                  ],
                ),
              ],
            ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load your library: $e")),
        data: (all) {
          if (all.isEmpty) {
            return _EmptyLibrary(onAdd: () => context.push('/library/new'), onRestore: () => restoreLibrary(context, ref));
          }
          final shown = filterLibrary(all, _filter, labels);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search places and labels',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _filter.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear the search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              setState(() => _filter = _filter.copyWith(query: ''));
                            },
                          ),
                  ),
                  onChanged: (q) => setState(() => _filter = _filter.copyWith(query: q)),
                ),
              ),
              _FilterBar(
                filter: _filter,
                labels: labels,
                tripOnlyCount: all.where((e) => !e.isSaved).length,
                onPickLabels: (kind) => _pickLabels(kind, labels),
                onToggleTripOnly: () => setState(() => _filter = _filter.copyWith(includeTripOnly: !_filter.includeTripOnly)),
                onClear: () => setState(() => _filter = LibraryFilter(query: _filter.query, includeTripOnly: _filter.includeTripOnly)),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _filter.narrows ? 'No places match.' : 'No saved places. Places that are only in trips are hidden.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _map && !selecting
                        ? _LibraryMap(entries: shown)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: shown.length,
                            itemBuilder: (_, i) {
                              final key = shown[i].place.placeKey;
                              return _PlaceTile(
                                entry: shown[i],
                                selecting: selecting,
                                selected: _selected.contains(key),
                                onTap: () => selecting ? _toggle(key) : openPlace(context, key),
                                onLongPress: () => _toggle(key),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/library/new'),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add place'),
            ),
      ),
    );
  }
}

/// Labels for several picked places: add one to all of them, or take one off
/// all of them.
class _BulkLabelSheet extends ConsumerWidget {
  final List<String> placeKeys;

  const _BulkLabelSheet({required this.placeKeys});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entries = ref.watch(libraryEntriesProvider).valueOrNull ?? const <LibraryEntry>[];
    final allLabels = ref.watch(labelsListProvider(null)).valueOrNull ?? const <Label>[];
    final picked = [for (final e in entries) if (placeKeys.contains(e.place.placeKey)) e];
    final counts = <String, int>{};
    final labelsById = <String, Label>{};
    for (final e in picked) {
      for (final l in e.labels) {
        counts[l.id] = (counts[l.id] ?? 0) + 1;
        labelsById[l.id] = l;
      }
    }
    final present = labelsById.values.toList()
      ..sort((a, b) => '${labelKinds.indexOf(a.kind)}${a.name.toLowerCase()}'.compareTo('${labelKinds.indexOf(b.kind)}${b.name.toLowerCase()}'));
    final controller = ref.read(libraryControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text('Labels for ${_placesText(picked.length)}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                final label = await showAddLabelSheet(context, labels: allLabels);
                if (label == null) return;
                final result = await controller.addLabelToPlaces(placeKeys, kind: label.$1, name: label.$2);
                messenger.showSnackBar(SnackBar(
                  content: Text(result is Failure ? (result as Failure).error : 'Added “${label.$2}” to ${_placesText(picked.length)}.'),
                ));
              },
              icon: const Icon(Icons.add),
              label: const Text('Add a label to all'),
            ),
            if (present.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('On these places', style: theme.textTheme.titleSmall),
              for (final l in present)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Align(alignment: Alignment.centerLeft, child: LabelPill(label: l)),
                  subtitle: Text('On ${counts[l.id]} of ${picked.length}'),
                  trailing: TextButton(
                    onPressed: () async {
                      final result = await controller.removeLabelFromPlaces(placeKeys, l.id);
                      messenger.showSnackBar(SnackBar(
                        content: Text(result is Failure ? (result as Failure).error : 'Took “${l.name}” off ${_placesText(counts[l.id] ?? 0)}.'),
                      ));
                    },
                    child: const Text('Remove from all'),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final LibraryFilter filter;
  final List<Label> labels;
  final int tripOnlyCount;
  final ValueChanged<String> onPickLabels;
  final VoidCallback onToggleTripOnly;
  final VoidCallback onClear;

  const _FilterBar({
    required this.filter,
    required this.labels,
    required this.tripOnlyCount,
    required this.onPickLabels,
    required this.onToggleTripOnly,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final kind in labelKinds)
            if (labels.any((l) => l.kind == kind))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Builder(builder: (context) {
                  final picked = labels.where((l) => l.kind == kind && filter.labelIds.contains(l.id)).length;
                  final (background, foreground) = labelColors(theme, kind);
                  return FilterChip(
                    avatar: Icon(labelKindIcon(kind), size: 18, color: picked > 0 ? foreground : null),
                    label: Text(picked > 0 ? '${labelKindTitle(kind)} · $picked' : labelKindTitle(kind)),
                    selected: picked > 0,
                    showCheckmark: false,
                    selectedColor: background,
                    labelStyle: picked > 0 ? TextStyle(color: foreground, fontWeight: FontWeight.w700) : null,
                    onSelected: (_) => onPickLabels(kind),
                  );
                }),
              ),
          if (tripOnlyCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('Only in trips · $tripOnlyCount'),
                selected: filter.includeTripOnly,
                onSelected: (_) => onToggleTripOnly(),
              ),
            ),
          if (filter.labelIds.isNotEmpty) ActionChip(label: const Text('Clear labels'), onPressed: onClear),
        ],
      ),
    );
  }
}

/// Picks labels of one kind to narrow the library down to.
class _LabelFilterSheet extends ConsumerStatefulWidget {
  final String kind;
  final List<Label> labels;
  final Set<String> selected;

  const _LabelFilterSheet({required this.kind, required this.labels, required this.selected});

  @override
  ConsumerState<_LabelFilterSheet> createState() => _LabelFilterSheetState();
}

class _LabelFilterSheetState extends ConsumerState<_LabelFilterSheet> {
  late final Set<String> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = ref.watch(labelPlaceCountsProvider);
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final l in widget.labels)
        if (q.isEmpty || l.name.toLowerCase().contains(q)) l,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final (_, foreground) = labelColors(theme, widget.kind);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(labelKindTitle(widget.kind), style: theme.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Places with any of the picked labels are shown.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              if (widget.labels.length > 8)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search), isDense: true),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in shown)
                      CheckboxListTile(
                        value: _selected.contains(l.id),
                        activeColor: foreground,
                        title: Text(l.name),
                        subtitle: Text(_placesText(counts[l.id] ?? 0)),
                        onChanged: (on) => setState(() => on == true ? _selected.add(l.id) : _selected.remove(l.id)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    TextButton(onPressed: () => setState(_selected.clear), child: const Text('None')),
                    const Spacer(),
                    FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Show places')),
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

String _placesText(int n) => n == 1 ? '1 place' : '$n places';

/// Opens a library place's page.
void openPlace(BuildContext context, String placeKey) => context.push('/library/places/${Uri.encodeComponent(placeKey)}');

class _PlaceTile extends StatelessWidget {
  final LibraryEntry entry;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PlaceTile({
    required this.entry,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = entry.place;
    final labelLine = entry.labels.map((l) => l.name).join(' · ');
    final subtitle = labelLine.isNotEmpty ? labelLine : (place.address ?? '');
    final trips = entry.tripIds.length;
    return ListTile(
      selected: selected,
      selectedTileColor: theme.trip.teaSoft,
      selectedColor: theme.colorScheme.onSurface,
      onLongPress: onLongPress,
      leading: PlaceThumb(entry: entry),
      title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: selecting
          ? Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? theme.trip.tea : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? theme.trip.tea : theme.colorScheme.outline, width: 2),
              ),
              child: selected ? Icon(Icons.check, size: 18, color: theme.colorScheme.surface) : null,
            )
          : !entry.isSaved
          ? Text('Only in trips', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          : trips == 0
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: theme.trip.teaSoft, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    trips == 1 ? 'In 1 trip' : 'In $trips trips',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.trip.tea, fontWeight: FontWeight.w700),
                  ),
                ),
      onTap: onTap,
    );
  }
}

/// A place's cover, else its first anime frame, else an icon tinted by its
/// first label. Only files on the device are shown; remote covers (Anitabi's
/// image hosts) are never fetched for a list.
class PlaceThumb extends StatelessWidget {
  final LibraryEntry entry;

  const PlaceThumb({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = entry.labels.isEmpty ? 'tag' : entry.labels.first.kind;
    final (background, foreground) = labelColors(theme, kind);
    final fallback = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Icon(entry.labels.any((l) => l.kind == 'anime') ? Icons.photo_camera_outlined : Icons.place_outlined,
          color: foreground),
    );
    return SpotThumb(placeKey: entry.place.placeKey, fallback: fallback);
  }
}

/// The library on a map: a pin per place, coloured by its anime so works tell
/// apart, merged into bubbles where they crowd. Tapping a pin shows its name
/// and a card to open it, rather than leaving the map.
class _LibraryMap extends StatefulWidget {
  final List<LibraryEntry> entries;

  const _LibraryMap({required this.entries});

  @override
  State<_LibraryMap> createState() => _LibraryMapState();
}

class _LibraryMapState extends State<_LibraryMap> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byKey = {for (final e in widget.entries) e.place.placeKey: e};
    final selected = byKey[_selected];
    final pins = [
      for (final e in widget.entries)
        MapPin(
          id: e.place.placeKey,
          point: LatLng(e.place.lat, e.place.lng),
          name: e.place.name,
          color: animeColor(e.labelsOf('anime').firstOrNull?.id, none: theme.trip.tea),
          selected: e.place.placeKey == _selected,
        ),
    ];
    return Stack(
      children: [
        AppMap(
          pins: pins,
          // A new filter or search fits the map to what's left.
          fitKey: Object.hashAll(widget.entries.map((e) => e.place.placeKey)),
          onPinTap: (pin) => setState(() => _selected = pin.id),
          onClusterOpen: (pins) => _pickFrom(context, [for (final p in pins) byKey[p.id]!]),
          onTap: (_) {
            if (_selected != null) setState(() => _selected = null);
          },
        ),
        if (selected != null)
          Positioned(
            left: 12,
            right: 12,
            // Above the Add place button.
            bottom: 96,
            child: _MapPlaceCard(entry: selected, onClose: () => setState(() => _selected = null)),
          ),
      ],
    );
  }

  /// Places at one spot that zooming can't split: pick one from a list.
  Future<void> _pickFrom(BuildContext context, List<LibraryEntry> entries) async {
    final key = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in entries)
              ListTile(
                leading: PlaceThumb(entry: e),
                title: Text(e.place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: _animeLine(e) == null ? null : Text(_animeLine(e)!, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, e.place.placeKey),
              ),
          ],
        ),
      ),
    );
    if (key != null && mounted) setState(() => _selected = key);
  }
}

String? _animeLine(LibraryEntry e) {
  final anime = e.labelsOf('anime').map((l) => l.name).toList();
  return anime.isEmpty ? null : anime.join(' · ');
}

class _MapPlaceCard extends StatelessWidget {
  final LibraryEntry entry;
  final VoidCallback onClose;

  const _MapPlaceCard({required this.entry, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anime = _animeLine(entry);
    return Card(
      key: const Key('libraryMapCard'),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openPlace(context, entry.place.placeKey),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              PlaceThumb(entry: entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.place.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    if (anime != null)
                      Text(anime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              TextButton(onPressed: () => openPlace(context, entry.place.placeKey), child: const Text('Open')),
              IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final VoidCallback onAdd;

  /// A new phone: bring the library over from a backup file.
  final VoidCallback onRestore;

  const _EmptyLibrary({required this.onAdd, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: theme.trip.teaSoft, shape: BoxShape.circle),
              child: Icon(Icons.bookmarks_outlined, size: 44, color: theme.trip.tea),
            ),
            const SizedBox(height: 16),
            Text('Your library is empty', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Save the places you want to visit, and label them by anime, tag and region.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Add a place')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/library/import'),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Import from Anitabi'),
            ),
            TextButton.icon(
              onPressed: onRestore,
              icon: const Icon(Icons.restore),
              label: const Text('Restore from a backup file'),
            ),
          ],
        ),
      ),
    );
  }
}
