import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/browser_info.dart';
import '../invite_links.dart';
import '../web_join_help.dart';

/// On the web join screen: in an app's own browser, how to get to one where
/// Google sign-in works; on Android, opening the invite in the app instead,
/// or getting the app.
class WebJoinHelp extends StatelessWidget {
  final WebJoinBrowser browser;
  final String token;
  final bool signedIn;

  const WebJoinHelp({super.key, required this.browser, required this.token, required this.signedIn});

  /// Whether there is anything to show.
  static bool shows(WebJoinBrowser browser, {required bool signedIn}) =>
      browser.android || (browser.inApp && !signedIn);

  @override
  Widget build(BuildContext context) {
    final inApp = browser.inApp && !signedIn;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inApp)
          _HelpCard(
            icon: Icons.open_in_browser,
            title: 'Open this in Chrome or Safari',
            text: "Google doesn't allow signing in inside an app's own browser, like LINE's or Instagram's. "
                'Copy the link and open it in your browser.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _copyLink(context),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy link'),
              ),
            ],
          ),
        if (inApp && browser.android) const SizedBox(height: 12),
        if (browser.android)
          _HelpCard(
            icon: Icons.phone_android,
            title: 'Have the Android app?',
            text: "Join in the app instead. If it isn't installed, this opens its download page.",
            actions: [
              FilledButton.tonal(
                onPressed: () => openUrlInThisTab(openInAppUrl(token)),
                child: const Text('Open in the app'),
              ),
              TextButton(
                onPressed: () => launchUrl(Uri.parse(apkReleasesUrl), mode: LaunchMode.externalApplication),
                child: const Text('Get the APK'),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: inviteLink(token)));
    messenger.showSnackBar(const SnackBar(content: Text('Link copied. Paste it in Chrome or Safari.')));
  }
}

class _HelpCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final List<Widget> actions;

  const _HelpCard({required this.icon, required this.title, required this.text, required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 6),
            Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: actions),
          ],
        ),
      ),
    );
  }
}
