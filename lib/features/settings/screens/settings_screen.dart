import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_version.dart';
import '../../../shared/map/app_map.dart';
import '../../anime/services/isnet_model_store.dart';
import '../../auth/providers/auth_provider.dart';
import '../../library/widgets/library_backup_flow.dart';
import '../services/storage_usage.dart';

/// Deletes the cutout model; tests replace it.
final deleteCutoutModelProvider = Provider<Future<void> Function()>((ref) => () => IsnetModelStore().delete());

/// Opens a link outside the app; tests replace it.
final openLinkProvider = Provider<Future<void> Function(Uri)>(
    (ref) => (uri) async => launchUrl(uri, mode: LaunchMode.externalApplication));

/// "Under 1 MB", "84 MB": a size on a line of its own.
String sizeLine(int bytes) {
  final s = formatBytes(bytes);
  return s[0].toUpperCase() + s.substring(1);
}

/// "less than 1 MB", "84 MB": a size inside a sentence.
String sizeInSentence(int bytes) => bytes < 1024 * 1024 ? 'less than 1 MB' : formatBytes(bytes);

const privacyPolicyUrl = 'https://trip-planner-2775c.web.app/privacy.html';
const sourceCodeUrl = 'https://github.com/bullyee/trip_planner';
const googleConnectionsUrl = 'https://myaccount.google.com/connections';
const sharedFramesFolder = 'Trip Planner Shared Frames';

/// Settings: the account, your data and About, in one place instead of the
/// ⋮ menus they used to be in. Opened from Home's gear and My Trips' account
/// button.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: const [
              _Header('Account'),
              _AccountSection(),
              Divider(height: 24),
              _Header('Your data'),
              _DataSection(),
              Divider(height: 24),
              _Header('About'),
              _AboutSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't sign in: $e")));
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authControllerProvider.notifier).signOut();
      messenger.showSnackBar(const SnackBar(content: Text('Signed out.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't sign out: $e")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    if (user == null) {
      return ListTile(
        key: const Key('settingsSignedOut'),
        leading: const Icon(Icons.account_circle_outlined),
        title: const Text('Not signed in'),
        subtitle: const Text('Signing in is only for sharing trips. Everything else works without an account.'),
        trailing: FilledButton.tonal(onPressed: () => _signIn(context, ref), child: const Text('Sign in')),
      );
    }
    final name = user.displayName;
    final email = user.email;
    return Column(
      children: [
        ListTile(
          key: const Key('settingsSignedIn'),
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(name ?? email ?? 'Signed in'),
          subtitle: Text([
            if (name != null && email != null) email,
            'Google account, for shared trips',
          ].join('\n')),
          isThreeLine: name != null && email != null,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          subtitle: const Text("Shared trips sync only while you're signed in. Your library and private trips don't need it."),
          onTap: () => _signOut(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.add_to_drive_outlined),
          title: const Text('Frames shared through Google Drive'),
          subtitle: const Text(
            'They stay in the "$sharedFramesFolder" folder in your Drive, and anyone with the link can see them. '
            'To stop sharing, delete them there, or remove Trip Planner\'s access to your Google account.',
          ),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => ref.read(openLinkProvider)(Uri.parse(googleConnectionsUrl)),
        ),
      ],
    );
  }
}

class _DataSection extends ConsumerWidget {
  const _DataSection();

  Future<void> _clearTiles(BuildContext context, WidgetRef ref, int bytes) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear map tiles?'),
        content: Text(
          'Frees ${sizeInSentence(bytes)}. Maps load their tiles again the next time you look at them, '
          'so they need a connection until then.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (go != true) return;
    await clearMapTileCache();
    ref.invalidate(storageUsageProvider);
  }

  Future<void> _deleteModel(BuildContext context, WidgetRef ref, int bytes) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete the cutout model?'),
        content: Text(
          'Frees ${sizeInSentence(bytes)}. Cut out character downloads it again (about 176 MB) the next time you use it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (go != true) return;
    await ref.read(deleteCutoutModelProvider)();
    ref.invalidate(storageUsageProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = kIsWeb ? null : ref.watch(storageUsageProvider);
    final u = usage?.valueOrNull;
    String size(int Function(StorageUsage) of) =>
        usage == null ? '' : (u == null ? (usage.hasError ? "Couldn't measure" : 'Measuring…') : sizeLine(of(u)));
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.save_alt),
          title: const Text('Back up to a file'),
          subtitle: const Text(
            'Your library with its photos and frames, and your private trips, in one file to keep or send to a new phone.',
          ),
          onTap: () => backUpLibrary(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore from a file'),
          subtitle: const Text("Adds what's in a backup and isn't on this phone yet. Nothing here is changed."),
          onTap: () => restoreLibrary(context, ref),
        ),
        if (usage != null) ...[
          ListTile(
            key: const Key('settingsYourData'),
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Your places, trips, photos and frames'),
            trailing: Text(size((u) => u.yourData)),
          ),
          ListTile(
            key: const Key('settingsMapTiles'),
            leading: const Icon(Icons.map_outlined),
            title: const Text('Map tiles'),
            subtitle: Text('The maps you looked at in the last 14 days, kept for using offline.\n${size((u) => u.mapTiles)}'),
            trailing: TextButton(
              onPressed: (u == null || u.mapTiles == 0) ? null : () => _clearTiles(context, ref, u.mapTiles),
              child: const Text('Clear'),
            ),
          ),
          if (u != null && u.cutoutModel > 0)
            ListTile(
              key: const Key('settingsCutoutModel'),
              leading: const Icon(Icons.content_cut),
              title: const Text('Cutout model'),
              subtitle: Text('For Cut out character, downloaded the first time.\n${sizeLine(u.cutoutModel)}'),
              trailing: TextButton(
                onPressed: () => _deleteModel(context, ref, u.cutoutModel),
                child: const Text('Delete'),
              ),
            ),
        ],
      ],
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(String url) => ref.read(openLinkProvider)(Uri.parse(url));
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Trip Planner'),
          subtitle: Text('Version $appVersionLabel'),
        ),
        ListTile(
          leading: const Icon(Icons.place_outlined),
          title: const Text('Spots and frames from Anitabi'),
          subtitle: const Text('anitabi.cn, shared under CC BY-NC-SA 4.0: free to use, never sold.'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open('https://www.anitabi.cn/'),
        ),
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: const Text('Maps from OpenStreetMap'),
          subtitle: const Text('© OpenStreetMap contributors'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open('https://www.openstreetmap.org/copyright'),
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Anime search from Bangumi'),
          subtitle: const Text('bgm.tv'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open('https://bgm.tv/'),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy policy'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open(privacyPolicyUrl),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Source code and releases'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open(sourceCodeUrl),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Open-source licences'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Trip Planner',
            applicationVersion: appVersionLabel,
          ),
        ),
      ],
    );
  }
}
