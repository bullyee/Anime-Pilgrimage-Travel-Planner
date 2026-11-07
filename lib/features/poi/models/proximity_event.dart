/// Represents an entry or exit proximity event when the user nears an anime pilgrimage spot.
enum ProximityEventType {
  enter,
  exit,
}

/// Configuration settings for the pilgrimage geofence engine.
class GeofenceConfig {
  /// Proximity radius in meters to trigger an 'enter' event (default 50m).
  final double enterRadiusMeters;

  /// Proximity radius in meters to trigger an 'exit' event (default 75m).
  /// Must be >= [enterRadiusMeters] to provide a hysteresis buffer against GPS jitter.
  final double exitRadiusMeters;

  /// Cooldown before re-alerting an enter event for the same spot (default 30 mins).
  final Duration cooldownDuration;

  const GeofenceConfig({
    this.enterRadiusMeters = 50.0,
    this.exitRadiusMeters = 75.0,
    this.cooldownDuration = const Duration(minutes: 30),
  }) : assert(exitRadiusMeters >= enterRadiusMeters,
            'exitRadiusMeters must be >= enterRadiusMeters for hysteresis');
}

/// An emitted proximity event containing detailed location and scene context.
class ProximityEvent {
  final ProximityEventType eventType;
  final String stopId;
  final String placeKey;
  final String stopName;
  final double distanceMeters;
  final double bearingDegrees;
  final String bearingCompass;
  final String? animeName;
  final String? coverUrl;
  final double stopLat;
  final double stopLng;
  final double userLat;
  final double userLng;
  final DateTime timestamp;

  const ProximityEvent({
    required this.eventType,
    required this.stopId,
    required this.placeKey,
    required this.stopName,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.bearingCompass,
    this.animeName,
    this.coverUrl,
    required this.stopLat,
    required this.stopLng,
    required this.userLat,
    required this.userLng,
    required this.timestamp,
  });

  bool get isEnter => eventType == ProximityEventType.enter;
  bool get isExit => eventType == ProximityEventType.exit;

  @override
  String toString() =>
      'ProximityEvent(${eventType.name}: $stopName, ${(distanceMeters).toStringAsFixed(1)}m, $bearingCompass)';
}

/// Internal tracked state for a single geofenced stop.
class TrackedStopState {
  final String stopId;
  final String placeKey;
  final String stopName;
  final double lat;
  final double lng;
  final String? animeName;
  final String? coverUrl;

  bool isInside;
  DateTime? lastEnteredAt;
  DateTime? lastExitedAt;

  TrackedStopState({
    required this.stopId,
    required this.placeKey,
    required this.stopName,
    required this.lat,
    required this.lng,
    this.animeName,
    this.coverUrl,
    this.isInside = false,
    this.lastEnteredAt,
    this.lastExitedAt,
  });
}
