import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_result.dart';
import '../../../core/utils/schedule_logic.dart';
import '../controllers/day_planner_controller.dart';
import '../models/planner_view.dart';
import '../providers/planner_providers.dart';
import 'day_card.dart' show dayLabel;

String _dayWithDate(PlannerDay d) =>
    d.date == null ? dayLabel(d) : '${dayLabel(d)} · ${DateFormat.MMMEd().format(d.date!)}';

/// Shows [result]'s error, or [ok] when it worked.
void reportResult(BuildContext context, AppResult<dynamic> result, {String? ok, SnackBarAction? action}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case Failure(:final error):
      messenger.showSnackBar(SnackBar(content: Text(error)));
    case Success():
      if (ok != null) messenger.showSnackBar(SnackBar(content: Text(ok), action: action));
  }
}

/// A stop's details and the quick actions for it. While editing, the stay
/// can be changed and the stop moved to another day or back to the backlog.
Future<void> showPlannerStopSheet(
  BuildContext context, {
  required String tripId,
  required String stopId,
  required bool editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _StopSheet(tripId: tripId, stopId: stopId, editing: editing),
  );
}

class _StopSheet extends ConsumerWidget {
  final String tripId;
  final String stopId;
  final bool editing;

  const _StopSheet({required this.tripId, required this.stopId, required this.editing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final view = ref.watch(plannerViewProvider(tripId)).valueOrNull;
    if (view == null) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));

    PlannerDay? foundDay;
    PlannerItem? foundItem;
    for (final d in view.days) {
      for (final it in d.items) {
        if (it.stop.id == stopId) {
          foundDay = d;
          foundItem = it;
        }
      }
    }
    // Final copies, so they stay promoted inside the callbacks below.
    final day = foundDay;
    final item = foundItem;
    final stop = item?.stop ?? view.backlog.where((s) => s.id == stopId).firstOrNull;
    if (stop == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Text('This stop is no longer in the trip.'));
    }
    final controller = ref.read(dayPlannerControllerProvider.notifier);

    Widget fact(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 96, child: Text(label, style: theme.textTheme.labelLarge)),
              Expanded(child: value),
            ],
          ),
        );
    Widget text(String? value) => Text(value ?? '', style: theme.textTheme.bodyMedium);

    final when = item == null
        ? 'Not on a day yet'
        : '${_dayWithDate(day!)} · ${formatTimelineMinutes(item.startMinutes)}–${formatTimelineMinutes(item.endMinutes)}'
            '${item.fixed ? ' (fixed time)' : ''}';

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            Text(stop.name, style: theme.textTheme.titleLarge),
            Text(
              stop.source == null ? 'Your own spot' : 'From ${stop.source}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            fact('When', text(when)),
            if (item != null)
              fact(
                'Stay',
                editing
                    ? Row(
                        children: [
                          IconButton.outlined(
                            tooltip: '5 minutes shorter',
                            onPressed: item.item.stayMinutes <= 5
                                ? null
                                : () => controller.setStay(item.item.id, item.item.stayMinutes - 5),
                            icon: const Icon(Icons.remove),
                          ),
                          SizedBox(
                            width: 72,
                            child: Text('${item.item.stayMinutes} min',
                                textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
                          ),
                          IconButton.outlined(
                            tooltip: '5 minutes longer',
                            onPressed: () => controller.setStay(item.item.id, item.item.stayMinutes + 5),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      )
                    : text('${item.item.stayMinutes} min'),
              ),
            if (stop.address?.trim().isNotEmpty ?? false) fact('Address', text(stop.address)),
            if (stop.description?.trim().isNotEmpty ?? false) fact('About', text(stop.description)),
            if (stop.accessTips?.trim().isNotEmpty ?? false) fact('Getting there', text(stop.accessTips)),
            if (stop.businessHours?.trim().isNotEmpty ?? false) fact('Hours', text(stop.businessHours)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item != null)
                  OutlinedButton.icon(
                    onPressed: () => controller.setVisited(item.item.id, !item.done),
                    icon: Icon(item.done ? Icons.check_circle : Icons.radio_button_unchecked),
                    label: Text(item.done ? 'Mark as not visited' : 'Mark as visited'),
                  ),
                if (editing && item != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final itemId = item.item.id;
                      final result = await controller.unschedule(itemId);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      reportResult(context, result,
                          ok: 'Moved ${stop.name} to the backlog.',
                          action: SnackBarAction(label: 'Undo', onPressed: () => controller.restoreItem(itemId)));
                    },
                    icon: const Icon(Icons.inbox_outlined),
                    label: const Text('Move to backlog'),
                  ),
              ],
            ),
            if (editing) ...[
              const SizedBox(height: 16),
              Text(item == null ? 'Add to a day' : 'Move to another day', style: theme.textTheme.titleSmall),
              for (final d in view.days)
                if (d != day)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(d.isBackup ? Icons.beach_access_outlined : Icons.today_outlined),
                    title: Text(_dayWithDate(d)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final result = item == null
                          ? await controller.scheduleStop(tripId: tripId, stopId: stop.id, dayId: d.day.id)
                          : await controller.moveItem(itemId: item.item.id, toDayId: d.day.id);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      reportResult(context, result, ok: 'Moved ${stop.name} to ${dayLabel(d)}.');
                    },
                  ),
            ],
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

/// "between Fri, Apr 30 and Sat, May 1", "on Fri, Apr 30 or later", or
/// "on Sat, May 1 or earlier".
String pinRangeText(PinRange range) {
  final f = DateFormat.MMMEd();
  if (range.min != null && range.max != null) return 'between ${f.format(range.min!)} and ${f.format(range.max!)}';
  if (range.min != null) return 'on ${f.format(range.min!)} or later';
  if (range.max != null) return 'on ${f.format(range.max!)} or earlier';
  return 'on any date';
}

/// Pins a day to a date the user picks, or unpins it.
Future<void> showPinSheet(BuildContext context, WidgetRef ref, PlannerView view, PlannerDay day) {
  final range = view.pinRangeFor(day);
  final controller = ref.read(dayPlannerControllerProvider.notifier);
  final next = range.nextPinned;
  final why = next == null
      ? ''
      : ' ${dayLabel(next)} is pinned to ${DateFormat.MMMEd().format(next.date!)}, and the days in between need dates of their own.';

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      DateTime local(DateTime d) => DateTime(d.year, d.month, d.day);
      Future<void> pick() async {
        final today = DateUtils.dateOnly(DateTime.now());
        final first = range.min == null ? DateTime(today.year - 5) : local(range.min!);
        final last = range.max == null ? DateTime(today.year + 5, 12, 31) : local(range.max!);
        var initial = day.date == null ? (range.min == null ? today : first) : local(day.date!);
        if (initial.isBefore(first)) initial = first;
        if (initial.isAfter(last)) initial = last;
        final picked = await showDatePicker(
          context: sheetContext,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          helpText: 'Pin ${dayLabel(day)} to',
        );
        if (picked == null || !sheetContext.mounted) return;
        final result = await controller.pinDay(day.day.id, picked);
        if (!sheetContext.mounted) return;
        Navigator.pop(sheetContext);
        reportResult(context, result, ok: '${dayLabel(day)} is pinned to ${DateFormat.MMMEd().format(picked)}.');
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                day.isPinned ? 'Change the date of ${dayLabel(day)}' : 'Pin ${dayLabel(day)} to a date',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'A pinned day keeps its date and stays in place, for events and reservations. '
                'The days after it continue from that date.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                range.isEmpty
                    ? "This day can't be pinned right now.$why"
                    : 'Pick a date ${pinRangeText(range)}.$why',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (day.isPinned)
                    TextButton(
                      onPressed: () async {
                        final result = await controller.pinDay(day.day.id, null);
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                        reportResult(context, result, ok: '${dayLabel(day)} is no longer pinned.');
                      },
                      child: const Text('Unpin'),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: range.isEmpty ? null : pick, child: const Text('Pick a date')),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Lists the backlog so stops can be put on [day] without dragging. The
/// sheet stays open, so several stops can be added in a row.
Future<void> showAddFromBacklogSheet(BuildContext context, {required String tripId, required PlannerDay day}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddFromBacklogSheet(tripId: tripId, dayId: day.day.id),
  );
}

class _AddFromBacklogSheet extends ConsumerWidget {
  final String tripId;
  final String dayId;

  const _AddFromBacklogSheet({required this.tripId, required this.dayId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final view = ref.watch(plannerViewProvider(tripId)).valueOrNull;
    final day = view?.dayById(dayId);
    if (view == null || day == null) return const SizedBox(height: 160);
    final controller = ref.read(dayPlannerControllerProvider.notifier);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Add to ${_dayWithDate(day)}', style: theme.textTheme.titleLarge),
            ),
            if (view.backlog.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  'Every stop in this trip is on a day. Add more stops in the Stops tab.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in view.backlog)
                      ListTile(
                        title: Text(s.name),
                        subtitle: s.address == null ? null : Text(s.address!, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () async {
                          final result = await controller.scheduleStop(tripId: tripId, stopId: s.id, dayId: dayId);
                          if (context.mounted && result is Failure) reportResult(context, result);
                        },
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
