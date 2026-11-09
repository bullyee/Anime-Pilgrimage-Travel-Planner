import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sharing/invite_links.dart';
import '../../sharing/models/trip_invite.dart';
import '../../sharing/models/trip_member.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../../sharing/sharing_text.dart';
import '../../sharing/widgets/invite_sheet.dart';
import '../../sharing/widgets/member_avatar.dart';
import '../providers/trip_providers.dart';

/// The trip's people, opened from the avatars in the trip's top bar.
class TripMembersScreen extends ConsumerWidget {
  final String tripId;

  const TripMembersScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripDetailProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: Text(trip.valueOrNull?.sharing == 'group' ? 'People in this trip' : 'Share this trip')),
      body: trip.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load this trip: $e")),
        data: (trip) => trip == null || trip.deletedAt != null
            ? const Center(child: Text('This trip was deleted.'))
            : TripMembersView(trip: trip),
      ),
    );
  }
}

/// Who the trip is shared with. Before it's shared: what sharing sends and
/// what stays private, and a button to invite people. Once it is: who's in
/// it and what each can do, the invites still open, and, for the owner,
/// changing that or stopping sharing.
class TripMembersView extends ConsumerWidget {
  final Trip trip;

  const TripMembersView({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(myTripRoleProvider(trip.id));
    if (trip.sharing != 'group') return _NotShared(trip: trip, canInvite: role == TripMemberRole.owner);
    return ref.watch(tripMembersProvider(trip.id)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text("Couldn't load who's in this trip: $e", textAlign: TextAlign.center),
            ),
          ),
          data: (members) => _Shared(trip: trip, members: members, role: role),
        );
  }
}

class _NotShared extends StatelessWidget {
  final Trip trip;
  final bool canInvite;

  const _NotShared({required this.trip, required this.canInvite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: p.wisteriaSoft, shape: BoxShape.circle),
                child: Icon(Icons.group_outlined, size: 44, color: p.wisteria),
              ),
              const SizedBox(height: 16),
              Text('Plan this trip together', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Invite friends with a link, a QR code or a 6-letter code. '
                'You choose whether they can edit or only view.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (canInvite) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => showInviteSheet(context, trip),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Invite people'),
                ),
              ],
              const SizedBox(height: 28),
              const _WhatIsShared(),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the others see once the trip is shared, and what stays private.
class _WhatIsShared extends StatelessWidget {
  const _WhatIsShared();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Items(
              icon: Icons.group_outlined,
              color: p.tea,
              title: 'Shared with the trip',
              items: const ['Days and stops', 'Times and travel', 'Trip notes', 'Spot facts'],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _Items(
              icon: Icons.lock_outline,
              color: p.wisteria,
              title: 'Only you',
              items: const ['Your library', 'My notes', 'Photos and visits'],
            ),
          ),
        ],
      ),
    );
  }
}

class _Items extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;

  const _Items({required this.icon, required this.color, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: color))),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(item, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}

class _Shared extends ConsumerWidget {
  final Trip trip;
  final List<TripMember> members;
  final TripMemberRole? role;

  const _Shared({required this.trip, required this.members, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final me = ref.watch(currentUserIdProvider);
    final owner = role == TripMemberRole.owner;
    final canInvite = owner || role == TripMemberRole.editor;
    final sorted = [...members]..sort((a, b) {
        final byOwner = (a.role == TripMemberRole.owner ? 0 : 1).compareTo(b.role == TripMemberRole.owner ? 0 : 1);
        return byOwner != 0 ? byOwner : a.joinedAt.compareTo(b.joinedAt);
      });
    final others = [for (final m in sorted) if (m.userId != me) m];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    members.length == 1 ? '1 person' : '${members.length} people',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (canInvite)
                  FilledButton.tonalIcon(
                    onPressed: () => showInviteSheet(context, trip),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Invite'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final member in sorted)
              _MemberTile(trip: trip, member: member, isMe: member.userId == me, canChange: owner),
            if (canInvite) _Invites(trip: trip),
            if (owner) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _stopSharing(context, ref, others),
                icon: const Icon(Icons.cloud_off_outlined),
                label: const Text('Stop sharing'),
                style: OutlinedButton.styleFrom(foregroundColor: p.vermilion, side: BorderSide(color: p.vermilion)),
              ),
              const SizedBox(height: 8),
              Text(
                _keepCopyNote(others, 'as it is then'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ] else if (role != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => leaveTrip(context, ref, trip),
                icon: const Icon(Icons.logout),
                label: const Text('Leave trip'),
                style: OutlinedButton.styleFrom(foregroundColor: p.vermilion, side: BorderSide(color: p.vermilion)),
              ),
              const SizedBox(height: 8),
              Text(
                _leaveNote,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _stopSharing(BuildContext context, WidgetRef ref, List<TripMember> others) async {
    final ok = await _confirm(
      context,
      title: 'Stop sharing ${trip.title}?',
      text: _keepCopyNote(others, 'as it is now'),
      action: 'Stop sharing',
    );
    if (!ok || !context.mounted) return;
    final service = ref.read(groupSharingServiceProvider);
    final invites = ref.read(tripInvitesProvider(trip.id)).valueOrNull ?? const <TripInvite>[];
    await _run(context, 'stop sharing', () async {
      // Once the trip is private they could only fail.
      for (final invite in invites) {
        await service.revokeInvite(invite.token);
      }
      await service.unshareTrip(trip.id);
    });
  }
}

const _leaveNote = 'You keep your own copy of the trip, as it is when you leave. It just stops syncing.';

/// Takes the user out of a trip someone else owns, after asking. Their copy
/// stays on the phone as a private trip, so the page stays open on it.
Future<void> leaveTrip(BuildContext context, WidgetRef ref, Trip trip) async {
  final ok = await _confirm(
    context,
    title: 'Leave ${trip.title}?',
    text: '$_leaveNote To join again, you need a new invite.',
    action: 'Leave',
  );
  if (!ok || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final left = await _run(context, 'leave the trip', () => ref.read(groupSharingServiceProvider).leaveTrip(trip.id));
  if (left) messenger.showSnackBar(SnackBar(content: Text('You left ${trip.title}. Your copy is still here.')));
}

/// "Aki and Ren keep their own copy of the trip, as it is then. It just stops
/// syncing."
String _keepCopyNote(List<TripMember> others, String when) {
  if (others.isEmpty) return 'Nobody else has joined, so it just becomes private again.';
  final names = others.map((m) => m.displayName).toList();
  final who = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return '$who ${names.length == 1 ? 'keeps' : 'keep'} their own copy of the trip, $when. It just stops syncing.';
}

enum _MemberAction { viewOnly, edit, owner, remove }

class _MemberTile extends ConsumerWidget {
  final Trip trip;
  final TripMember member;
  final bool isMe;

  /// Whether the user is the owner, who can change what the others can do.
  final bool canChange;

  const _MemberTile({required this.trip, required this.member, required this.isMe, required this.canChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = member.displayName;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: MemberAvatar(name: name, avatarUrl: member.avatarUrl),
      title: Text(isMe ? 'You' : name),
      subtitle: Text(roleLabel(member.role)),
      trailing: canChange && !isMe && member.role != TripMemberRole.owner
          ? PopupMenuButton<_MemberAction>(
              tooltip: 'Change what $name can do',
              onSelected: (action) => _act(context, ref, action),
              itemBuilder: (_) => [
                if (member.role == TripMemberRole.editor)
                  const PopupMenuItem(value: _MemberAction.viewOnly, child: Text('Make view only'))
                else
                  const PopupMenuItem(value: _MemberAction.edit, child: Text('Allow editing')),
                const PopupMenuItem(value: _MemberAction.owner, child: Text('Make owner')),
                const PopupMenuItem(value: _MemberAction.remove, child: Text('Remove from trip')),
              ],
            )
          : null,
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, _MemberAction action) async {
    final service = ref.read(groupSharingServiceProvider);
    final name = member.displayName;
    switch (action) {
      case _MemberAction.viewOnly:
        await _run(context, 'change what $name can do',
            () => service.updateMemberRole(trip.id, member.userId, TripMemberRole.viewer));
      case _MemberAction.edit:
        await _run(context, 'change what $name can do',
            () => service.updateMemberRole(trip.id, member.userId, TripMemberRole.editor));
      case _MemberAction.owner:
        final ok = await _confirm(
          context,
          title: 'Make $name the owner?',
          text: '$name can then invite people, change what the others can do, and stop sharing. '
              'You stay in the trip and can still edit it.',
          action: 'Make owner',
        );
        if (ok && context.mounted) {
          await _run(context, 'make $name the owner', () => service.transferOwnership(trip.id, member.userId));
        }
      case _MemberAction.remove:
        final ok = await _confirm(
          context,
          title: 'Remove $name from the trip?',
          text: '$name keeps a copy of the trip as it is now, but it stops syncing.',
          action: 'Remove',
        );
        if (ok && context.mounted) {
          await _run(context, 'remove $name', () => service.removeMember(trip.id, member.userId));
        }
    }
  }
}

/// The invites the user made that can still be used, each with its code and
/// a way to stop it. Tapping one shows its QR code and link again.
class _Invites extends ConsumerWidget {
  final Trip trip;

  const _Invites({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ref.watch(tripInvitesProvider(trip.id)).when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text("Couldn't load your invites.", style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ),
          data: (invites) {
            if (invites.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text('Invites', style: theme.textTheme.titleSmall),
                for (final invite in invites)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.qr_code_2, color: muted),
                    title: Text(
                      formatShortCode(invite.shortCode),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 2),
                    ),
                    subtitle: Text(
                      '${roleLabel(invite.role)} · until ${DateFormat.MMMd().format(invite.expiresAt)}',
                    ),
                    trailing: TextButton(
                      onPressed: () => _run(
                        context,
                        'stop the invite',
                        () => ref.read(groupSharingServiceProvider).revokeInvite(invite.token),
                      ),
                      child: const Text('Stop'),
                    ),
                    onTap: () => showInviteSheet(context, trip, invite: invite),
                  ),
              ],
            );
          },
        );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String text,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return ok == true;
}

/// Runs a sharing change, and says so when it fails. The members and
/// invites lists update by themselves. Returns whether it went through.
Future<bool> _run(BuildContext context, String doing, Future<void> Function() change) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await change().timeout(sharingTimeout);
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(sharingErrorText(e, doing))));
    return false;
  }
}
