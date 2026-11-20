import 'package:web/web.dart' as web;

import 'app_locale.dart';
import 'locale_store.dart';

const _localeStorageKey = 'trip_planner_locale';

/// Stores the UI language preference in browser `localStorage`, falling back
/// to an in-memory value when storage access is blocked (e.g. private tabs).
class WebAppLocaleStore implements AppLocaleStore {
  AppLocaleOption _fallback = AppLocaleOption.system;

  @override
  Future<AppLocaleOption> read() async {
    try {
      final saved = web.window.localStorage.getItem(_localeStorageKey);
      if (saved == null) return _fallback;
      final parsed = AppLocaleOption.fromTag(saved);
      _fallback = parsed;
      return parsed;
    } catch (_) {
      return _fallback;
    }
  }

  @override
  Future<void> write(AppLocaleOption option) async {
    _fallback = option;
    try {
      web.window.localStorage.setItem(_localeStorageKey, option.tag);
    } catch (_) {
      // Ignore storage quota / private-browsing exceptions; in-memory state stays updated.
    }
  }
}

AppLocaleStore createPlatformAppLocaleStore() => WebAppLocaleStore();
