import 'app_locale.dart';
import 'locale_store_io.dart'
    if (dart.library.js_interop) 'locale_store_web.dart' as platform_store;

/// Persists the user's chosen UI language across app restarts.
abstract class AppLocaleStore {
  Future<AppLocaleOption> read();
  Future<void> write(AppLocaleOption option);
}

/// In-memory locale store for tests and isolated environments.
class InMemoryAppLocaleStore implements AppLocaleStore {
  InMemoryAppLocaleStore([this.value = AppLocaleOption.system]);

  AppLocaleOption value;

  @override
  Future<AppLocaleOption> read() async => value;

  @override
  Future<void> write(AppLocaleOption option) async => value = option;
}

/// Creates the platform-appropriate persistent locale store (IO file or Web localStorage).
AppLocaleStore createDefaultAppLocaleStore() => platform_store.createPlatformAppLocaleStore();
