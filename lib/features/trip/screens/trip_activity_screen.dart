import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../../sharing/widgets/member_avatar.dart';
import '../providers/plan_together_providers.dart';
import '../providers/trip_providers.dart';

/// "Today", "Yesterday", or "Sat, May 2".
String activityDayHeader(DateTime at, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final days = today.difference(DateUtils.dateOnly(at)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return DateFormat.MMMEd().format(at);
}

/// A shared trip's activity (What changed): who changed what, newest first and
/// grouped by day, for the last 30 days. Opening it clears the trip's dot.
/// Tapping an entry about a stop opens the stop.
class TripActivityScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripActivityScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripActivityScreen> createState() => _TripActivityScreenState();
}

class _TripActivityScreenState extends ConsumerState<TripActivityScreen> {
  late final AppDatabase _db = ref.read(databaseProvider);
  late final String _me = ref.read(currentUserIdProvider);

  @override
  void initState() {
    super.initState();
    _markSeen();
  }

  @override
  void dispose() {
    // Entries that arrived while the page was open count as seen too.
    _markSeen();
    super.dispose();
  }

  void _markSeen() => markTripActivitySeen(_db, widget.tripId, _me);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(tripActivityProvider(widget.tripId));
    final trip = ref.watch(tripDetailProvider(widget.tripId)).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What changed'),
            if (trip != null)
              Text(trip.title,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load the changes: $e")),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No changes in the last 30 days.\nWhen someone in the trip adds, moves or deletes something, it shows here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            );
          }
          final children = <Widget>[];
          String? header;
          for (final entry in list) {
            final h = activityDayHeader(entry.createdAt);
            if (h != header) {
              header = h;
              children.add(Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(h, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ));
            }
            children.add(_ActivityTile(entry: entry));
          }
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: children);
        },
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  final TripActivity entry;

  const _ActivityTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(memberNameProvider((tripId: entry.tripId, userId: entry.actorId)));
    final members = ref.watch(tripMembersProvider(entry.tripId)).valueOrNull;
    final avatarUrl = members?.where((m) => m.userId == entry.actorId).firstOrNull?.avatarUrl;
    final stopExists = entry.entityType == 'stop'
        ? ref.watch(_liveStopProvider(entry.entityId)).valueOrNull ?? false
        : false;
    return ListTile(
      key: Key('activity_${entry.id}'),
      leading: MemberAvatar(name: name, avatarUrl: avatarUrl, radius: 18),
      title: Text.rich(TextSpan(children: [
        TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: ' ${entry.summary}'),
      ])),
      subtitle: Text(
        [DateFormat.Hm().format(entry.createdAt), if (entry.syncStatus == 1) 'Not sent yet'].join(' · '),
        style: theme.textTheme.bodySmall,
      ),
      onTap: stopExists ? () => context.push('/trips/${entry.tripId}/stops/${entry.entityId}') : null,
    );
  }
}

/// Whether a stop is still in the trip, so an entry about it can open it.
final _liveStopProvider = StreamProvider.autoDispose.family<bool, String>((ref, stopId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.stops)..where((s) => s.id.equals(stopId) & s.deletedAt.isNull()))
      .watchSingleOrNull()
      .map((s) => s != null);
});

/// The trip page's top-bar button for What changed, with a dot while
/// someone else changed the trip since the user last looked.
class TripActivityButton extends ConsumerWidget {
  final String tripId;

  const TripActivityButton({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(tripHasUnreadProvider(tripId));
    return IconButton(
      key: const Key('tripActivityButton'),
      tooltip: unread ? 'What changed (new)' : 'What changed',
      icon: Badge(isLabelVisible: unread, smallSize: 8, child: const Icon(Icons.history)),
      onPressed: () => context.push('/trips/$tripId/activity'),
    );
  }
}

/// A small dot on a trip's card while someone else changed it since the user
/// last opened its What changed.
class TripUnreadDot extends ConsumerWidget {
  final String tripId;
  final EdgeInsetsGeometry padding;

  const TripUnreadDot({super.key, required this.tripId, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(tripHasUnreadProvider(tripId))) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Semantics(
        label: 'Changed since you last looked',
        child: Container(
          key: Key('tripUnreadDot_$tripId'),
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
