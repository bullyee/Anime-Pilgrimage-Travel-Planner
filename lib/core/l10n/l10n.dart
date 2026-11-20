import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// Convenient access to generated [AppLocalizations] from any [BuildContext].
///
/// Falls back to English (`en`) when rendered inside an isolated widget tree
/// or test harness without localization delegates installed.
extension AppL10nX on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('en'));
}
