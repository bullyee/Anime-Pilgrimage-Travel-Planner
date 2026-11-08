import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Dart side of the `trip_planner/overlay` channel (`MainActivity.kt` and
/// `ReferenceOverlay.kt`): floats the anime reference in a small draggable
/// window over the phone's own camera app.
///
/// Android only — drawing over another app isn't possible on iOS, so every
/// method is a no-op elsewhere and [isSupported] is false.
class CameraOverlay {
  static const MethodChannel _channel = MethodChannel('trip_planner/overlay');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Whether "Display over other apps" is granted (always true below
  /// Android 6).
  static Future<bool> canDrawOverlays() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
  }

  /// Opens the system "Display over other apps" screen for this app. Returns
  /// right away — the user grants it there, so check [canDrawOverlays] again
  /// on the next attempt.
  static Future<void> requestPermission() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('requestPermission');
  }

  /// Shows the image at [path] in the floating window at [opacity] (0..1).
  /// Returns false when it couldn't be shown (no permission, or an image
  /// that won't decode).
  ///
  /// With [followCamera] (the camera flow), the window hides while the user
  /// is in another app and comes back with the camera. Without it, the
  /// window stays up over every app until closed (double-tap, or [hide]).
  static Future<bool> show(
    String path, {
    double opacity = 0.6,
    bool followCamera = true,
  }) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('showOverlay', {
            'path': path,
            'opacity': opacity,
            'followCamera': followCamera,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Removes the floating window. Safe to call when nothing is showing.
  static Future<void> hide() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('hideOverlay');
    } on PlatformException {
      // Already gone.
    }
  }
}
