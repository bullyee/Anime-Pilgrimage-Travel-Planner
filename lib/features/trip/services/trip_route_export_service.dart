import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/database.dart';
import '../../planner/models/planner_view.dart';

final tripRouteExportServiceProvider = Provider<TripRouteExportService>(
  (ref) => const TripRouteExportService(),
);

final shareRouteFileProvider = Provider<Future<void> Function(TripRouteExportResult result)>(
  (ref) => defaultShareRouteFile,
);

/// Hands a finished route export to the system share sheet or web download.
Future<void> defaultShareRouteFile(TripRouteExportResult result) async {
  if (kIsWeb) {
    final bytes = utf8.encode(result.content);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: result.fileName,
      mimeType: result.mimeType,
    );
    await SharePlus.instance.share(ShareParams(
      files: [xFile],
      subject: result.subject,
      downloadFallbackEnabled: true,
    ));
  } else {
    final tempDir = await getTemporaryDirectory();
    final routesDir = Directory(p.join(tempDir.path, 'routes'));
    if (!routesDir.existsSync()) {
      await routesDir.create(recursive: true);
    }
    final file = File(p.join(routesDir.path, result.fileName));
    await file.writeAsString(result.content, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: result.mimeType)],
      subject: result.subject,
    ));
  }
}

/// Result of exporting a trip's route to a file.
class TripRouteExportResult {
  /// File contents (XML for GPX, JSON for GeoJSON).
  final String content;

  /// Default file name, e.g. `kyoto_pilgrimage-route.gpx`.
  final String fileName;

  /// MIME type of the exported file.
  final String mimeType;

  /// Subject for the system share sheet.
  final String subject;

  /// Number of unique stops included in the export.
  final int stopCount;

  /// Number of unique stops skipped because they had no coordinates.
  final int skippedCount;

  const TripRouteExportResult({
    required this.content,
    required this.fileName,
    required this.mimeType,
    required this.subject,
    required this.stopCount,
    required this.skippedCount,
  });
}

/// Exports a trip's route as standard GPX 1.1 or GeoJSON for external
/// GPS apps (OsmAnd, Organic Maps, Garmin, Google My Maps).
class TripRouteExportService {
  const TripRouteExportService();

  /// Whether [lat] and [lng] form valid non-zero GPS coordinates.
  static bool hasValidCoordinates(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;
    return true;
  }

  /// Turns [title] into a clean file-name slug.
  static String slugify(String title) {
    final clean = title
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fa5\u3040-\u30ff-]'), '')
        .trim()
        .replaceAll(RegExp(r'[\s\u3000]+'), '_');
    return clean.isEmpty ? 'trip' : clean;
  }

  /// Exports [plannerView] to GPX 1.1 format:
  /// - Unique waypoints (`<wpt>`) for each stop with coordinates.
  /// - A route (`<rte>`) for each day preserving the visiting sequence.
  TripRouteExportResult exportGpx({
    required Trip trip,
    required PlannerView plannerView,
    DateTime? exportedAt,
  }) {
    final now = (exportedAt ?? DateTime.now()).toUtc();
    final slug = slugify(trip.title);

    final seenStopIds = <String>{};
    final skippedStopIds = <String>{};
    final waypoints = <String>[];
    final routes = <String>[];

    int dayNumber = 0;
    int backupNumber = 0;
    for (final day in plannerView.days) {
      final String dayLabel;
      final int? currentDayNumber;
      if (day.isBackup) {
        backupNumber++;
        dayLabel = 'Backup Day $backupNumber';
        currentDayNumber = null;
      } else {
        dayNumber++;
        currentDayNumber = dayNumber;
        dayLabel = day.date != null
            ? 'Day $dayNumber (${_formatDateOnly(day.date!)})'
            : 'Day $dayNumber';
      }

      final routePoints = <String>[];
      for (final it in day.items) {
        final stop = it.stop;
        if (!hasValidCoordinates(stop.lat, stop.lng)) {
          skippedStopIds.add(stop.id);
          continue;
        }

        final timeStr = _formatClockTime(it.startMinutes);
        final rawDesc = _stopDescription(stop);
        final rteptDesc = rawDesc != null
            ? 'Planned $timeStr · $rawDesc'
            : 'Planned $timeStr';
        final wptDesc = rawDesc != null
            ? '$dayLabel · Planned $timeStr · $rawDesc'
            : '$dayLabel · Planned $timeStr';

        // Add waypoint once per unique stop id
        if (seenStopIds.add(stop.id)) {
          waypoints.add(_renderWpt(stop, desc: wptDesc));
        }

        // Add route point for this day's sequence
        routePoints.add(_renderRtept(stop, desc: rteptDesc));
      }

      if (routePoints.isNotEmpty) {
        final buf = StringBuffer();
        buf.writeln('    <rte>');
        buf.writeln('      <name>${_xmlEscape(dayLabel)}</name>');
        if (currentDayNumber != null) {
          buf.writeln('      <number>$currentDayNumber</number>');
        }
        for (final pt in routePoints) {
          buf.writeln(pt);
        }
        buf.write('    </rte>');
        routes.add(buf.toString());
      }
    }

    // Process any backlog stops not yet assigned to days
    for (final stop in plannerView.backlog) {
      if (!hasValidCoordinates(stop.lat, stop.lng)) {
        skippedStopIds.add(stop.id);
        continue;
      }
      if (seenStopIds.add(stop.id)) {
        waypoints.add(_renderWpt(stop, desc: _stopDescription(stop)));
      }
    }

    final xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xml.writeln(
      '<gpx version="1.1" creator="Trip Planner" '
      'xmlns="http://www.topografix.com/GPX/1/1" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 '
      'http://www.topografix.com/GPX/1/1/gpx.xsd">',
    );
    xml.writeln('  <metadata>');
    xml.writeln('    <name>${_xmlEscape(trip.title)}</name>');
    if (trip.description != null && trip.description!.trim().isNotEmpty) {
      xml.writeln('    <desc>${_xmlEscape(trip.description!.trim())}</desc>');
    }
    xml.writeln('    <time>${now.toIso8601String()}</time>');
    xml.writeln('  </metadata>');

    for (final wpt in waypoints) {
      xml.writeln(wpt);
    }
    for (final rte in routes) {
      xml.writeln(rte);
    }

    xml.write('</gpx>');

    return TripRouteExportResult(
      content: xml.toString(),
      fileName: '$slug-route.gpx',
      mimeType: 'application/gpx+xml',
      subject: '${trip.title} Route (GPX)',
      stopCount: seenStopIds.length,
      skippedCount: skippedStopIds.length,
    );
  }

  /// Exports [plannerView] to GeoJSON FeatureCollection format:
  /// Each stop with coordinates becomes a Point feature with metadata.
  TripRouteExportResult exportGeoJson({
    required Trip trip,
    required PlannerView plannerView,
  }) {
    final slug = slugify(trip.title);
    final features = <Map<String, dynamic>>[];
    final seenStopIds = <String>{};
    final skippedStopIds = <String>{};

    int dayNumber = 0;
    for (final day in plannerView.days) {
      final int? currentDayNumber;
      if (day.isBackup) {
        currentDayNumber = null;
      } else {
        dayNumber++;
        currentDayNumber = dayNumber;
      }

      int order = 0;
      for (final it in day.items) {
        order++;
        final stop = it.stop;
        if (!hasValidCoordinates(stop.lat, stop.lng)) {
          skippedStopIds.add(stop.id);
          continue;
        }

        seenStopIds.add(stop.id);
        final timeStr = _formatClockTime(it.startMinutes);
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            // GeoJSON coordinates are [longitude, latitude]
            'coordinates': [stop.lng, stop.lat],
          },
          'properties': {
            'day': currentDayNumber,
            if (day.isBackup) 'backup': true,
            'order': order,
            'name': stop.name,
            if (day.date != null) 'date': _formatDateOnly(day.date!),
            'time': timeStr,
            if (stop.note != null && stop.note!.trim().isNotEmpty)
              'notes': stop.note!.trim(),
            if (stop.address != null && stop.address!.trim().isNotEmpty)
              'address': stop.address!.trim(),
          },
        });
      }
    }

    // Include backlog stops with day = null
    int backlogOrder = 0;
    for (final stop in plannerView.backlog) {
      backlogOrder++;
      if (!hasValidCoordinates(stop.lat, stop.lng)) {
        skippedStopIds.add(stop.id);
        continue;
      }
      seenStopIds.add(stop.id);
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [stop.lng, stop.lat],
        },
        'properties': {
          'day': null,
          'order': backlogOrder,
          'name': stop.name,
          if (stop.note != null && stop.note!.trim().isNotEmpty)
            'notes': stop.note!.trim(),
          if (stop.address != null && stop.address!.trim().isNotEmpty)
            'address': stop.address!.trim(),
        },
      });
    }

    final collection = {
      'type': 'FeatureCollection',
      'name': trip.title,
      'features': features,
    };

    return TripRouteExportResult(
      content: const JsonEncoder.withIndent('  ').convert(collection),
      fileName: '$slug-route.geojson',
      mimeType: 'application/geo+json',
      subject: '${trip.title} Route (GeoJSON)',
      stopCount: seenStopIds.length,
      skippedCount: skippedStopIds.length,
    );
  }

  static String _renderWpt(Stop stop, {String? desc}) {
    final buf = StringBuffer();
    buf.writeln('  <wpt lat="${stop.lat}" lon="${stop.lng}">');
    buf.writeln('    <name>${_xmlEscape(stop.name)}</name>');
    if (desc != null && desc.isNotEmpty) buf.writeln('    <desc>${_xmlEscape(desc)}</desc>');
    buf.write('  </wpt>');
    return buf.toString();
  }

  static String _renderRtept(Stop stop, {String? desc}) {
    final buf = StringBuffer();
    buf.writeln('      <rtept lat="${stop.lat}" lon="${stop.lng}">');
    buf.writeln('        <name>${_xmlEscape(stop.name)}</name>');
    if (desc != null && desc.isNotEmpty) buf.writeln('        <desc>${_xmlEscape(desc)}</desc>');
    buf.write('      </rtept>');
    return buf.toString();
  }

  static String? _stopDescription(Stop stop) {
    final note = stop.note?.trim();
    if (note != null && note.isNotEmpty) return note;
    final addr = stop.address?.trim();
    if (addr != null && addr.isNotEmpty) return addr;
    final desc = stop.description?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return null;
  }

  static String _formatClockTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatDateOnly(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
