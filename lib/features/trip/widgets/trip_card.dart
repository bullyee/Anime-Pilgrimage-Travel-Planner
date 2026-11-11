import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sharing/models/trip_member.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../../sharing/widgets/member_avatar.dart';
import '../models/trip_summary.dart';
import 'trip_sync_icon.dart';

/// "Apr 29 – May 4", or "No dates yet". The year is added when the trip
/// isn't in the current year.
String tripDateLine({
  required DateTime? firstDate,
  required DateTime? lastDate,
  DateTime? now,
}) {
  if (firstDate == null || lastDate == null) return 'No dates yet';
  final thisYear = (now ?? DateTime.now()).year;
  final md = DateFormat.MMMd();
  final range = firstDate == lastDate
      ? md.format(firstDate)
      : '${md.format(firstDate)} – ${md.format(lastDate)}';
  final year = lastDate.year == thisYear && firstDate.year == thisYear ? '' : ', ${lastDate.year}';
  return '$range$year';
}

/// A trip in the list: its first date and its title, its description when
/// it has one, plus who it's shared with, and a cloud while a shared trip
/// isn't in sync. The section it's listed under says whether it's under
/// way, coming up or over, so the card doesn't repeat that.
class TripCard extends StatelessWidget {
  final TripSummary summary;
  final VoidCallback onTap;

  const TripCard({super.key, required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shared = summary.trip.sharing == 'group';
    final description = summary.trip.description?.trim() ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              TripDateBadge(date: summary.firstDate, status: summary.status),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            summary.trip.title,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (shared)
                          TripSyncIcon(tripId: summary.trip.id, padding: const EdgeInsets.only(left: 8, top: 2)),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        key: const Key('tripCardDescription'),
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (shared) ...[
                      const SizedBox(height: 6),
                      TripMembersLine(tripId: summary.trip.id),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "You and Aki", "You, Aki and Ren" or "You and 3 others", after the
/// others' avatars; "Only you so far" before anyone joins.
String membersLine(List<String> otherNames) => switch (otherNames) {
      [] => 'Only you so far',
      [final a] => 'You and $a',
      [final a, final b] => 'You, $a and $b',
      _ => 'You and ${otherNames.length} others',
    };

/// Who a shared trip is shared with: the others' avatars, up to three, and
/// [membersLine]. Until the members load, or when they can't (signed out,
/// say), it just says the trip is shared.
class TripMembersLine extends ConsumerWidget {
  final String tripId;

  const TripMembersLine({super.key, required this.tripId});

  static const _shown = 3;
  static const _radius = 11.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = theme.trip.wisteria;
    final style = theme.textTheme.bodyMedium?.copyWith(color: color);
    final me = ref.watch(currentUserIdProvider);
    final members = ref.watch(tripMembersProvider(tripId)).valueOrNull;
    if (members == null || members.every((m) => m.userId != me)) {
      return Row(
        children: [
          Icon(Icons.group_outlined, size: 18, color: color),
          const SizedBox(width: 6),
          Text('Shared', style: style),
        ],
      );
    }
    final others = [for (final m in members) if (m.userId != me) m]
      ..sort((a, b) {
        final byOwner = (a.role == TripMemberRole.owner ? 0 : 1).compareTo(b.role == TripMemberRole.owner ? 0 : 1);
        return byOwner != 0 ? byOwner : a.joinedAt.compareTo(b.joinedAt);
      });
    final faces = others.take(_shown).toList();
    // Each avatar overlaps the one before it by a third, ringed in the
    // card's color so the edges stay apart.
    const step = _radius * 2 * 2 / 3;
    return Row(
      children: [
        if (faces.isEmpty)
          Icon(Icons.group_outlined, size: 18, color: color)
        else
          SizedBox(
            width: step * (faces.length - 1) + _radius * 2 + 2,
            height: _radius * 2 + 2,
            child: Stack(
              children: [
                for (var i = 0; i < faces.length; i++)
                  Positioned(
                    left: step * i,
                    child: CircleAvatar(
                      radius: _radius + 1,
                      backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
                      child: MemberAvatar(name: faces[i].displayName, avatarUrl: faces[i].avatarUrl, radius: _radius),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            membersLine([for (final m in others) m.displayName]),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The colors a trip's status is shown in: tea while it's under way,
/// wisteria while it's still being planned, grey once it's over.
(Color background, Color foreground) tripStatusColors(ThemeData theme, TripStatus status) {
  final p = theme.trip;
  return switch (status) {
    TripStatus.ongoing => (p.teaSoft, p.tea),
    TripStatus.planning => (p.wisteriaSoft, p.wisteria),
    TripStatus.finished => (theme.colorScheme.surfaceContainerHighest, theme.colorScheme.onSurfaceVariant),
  };
}

/// The trip's first date as a small calendar leaf, with the year when it
/// isn't this year, or a suitcase when the trip has no dates yet.
class TripDateBadge extends StatelessWidget {
  final DateTime? date;
  final TripStatus status;

  const TripDateBadge({super.key, required this.date, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = tripStatusColors(theme, status);
    final d = date;
    final otherYear = d != null && d.year != DateTime.now().year;
    return Semantics(
      label: d == null ? 'No dates yet' : 'Starts ${DateFormat.yMMMd().format(d)}',
      excludeSemantics: true,
      child: Container(
        width: 54,
        height: 58,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: d == null
            ? Icon(Icons.luggage_outlined, color: foreground)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.MMM().format(d).toUpperCase(),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: foreground, fontWeight: FontWeight.w700, letterSpacing: 1, height: 1.1),
                  ),
                  Text(
                    '${d.day}',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: foreground, fontWeight: FontWeight.w800, height: 1.05),
                  ),
                  if (otherYear)
                    Text(
                      '${d.year}',
                      style: theme.textTheme.labelSmall?.copyWith(color: foreground, fontSize: 10, height: 1.1),
                    ),
                ],
              ),
      ),
    );
  }
}
