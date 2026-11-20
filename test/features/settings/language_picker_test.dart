import 'dart:io';

import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/l10n/app_locale.dart';
import 'package:trip_planner/core/l10n/l10n.dart';
import 'package:trip_planner/core/l10n/locale_provider.dart';
import 'package:trip_planner/core/l10n/locale_store.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/core/router/app_frame.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/camera/services/anime_camera_launcher.dart';
import 'package:trip_planner/features/settings/screens/settings_screen.dart';
import 'package:trip_planner/features/settings/services/storage_usage.dart';
import 'package:trip_planner/features/sync/providers/drive_cleanup_providers.dart';
import 'package:trip_planner/features/sync/providers/drive_upload_quality_provider.dart';
import 'package:trip_planner/features/sync/services/drive_upload_quality.dart';

class _ShellHarness extends ConsumerWidget {
  const _ShellHarness({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = ref.watch(appLocaleProvider);
    return MaterialApp.router(
      locale: appLocale.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: resolveAppLocale,
      routerConfig: router,
    );
  }
}

void main() {
  late AppDatabase db;
  late InMemoryAppLocaleStore localeStore;
  late Directory tmpDir;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    localeStore = InMemoryAppLocaleStore();
    tmpDir = Directory.systemTemp.createTempSync('lang_picker_test_');
    debugAnimeCameraSupportedOverride = true;
  });

  tearDown(() async {
    debugAnimeCameraSupportedOverride = null;
    await db.close();
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => AppFrame(shell: shell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: FilledButton(
                        onPressed: () => context.push('/settings'),
                        child: const Text('Open Settings'),
                      ),
                    ),
                  ),
                ),
              ]),
              StatefulShellBranch(routes: [GoRoute(path: '/trips', builder: (_, _) => const SizedBox())]),
              StatefulShellBranch(routes: [GoRoute(path: '/library', builder: (_, _) => const SizedBox())]),
              StatefulShellBranch(routes: [GoRoute(path: '/photos', builder: (_, _) => const SizedBox())]),
            ],
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      );

  testWidgets('changing language updates Settings and bottom navigation live and persists choice', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final qualityFile = File(p.join(tmpDir.path, 'quality.txt'));
    final qualityStore = FileDriveUploadQualityStore(directory: () async => qualityFile.parent);
    final router = buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appLocaleStoreProvider.overrideWithValue(localeStore),
          authStateChangesProvider.overrideWith((ref) => Stream<User?>.value(null)),
          storageUsageProvider.overrideWith((ref) async => const StorageUsage(total: 0, mapTiles: 0, cutoutModel: 0)),
          driveRemovalsWaitingProvider.overrideWith((ref) => Stream.value(0)),
          driveUploadQualityStoreProvider.overrideWithValue(qualityStore),
        ],
        child: _ShellHarness(router: router),
      ),
    );
    await tester.pumpAndSettle();

    // Default test locale resolves to English.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.byTooltip('Shoot'), findsOneWidget);

    // Open Settings and pick Traditional Chinese.
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('settingsLanguage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsLanguage')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.text('System default')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('English')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('繁體中文')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('日本語')), findsOneWidget);

    await tester.tap(find.byKey(const Key('appLocale-zhHant')));
    await tester.pumpAndSettle();
    expect(localeStore.value, AppLocaleOption.zhHant);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('settingsLanguage')), matching: find.text('繁體中文')), findsOneWidget);

    // Pop back to AppFrame and confirm bottom nav labels updated to Traditional Chinese.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('首頁'), findsOneWidget);
    expect(find.text('行程'), findsOneWidget);
    expect(find.text('景點庫'), findsOneWidget);
    expect(find.text('相片'), findsOneWidget);
    expect(find.byTooltip('拍攝'), findsOneWidget);

    // Re-open Settings and switch to Japanese.
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settingsLanguage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsLanguage')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('appLocale-ja')));
    await tester.pumpAndSettle();
    expect(localeStore.value, AppLocaleOption.ja);

    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('settingsLanguage')), matching: find.text('日本語')), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('ライブラリ'), findsOneWidget);
    expect(find.text('写真'), findsOneWidget);
    expect(find.byTooltip('撮影'), findsOneWidget);

    // Switch back to English cleanly.
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settingsLanguage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsLanguage')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('appLocale-en')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(localeStore.value, AppLocaleOption.en);
    expect(find.text('Settings'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.byTooltip('Shoot'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
