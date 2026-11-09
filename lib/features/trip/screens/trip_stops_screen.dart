import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../library/widgets/spot_thumb.dart';
import '../../sharing/providers/group_sharing_providers.dart';
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

/// The trip's stops with a search field, opened from the search action in
/// the trip's top bar: what's planned on which day, and what isn't yet.
/// Tapping a stop goes back to the plan, which shows it on its day; when
/// there is no plan to go back to, it opens the stop's page.
class TripStopsScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripStopsScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripStopsScreen> createState() => _TripStopsScreenState();
}

class _TripStopsScreenState extends ConsumerState<TripStopsScreen> {
  final _search = TextEditingController();
  String _query = '';
  StopOrder _order = StopOrder.plan;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(String stopId) {
    if (context.canPop()) {
      context.pop(stopId);
    } else {
      context.push('/trips/${widget.tripId}/stops/$stopId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(tripStopEntriesProvider(widget.tripId));
    final canEdit = ref.watch(canEditTripProvider(widget.tripId));
    final entries = entriesAsync.valueOrNull ?? const <TripStopEntry>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _search,
          autofocus: true,
          decoration: InputDecoration(
            hintText: entries.isEmpty ? 'Search stops' : 'Search ${entries.length} stops',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _search.clear();
                _query = '';
              }),
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
      floatingActionButton: canEdit && entries.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => openAddStopsSheet(context, widget.tripId),
              icon: const Icon(Icons.add),
              label: const Text('Add stops'),
            )
          : null,
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load the stops: $e")),
        data: (entries) {
          if (entries.isEmpty) {
            return _EmptyStops(onAdd: canEdit ? () => openAddStopsSheet(context, widget.tripId) : null);
          }
          final q = _query.trim().toLowerCase();
          final matching = q.isEmpty
              ? entries
              : entries
                  .where((e) =>
                      e.stop.name.toLowerCase().contains(q) ||
                      (e.stop.address?.toLowerCase().contains(q) ?? false))
                  .toList();
          final shown = orderStopEntries(matching, _order);
          if (shown.isEmpty) return const Center(child: Text('No stops match your search.'));
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 96),
                itemCount: shown.length,
                itemBuilder: (context, i) => _StopTile(entry: shown[i], onTap: () => _open(shown[i].stop.id)),
              ),
            ),
          );
        },
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
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
