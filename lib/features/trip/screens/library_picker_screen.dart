import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../library/providers/place_providers.dart';
import '../../library/widgets/spot_thumb.dart';
import '../../planner/models/planner_view.dart';
import '../../planner/providers/planner_providers.dart';
import '../../planner/widgets/day_card.dart' show dayName;
import '../controllers/trip_stops_controller.dart';
import '../providers/trip_providers.dart';

/// Picks saved places from the library and adds them to a trip as stops,
/// optionally putting them straight onto [initialDayId].
class LibraryPickerScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String? initialDayId;

  const LibraryPickerScreen({super.key, required this.tripId, this.initialDayId});

  @override
  ConsumerState<LibraryPickerScreen> createState() => _LibraryPickerScreenState();
}

class _LibraryPickerScreenState extends ConsumerState<LibraryPickerScreen> {
  final _selected = <String>{};
  String _query = '';
  bool _saving = false;
  late String? _targetDayId = widget.initialDayId;

  Future<void> _add(String? dayId) async {
    setState(() => _saving = true);
    final result = await ref
        .read(tripStopsControllerProvider.notifier)
        // Places already in the trip were ticked on purpose: they become a
        // second stop.
        .addFromLibrary(tripId: widget.tripId, placeKeys: _selected.toList(), repeat: true, dayId: dayId);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success(:final value):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value == 1 ? 'Added 1 stop.' : 'Added $value stops.')),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/trips/${widget.tripId}/stops');
        }
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't add the stops: $error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placesAsync = ref.watch(placesListProvider('saved'));
    final inTrip = {
      for (final s in ref.watch(tripStopsProvider(widget.tripId)).valueOrNull ?? const <Stop>[]) s.placeKey,
    };
    final view = ref.watch(plannerViewProvider(widget.tripId)).valueOrNull;
    final days = view?.days ?? const <PlannerDay>[];
    final validTargetDayId = _targetDayId != null && days.any((d) => d.day.id == _targetDayId) ? _targetDayId : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Add from library')),
      body: placesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load your library: $e")),
        data: (places) {
          if (places.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Your library is empty. Places you save show up here, so you can add them to any trip. '
                  'For now, add a new spot from the map instead.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          final q = _query.trim().toLowerCase();
          final shown = [...places.where((p) => q.isEmpty || p.name.toLowerCase().contains(q))]
            ..sort((a, b) => a.name.compareTo(b.name));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search ${places.length} places',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final place = shown[i];
                    final already = inTrip.contains(place.placeKey);
                    final picked = _selected.contains(place.placeKey);
                    return CheckboxListTile(
                      value: picked,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(place.placeKey);
                        } else {
                          _selected.remove(place.placeKey);
                        }
                      }),
                      secondary: SpotThumb(
                        placeKey: place.placeKey,
                        fallback: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.place_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                      title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        already
                            ? (picked ? 'Already in this trip, added again as a second stop' : 'Already in this trip')
                            : (place.address ?? place.source ?? 'Saved place'),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (days.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Add to:',
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Backlog'),
                        selected: validTargetDayId == null,
                        onSelected: _saving ? null : (_) => setState(() => _targetDayId = null),
                      ),
                      for (final d in days) ...[
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: Text(dayName(d)),
                          selected: validTargetDayId == d.day.id,
                          onSelected: _saving ? null : (_) => setState(() => _targetDayId = d.day.id),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _selected.isEmpty || _saving ? null : () => _add(validTargetDayId),
                child: Text(_selected.isEmpty
                    ? 'Pick places to add'
                    : _selected.length == 1
                        ? 'Add 1 stop'
                        : 'Add ${_selected.length} stops'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
