import 'package:flutter/material.dart';

/// How long a deletion's Undo stays on screen.
const undoDuration = Duration(seconds: 6);

/// Says something was deleted, with Undo, in place of whatever SnackBar is
/// showing or waiting. It goes away by itself after [undoDuration]: a
/// SnackBar with an action would otherwise stay until dismissed, holding
/// back the ones after it. Its `closed` future says whether Undo was tapped
/// (`SnackBarClosedReason.action`).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndoSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  required VoidCallback onUndo,
}) {
  messenger.clearSnackBars();
  return messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: undoDuration,
    persist: false,
    action: SnackBarAction(label: 'Undo', onPressed: onUndo),
  ));
}
