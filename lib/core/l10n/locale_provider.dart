import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_locale.dart';
import 'locale_store.dart';

/// Platform locale store provider (overridable in widget/unit tests).
final appLocaleStoreProvider = Provider<AppLocaleStore>((ref) => createDefaultAppLocaleStore());

/// Currently active UI language setting ([AppLocaleOption.system] until loaded or chosen).
final appLocaleProvider = NotifierProvider<AppLocaleNotifier, AppLocaleOption>(AppLocaleNotifier.new);

/// Loads and persists the user's UI language preference without allowing slow initial
/// disk reads to overwrite a selection made earlier in the session.
class AppLocaleNotifier extends Notifier<AppLocaleOption> {
  late Future<void> _loaded;
  bool _chosenHere = false;

  @override
  AppLocaleOption build() {
    final store = ref.watch(appLocaleStoreProvider);
    _chosenHere = false;
    _loaded = store.read().then((saved) {
      if (!_chosenHere) state = saved;
    }, onError: (Object _) {});
    return AppLocaleOption.system;
  }

  /// Waits for initial storage load to settle and returns the effective choice.
  Future<AppLocaleOption> current() async {
    await _loaded;
    return state;
  }

  /// Applies [option] immediately and persists it to [appLocaleStoreProvider].
  Future<void> choose(AppLocaleOption option) async {
    _chosenHere = true;
    state = option;
    try {
      await ref.read(appLocaleStoreProvider).write(option);
    } catch (e) {
      debugPrint('[AppLocale] could not save the choice: $e');
    }
  }
}
