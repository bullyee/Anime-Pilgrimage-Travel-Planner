import 'package:flutter/foundation.dart';

/// Geographic coordinate point with optional elevation and timestamp.
@immutable
class GeoPoint {
  final double lat;
  final double lng;
  final double? elevation;
  final DateTime? time;

  const GeoPoint({
    required this.lat,
    required this.lng,
    this.elevation,
    this.time,
  });

  bool get isValid => lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          elevation == other.elevation &&
          time == other.time;

  @override
  int get hashCode => Object.hash(lat, lng, elevation, time);

  @override
  String toString() => 'GeoPoint(lat: $lat, lng: $lng, ele: $elevation, time: $time)';
}

/// A GPX Waypoint element (`<wpt>`, `<rtept>`, or `<trkpt>`).
@immutable
class GpxWaypoint {
  final double lat;
  final double lng;
  final double? elevation;
  final DateTime? time;
  final String? name;
  final String? description;
  final String? comment;
  final String? symbol;
  final String? source;
  final Map<String, String> extensions;

  const GpxWaypoint({
    required this.lat,
    required this.lng,
    this.elevation,
    this.time,
    this.name,
    this.description,
    this.comment,
    this.symbol,
    this.source,
    this.extensions = const {},
  });

  bool get isValid => lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;

  GpxWaypoint copyWith({
    double? lat,
    double? lng,
    double? elevation,
    DateTime? time,
    String? name,
    String? description,
    String? comment,
    String? symbol,
    String? source,
    Map<String, String>? extensions,
  }) {
    return GpxWaypoint(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      elevation: elevation ?? this.elevation,
      time: time ?? this.time,
      name: name ?? this.name,
      description: description ?? this.description,
      comment: comment ?? this.comment,
      symbol: symbol ?? this.symbol,
      source: source ?? this.source,
      extensions: extensions ?? this.extensions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpxWaypoint &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          elevation == other.elevation &&
          time == other.time &&
          name == other.name &&
          description == other.description &&
          comment == other.comment &&
          symbol == other.symbol &&
          source == other.source &&
          mapEquals(extensions, other.extensions);

  @override
  int get hashCode => Object.hash(
        lat,
        lng,
        elevation,
        time,
        name,
        description,
        comment,
        symbol,
        source,
      );

  @override
  String toString() =>
      'GpxWaypoint(name: $name, lat: $lat, lng: $lng, ele: $elevation, time: $time)';
}

/// A GPX Route element (`<rte>`).
@immutable
class GpxRoute {
  final String? name;
  final String? description;
  final String? number;
  final List<GpxWaypoint> points;

  const GpxRoute({
    this.name,
    this.description,
    this.number,
    this.points = const [],
  });
}

/// A GPX Track Segment element (`<trkseg>`).
@immutable
class GpxTrackSegment {
  final List<GpxWaypoint> points;

  const GpxTrackSegment({
    this.points = const [],
  });
}

/// A GPX Track element (`<trk>`).
@immutable
class GpxTrack {
  final String? name;
  final String? description;
  final List<GpxTrackSegment> segments;

  const GpxTrack({
    this.name,
    this.description,
    this.segments = const [],
  });
}

/// A complete GPX Document (`<gpx>`).
@immutable
class GpxDocument {
  final String? name;
  final String? description;
  final String? author;
  final String creator;
  final DateTime? time;
  final List<GpxWaypoint> waypoints;
  final List<GpxRoute> routes;
  final List<GpxTrack> tracks;

  const GpxDocument({
    this.name,
    this.description,
    this.author,
    this.creator = 'Anime Pilgrimage Travel Planner',
    this.time,
    this.waypoints = const [],
    this.routes = const [],
    this.tracks = const [],
  });

  /// Flattened list of all points in the document.
  List<GpxWaypoint> get allPoints {
    final list = <GpxWaypoint>[...waypoints];
    for (final r in routes) {
      list.addAll(r.points);
    }
    for (final t in tracks) {
      for (final seg in t.segments) {
        list.addAll(seg.points);
      }
    }
    return list;
  }
}

/// A KML Placemark element (`<Placemark>`).
@immutable
class KmlPlacemark {
  final String? id;
  final String name;
  final String? description;
  final double lat;
  final double lng;
  final double? elevation;
  final String? styleUrl;
  final Map<String, String> extendedData;

  const KmlPlacemark({
    this.id,
    required this.name,
    this.description,
    required this.lat,
    required this.lng,
    this.elevation,
    this.styleUrl,
    this.extendedData = const {},
  });

  bool get isValid => lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KmlPlacemark &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          lat == other.lat &&
          lng == other.lng &&
          elevation == other.elevation &&
          styleUrl == other.styleUrl &&
          mapEquals(extendedData, other.extendedData);

  @override
  int get hashCode => Object.hash(id, name, description, lat, lng, elevation, styleUrl);

  @override
  String toString() => 'KmlPlacemark(name: $name, lat: $lat, lng: $lng)';
}

/// A KML LineString path (`<LineString>`).
@immutable
class KmlLineString {
  final String? name;
  final String? description;
  final List<GeoPoint> coordinates;
  final String? styleUrl;

  const KmlLineString({
    this.name,
    this.description,
    this.coordinates = const [],
    this.styleUrl,
  });
}

/// A KML Folder element (`<Folder>`).
@immutable
class KmlFolder {
  final String name;
  final String? description;
  final List<KmlPlacemark> placemarks;
  final List<KmlLineString> paths;

  const KmlFolder({
    required this.name,
    this.description,
    this.placemarks = const [],
    this.paths = const [],
  });
}

/// A complete KML Document (`<kml>`).
@immutable
class KmlDocument {
  final String name;
  final String? description;
  final List<KmlFolder> folders;
  final List<KmlPlacemark> standalonePlacemarks;
  final List<KmlLineString> standalonePaths;

  const KmlDocument({
    required this.name,
    this.description,
    this.folders = const [],
    this.standalonePlacemarks = const [],
    this.standalonePaths = const [],
  });

  /// Flattened list of all placemarks in the document.
  List<KmlPlacemark> get allPlacemarks {
    final list = <KmlPlacemark>[...standalonePlacemarks];
    for (final f in folders) {
      list.addAll(f.placemarks);
    }
    return list;
  }
}

/// Result of importing GPX or KML points into a trip.
@immutable
class PorterImportResult {
  final int importedCount;
  final int skippedCount;
  final List<String> createdStopIds;
  final List<String> createdPlaceKeys;
  final List<String> errors;

  const PorterImportResult({
    required this.importedCount,
    required this.skippedCount,
    this.createdStopIds = const [],
    this.createdPlaceKeys = const [],
    this.errors = const [],
  });
}
