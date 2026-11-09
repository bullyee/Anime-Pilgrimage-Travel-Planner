import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../../planner/widgets/day_planner.dart';
import '../../planner/widgets/planner_sheets.dart';
import '../../sharing/models/trip_member.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../controllers/trips_controller.dart';
import '../providers/trip_providers.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_form_sheet.dart';
import '../widgets/trip_members_button.dart';
import '../widgets/trip_sync_icon.dart';
import 'trip_members_screen.dart';
import 'trip_overview_tab.dart';

enum TripTab { overview, plan }

/// One trip, in two tabs: its overview and the day planner. Its stops open
/// from the search action, and its people from the avatars in the top bar.
class TripScreen extends ConsumerStatefulWidget {
  final String tripId;
  final TripTab initialTab;

  const TripScreen({super.key, required this.tripId, this.initialTab = TripTab.overview});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: TripTab.values.length, vsync: this, initialIndex: widget.initialTab.index);
  bool _grid = false;
  bool _editing = false;
  final _jump = PlannerJump();

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _jump.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  void _showTab(TripTab tab) => _tabs.animateTo(tab.index);

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
    final role = ref.watch(myTripRoleProvider(trip.id));
    final canEdit = ref.watch(canEditTripProvider(trip.id));
    // A viewer's role can change while they're on the page.
    final editing = _editing && canEdit;
    final shared = trip.sharing == 'group';
    final menu = [
      if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit name and dates')),
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
          IconButton(
            tooltip: 'Search stops',
            icon: const Icon(Icons.search),
            onPressed: () => _searchStops(context, trip.id, editing),
          ),
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
          TripMembersButton(trip: trip),
          if (menu.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _editTrip(context, trip);
                if (value == 'delete') _deleteTrip(context, trip);
                if (value == 'leave') leaveTrip(context, ref, trip);
              },
              itemBuilder: (_) => menu,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Plan')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        // Swiping belongs to the planner's days, so tabs change by tapping.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          TripOverviewTab(trip: trip, onShowPlan: () => _showTab(TripTab.plan)),
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
                  jump: _jump,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens the trip's stops with a search field. A stop picked there is
  /// shown on its day in the plan, with its sheet open.
  Future<void> _searchStops(BuildContext context, String tripId, bool editing) async {
    final stopId = await context.push<String>('/trips/$tripId/stops');
    if (stopId == null || !context.mounted) return;
    _showTab(TripTab.plan);
    _jump.toStop(stopId);
    await showPlannerStopSheet(context, tripId: tripId, stopId: stopId, editing: editing);
  }

  Future<void> _editTrip(BuildContext context, Trip trip) async {
    final form = await showTripForm(context, editing: trip);
    if (form == null || !context.mounted) return;
    final result = await ref.read(tripsControllerProvider.notifier).updateTrip(
          tripId: trip.id,
          title: form.title,
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
}
