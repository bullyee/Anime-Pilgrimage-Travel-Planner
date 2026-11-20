import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_provider.dart';

/// UI language choices rendered as radio tiles; selections take effect and persist immediately.
class LanguageOptions extends ConsumerWidget {
  const LanguageOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(appLocaleProvider);
    return RadioGroup<AppLocaleOption>(
      groupValue: selected,
      onChanged: (option) {
        if (option != null) ref.read(appLocaleProvider.notifier).choose(option);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in AppLocaleOption.values)
            RadioListTile<AppLocaleOption>(
              key: ValueKey('appLocale-${option.name}'),
              value: option,
              contentPadding: EdgeInsets.zero,
              title: Text(option.nativeLabel ?? l10n.settingsLanguageSystem),
              subtitle: option == AppLocaleOption.system
                  ? Text(l10n.settingsLanguageSystemSubtitle)
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Settings -> Language dialog.
Future<void> showLanguagePicker(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.settingsLanguageDialogTitle),
        content: const SingleChildScrollView(
          child: LanguageOptions(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonDone),
          ),
        ],
      );
    },
  );
}
