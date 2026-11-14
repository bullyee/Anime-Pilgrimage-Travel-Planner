import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../../planner/providers/planner_providers.dart';
import '../../planner/widgets/day_planner.dart';
import '../../sharing/models/trip_member.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../../sharing/widgets/invite_sheet.dart';
import '../controllers/trips_controller.dart';
import '../providers/trip_providers.dart';
import '../services/trip_route_export_service.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_form_sheet.dart';
import '../widgets/trip_sync_icon.dart';
import 'trip_members_tab.dart';
import 'trip_stops_tab.dart';

enum TripTab {
  plan,
  stops,
  members;

  /// The tab a `?tab=` link names. Anything else, such as the old
  /// `overview`, opens the plan.
  static TripTab fromQuery(String? name) => values.asNameMap()[name] ?? plan;
}

/// One trip, in three tabs: the day planner, its stops, and who it's shared
/// with. The plan opens read-only; the pencil turns editing on.
class TripScreen extends ConsumerStatefulWidget {
  final String tripId;
  final TripTab initialTab;

  const TripScreen({super.key, required this.tripId, this.initialTab = TripTab.plan});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: TripTab.values.length, vsync: this, initialIndex: widget.initialTab.index);
  bool _grid = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    return tripAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text("Couldn't load this trip: $e"))),
      data: (trip) {
        if (trip == null || trip.deletedAt != null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('This trip was deleted.')));
        }
        return _scaffold(context, trip);
      },
    );
  }

  Widget _scaffold(BuildContext context, Trip trip) {
    final theme = Theme.of(context);
    final blocks = ref.watch(tripResolvedBlockDatesProvider(trip.id));
    final dated = blocks.where((b) => !b.isBackup && b.date != null).toList();
    final subtitle = tripDateLine(
      firstDate: dated.isEmpty ? null : dated.first.date,
      lastDate: dated.isEmpty ? null : dated.last.date,
    );
    final tab = TripTab.values[_tabs.index];
    final hasStops = ref.watch(tripStopsProvider(trip.id)).valueOrNull?.isNotEmpty ?? false;
    final role = ref.watch(myTripRoleProvider(trip.id));
    final canEdit = ref.watch(canEditTripProvider(trip.id));
    // A viewer's role can change while they're on the page.
    final editing = _editing && canEdit;
    final shared = trip.sharing == 'group';
    final hasAccess = !shared || role != null;
    final menu = [
      if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit trip')),
      if (hasAccess) ...[
        const PopupMenuItem(value: 'export_gpx', child: Text('Export route (GPX)')),
        const PopupMenuItem(value: 'export_geojson', child: Text('Export route (GeoJSON)')),
      ],
      if (role == TripMemberRole.owner) const PopupMenuItem(value: 'delete', child: Text('Delete trip')),
      if (shared && role != null && role != TripMemberRole.owner)
        const PopupMenuItem(value: 'leave', child: Text('Leave trip')),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(child: Text(trip.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (shared)
                  TripSyncIcon(tripId: trip.id, padding: const EdgeInsets.only(left: 6)),
              ],
            ),
            Text(
              role == TripMemberRole.viewer ? '$subtitle · View only' : subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (tab == TripTab.plan)
            IconButton(
              tooltip: _grid ? 'Show one day at a time' : 'Show all days',
              icon: Icon(_grid ? Icons.view_carousel_outlined : Icons.grid_view),
              onPressed: () => setState(() => _grid = !_grid),
            ),
          if (tab == TripTab.plan && canEdit)
            editing
                ? TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Done'))
                : IconButton(
                    tooltip: 'Edit the plan',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => setState(() => _editing = true),
                  ),
          IconButton(
            tooltip: 'Pilgrimage map',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push('/trips/${trip.id}/map'),
          ),
          if (role == TripMemberRole.owner || role == TripMemberRole.editor)
            IconButton(
              tooltip: 'Invite people',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => showInviteSheet(context, trip),
            ),
          if (menu.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _editTrip(context, trip);
                if (value == 'export_gpx') _exportRoute(context, trip, isGeoJson: false);
                if (value == 'export_geojson') _exportRoute(context, trip, isGeoJson: true);
                if (value == 'delete') _deleteTrip(context, trip);
                if (value == 'leave') leaveTrip(context, ref, trip);
              },
              itemBuilder: (_) => menu,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Plan'), Tab(text: 'Stops'), Tab(text: 'Members')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        // Swiping belongs to the planner's days, so tabs change by tapping.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Column(
            children: [
              if (editing)
                Container(
                  width: double.infinity,
                  color: theme.trip.teaSoft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: theme.trip.tea),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Editing the plan. Hold a stop to move it. Changes are saved as you go.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: DayPlanner(
                  tripId: trip.id,
                  grid: _grid,
                  editing: editing,
                  onGridChanged: (grid) => setState(() => _grid = grid),
                ),
              ),
            ],
          ),
          TripStopsTab(tripId: trip.id),
          TripMembersTab(trip: trip),
        ],
      ),
      floatingActionButton: tab == TripTab.stops && hasStops && canEdit
          ? FloatingActionButton.extended(
              onPressed: () => openAddStopsSheet(context, trip.id),
              icon: const Icon(Icons.add),
              label: const Text('Add stops'),
            )
          : null,
    );
  }

  Future<void> _editTrip(BuildContext context, Trip trip) async {
    final form = await showTripForm(context, editing: trip);
    if (form == null || !context.mounted) return;
    final result = await ref.read(tripsControllerProvider.notifier).updateTrip(
          tripId: trip.id,
          title: form.title,
          description: form.description,
          startDate: form.startDate,
        );
    if (!context.mounted) return;
    if (result case Failure(:final error)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _deleteTrip(BuildContext context, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${trip.title}”?'),
        content: const Text("Its days, stops and schedule are deleted too. You can't undo this yet."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(tripsControllerProvider.notifier).deleteTrip(trip.id);
    if (!context.mounted) return;
    switch (result) {
      case Success():
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/trips');
        }
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't delete the trip: $error")));
    }
  }

  Future<void> _exportRoute(BuildContext context, Trip trip, {required bool isGeoJson}) async {
    final view = ref.read(plannerViewProvider(trip.id)).valueOrNull;
    if (view == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip details are still loading.')),
      );
      return;
    }

    final exporter = ref.read(tripRouteExportServiceProvider);
    final result = isGeoJson
        ? exporter.exportGeoJson(trip: trip, plannerView: view)
        : exporter.exportGpx(trip: trip, plannerView: view);

    if (result.stopCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('None of the stops in this trip have coordinates to export.')),
      );
      return;
    }

    try {
      await ref.read(shareRouteFileProvider)(result);
      if (!context.mounted) return;
      final skippedMsg = result.skippedCount > 0
          ? ' (${result.skippedCount} without coordinates skipped)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${result.stopCount} ${result.stopCount == 1 ? 'stop' : 'stops'}$skippedMsg.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't export route: $e")),
      );
    }
  }
}
