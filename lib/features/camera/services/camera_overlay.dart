import 'dart:async';
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
  /// window stays up over every app until closed (its ✕, or [hide]); a
  /// double-tap shrinks it to a dot.
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

  /// Shows [paths], frames of one spot, in the floating window over the
  /// camera, starting on [index]. With more than one, ‹ › in the window's bar
  /// switch between them in place, and each switch is reported on
  /// [frameChanges]. With [keepPlacement] the window comes back where the
  /// last camera window was, at the same size and opacity (for the next
  /// round of the same series); otherwise it starts small near the top.
  static Future<bool> showFrames(
    List<String> paths, {
    int index = 0,
    double opacity = 0.6,
    bool keepPlacement = false,
  }) async {
    if (!isSupported || paths.isEmpty) return false;
    _listen();
    try {
      return await _channel.invokeMethod<bool>('showOverlay', {
            'paths': paths,
            'index': index,
            'opacity': opacity,
            'followCamera': true,
            'keepPlacement': keepPlacement,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static final _frameChanges = StreamController<int>.broadcast();
  static var _listening = false;

  /// The frame the window switched to, as an index into the paths given to
  /// [showFrames], each time the user switches.
  static Stream<int> get frameChanges => _frameChanges.stream;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'frameChanged' && call.arguments is int) {
        _frameChanges.add(call.arguments as int);
      }
    });
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

/// The floating window as the shots screen uses it, so tests can stand in
/// for the platform side.
abstract class ReferenceWindow {
  const ReferenceWindow();

  /// Whether the window may be shown ("Display over other apps").
  Future<bool> canShow();

  /// See [CameraOverlay.showFrames].
  Future<bool> show(List<String> paths, {int index = 0, bool keepPlacement = false});

  Future<void> hide();

  /// See [CameraOverlay.frameChanges].
  Stream<int> get frameChanges;
}

/// [ReferenceWindow] over the phone's camera app, through [CameraOverlay].
class CameraOverlayWindow extends ReferenceWindow {
  const CameraOverlayWindow();

  @override
  Future<bool> canShow() => CameraOverlay.canDrawOverlays();

  @override
  Future<bool> show(List<String> paths, {int index = 0, bool keepPlacement = false}) =>
      CameraOverlay.showFrames(paths, index: index, keepPlacement: keepPlacement);

  @override
  Future<void> hide() => CameraOverlay.hide();

  @override
  Stream<int> get frameChanges => CameraOverlay.frameChanges;
}
