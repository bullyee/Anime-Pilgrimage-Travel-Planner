import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/group_sharing_providers.dart';

/// Whether nobody is signed in on this device. A shared trip stays here
/// after signing out, but it can't sync, show its members, or be left
/// until someone signs in again.
final signedOutProvider = Provider.autoDispose<bool>((ref) => ref.watch(currentUserIdProvider) == guestUserId);

/// What a shared trip can't do while signed out.
const signedOutTripText = "You're signed out. Sign in to sync this trip, see who's in it, or leave it.";

/// Google sign-in from a shared trip; a failure shows as a message.
Future<void> signInForSharedTrip(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't sign in: $e")));
  }
}

/// A strip at the top of a shared trip while signed out, with Sign in.
class SignedOutTripStrip extends ConsumerWidget {
  const SignedOutTripStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('signedOutTripStrip'),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(signedOutTripText, style: theme.textTheme.bodyMedium)),
              ],
            ),
            TextButton(onPressed: () => signInForSharedTrip(context, ref), child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }
}
