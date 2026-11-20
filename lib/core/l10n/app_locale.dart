import 'dart:ui' show Locale;

/// Supported UI language choices in Settings.
///
/// [system] follows the device/browser locale (resolved via [resolveAppLocale]),
/// falling back to [en] for any unsupported language (Western market default).
enum AppLocaleOption {
  system(tag: 'system', locale: null),
  en(tag: 'en', locale: Locale('en'), nativeLabel: 'English'),
  zhHant(
    tag: 'zh_Hant',
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    nativeLabel: '繁體中文',
  ),
  ja(tag: 'ja', locale: Locale('ja'), nativeLabel: '日本語');

  const AppLocaleOption({
    required this.tag,
    required this.locale,
    this.nativeLabel,
  });

  /// Persisted storage identifier (e.g. `'system'`, `'en'`, `'zh_Hant'`, `'ja'`).
  final String tag;

  /// Explicit Flutter [Locale] to force, or `null` to follow the OS/browser.
  final Locale? locale;

  /// Native display name shown in the picker so users can always recognize it.
  final String? nativeLabel;

  /// Parses a stored language tag; returns [system] for missing or unknown values.
  static AppLocaleOption fromTag(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return system;
    final norm = trimmed.replaceAll('-', '_').toLowerCase();
    if (norm == 'en' || norm.startsWith('en_')) return en;
    if (norm == 'ja' || norm.startsWith('ja_')) return ja;
    if (norm == 'zh_hant' ||
        norm.startsWith('zh_hant_') ||
        norm == 'zh_tw' ||
        norm == 'zh_hk' ||
        norm == 'zh_mo' ||
        norm == 'zh') {
      return zhHant;
    }
    return system;
  }
}

/// Resolves [deviceLocale] against supported app locales (`en`, `zh_Hant`, `zh`, `ja`).
///
/// Unsupported locales (e.g. European/other languages) fall back to English (`en`)
/// to serve the primary Western release market cleanly.
Locale resolveAppLocale(Locale? deviceLocale, Iterable<Locale> supportedLocales) {
  if (deviceLocale == null) return const Locale('en');
  final lang = deviceLocale.languageCode.toLowerCase();
  if (lang == 'ja') return const Locale('ja');
  if (lang == 'zh') {
    final script = deviceLocale.scriptCode?.toLowerCase();
    final country = deviceLocale.countryCode?.toLowerCase();
    if (script == 'hant' || country == 'tw' || country == 'hk' || country == 'mo') {
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    }
    return const Locale('zh');
  }
  return const Locale('en');
}
