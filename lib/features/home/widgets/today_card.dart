import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../library/widgets/place_page_parts.dart';
import '../../planner/models/planner_view.dart';
import '../../planner/providers/planner_providers.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../../trip/providers/trip_providers.dart';
import '../providers/home_providers.dart';
import 'home_mini_map.dart';

/// Home's top card on a day of a trip (roadmap v0.3.0, Home version A):
/// today's stops on a small map, the next one with its frame, and Take
/// photo. The map opens the trip's day map, where the other days are; the
/// card itself only ever shows today.
class TodayCard extends ConsumerWidget {
  final String tripId;

  const TodayCard({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final view = ref.watch(plannerViewProvider(tripId));
    final today = normalizeDateOnly(ref.watch(homeClockProvider)());

    return Card(
      key: const Key('homeToday'),
      elevation: 0,
      margin: EdgeInsets.zero,
      color: p.teaSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: switch (view) {
          AsyncData(:final value?) => _content(context, ref, value, today),
          AsyncError(:final error) => Text("Couldn't load the trip: $error"),
          _ => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        },
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, PlannerView view, DateTime today) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final days = view.datedDays;
    final day = days.where((d) => d.date != null && d.date!.isAtSameMomentAs(today)).firstOrNull;
    final items = day?.items ?? const <PlannerItem>[];
    final done = items.where((it) => it.done).length;
    final nextIndex = items.indexWhere((it) => !it.done);
    final canEdit = ref.watch(canEditTripProvider(tripId));
    void openMap() => context.push(
        day == null ? '/trips/$tripId?tab=plan' : '/trips/$tripId/map?day=${Uri.encodeQueryComponent(day.day.id)}');
    void plan() => context.push('/trips/$tripId?tab=plan');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'TODAY · ${DateFormat('EEE, MMM d').format(today).toUpperCase()}',
                style: theme.textTheme.labelMedium?.copyWith(color: p.tea, fontWeight: FontWeight.w700, letterSpacing: 0.6),
              ),
            ),
            if (day != null)
              DecoratedBox(
                decoration: BoxDecoration(color: p.tea.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text('Day ${day.index + 1} of ${days.length}',
                      style: theme.textTheme.labelMedium?.copyWith(color: p.tea, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(view.trip.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (items.isNotEmpty)
              Text('$done of ${items.length} visited',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty) ...[
          Text(day == null ? 'No day of this trip falls on today.' : 'Nothing planned for Day ${day.index + 1}.',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text('Shoot works without a plan too.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: plan, child: Text(day == null ? 'Open the plan' : 'Plan this day')),
        ] else ...[
          HomeMiniMap(
            key: const Key('homeTodayMap'),
            color: p.tea,
            doneColor: theme.colorScheme.outline,
            openLabel: 'Open map',
            onOpen: openMap,
            pins: [
              for (final (i, it) in items.indexed)
                MiniPin(lat: it.stop.lat, lng: it.stop.lng, label: '${i + 1}', done: it.done, next: i == nextIndex),
            ],
          ),
          const SizedBox(height: 12),
          if (nextIndex < 0)
            Row(
              children: [
                Icon(Icons.check_circle, color: p.tea),
                const SizedBox(width: 8),
                Expanded(child: Text('Every stop for today is done.', style: theme.textTheme.titleSmall)),
              ],
            )
          else
            _NextStop(tripId: tripId, number: nextIndex + 1, item: items[nextIndex], canEdit: canEdit),
        ],
      ],
    );
  }
}

/// The next stop of the day: its first frame, name and time, with Take photo
/// and Mark done. Marking done is the user's call (a shot never does it), and
/// only the people who can edit the trip see it.
class _NextStop extends ConsumerWidget {
  final String tripId;
  final int number;
  final PlannerItem item;
  final bool canEdit;

  const _NextStop({required this.tripId, required this.number, required this.item, required this.canEdit});

  Future<void> _markDone(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(tripRepositoryProvider);
    final before = item.item.status;
    final messenger = ScaffoldMessenger.of(context);
    await repo.updateScheduleItemStatus(itemId: item.item.id, status: 'done');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${item.stop.name} done'),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.updateScheduleItemStatus(itemId: item.item.id, status: before),
        ),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final frames = ref.watch(stopReferenceImagesProvider(item.stop.id)).valueOrNull ?? const [];
    final details = [
      formatTimelineMinutes(item.startMinutes),
      if (frames.isNotEmpty) frames.length == 1 ? '1 frame' : '${frames.length} frames',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('homeNext:${item.item.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/trips/$tripId/stops/${item.stop.id}'),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 88,
                  height: 56,
                  child: frames.isEmpty
                      ? ColoredBox(
                          color: theme.colorScheme.surface,
                          child: Icon(Icons.place_outlined, color: p.tea),
                        )
                      : FrameImage(frame: frames.first, cacheWidth: 300),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$number · NEXT',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: p.tea, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    Text(item.stop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(details,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (animeCameraSupported)
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: p.tea),
                  onPressed: () => openAnimeCamera(context, ref, placeKey: item.stop.placeKey, tripId: tripId),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Take photo'),
                ),
              ),
            if (animeCameraSupported && canEdit) const SizedBox(width: 8),
            if (canEdit)
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _markDone(context, ref),
                  child: const Text('Mark done'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
