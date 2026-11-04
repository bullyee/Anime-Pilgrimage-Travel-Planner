import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../../planner/widgets/day_planner.dart';
import '../../sharing/models/trip_member.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../../sharing/widgets/invite_sheet.dart';
import '../controllers/trips_controller.dart';
import '../providers/trip_providers.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_form_sheet.dart';
import 'trip_members_tab.dart';
import 'trip_overview_tab.dart';
import 'trip_stops_tab.dart';

enum TripTab { overview, plan, stops, members }

/// One trip, in four tabs: its overview, the day planner, its stops, and
/// who it's shared with.
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
    final hasStops = ref.watch(tripStopsProvider(trip.id)).valueOrNull?.isNotEmpty ?? false;
    final role = ref.watch(myTripRoleProvider(trip.id));

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trip.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          if (tab == TripTab.plan)
            IconButton(
              tooltip: _grid ? 'Show one day at a time' : 'Show all days',
              icon: Icon(_grid ? Icons.view_carousel_outlined : Icons.grid_view),
              onPressed: () => setState(() => _grid = !_grid),
            ),
          if (tab == TripTab.plan)
            _editing
                ? TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Done'))
                : IconButton(
                    tooltip: 'Edit the plan',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => setState(() => _editing = true),
                  ),
          if (role == TripMemberRole.owner || role == TripMemberRole.editor)
            IconButton(
              tooltip: 'Invite people',
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => showInviteSheet(context, trip),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _editTrip(context, trip);
              if (value == 'delete') _deleteTrip(context, trip);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit name and dates')),
              PopupMenuItem(value: 'delete', child: Text('Delete trip')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Plan'), Tab(text: 'Stops'), Tab(text: 'Members')],
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
              if (_editing)
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
                  editing: _editing,
                  onGridChanged: (grid) => setState(() => _grid = grid),
                ),
              ),
            ],
          ),
          TripStopsTab(tripId: trip.id),
          TripMembersTab(trip: trip),
        ],
      ),
      floatingActionButton: tab == TripTab.stops && hasStops
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
