import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Goes back, or to [fallback] when this screen is the only page: opened
/// straight from a link (an invite, a reloaded web page) or after joining a
/// trip, where there is nothing to go back to.
///
/// A screen's back guard (a [PopScope] asking before it drops an edit) still
/// runs first.
Future<void> goUp(BuildContext context, String fallback) async {
  if (await Navigator.of(context).maybePop()) return;
  if (context.mounted) context.go(fallback);
}

/// The app bar's back arrow for a screen that may be the only page (see
/// [goUp]). Shown only then; otherwise the app bar's own arrow stays.
///
/// ```dart
/// AppBar(leading: UpButton.ifAlone(context, fallback: '/trips'))
/// ```
class UpButton extends StatelessWidget {
  const UpButton({super.key, required this.fallback});

  /// The page to go to when there is nothing to go back to.
  final String fallback;

  /// An [UpButton] when this screen is the only page, else null.
  static Widget? ifAlone(BuildContext context, {required String fallback}) {
    final router = GoRouter.maybeOf(context);
    return router == null || router.canPop() ? null : UpButton(fallback: fallback);
  }

  @override
  Widget build(BuildContext context) => BackButton(onPressed: () => goUp(context, fallback));
}
