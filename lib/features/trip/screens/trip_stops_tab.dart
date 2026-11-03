import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_result.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/name_dialog.dart';
import '../controllers/trip_stops_controller.dart';
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
/// isn't yet. The tab's add button lives on the trip screen.
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(tripStopEntriesProvider(widget.tripId));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Couldn't load the stops: $e")),
      data: (entries) {
        if (entries.isEmpty) return _EmptyStops(onAdd: () => openAddStopsSheet(context, widget.tripId));
        final q = _query.trim().toLowerCase();
        final matching = q.isEmpty
            ? entries
            : entries
                .where((e) =>
                    e.stop.name.toLowerCase().contains(q) ||
                    (e.stop.address?.toLowerCase().contains(q) ?? false))
                .toList();
        final shown = orderStopEntries(matching, _order);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search ${entries.length} stops',
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
                ),
                Expanded(
                  child: shown.isEmpty
                      ? const Center(child: Text('No stops match your search.'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: shown.length,
                          itemBuilder: (context, i) => _StopTile(
                            entry: shown[i],
                            onTap: () => showStopDetails(context, ref, shown[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
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
  final VoidCallback onTap;

  const _StopTile({required this.entry, required this.onTap});

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
      leading: CircleAvatar(
        backgroundColor: background,
        foregroundColor: foreground,
        child: Icon(fromAnitabi ? Icons.photo_camera_outlined : Icons.place_outlined, size: 20),
      ),
      title: Text(entry.stop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        stopWhenLine(entry),
        style: entry.isPlanned ? TextStyle(color: foreground, fontWeight: FontWeight.w600) : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _EmptyStops extends StatelessWidget {
  final VoidCallback onAdd;

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
              'Add places from your library, or pick a new spot on the map. You can arrange them by day afterwards.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add stops')),
          ],
        ),
      ),
    );
  }
}

/// Shows a stop's details, with a way to remove it from the trip.
Future<void> showStopDetails(BuildContext context, WidgetRef ref, TripStopEntry entry) {
  final stop = entry.stop;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      Widget row(String label, String? value) => value == null || value.trim().isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 96, child: Text(label, style: theme.textTheme.labelLarge)),
                  Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
                ],
              ),
            );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(stop.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                stop.source == null ? 'Your own spot' : 'From ${stop.source}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              row('When', stopWhenLine(entry)),
              row('Address', stop.address),
              row('About', stop.description),
              row('Getting there', stop.accessTips),
              row('Hours', stop.businessHours),
              row('Location', '${stop.lat.toStringAsFixed(5)}, ${stop.lng.toStringAsFixed(5)}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final name = await askName(sheetContext, title: 'Rename this stop', action: 'Rename', initial: stop.name);
                      if (name == null || name == stop.name || !sheetContext.mounted) return;
                      final result = await ref.read(tripStopsControllerProvider.notifier).renameStop(stop.id, name);
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(switch (result) {
                          Success() => 'Renamed to $name. Your library keeps its own name.',
                          Failure(:final error) => error,
                        }),
                      ));
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Rename'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/library/places/${Uri.encodeComponent(stop.placeKey)}');
                    },
                    icon: const Icon(Icons.bookmarks_outlined),
                    label: const Text('Place page'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: sheetContext,
                        builder: (dialogContext) => AlertDialog(
                          title: Text('Remove “${stop.name}”?'),
                          content: Text(entry.isPlanned
                              ? 'This also takes it off ${stopWhenLine(entry).split(' · ').first}. Your library is not changed.'
                              : 'Your library is not changed.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
                          ],
                        ),
                      );
                      if (confirmed != true || !sheetContext.mounted) return;
                      final result = await ref.read(tripStopsControllerProvider.notifier).removeStop(stop.id);
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(switch (result) {
                          Success() => 'Removed ${stop.name}.',
                          Failure(:final error) => "Couldn't remove ${stop.name}: $error",
                        }),
                      ));
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove from trip'),
                  ),
                  const Spacer(),
                  FilledButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Done')),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
