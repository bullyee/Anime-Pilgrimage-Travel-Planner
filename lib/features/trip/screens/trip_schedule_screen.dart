import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/up_button.dart';
import '../../planner/widgets/day_planner.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../providers/trip_providers.dart';

/// A trip's schedule: the day planner, with times, one day at a time or all
/// days at once. Reached from the trip page's app bar, now that the trip
/// page lists places; it opens read-only and the pencil turns editing on.
class TripScheduleScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripScheduleScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripScheduleScreen> createState() => _TripScheduleScreenState();
}

class _TripScheduleScreenState extends ConsumerState<TripScheduleScreen> {
  bool _grid = false;
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trip = ref.watch(tripDetailProvider(widget.tripId)).valueOrNull;
    final canEdit = ref.watch(canEditTripProvider(widget.tripId));
    // A viewer's role can change while they're on the page.
    final editing = _editing && canEdit;
    return Scaffold(
      appBar: AppBar(
        leading: UpButton.ifAlone(context, fallback: '/trips/${widget.tripId}'),
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.tripSchedule),
            if (trip != null)
              Text(
                trip.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _grid ? 'Show one day at a time' : 'Show all days',
            icon: Icon(_grid ? Icons.view_carousel_outlined : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          if (canEdit)
            editing
                ? TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Done'))
                : IconButton(
                    tooltip: 'Edit the plan',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => setState(() => _editing = true),
                  ),
        ],
      ),
      body: Column(
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
              tripId: widget.tripId,
              grid: _grid,
              editing: editing,
              onGridChanged: (grid) => setState(() => _grid = grid),
            ),
          ),
        ],
      ),
    );
  }
}
