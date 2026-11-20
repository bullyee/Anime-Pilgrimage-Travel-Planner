import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/l10n/app_locale.dart';
import 'package:trip_planner/core/l10n/l10n.dart';
import 'package:trip_planner/core/l10n/locale_provider.dart';
import 'package:trip_planner/core/l10n/locale_store.dart';
import 'package:trip_planner/core/l10n/locale_store_io.dart';

class _DelayedLocaleStore implements AppLocaleStore {
  final Completer<AppLocaleOption> readCompleter = Completer<AppLocaleOption>();
  final List<AppLocaleOption> writes = [];
  bool failWrites = false;

  @override
  Future<AppLocaleOption> read() => readCompleter.future;

  @override
  Future<void> write(AppLocaleOption option) async {
    writes.add(option);
    if (failWrites) throw StateError('disk full');
  }
}

void main() {
  group('AppLocaleOption.fromTag', () {
    test('parses canonical and variant tags cleanly', () {
      expect(AppLocaleOption.fromTag('en'), AppLocaleOption.en);
      expect(AppLocaleOption.fromTag('en-US'), AppLocaleOption.en);
      expect(AppLocaleOption.fromTag('EN_gb'), AppLocaleOption.en);

      expect(AppLocaleOption.fromTag('ja'), AppLocaleOption.ja);
      expect(AppLocaleOption.fromTag('ja-JP'), AppLocaleOption.ja);
      expect(AppLocaleOption.fromTag('JA_jp'), AppLocaleOption.ja);

      expect(AppLocaleOption.fromTag('zh_Hant'), AppLocaleOption.zhHant);
      expect(AppLocaleOption.fromTag('zh-Hant'), AppLocaleOption.zhHant);
      expect(AppLocaleOption.fromTag('zh-Hant-TW'), AppLocaleOption.zhHant);
      expect(AppLocaleOption.fromTag('zh-TW'), AppLocaleOption.zhHant);
      expect(AppLocaleOption.fromTag('zh_HK'), AppLocaleOption.zhHant);
      expect(AppLocaleOption.fromTag('zh-mo'), AppLocaleOption.zhHant);
      expect(AppLocaleOption.fromTag('zh'), AppLocaleOption.zhHant);

      expect(AppLocaleOption.fromTag('system'), AppLocaleOption.system);
    });

    test('falls back safely to system for missing, corrupt, or extreme tags', () {
      expect(AppLocaleOption.fromTag(null), AppLocaleOption.system);
      expect(AppLocaleOption.fromTag(''), AppLocaleOption.system);
      expect(AppLocaleOption.fromTag('   \n  '), AppLocaleOption.system);
      expect(AppLocaleOption.fromTag('fr-FR'), AppLocaleOption.system);
      expect(AppLocaleOption.fromTag('🌍🗾'), AppLocaleOption.system);
      expect(AppLocaleOption.fromTag('unexpected-invalid-tag'), AppLocaleOption.system);
    });
  });

  group('resolveAppLocale', () {
    test('defaults Western and unsupported locales to English', () {
      for (final loc in <Locale?>[
        null,
        const Locale('en'),
        const Locale('en', 'US'),
        const Locale('en', 'GB'),
        const Locale('fr', 'FR'),
        const Locale('de', 'DE'),
        const Locale('es', 'ES'),
        const Locale('ko', 'KR'),
      ]) {
        expect(
          resolveAppLocale(loc, AppLocalizations.supportedLocales),
          const Locale('en'),
          reason: 'Expected English fallback for $loc',
        );
      }
    });

    test('resolves Japanese and Chinese variants accurately', () {
      expect(
        resolveAppLocale(const Locale('ja'), AppLocalizations.supportedLocales),
        const Locale('ja'),
      );
      expect(
        resolveAppLocale(const Locale('ja', 'JP'), AppLocalizations.supportedLocales),
        const Locale('ja'),
      );

      for (final hant in const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
        Locale('zh', 'TW'),
        Locale('zh', 'HK'),
        Locale('zh', 'MO'),
      ]) {
        expect(
          resolveAppLocale(hant, AppLocalizations.supportedLocales),
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          reason: 'Expected zh_Hant for $hant',
        );
      }

      expect(
        resolveAppLocale(const Locale('zh'), AppLocalizations.supportedLocales),
        const Locale('zh'),
      );
      expect(
        resolveAppLocale(const Locale('zh', 'CN'), AppLocalizations.supportedLocales),
        const Locale('zh'),
      );
    });
  });

  group('FileAppLocaleStore', () {
    test('persists across reads and tolerates missing or corrupt files', () async {
      final root = Directory.systemTemp.createTempSync('locale_store_test_');
      addTearDown(() => root.deleteSync(recursive: true));

      final store = FileAppLocaleStore(directory: () async => root);
      expect(await store.read(), AppLocaleOption.system);

      for (final option in AppLocaleOption.values) {
        await store.write(option);
        expect(await store.read(), option);
      }

      File('${root.path}${Platform.pathSeparator}app_locale.txt').writeAsStringSync('💥bad-value');
      expect(await store.read(), AppLocaleOption.system);
    });
  });

  group('AppLocaleNotifier', () {
    test('loads saved locale from store asynchronously', () async {
      final store = InMemoryAppLocaleStore(AppLocaleOption.zhHant);
      final container = ProviderContainer(
        overrides: [appLocaleStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(await container.read(appLocaleProvider.notifier).current(), AppLocaleOption.zhHant);
      expect(container.read(appLocaleProvider), AppLocaleOption.zhHant);
    });

    test('startup read resolving after user choose() does not overwrite choice', () async {
      final delayedStore = _DelayedLocaleStore();
      final container = ProviderContainer(
        overrides: [appLocaleStoreProvider.overrideWithValue(delayedStore)],
      );
      addTearDown(container.dispose);

      // Start initial build before delayed read resolves.
      expect(container.read(appLocaleProvider), AppLocaleOption.system);

      // User picks Japanese before disk read completes.
      await container.read(appLocaleProvider.notifier).choose(AppLocaleOption.ja);
      expect(container.read(appLocaleProvider), AppLocaleOption.ja);

      // Late disk read arrives with stale English value.
      delayedStore.readCompleter.complete(AppLocaleOption.en);
      await container.read(appLocaleProvider.notifier).current();

      expect(container.read(appLocaleProvider), AppLocaleOption.ja);
    });

    test('write failure updates in-memory state cleanly without throwing', () async {
      final failingStore = _DelayedLocaleStore()..failWrites = true;
      failingStore.readCompleter.complete(AppLocaleOption.system);
      final container = ProviderContainer(
        overrides: [appLocaleStoreProvider.overrideWithValue(failingStore)],
      );
      addTearDown(container.dispose);

      await container.read(appLocaleProvider.notifier).choose(AppLocaleOption.zhHant);
      expect(container.read(appLocaleProvider), AppLocaleOption.zhHant);
      expect(failingStore.writes, [AppLocaleOption.zhHant]);
    });
  });

  group('Generated AppLocalizations', () {
    test('provides distinct localized copies and plurals across all supported locales', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final hant = lookupAppLocalizations(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
      final zh = lookupAppLocalizations(const Locale('zh'));
      final ja = lookupAppLocalizations(const Locale('ja'));

      expect(en.navHome, 'Home');
      expect(hant.navHome, '首頁');
      expect(zh.navHome, '首頁');
      expect(ja.navHome, 'ホーム');

      expect(en.settingsDriveRemovalsWaiting(1), contains('One removal is waiting'));
      expect(en.settingsDriveRemovalsWaiting(3), contains('3 removals are waiting'));
      expect(hant.settingsDriveRemovalsWaiting(3), contains('3 項'));
      expect(ja.settingsDriveRemovalsWaiting(3), contains('3 件'));

      expect(en.settingsClearMapTilesDialogBody('12 MB'), contains('12 MB'));
      expect(hant.settingsVersion('0.3.1'), contains('0.3.1'));
    });
  });
}
