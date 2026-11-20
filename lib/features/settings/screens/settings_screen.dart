import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_version.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../shared/map/app_map.dart';
import '../../anime/services/isnet_model_store.dart';
import '../../auth/providers/auth_provider.dart';
import '../../library/widgets/library_backup_flow.dart';
import '../../sync/providers/drive_cleanup_providers.dart';
import '../../sync/widgets/drive_cleanup_flow.dart';
import '../../sync/providers/drive_upload_quality_provider.dart';
import '../../sync/widgets/drive_upload_quality_picker.dart';
import '../services/storage_usage.dart';
import '../widgets/language_picker.dart';

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

String _localizedSizeLine(AppLocalizations l10n, int bytes) =>
    bytes < 1024 * 1024 ? l10n.settingsSizeUnder1Mb : sizeLine(bytes);

String _localizedSizeInSentence(AppLocalizations l10n, int bytes) =>
    bytes < 1024 * 1024 ? l10n.settingsSizeLessThan1Mb : formatBytes(bytes);

const privacyPolicyUrl = 'https://trip-planner-2775c.web.app/privacy.html';
const sourceCodeUrl = 'https://github.com/bullyee/trip_planner';

/// Settings: the account, app language, your data and About, in one place instead of the
/// ⋮ menus they used to be in. Opened from Home's gear and My Trips' account
/// button.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Header(l10n.settingsSectionAccount),
              const _AccountSection(),
              const Divider(height: 24),
              _Header(l10n.settingsSectionData),
              const _DataSection(),
              const Divider(height: 24),
              _Header(l10n.settingsSectionApp),
              const _LanguageTile(),
              const Divider(height: 24),
              _Header(l10n.settingsSectionAbout),
              const _AboutSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(appLocaleProvider);
    return ListTile(
      key: const Key('settingsLanguage'),
      leading: const Icon(Icons.language),
      title: Text(l10n.settingsLanguage),
      subtitle: Text(current.nativeLabel ?? l10n.settingsLanguageSystem),
      onTap: () => showLanguagePicker(context),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsSignInFailed('$e'))),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(authControllerProvider.notifier).signOut();
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSignedOut)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSignOutFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    if (user == null) {
      return ListTile(
        key: const Key('settingsSignedOut'),
        leading: const Icon(Icons.account_circle_outlined),
        title: Text(l10n.settingsNotSignedInTitle),
        subtitle: Text(l10n.settingsNotSignedInSubtitle),
        trailing: FilledButton.tonal(
          onPressed: () => _signIn(context, ref),
          child: Text(l10n.settingsSignInButton),
        ),
      );
    }
    final name = user.displayName;
    final email = user.email;
    return Column(
      children: [
        ListTile(
          key: const Key('settingsSignedIn'),
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(name ?? email ?? l10n.settingsSignedInFallbackTitle),
          subtitle: Text([
            if (name != null && email != null) email,
            l10n.settingsGoogleAccountSubtitle,
          ].join('\n')),
          isThreeLine: name != null && email != null,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l10n.settingsSignOutTitle),
          subtitle: Text(l10n.settingsSignOutSubtitle),
          onTap: () => _signOut(context, ref),
        ),
        const _UploadQualityTile(),
        const _DriveRemovalTile(),
      ],
    );
  }
}

/// Remove every frame this user shared through Google Drive, and how many
/// removals are still waiting to reach Drive.
class _UploadQualityTile extends ConsumerWidget {
  const _UploadQualityTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = ref.watch(driveUploadQualityProvider);
    return ListTile(
      key: const Key('settingsUploadQuality'),
      leading: const Icon(Icons.high_quality_outlined),
      title: Text(context.l10n.settingsFrameUploadQualityTitle),
      subtitle: Text('${quality.label}: ${quality.detail}'),
      onTap: () => showDriveUploadQualityPicker(context),
    );
  }
}

class _DriveRemovalTile extends ConsumerWidget {
  const _DriveRemovalTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final waiting = ref.watch(driveRemovalsWaitingProvider).valueOrNull ?? 0;
    return ListTile(
      key: const Key('settingsDriveRemoval'),
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(l10n.settingsDriveRemoveTitle),
      subtitle: Text([
        l10n.settingsDriveRemoveSubtitle,
        if (waiting > 0) l10n.settingsDriveRemovalsWaiting(waiting),
      ].join('\n\n')),
      isThreeLine: true,
      onTap: () => confirmAndRemoveAllSharedFrames(context, ref),
    );
  }
}

class _DataSection extends ConsumerWidget {
  const _DataSection();

  Future<void> _clearTiles(BuildContext context, WidgetRef ref, int bytes) async {
    final l10n = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsClearMapTilesDialogTitle),
        content: Text(l10n.settingsClearMapTilesDialogBody(_localizedSizeInSentence(l10n, bytes))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.commonClear)),
        ],
      ),
    );
    if (go != true) return;
    await clearMapTileCache();
    ref.invalidate(storageUsageProvider);
  }

  Future<void> _deleteModel(BuildContext context, WidgetRef ref, int bytes) async {
    final l10n = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsDeleteModelDialogTitle),
        content: Text(l10n.settingsDeleteModelDialogBody(_localizedSizeInSentence(l10n, bytes))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.commonDelete)),
        ],
      ),
    );
    if (go != true) return;
    await ref.read(deleteCutoutModelProvider)();
    ref.invalidate(storageUsageProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final usage = kIsWeb ? null : ref.watch(storageUsageProvider);
    final u = usage?.valueOrNull;
    String size(int Function(StorageUsage) of) => usage == null
        ? ''
        : (u == null ? (usage.hasError ? l10n.settingsStorageError : l10n.settingsStorageMeasuring) : _localizedSizeLine(l10n, of(u)));
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.save_alt),
          title: Text(l10n.settingsBackupTitle),
          subtitle: Text(l10n.settingsBackupSubtitle),
          onTap: () => backUpLibrary(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: Text(l10n.settingsRestoreTitle),
          subtitle: Text(l10n.settingsRestoreSubtitle),
          onTap: () => restoreLibrary(context, ref),
        ),
        if (usage != null) ...[
          ListTile(
            key: const Key('settingsYourData'),
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.settingsYourDataTitle),
            trailing: Text(size((u) => u.yourData)),
          ),
          ListTile(
            key: const Key('settingsMapTiles'),
            leading: const Icon(Icons.map_outlined),
            title: Text(l10n.settingsMapTilesTitle),
            subtitle: Text(l10n.settingsMapTilesSubtitle(size((u) => u.mapTiles))),
            trailing: TextButton(
              onPressed: (u == null || u.mapTiles == 0) ? null : () => _clearTiles(context, ref, u.mapTiles),
              child: Text(l10n.commonClear),
            ),
          ),
          if (u != null && u.cutoutModel > 0)
            ListTile(
              key: const Key('settingsCutoutModel'),
              leading: const Icon(Icons.content_cut),
              title: Text(l10n.settingsCutoutModelTitle),
              subtitle: Text(l10n.settingsCutoutModelSubtitle(_localizedSizeLine(l10n, u.cutoutModel))),
              trailing: TextButton(
                onPressed: () => _deleteModel(context, ref, u.cutoutModel),
                child: Text(l10n.commonDelete),
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
    final l10n = context.l10n;
    void open(String url) => ref.read(openLinkProvider)(Uri.parse(url));
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.appTitle),
          subtitle: Text(l10n.settingsVersion(appVersionLabel)),
        ),
        ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(l10n.settingsAboutAnitabiTitle),
          subtitle: Text(l10n.settingsAboutAnitabiSubtitle),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open('https://www.anitabi.cn/'),
        ),
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: Text(l10n.settingsAboutOsmTitle),
          subtitle: Text(l10n.settingsAboutOsmSubtitle),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open('https://www.openstreetmap.org/copyright'),
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: Text(l10n.settingsAboutBangumiTitle),
          subtitle: Text(l10n.settingsAboutBangumiSubtitle),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open('https://bgm.tv/'),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(l10n.settingsPrivacyPolicy),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open(privacyPolicyUrl),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text(l10n.settingsSourceCode),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => open(sourceCodeUrl),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(l10n.settingsOpenSourceLicences),
          onTap: () => showLicensePage(
            context: context,
            applicationName: l10n.appTitle,
            applicationVersion: appVersionLabel,
          ),
        ),
      ],
    );
  }
}
