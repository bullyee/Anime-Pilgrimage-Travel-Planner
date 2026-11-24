import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

/// Follows the user's position for a page that shows distances, while the
/// app is in front: it asks for the permission when [start] is first called
/// (the page opening), never again after a refusal, and stops while the app
/// is in the background. Without a position (no permission, no service, a
/// desktop or a test) [position] stays null and the page works without it.
class PositionFollower extends ValueNotifier<Position?> with WidgetsBindingObserver {
  StreamSubscription<Position>? _sub;
  bool _paused = false;
  bool _disposed = false;

  /// Asked for the permission already: a refusal isn't asked again, even
  /// when the app comes back to the front (which closing the prompt does).
  bool _asked = false;

  /// A [start] is between its awaits: another one waits for nothing.
  bool _starting = false;

  PositionFollower() : super(null) {
    WidgetsBinding.instance.addObserver(this);
  }

  Position? get position => value;

  /// Starts following, unless it already does or was paused for a camera.
  Future<void> start() async {
    if (_sub != null || _paused || _disposed || _starting) return;
    _starting = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && !_asked) {
        _asked = true;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      if (_disposed || _paused || _sub != null) return;
      // The browser has no last position (the web plugin throws), and the
      // stream below still works there.
      if (!kIsWeb) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null && !_disposed) value = last;
        } catch (_) {}
      }
      if (_disposed || _paused || _sub != null) return;
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen(
        (pos) {
          if (!_disposed) value = pos;
        },
        onError: (_) {},
      );
    } catch (_) {
      // No geolocation here (desktop, tests): distances stay hidden.
    } finally {
      _starting = false;
    }
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// Stops while something else has the screen (the camera), until [resume].
  void pause() {
    _paused = true;
    _stop();
  }

  void resume() {
    _paused = false;
    start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stop();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }
}
