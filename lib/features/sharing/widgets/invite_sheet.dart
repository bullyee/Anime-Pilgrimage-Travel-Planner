import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/database.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../invite_links.dart';
import '../models/trip_invite.dart';
import '../models/trip_member.dart';
import '../providers/group_sharing_providers.dart';
import '../sharing_text.dart';

/// Opens the invite sheet for [trip]: choose what invitees can do, then share
/// the invite as a code, a QR code or a link. With [invite], it opens at that
/// invite.
Future<void> showInviteSheet(BuildContext context, Trip trip, {TripInvite? invite}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => InviteSheet(trip: trip, invite: invite),
  );
}

class InviteSheet extends ConsumerStatefulWidget {
  final Trip trip;
  final TripInvite? invite;

  const InviteSheet({super.key, required this.trip, this.invite});

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  TripMemberRole _role = TripMemberRole.editor;
  late TripInvite? _invite = widget.invite;
  bool _busy = false;
  String? _error;

  /// What was just copied, "code" or "link", so its button shows a tick.
  String? _copied;

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(currentUserIdProvider) != guestUserId;
    final invite = _invite;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: !signedIn
              ? _signIn(context)
              : invite == null
                  ? _choose(context)
                  : _ready(context, invite),
        ),
      ),
    );
  }

  Widget _choose(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Invite to ${widget.trip.title}', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Text('What can they do?', style: theme.textTheme.titleSmall),
        RadioGroup<TripMemberRole>(
          groupValue: _role,
          onChanged: (role) {
            if (role != null && !_busy) setState(() => _role = role);
          },
          child: const Column(
            children: [
              RadioListTile<TripMemberRole>(
                value: TripMemberRole.editor,
                contentPadding: EdgeInsets.zero,
                title: Text('Edit'),
                subtitle: Text('Add, move and remove stops, and change times and trip notes.'),
              ),
              RadioListTile<TripMemberRole>(
                value: TripMemberRole.viewer,
                contentPadding: EdgeInsets.zero,
                title: Text('View only'),
                subtitle: Text('See the plan as it changes, without editing it.'),
              ),
            ],
          ),
        ),
        if (widget.trip.sharing != 'group') ...[
          const SizedBox(height: 8),
          const _Note(
            icon: Icons.cloud_upload_outlined,
            text: "This is the trip's first invite, so its days, stops and trip notes go to the cloud now. "
                'Your library, notes and photos stay on this phone.',
          ),
        ],
        ..._errorLine(context),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create invite'),
        ),
        const SizedBox(height: 12),
        Text(
          'An invite works for 7 days, for anyone who has its link or code. You can stop it any time.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _ready(BuildContext context, TripInvite invite) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final link = inviteLink(invite.token);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Invite to ${widget.trip.title}', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              icon: invite.role == TripMemberRole.viewer ? Icons.visibility_outlined : Icons.edit_outlined,
              text: roleLabel(invite.role),
            ),
            _Chip(icon: Icons.schedule, text: 'Works until ${DateFormat.MMMd().format(invite.expiresAt)}'),
          ],
        ),
        const SizedBox(height: 20),
        Text('Code', style: theme.textTheme.labelLarge?.copyWith(color: muted)),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                formatShortCode(invite.shortCode),
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 4),
              ),
            ),
            IconButton(
              tooltip: 'Copy the code',
              icon: Icon(_copied == 'code' ? Icons.check : Icons.copy),
              onPressed: () => _copy('code', invite.shortCode),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          // Dark on white in either theme, so any camera can read it.
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(
              data: link,
              size: 200,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              semanticsLabel: 'QR code of the invite link',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scanning it with a phone camera opens the invite.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                link.replaceFirst('https://', ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
            IconButton(
              tooltip: 'Copy the link',
              icon: Icon(_copied == 'link' ? Icons.check : Icons.link),
              onPressed: () => _copy('link', link),
            ),
          ],
        ),
        ..._errorLine(context),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _share(invite),
          icon: const Icon(Icons.share),
          label: const Text('Share invite'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _busy ? null : () => _stop(invite),
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: const Text('Stop this invite'),
        ),
      ],
    );
  }

  Widget _signIn(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sign in to invite people', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'A shared trip belongs to your Google account, so the others can see who invited them. '
          'Then you come back to this trip.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        ..._errorLine(context),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _signInNow,
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
        ),
      ],
    );
  }

  List<Widget> _errorLine(BuildContext context) {
    final error = _error;
    if (error == null) return const [];
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 12),
      Text(error, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
    ];
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(groupSharingServiceProvider);
    final profile = ref.read(sharingProfileProvider);
    try {
      if (widget.trip.ownerId == guestUserId) {
        // Made before signing in: it becomes this account's before it's shared.
        await service.claimGuestTrips(service.currentUserId);
      }
      final invite = await service
          .createInvite(
            tripId: widget.trip.id,
            role: _role,
            inviterName: profile.name,
            inviterAvatarUrl: profile.avatarUrl,
          )
          .timeout(sharingTimeout);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = sharingErrorText(e, 'create the invite');
      });
    }
  }

  Future<void> _stop(TripInvite invite) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(groupSharingServiceProvider).revokeInvite(invite.token).timeout(sharingTimeout);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = sharingErrorText(e, 'stop the invite');
      });
    }
  }

  Future<void> _copy(String what, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = what);
  }

  Future<void> _share(TripInvite invite) async {
    // Where the share sheet points from on an iPad.
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: inviteShareText(invite),
      subject: 'Join ${widget.trip.title}',
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  /// Signing in rebuilds the router, so it's told to come back to this
  /// trip's members afterwards.
  Future<void> _signInNow() async {
    final returnTo = ref.read(signInReturnProvider.notifier);
    returnTo.state = '/trips/${widget.trip.id}?tab=members';
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } catch (e) {
      returnTo.state = null;
      if (mounted) setState(() => _error = "Couldn't sign in: $e");
    }
  }
}

/// A tinted note, like the one about what a first invite sends to the cloud.
class _Note extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.wisteriaSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: p.wisteria),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: p.teaSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: p.tea),
          const SizedBox(width: 6),
          Text(text, style: theme.textTheme.labelLarge?.copyWith(color: p.tea)),
        ],
      ),
    );
  }
}
