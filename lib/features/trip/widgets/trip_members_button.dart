import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sharing/models/trip_member.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../../sharing/widgets/member_avatar.dart';

/// The trip's people in its top bar: the others' avatars on a shared trip,
/// up to three, or an invite icon on a private one. Either opens the member
/// list, where people are invited.
class TripMembersButton extends ConsumerWidget {
  final Trip trip;

  const TripMembersButton({super.key, required this.trip});

  static const _shown = 3;
  static const _radius = 13.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open() => context.push('/trips/${trip.id}/members');
    if (trip.sharing != 'group') {
      return IconButton(tooltip: 'Share this trip', icon: const Icon(Icons.person_add_alt_1_outlined), onPressed: open);
    }
    final theme = Theme.of(context);
    final me = ref.watch(currentUserIdProvider);
    final members = ref.watch(tripMembersProvider(trip.id)).valueOrNull ?? const <TripMember>[];
    final others =
        [
          for (final m in members)
            if (m.userId != me) m,
        ]..sort((a, b) {
          final byOwner = (a.role == TripMemberRole.owner ? 0 : 1).compareTo(b.role == TripMemberRole.owner ? 0 : 1);
          return byOwner != 0 ? byOwner : a.joinedAt.compareTo(b.joinedAt);
        });
    if (others.isEmpty) {
      return IconButton(tooltip: 'People in this trip', icon: const Icon(Icons.group_outlined), onPressed: open);
    }
    final faces = others.take(_shown).toList();
    // Each avatar overlaps the one before it by a third, ringed in the bar's
    // color so the edges stay apart.
    const step = _radius * 2 * 2 / 3;
    final ring = theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    return Tooltip(
      message: 'People in this trip',
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SizedBox(
            width: step * (faces.length - 1) + _radius * 2 + 2,
            height: _radius * 2 + 2,
            child: Stack(
              children: [
                for (var i = 0; i < faces.length; i++)
                  Positioned(
                    left: step * i,
                    child: CircleAvatar(
                      radius: _radius + 1,
                      backgroundColor: ring,
                      child: MemberAvatar(name: faces[i].displayName, avatarUrl: faces[i].avatarUrl, radius: _radius),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
