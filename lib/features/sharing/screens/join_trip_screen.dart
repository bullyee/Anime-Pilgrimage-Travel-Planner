import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trip/providers/trip_providers.dart';
import '../../trip/widgets/trip_card.dart';
import '../controllers/join_trip_controller.dart';
import '../invite_links.dart';
import '../models/trip_invite.dart';
import '../models/trip_member.dart';
import '../providers/group_sharing_providers.dart';
import '../widgets/member_avatar.dart';

/// How long a joined trip's days and stops may take to come down before the
/// screen says they'll show up in My Trips instead.
const joinedTripWait = Duration(seconds: 20);

/// Joining a trip: enter a code or paste a link, see whose trip it is and
/// what joining means, then join. An invite link opens it at the preview,
/// with [invite] set to the link's token or code.
class JoinTripScreen extends ConsumerStatefulWidget {
  final String? invite;

  const JoinTripScreen({super.key, this.invite});

  @override
  ConsumerState<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends ConsumerState<JoinTripScreen> {
  final _code = TextEditingController();

  /// Opened from a link, until "Enter another code".
  late bool _fromLink = widget.invite != null;

  /// The trip just joined, while its days and stops come down.
  String? _joinedTripId;
  bool _slow = false;
  bool _opened = false;
  Timer? _slowTimer;

  JoinTripController get _controller => ref.read(joinTripControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    final invite = widget.invite;
    if (invite != null) {
      // After the first build, which mustn't change a provider.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.updateCode(invite);
      });
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinTripControllerProvider);
    final invite = state.invite;
    final signedIn = ref.watch(currentUserIdProvider) != guestUserId;
    final tripId = _joinedTripId ?? invite?.tripId;
    final localTrip = tripId == null ? null : ref.watch(tripDetailProvider(tripId)).valueOrNull;
    final tripHere = localTrip != null && localTrip.deletedAt == null && localTrip.sharing == 'group';

    if (_joinedTripId != null && tripHere && !_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTrip(_joinedTripId!);
      });
    }

    final entering = !_fromLink && _joinedTripId == null && !state.isJoining && invite == null &&
        state.problem != JoinTripProblem.offline;
    return Scaffold(
      appBar: AppBar(title: Text(entering ? 'Join a trip' : 'Invite')),
      body: entering ? _entry(context, state) : _invite(context, state, signedIn: signedIn, tripHere: tripHere),
    );
  }

  /// Everything but the code screen: the preview, joining, and why an invite
  /// can't be used.
  Widget _invite(BuildContext context, JoinTripState state, {required bool signedIn, required bool tripHere}) {
    final invite = state.invite;
    final p = Theme.of(context).trip;
    final title = invite?.tripTitle ?? 'the trip';
    final inviter = invite?.inviterName ?? 'the person who invited you';
    final another = TextButton(onPressed: _another, child: const Text('Enter another code'));

    if (_joinedTripId != null) {
      if (!_slow) {
        return _StateView.busy(title: 'Joining $title', text: 'Getting its days and stops…');
      }
      return _StateView(
        icon: Icons.check_circle_outline,
        color: p.tea,
        background: p.teaSoft,
        title: "You're in $title",
        text: 'Its days and stops show up in My Trips once they have downloaded.',
        action: FilledButton(onPressed: () => context.go('/trips'), child: const Text('Go to My Trips')),
      );
    }
    if (state.isJoining) {
      return _StateView.busy(title: 'Joining $title', text: 'Getting its days and stops…');
    }
    if (state.isLoading || state.code.isEmpty) {
      return const _StateView.busy(title: 'Finding the trip…', text: '');
    }
    if (state.problem == JoinTripProblem.offline) {
      return _StateView(
        icon: Icons.cloud_off_outlined,
        color: p.wisteria,
        background: p.wisteriaSoft,
        title: "You're offline",
        text: 'Finding and joining a trip needs a connection. Once you’ve joined, it works offline too.',
        action: FilledButton(
          onPressed: invite != null && invite.isValid ? _join : () => _controller.fetchPreview(),
          child: const Text('Try again'),
        ),
      );
    }
    if (invite != null && tripHere) {
      return _StateView(
        icon: Icons.check_circle_outline,
        color: p.tea,
        background: p.teaSoft,
        title: "You're already in this trip",
        text: '$title is in your trips.',
        action: FilledButton(onPressed: () => _openTrip(invite.tripId), child: const Text('Open trip')),
      );
    }
    switch (state.problem) {
      case JoinTripProblem.expired:
        return _StateView(
          icon: Icons.timer_off_outlined,
          color: p.vermilion,
          background: p.vermilionSoft,
          title: 'This invite has expired',
          text: 'Invites work for 7 days. Ask $inviter for a new one.',
          action: another,
        );
      case JoinTripProblem.stopped:
        return _StateView(
          icon: Icons.link_off,
          color: p.vermilion,
          background: p.vermilionSoft,
          title: 'This invite was stopped',
          text: 'Someone in the trip stopped it. Ask $inviter for a new one if you still want to join.',
          action: another,
        );
      case JoinTripProblem.notFound:
        return _StateView(
          icon: Icons.search_off,
          color: p.vermilion,
          background: p.vermilionSoft,
          title: "Couldn't find this invite",
          text: 'The link may be cut short. Ask for a new one, or enter its code.',
          action: TextButton(onPressed: _another, child: const Text('Enter a code')),
        );
      case JoinTripProblem.failed:
        return _StateView(
          icon: Icons.error_outline,
          color: p.vermilion,
          background: p.vermilionSoft,
          title: invite == null ? "Couldn't load this invite" : "Couldn't join the trip",
          text: 'Something went wrong on the way. Try again in a moment.\n\n${state.errorMessage ?? ''}'.trim(),
          action: FilledButton(
            onPressed: invite != null && invite.isValid ? _join : () => _controller.fetchPreview(),
            child: const Text('Try again'),
          ),
        );
      case JoinTripProblem.offline:
      case null:
        break;
    }
    if (invite == null) return const _StateView.busy(title: 'Finding the trip…', text: '');
    if (!signedIn) {
      return _StateView(
        icon: Icons.account_circle_outlined,
        color: p.wisteria,
        background: p.wisteriaSoft,
        title: 'Sign in to join $title',
        text: 'A shared trip belongs to your Google account, so the others can see who joined. '
            'Then you come back to this invite.',
        action: FilledButton.icon(
          onPressed: () => _signIn(invite),
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
        ),
      );
    }
    return _preview(context, invite);
  }

  Widget _entry(BuildContext context, JoinTripState state) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final error = switch (state.problem) {
      JoinTripProblem.notFound => 'No invite matches this code or link. Check it and try again.',
      JoinTripProblem.failed => "Couldn't look it up. Try again in a moment.",
      _ => null,
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            if (state.isLoading) const LinearProgressIndicator() else const SizedBox(height: 4),
            const SizedBox(height: 12),
            Text('Enter the code from your invite.', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-HJ-NP-Za-hj-np-z2-9]')),
                const _UpperCase(),
              ],
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Invite code',
                helperText: "6 letters and numbers. Codes leave out 0, O, 1 and I, so they can't be mixed up.",
                helperMaxLines: 3,
                errorText: error,
                errorMaxLines: 3,
                counterText: '',
                border: const OutlineInputBorder(),
              ),
              onChanged: (text) => _controller.updateCode(text),
              onSubmitted: (_) => _find(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isShortCode(state.code) && !state.isLoading ? _find : null,
              child: const Text('Find the trip'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: state.isLoading ? null : _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste an invite link'),
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.qr_code_2, color: muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Got a QR code? Scan it with your phone's camera, and the invite opens here.",
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, TripInvite invite) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final editing = invite.role != TripMemberRole.viewer;
    final start = invite.tripDates == null ? null : DateTime.tryParse(invite.tripDates!);
    final dates = start == null ? 'No dates yet' : 'From ${tripDateLine(firstDate: start, lastDate: start)}';
    final stops = switch (invite.stopCount) { 0 => 'no stops yet', 1 => '1 stop', final n => '$n stops' };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Row(
              children: [
                MemberAvatar(name: invite.inviterName),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${invite.inviterName} invited you to ${editing ? 'edit' : 'view'}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'The invite works until ${DateFormat.MMMd().format(invite.expiresAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    TripDateBadge(date: start, status: TripStatus.planning),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invite.tripTitle, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('$dates · $stops', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Point(
              icon: editing ? Icons.edit_outlined : Icons.visibility_outlined,
              text: editing
                  ? 'You can add, move and remove stops, and change times and trip notes.'
                  : 'You can see the plan as it changes, but not edit it.',
            ),
            const _Point(icon: Icons.sync, text: 'Changes reach everyone in the trip as they happen.'),
            const _Point(icon: Icons.lock_outline, text: 'Your library, notes and photos stay private.'),
            const SizedBox(height: 24),
            FilledButton(onPressed: _join, child: const Text('Join trip')),
            const SizedBox(height: 4),
            TextButton(onPressed: _leave, child: const Text('Not now')),
          ],
        ),
      ),
    );
  }

  Future<void> _find() async {
    if (!isShortCode(ref.read(joinTripControllerProvider).code)) return;
    await _controller.fetchPreview();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final found = inviteFromText(data?.text ?? '');
    if (!mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("There's no invite link or code on the clipboard.")),
      );
      return;
    }
    _code.text = isShortCode(found) ? found : '';
    await _controller.updateCode(found);
  }

  Future<void> _join() async {
    final profile = ref.read(sharingProfileProvider);
    final member = await _controller.joinTrip(displayName: profile.name, avatarUrl: profile.avatarUrl);
    if (member == null || !mounted) return;
    setState(() => _joinedTripId = member.tripId);
    _slowTimer = Timer(joinedTripWait, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  /// Signing in rebuilds the router, so it's told to come back to this
  /// invite afterwards.
  Future<void> _signIn(TripInvite invite) async {
    final returnTo = ref.read(signInReturnProvider.notifier);
    returnTo.state = Uri(path: '/join', queryParameters: {'token': invite.token}).toString();
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } catch (e) {
      returnTo.state = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't sign in: $e")));
    }
  }

  void _openTrip(String tripId) {
    if (context.canPop()) {
      context.pushReplacement('/trips/$tripId');
    } else {
      context.go('/trips/$tripId');
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/trips');
    }
  }

  void _another() {
    _controller.reset();
    _code.clear();
    setState(() => _fromLink = false);
  }
}

/// One line of what joining means.
class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.trip.tea),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// A whole-screen state: an icon (or a spinner) in a soft circle, a title, a
/// line of text and what to do next.
class _StateView extends StatelessWidget {
  final IconData? icon;
  final Color? color;
  final Color? background;
  final String title;
  final String text;
  final Widget? action;

  const _StateView({
    required IconData this.icon,
    required Color this.color,
    required Color this.background,
    required this.title,
    required this.text,
    this.action,
  });

  const _StateView.busy({required this.title, required this.text})
      : icon = null,
        color = null,
        background = null,
        action = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon == null)
                const SizedBox(width: 56, height: 56, child: CircularProgressIndicator())
              else
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                  child: Icon(icon, size: 44, color: color),
                ),
              const SizedBox(height: 20),
              Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  const _UpperCase();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
