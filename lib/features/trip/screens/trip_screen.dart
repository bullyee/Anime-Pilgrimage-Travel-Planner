import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../shared/widgets/undo_snack_bar.dart';
import '../../planner/widgets/day_planner.dart';
import '../../planner/widgets/planner_sheets.dart';
import '../../sharing/models/trip_member.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../controllers/trips_controller.dart';
import '../providers/trip_list_providers.dart';
import '../providers/trip_providers.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_form_sheet.dart';
import '../widgets/trip_members_button.dart';
import '../widgets/trip_sync_icon.dart';
import 'trip_members_screen.dart';
import 'trip_stops_screen.dart';

/// One trip's page, which is its plan: the days, one at a time or all at
/// once, with the stops not on a day yet at the end. Owners and editors
/// change it in place; viewers see the same page without the ways to change
/// it. Each day opens its map, the day's Pilgrimage view. The top bar
/// searches the stops and opens the trip's people.
class TripScreen extends ConsumerStatefulWidget {
  final String tripId;

  /// A stop whose day the plan opens on, instead of today's.
  final String? initialStopId;

  const TripScreen({super.key, required this.tripId, this.initialStopId});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  bool _grid = false;
  final _jump = PlannerJump();

  @override
  void initState() {
    super.initState();
    if (widget.initialStopId case final stopId?) _jump.toStop(stopId);
  }

  @override
  void dispose() {
    _jump.dispose();
    super.dispose();
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
    final role = ref.watch(myTripRoleProvider(trip.id));
    final canEdit = ref.watch(canEditTripProvider(trip.id));
    final shared = trip.sharing == 'group';
    final menu = [
      if (canEdit) const PopupMenuItem(value: 'add', child: Text('Add stops')),
      if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit name and dates')),
      if (role == TripMemberRole.owner) const PopupMenuItem(value: 'delete', child: Text('Delete trip')),
      if (shared && role != null && role != TripMemberRole.owner)
        const PopupMenuItem(value: 'leave', child: Text('Leave trip')),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search stops',
            icon: const Icon(Icons.search),
            onPressed: () => _searchStops(context, trip.id, canEdit),
          ),
          IconButton(
            tooltip: _grid ? 'Show one day at a time' : 'Show all days',
            icon: Icon(_grid ? Icons.view_carousel_outlined : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          TripMembersButton(trip: trip),
          if (menu.isNotEmpty)
            PopupMenuButton<String>(
              key: const Key('tripMenu'),
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'add') openAddStopsSheet(context, trip.id);
                if (value == 'edit') _editTrip(context, trip);
                if (value == 'delete') _deleteTrip(context, trip);
                if (value == 'leave') leaveTrip(context, ref, trip);
              },
              itemBuilder: (_) => menu,
            ),
        ],
      ),
      body: DayPlanner(
        tripId: trip.id,
        grid: _grid,
        // A viewer's role can change while they're on the page.
        editing: canEdit,
        onGridChanged: (grid) => setState(() => _grid = grid),
        jump: _jump,
      ),
    );
  }

  /// Opens the trip's stops with a search field. A stop picked there is
  /// shown on its day in the plan, with its sheet open.
  Future<void> _searchStops(BuildContext context, String tripId, bool editing) async {
    final stopId = await context.push<String>('/trips/$tripId/stops');
    if (stopId == null || !context.mounted) return;
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
        content: Text(trip.sharing == 'group'
            ? 'Its days, stops and schedule are deleted too, for everyone in it.'
            : 'Its days, stops and schedule are deleted too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Hidden now, deleted once the Undo is gone (see pendingTripDeletesProvider).
    final messenger = ScaffoldMessenger.of(context);
    final pending = ref.read(pendingTripDeletesProvider.notifier)..hide(trip.id);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/trips');
    }
    final bar = showUndoSnackBar(messenger, 'Deleted “${trip.title}”.', onUndo: () => pending.undo(trip.id));
    final reason = await bar.closed;
    if (reason == SnackBarClosedReason.action) return;
    if (await pending.commit(trip.id) case Failure(:final error)) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't delete the trip: $error")));
    }
  }
}
