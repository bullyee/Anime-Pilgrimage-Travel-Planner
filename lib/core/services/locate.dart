import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Why the phone's position isn't known.
enum LocateProblem {
  /// Location is turned off on the device.
  serviceOff,

  /// The user said no; asking again may still work.
  denied,

  /// The user said no for good: only the app's settings can change it.
  deniedForever,

  /// No fix came in time, and there was no recent one to fall back on.
  noFix,
}

/// Where the phone is, or why that isn't known.
class LocateResult {
  final Position? position;
  final LocateProblem? problem;

  const LocateResult.found(Position this.position) : problem = null;

  const LocateResult.failed(LocateProblem this.problem) : position = null;
}

/// Finds where the phone is once, asking for the location permission if it
/// hasn't been asked yet.
///
/// It asks for a fresh fix, since the cached one can be from wherever the
/// phone was hours ago, and falls back to the cached one only if none comes
/// within [timeLimit] and the cached one isn't older than [maxCachedAge]
/// (any age when null).
Future<LocateResult> locateOnce({Duration timeLimit = const Duration(seconds: 8), Duration? maxCachedAge}) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return const LocateResult.failed(LocateProblem.serviceOff);
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.deniedForever) {
    return const LocateResult.failed(LocateProblem.deniedForever);
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
    return const LocateResult.failed(LocateProblem.denied);
  }
  try {
    return LocateResult.found(
      await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeLimit),
      ),
    );
  } on TimeoutException {
    final cached = await Geolocator.getLastKnownPosition();
    if (cached == null) return const LocateResult.failed(LocateProblem.noFix);
    if (maxCachedAge != null && DateTime.now().difference(cached.timestamp) > maxCachedAge) {
      return const LocateResult.failed(LocateProblem.noFix);
    }
    return LocateResult.found(cached);
  }
}

/// [locateOnce], swappable in tests.
final locateProvider = Provider<Future<LocateResult> Function()>(
  (ref) =>
      () => locateOnce(maxCachedAge: const Duration(minutes: 5)),
);
