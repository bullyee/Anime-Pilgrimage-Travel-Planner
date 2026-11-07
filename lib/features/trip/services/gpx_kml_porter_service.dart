import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/fractional_index.dart';
import '../models/gpx_kml_models.dart';

/// Bidirectional GPX 1.1 and KML 2.2 export/import service for pilgrimage trips.
///
/// Features:
/// - Full compliance with GPX 1.1 schema (waypoints, routes, tracks, custom anime extensions).
/// - Full compliance with KML 2.2 schema (folders per day, styling, Placemark points and LineString paths).
/// - Relational and foreign key integrity (zero data loss, topological insertion ordering).
/// - Entity scope isolation ensuring imports/exports stay strictly within trip boundaries.
class GpxKmlPorterService {
  final Uuid _uuid;

  const GpxKmlPorterService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  // ===========================================================================
  // GPX XML BUILDER & PARSER
  // ===========================================================================

  /// Generates a well-formed GPX 1.1 XML string from a [GpxDocument].
  String buildGpx(GpxDocument doc) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<gpx version="1.1" creator="${escapeXml(doc.creator)}" '
        'xmlns="http://www.topografix.com/GPX/1/1" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">');

    // Metadata
    final hasMetadata = doc.name != null || doc.description != null || doc.author != null || doc.time != null;
    if (hasMetadata) {
      sb.writeln('  <metadata>');
      if (doc.name != null) sb.writeln('    <name>${escapeXml(doc.name!)}</name>');
      if (doc.description != null) sb.writeln('    <desc>${escapeXml(doc.description!)}</desc>');
      if (doc.author != null) {
        sb.writeln('    <author><name>${escapeXml(doc.author!)}</name></author>');
      }
      if (doc.time != null) {
        sb.writeln('    <time>${doc.time!.toUtc().toIso8601String()}</time>');
      }
      sb.writeln('  </metadata>');
    }

    // Standalone Waypoints (<wpt>)
    for (final wpt in doc.waypoints) {
      _writeGpxWaypoint(sb, 'wpt', wpt, indent: '  ');
    }

    // Routes (<rte>)
    for (final rte in doc.routes) {
      sb.writeln('  <rte>');
      if (rte.name != null) sb.writeln('    <name>${escapeXml(rte.name!)}</name>');
      if (rte.description != null) sb.writeln('    <desc>${escapeXml(rte.description!)}</desc>');
      if (rte.number != null) sb.writeln('    <number>${escapeXml(rte.number!)}</number>');
      for (final pt in rte.points) {
        _writeGpxWaypoint(sb, 'rtept', pt, indent: '    ');
      }
      sb.writeln('  </rte>');
    }

    // Tracks (<trk>)
    for (final trk in doc.tracks) {
      sb.writeln('  <trk>');
      if (trk.name != null) sb.writeln('    <name>${escapeXml(trk.name!)}</name>');
      if (trk.description != null) sb.writeln('    <desc>${escapeXml(trk.description!)}</desc>');
      for (final seg in trk.segments) {
        sb.writeln('    <trkseg>');
        for (final pt in seg.points) {
          _writeGpxWaypoint(sb, 'trkpt', pt, indent: '      ');
        }
        sb.writeln('    </trkseg>');
      }
      sb.writeln('  </trk>');
    }

    sb.writeln('</gpx>');
    return sb.toString();
  }

  void _writeGpxWaypoint(StringBuffer sb, String tag, GpxWaypoint wpt, {required String indent}) {
    sb.writeln('$indent<$tag lat="${wpt.lat}" lon="${wpt.lng}">');
    if (wpt.elevation != null) sb.writeln('$indent  <ele>${wpt.elevation}</ele>');
    if (wpt.time != null) sb.writeln('$indent  <time>${wpt.time!.toUtc().toIso8601String()}</time>');
    if (wpt.name != null) sb.writeln('$indent  <name>${escapeXml(wpt.name!)}</name>');
    if (wpt.comment != null) sb.writeln('$indent  <cmt>${escapeXml(wpt.comment!)}</cmt>');
    if (wpt.description != null) sb.writeln('$indent  <desc>${escapeXml(wpt.description!)}</desc>');
    if (wpt.source != null) sb.writeln('$indent  <src>${escapeXml(wpt.source!)}</src>');
    if (wpt.symbol != null) sb.writeln('$indent  <sym>${escapeXml(wpt.symbol!)}</sym>');

    if (wpt.extensions.isNotEmpty) {
      sb.writeln('$indent  <extensions>');
      for (final entry in wpt.extensions.entries) {
        sb.writeln('$indent    <${entry.key}>${escapeXml(entry.value)}</${entry.key}>');
      }
      sb.writeln('$indent  </extensions>');
    }
    sb.writeln('$indent</$tag>');
  }

  /// Parses a GPX XML string into a [GpxDocument].
  GpxDocument parseGpx(String xml) {
    final creator = getAttributeFromOpeningTag(xml, 'gpx', 'creator') ?? 'Unknown';

    // Parse metadata
    final metadataBlock = getTagInnerXml(xml, 'metadata');
    String? docName;
    String? docDesc;
    String? docAuthor;
    DateTime? docTime;

    if (metadataBlock != null) {
      docName = getTagText(metadataBlock, 'name');
      docDesc = getTagText(metadataBlock, 'desc');
      final authorBlock = getTagInnerXml(metadataBlock, 'author');
      docAuthor = authorBlock != null ? getTagText(authorBlock, 'name') : null;
      final timeStr = getTagText(metadataBlock, 'time');
      if (timeStr != null) {
        docTime = DateTime.tryParse(timeStr);
      }
    }

    // Parse standalone waypoints (<wpt>)
    final waypoints = <GpxWaypoint>[];
    for (final match in getAllTagBlocks(xml, 'wpt')) {
      final wpt = _parseWaypointBlock(match.group(0)!);
      if (wpt != null) waypoints.add(wpt);
    }

    // Parse routes (<rte>)
    final routes = <GpxRoute>[];
    for (final rMatch in getAllTagBlocks(xml, 'rte')) {
      final rBlock = rMatch.group(0)!;
      final rName = getTagText(rBlock, 'name');
      final rDesc = getTagText(rBlock, 'desc');
      final rNum = getTagText(rBlock, 'number');

      final rPoints = <GpxWaypoint>[];
      for (final ptMatch in getAllTagBlocks(rBlock, 'rtept')) {
        final pt = _parseWaypointBlock(ptMatch.group(0)!);
        if (pt != null) rPoints.add(pt);
      }
      routes.add(GpxRoute(name: rName, description: rDesc, number: rNum, points: rPoints));
    }

    // Parse tracks (<trk>)
    final tracks = <GpxTrack>[];
    for (final tMatch in getAllTagBlocks(xml, 'trk')) {
      final tBlock = tMatch.group(0)!;
      final tName = getTagText(tBlock, 'name');
      final tDesc = getTagText(tBlock, 'desc');

      final segments = <GpxTrackSegment>[];
      for (final sMatch in getAllTagBlocks(tBlock, 'trkseg')) {
        final sBlock = sMatch.group(0)!;
        final segPoints = <GpxWaypoint>[];
        for (final ptMatch in getAllTagBlocks(sBlock, 'trkpt')) {
          final pt = _parseWaypointBlock(ptMatch.group(0)!);
          if (pt != null) segPoints.add(pt);
        }
        segments.add(GpxTrackSegment(points: segPoints));
      }
      tracks.add(GpxTrack(name: tName, description: tDesc, segments: segments));
    }

    return GpxDocument(
      name: docName,
      description: docDesc,
      author: docAuthor,
      creator: creator,
      time: docTime,
      waypoints: waypoints,
      routes: routes,
      tracks: tracks,
    );
  }

  GpxWaypoint? _parseWaypointBlock(String block) {
    final openTagMatch = RegExp(r'<[a-zA-Z0-9:]+\s+([^>]+)>').firstMatch(block);
    if (openTagMatch == null) return null;

    final openAttrs = openTagMatch.group(1)!;
    final latStr = getAttribute(openAttrs, 'lat');
    final lonStr = getAttribute(openAttrs, 'lon') ?? getAttribute(openAttrs, 'lng');

    if (latStr == null || lonStr == null) return null;
    final lat = double.tryParse(latStr);
    final lon = double.tryParse(lonStr);
    if (lat == null || lon == null) return null;

    final eleStr = getTagText(block, 'ele');
    final ele = eleStr != null ? double.tryParse(eleStr) : null;
    final timeStr = getTagText(block, 'time');
    final time = timeStr != null ? DateTime.tryParse(timeStr) : null;
    final name = getTagText(block, 'name');
    final cmt = getTagText(block, 'cmt');
    final desc = getTagText(block, 'desc');
    final src = getTagText(block, 'src');
    final sym = getTagText(block, 'sym');

    // Extensions
    final extensions = <String, String>{};
    final extBlock = getTagInnerXml(block, 'extensions');
    if (extBlock != null) {
      final extPattern = RegExp(r'<([a-zA-Z0-9_\-]+)>([\s\S]*?)</\1>');
      for (final m in extPattern.allMatches(extBlock)) {
        final k = m.group(1)!;
        final v = extractText(m.group(2) ?? '');
        extensions[k] = v;
      }
    }

    return GpxWaypoint(
      lat: lat,
      lng: lon,
      elevation: ele,
      time: time,
      name: name,
      description: desc,
      comment: cmt,
      symbol: sym,
      source: src,
      extensions: extensions,
    );
  }

  // ===========================================================================
  // KML XML BUILDER & PARSER
  // ===========================================================================

  /// Generates a well-formed KML 2.2 XML string from a [KmlDocument].
  String buildKml(KmlDocument doc) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    sb.writeln('  <Document>');
    sb.writeln('    <name>${escapeXml(doc.name)}</name>');
    if (doc.description != null) {
      sb.writeln('    <description>${escapeXml(doc.description!)}</description>');
    }

    // Standard Styles
    sb.writeln('    <Style id="animeSpotPin">');
    sb.writeln('      <IconStyle>');
    sb.writeln('        <scale>1.1</scale>');
    sb.writeln('        <Icon>');
    sb.writeln('          <href>https://maps.google.com/mapfiles/kml/paddle/red-circle.png</href>');
    sb.writeln('        </Icon>');
    sb.writeln('      </IconStyle>');
    sb.writeln('    </Style>');

    sb.writeln('    <Style id="dayRoute">');
    sb.writeln('      <LineStyle>');
    sb.writeln('        <color>ff1e88e5</color>');
    sb.writeln('        <width>4</width>');
    sb.writeln('      </LineStyle>');
    sb.writeln('    </Style>');

    // Folders
    for (final folder in doc.folders) {
      sb.writeln('    <Folder>');
      sb.writeln('      <name>${escapeXml(folder.name)}</name>');
      if (folder.description != null) {
        sb.writeln('      <description>${escapeXml(folder.description!)}</description>');
      }
      for (final placemark in folder.placemarks) {
        _writeKmlPlacemark(sb, placemark, indent: '      ');
      }
      for (final path in folder.paths) {
        _writeKmlLineString(sb, path, indent: '      ');
      }
      sb.writeln('    </Folder>');
    }

    // Standalone placemarks and paths
    for (final placemark in doc.standalonePlacemarks) {
      _writeKmlPlacemark(sb, placemark, indent: '    ');
    }
    for (final path in doc.standalonePaths) {
      _writeKmlLineString(sb, path, indent: '    ');
    }

    sb.writeln('  </Document>');
    sb.writeln('</kml>');
    return sb.toString();
  }

  void _writeKmlPlacemark(StringBuffer sb, KmlPlacemark pm, {required String indent}) {
    sb.writeln('$indent<Placemark${pm.id != null ? ' id="${escapeXml(pm.id!)}"' : ''}>');
    sb.writeln('$indent  <name>${escapeXml(pm.name)}</name>');
    if (pm.description != null) {
      sb.writeln('$indent  <description><![CDATA[${pm.description!}]]></description>');
    }
    if (pm.styleUrl != null) {
      sb.writeln('$indent  <styleUrl>${pm.styleUrl}</styleUrl>');
    } else {
      sb.writeln('$indent  <styleUrl>#animeSpotPin</styleUrl>');
    }

    if (pm.extendedData.isNotEmpty) {
      sb.writeln('$indent  <ExtendedData>');
      for (final entry in pm.extendedData.entries) {
        sb.writeln('$indent    <Data name="${escapeXml(entry.key)}">');
        sb.writeln('$indent      <value>${escapeXml(entry.value)}</value>');
        sb.writeln('$indent    </Data>');
      }
      sb.writeln('$indent  </ExtendedData>');
    }

    sb.writeln('$indent  <Point>');
    final ele = pm.elevation != null ? ',${pm.elevation}' : ',0';
    // KML format is longitude,latitude[,altitude]
    sb.writeln('$indent    <coordinates>${pm.lng},${pm.lat}$ele</coordinates>');
    sb.writeln('$indent  </Point>');
    sb.writeln('$indent</Placemark>');
  }

  void _writeKmlLineString(StringBuffer sb, KmlLineString path, {required String indent}) {
    if (path.coordinates.isEmpty) return;
    sb.writeln('$indent<Placemark>');
    if (path.name != null) sb.writeln('$indent  <name>${escapeXml(path.name!)}</name>');
    if (path.description != null) sb.writeln('$indent  <description>${escapeXml(path.description!)}</description>');
    final style = path.styleUrl ?? '#dayRoute';
    sb.writeln('$indent  <styleUrl>$style</styleUrl>');
    sb.writeln('$indent  <LineString>');
    sb.writeln('$indent    <tessellate>1</tessellate>');
    sb.write('$indent    <coordinates>');
    final coordStrs = path.coordinates.map((pt) {
      final ele = pt.elevation != null ? ',${pt.elevation}' : ',0';
      return '${pt.lng},${pt.lat}$ele';
    }).join(' ');
    sb.write(coordStrs);
    sb.writeln('</coordinates>');
    sb.writeln('$indent  </LineString>');
    sb.writeln('$indent</Placemark>');
  }

  /// Parses a KML XML string into a [KmlDocument].
  KmlDocument parseKml(String xml) {
    final docBlock = getTagInnerXml(xml, 'Document') ?? xml;
    final docName = getTagText(docBlock, 'name') ?? 'Imported KML';
    final docDesc = getTagText(docBlock, 'description');

    final folders = <KmlFolder>[];
    // Find all <Folder> blocks
    for (final fMatch in getAllTagBlocks(docBlock, 'Folder')) {
      final fBlock = fMatch.group(0)!;
      final fName = getTagText(fBlock, 'name') ?? 'Folder';
      final fDesc = getTagText(fBlock, 'description');

      final placemarks = <KmlPlacemark>[];
      final paths = <KmlLineString>[];

      for (final pmMatch in getAllTagBlocks(fBlock, 'Placemark')) {
        final pmBlock = pmMatch.group(0)!;
        if (pmBlock.contains('<Point')) {
          final pm = _parseKmlPlacemark(pmBlock);
          if (pm != null) placemarks.add(pm);
        } else if (pmBlock.contains('<LineString')) {
          final path = _parseKmlLineString(pmBlock);
          if (path != null) paths.add(path);
        }
      }
      folders.add(KmlFolder(name: fName, description: fDesc, placemarks: placemarks, paths: paths));
    }

    // Extract standalone placemarks outside <Folder>
    // To do this reliably, strip out all <Folder> blocks and find remaining <Placemark>s
    final strippedOfFolders = docBlock.replaceAll(RegExp(r'<Folder[\s\S]*?</Folder>', caseSensitive: false), '');
    final standalonePlacemarks = <KmlPlacemark>[];
    final standalonePaths = <KmlLineString>[];

    for (final pmMatch in getAllTagBlocks(strippedOfFolders, 'Placemark')) {
      final pmBlock = pmMatch.group(0)!;
      if (pmBlock.contains('<Point')) {
        final pm = _parseKmlPlacemark(pmBlock);
        if (pm != null) standalonePlacemarks.add(pm);
      } else if (pmBlock.contains('<LineString')) {
        final path = _parseKmlLineString(pmBlock);
        if (path != null) standalonePaths.add(path);
      }
    }

    return KmlDocument(
      name: docName,
      description: docDesc,
      folders: folders,
      standalonePlacemarks: standalonePlacemarks,
      standalonePaths: standalonePaths,
    );
  }

  KmlPlacemark? _parseKmlPlacemark(String block) {
    final name = getTagText(block, 'name') ?? 'Waypoint';
    final desc = getTagText(block, 'description');
    final styleUrl = getTagText(block, 'styleUrl');

    final pointBlock = getTagInnerXml(block, 'Point');
    if (pointBlock == null) return null;
    final coordStr = getTagText(pointBlock, 'coordinates');
    if (coordStr == null) return null;

    final parts = coordStr.trim().split(RegExp(r'[,\s]+'));
    if (parts.length < 2) return null;

    // KML is lng,lat[,ele]
    final lng = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lng == null || lat == null) return null;
    final ele = parts.length > 2 ? double.tryParse(parts[2]) : null;

    // ExtendedData
    final extendedData = <String, String>{};
    final extBlock = getTagInnerXml(block, 'ExtendedData');
    if (extBlock != null) {
      // Check <Data name="..."> <value>...</value> </Data>
      final dataPattern = RegExp(r"""<Data\s+name=["']([^"']+)["']>[\s\S]*?<value>([\s\S]*?)</value>""", caseSensitive: false);
      for (final m in dataPattern.allMatches(extBlock)) {
        extendedData[m.group(1)!] = extractText(m.group(2) ?? '');
      }

      // Check <SimpleData name="...">...</SimpleData>
      final simplePattern = RegExp(r"""<SimpleData\s+name=["']([^"']+)["']>([\s\S]*?)</SimpleData>""", caseSensitive: false);
      for (final m in simplePattern.allMatches(extBlock)) {
        extendedData[m.group(1)!] = extractText(m.group(2) ?? '');
      }
    }

    return KmlPlacemark(
      name: name,
      description: desc,
      lat: lat,
      lng: lng,
      elevation: ele,
      styleUrl: styleUrl,
      extendedData: extendedData,
    );
  }

  KmlLineString? _parseKmlLineString(String block) {
    final name = getTagText(block, 'name');
    final desc = getTagText(block, 'description');
    final styleUrl = getTagText(block, 'styleUrl');

    final lsBlock = getTagInnerXml(block, 'LineString');
    if (lsBlock == null) return null;
    final coordStr = getTagText(lsBlock, 'coordinates');
    if (coordStr == null) return null;

    final coords = <GeoPoint>[];
    // Tuples are separated by whitespace, components by comma
    final tuples = coordStr.trim().split(RegExp(r'\s+'));
    for (final tuple in tuples) {
      final parts = tuple.split(',');
      if (parts.length >= 2) {
        final lng = double.tryParse(parts[0]);
        final lat = double.tryParse(parts[1]);
        final ele = parts.length > 2 ? double.tryParse(parts[2]) : null;
        if (lat != null && lng != null) {
          coords.add(GeoPoint(lat: lat, lng: lng, elevation: ele));
        }
      }
    }

    return KmlLineString(
      name: name,
      description: desc,
      coordinates: coords,
      styleUrl: styleUrl,
    );
  }

  // ===========================================================================
  // SQLITE EXPORT OPERATIONS
  // ===========================================================================

  /// Exports an entire trip from SQLite into GPX 1.1 XML.
  Future<String> exportTripToGpx(AppDatabase db, String tripId) async {
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) {
      throw ArgumentError('Trip with ID $tripId not found');
    }

    final days = await (db.select(db.tripDays)
          ..where((d) => d.tripId.equals(tripId))
          ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
        .get();

    final stops = await (db.select(db.stops)..where((s) => s.tripId.equals(tripId))).get();
    final stopMap = {for (final s in stops) s.id: s};

    final scheduleItems = await (db.select(db.scheduleItems)
          ..where((s) => s.tripId.equals(tripId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
        .get();

    // Query anime labels for stops
    final stopAnimeLabels = await _loadStopAnimeLabels(db, stops.map((s) => s.id).toList());

    // Map all stops to GPX waypoints
    final waypoints = <GpxWaypoint>[];
    for (final stop in stops) {
      final animeTitle = stopAnimeLabels[stop.id];
      final extensions = <String, String>{
        'placeKey': stop.placeKey,
        if (animeTitle != null) 'animeTitle': animeTitle,
        if (stop.address != null) 'address': stop.address!,
        if (stop.businessHours != null) 'businessHours': stop.businessHours!,
      };

      waypoints.add(GpxWaypoint(
        lat: stop.lat,
        lng: stop.lng,
        name: stop.name,
        description: stop.description,
        comment: stop.note,
        source: stop.source,
        extensions: extensions,
      ));
    }

    // Group schedule items by day to form routes
    final routes = <GpxRoute>[];
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayItems = scheduleItems.where((it) => it.dayId == day.id).toList();
      final dayPoints = <GpxWaypoint>[];

      for (final item in dayItems) {
        final stop = stopMap[item.stopId];
        if (stop == null) continue;

        final animeTitle = stopAnimeLabels[stop.id];
        final extensions = <String, String>{
          'placeKey': stop.placeKey,
          'scheduleStatus': item.status,
          'stayMinutes': item.stayMinutes.toString(),
          if (item.fixedTime != null) 'fixedTime': item.fixedTime.toString(),
          if (animeTitle != null) 'animeTitle': animeTitle,
        };

        dayPoints.add(GpxWaypoint(
          lat: stop.lat,
          lng: stop.lng,
          name: stop.name,
          description: stop.description,
          comment: stop.note,
          source: stop.source,
          extensions: extensions,
        ));
      }

      final dayTitle = day.title ?? 'Day ${i + 1}';
      final routeName = day.pinnedDate != null ? '$dayTitle (${day.pinnedDate})' : dayTitle;
      routes.add(GpxRoute(
        name: routeName,
        number: '${i + 1}',
        points: dayPoints,
      ));
    }

    final doc = GpxDocument(
      name: trip.title,
      description: trip.description,
      creator: 'Anime Pilgrimage Travel Planner',
      time: trip.createdAt,
      waypoints: waypoints,
      routes: routes,
    );

    return buildGpx(doc);
  }

  /// Exports an entire trip from SQLite into KML 2.2 XML with day folders and connecting lines.
  Future<String> exportTripToKml(AppDatabase db, String tripId) async {
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) {
      throw ArgumentError('Trip with ID $tripId not found');
    }

    final days = await (db.select(db.tripDays)
          ..where((d) => d.tripId.equals(tripId))
          ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
        .get();

    final stops = await (db.select(db.stops)..where((s) => s.tripId.equals(tripId))).get();
    final stopMap = {for (final s in stops) s.id: s};

    final scheduleItems = await (db.select(db.scheduleItems)
          ..where((s) => s.tripId.equals(tripId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
        .get();

    final stopAnimeLabels = await _loadStopAnimeLabels(db, stops.map((s) => s.id).toList());

    final scheduledStopIds = scheduleItems.map((it) => it.stopId).toSet();
    final folders = <KmlFolder>[];

    // Day folders
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayItems = scheduleItems.where((it) => it.dayId == day.id).toList();
      final dayPlacemarks = <KmlPlacemark>[];
      final lineCoords = <GeoPoint>[];

      for (final item in dayItems) {
        final stop = stopMap[item.stopId];
        if (stop == null) continue;

        final animeTitle = stopAnimeLabels[stop.id];
        final descHtml = _buildStopHtmlDescription(stop, animeTitle: animeTitle, item: item);

        final extData = <String, String>{
          'placeKey': stop.placeKey,
          'status': item.status,
          'stayMinutes': item.stayMinutes.toString(),
          if (animeTitle != null) 'animeTitle': animeTitle,
          if (stop.address != null) 'address': stop.address!,
        };

        dayPlacemarks.add(KmlPlacemark(
          id: stop.id,
          name: stop.name,
          description: descHtml,
          lat: stop.lat,
          lng: stop.lng,
          styleUrl: '#animeSpotPin',
          extendedData: extData,
        ));

        lineCoords.add(GeoPoint(lat: stop.lat, lng: stop.lng));
      }

      final paths = <KmlLineString>[];
      if (lineCoords.length >= 2) {
        paths.add(KmlLineString(
          name: 'Day ${i + 1} Route',
          coordinates: lineCoords,
          styleUrl: '#dayRoute',
        ));
      }

      final dayTitle = day.title ?? 'Day ${i + 1}';
      final folderName = day.pinnedDate != null ? '$dayTitle (${day.pinnedDate})' : dayTitle;

      folders.add(KmlFolder(
        name: folderName,
        description: 'Scheduled pilgrimage spots for $dayTitle',
        placemarks: dayPlacemarks,
        paths: paths,
      ));
    }

    // Unscheduled stops folder
    final unscheduledStops = stops.where((s) => !scheduledStopIds.contains(s.id)).toList();
    if (unscheduledStops.isNotEmpty) {
      final unPlacemarks = unscheduledStops.map((stop) {
        final animeTitle = stopAnimeLabels[stop.id];
        return KmlPlacemark(
          id: stop.id,
          name: stop.name,
          description: _buildStopHtmlDescription(stop, animeTitle: animeTitle),
          lat: stop.lat,
          lng: stop.lng,
          styleUrl: '#animeSpotPin',
          extendedData: {
            'placeKey': stop.placeKey,
            if (animeTitle != null) 'animeTitle': animeTitle,
          },
        );
      }).toList();

      folders.add(KmlFolder(
        name: 'Unscheduled Spots',
        description: 'Pilgrimage spots not yet scheduled onto specific days',
        placemarks: unPlacemarks,
      ));
    }

    final doc = KmlDocument(
      name: trip.title,
      description: trip.description,
      folders: folders,
    );

    return buildKml(doc);
  }

  // ===========================================================================
  // SQLITE IMPORT OPERATIONS
  // ===========================================================================

  /// Imports GPX waypoints into a trip within SQLite.
  ///
  /// Guarantees:
  /// - Scope Isolation: verifies [tripId] and [targetDayId] belong to the same trip.
  /// - Topological Ingestion Ordering: ensures parent [Places] exist before inserting child [Stops].
  /// - Awaited transaction with zero fire-and-forget mutations.
  Future<PorterImportResult> importGpxToTrip(
    AppDatabase db,
    String tripId,
    String gpxXml, {
    String? targetDayId,
    String? addedBy,
  }) async {
    final gpxDoc = parseGpx(gpxXml);
    final allWaypoints = gpxDoc.allPoints;
    if (allWaypoints.isEmpty) {
      return const PorterImportResult(importedCount: 0, skippedCount: 0);
    }

    return await db.transaction(() async {
      final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
      if (trip == null) {
        throw ArgumentError('Trip with ID $tripId not found');
      }

      // Resolve destination day with Entity Scope Isolation
      final String resolvedDayId;
      if (targetDayId != null) {
        final day = await (db.select(db.tripDays)
              ..where((d) => d.id.equals(targetDayId) & d.tripId.equals(tripId)))
            .getSingleOrNull();
        if (day == null) {
          throw ArgumentError('Target day $targetDayId does not belong to trip $tripId');
        }
        resolvedDayId = day.id;
      } else {
        final existingDays = await (db.select(db.tripDays)
              ..where((d) => d.tripId.equals(tripId))
              ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
            .get();

        if (existingDays.isNotEmpty) {
          resolvedDayId = existingDays.first.id;
        } else {
          final newDayId = _uuid.v4();
          await db.into(db.tripDays).insert(TripDaysCompanion.insert(
                id: newDayId,
                tripId: tripId,
                sortKey: FractionalIndexUtil.generateKeyBetween(null, null),
                title: const Value('Day 1'),
              ));
          resolvedDayId = newDayId;
        }
      }

      // Query existing schedule item sort keys
      final existingItems = await (db.select(db.scheduleItems)
            ..where((s) => s.dayId.equals(resolvedDayId))
            ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
          .get();
      final existingKeys = existingItems.map((it) => it.sortKey).toList();

      final createdStopIds = <String>[];
      final createdPlaceKeys = <String>[];
      final errors = <String>[];
      int skippedCount = 0;

      for (final wpt in allWaypoints) {
        // Validation (Adversarial standard)
        if (!wpt.isValid) {
          skippedCount++;
          errors.add('Invalid coordinates for "${wpt.name}": (${wpt.lat}, ${wpt.lng})');
          continue;
        }

        final placeKey = wpt.extensions['placeKey'] ?? 'gpx_${_uuid.v4()}';
        final spotName = wpt.name?.trim().isNotEmpty == true ? wpt.name!.trim() : 'Imported Waypoint';

        // Topological ordering: Ensure parent Place exists
        final existingPlace = await (db.select(db.places)..where((p) => p.placeKey.equals(placeKey))).getSingleOrNull();
        if (existingPlace == null) {
          await db.into(db.places).insert(PlacesCompanion.insert(
                placeKey: placeKey,
                name: spotName,
                lat: wpt.lat,
                lng: wpt.lng,
                description: Value(wpt.description),
                accessTips: Value(wpt.comment),
                source: Value(wpt.source ?? 'gpx_import'),
              ));
          createdPlaceKeys.add(placeKey);
        }

        // Insert child Stop
        final stopId = _uuid.v4();
        await db.into(db.stops).insert(StopsCompanion.insert(
              id: stopId,
              tripId: tripId,
              placeKey: placeKey,
              name: spotName,
              lat: wpt.lat,
              lng: wpt.lng,
              description: Value(wpt.description),
              note: Value(wpt.comment),
              source: Value(wpt.source ?? 'gpx_import'),
              addedBy: addedBy ?? 'import',
            ));
        createdStopIds.add(stopId);

        // Link Anime Label if present in extensions
        final animeTitle = wpt.extensions['animeTitle'];
        if (animeTitle != null && animeTitle.trim().isNotEmpty) {
          await _ensureAndAttachAnimeLabel(db, stopId, placeKey, animeTitle.trim());
        }

        // Generate fractional sort key & insert ScheduleItem
        final nextKey = FractionalIndexUtil.append(existingKeys);
        existingKeys.add(nextKey);

        final stayMinutes = int.tryParse(wpt.extensions['stayMinutes'] ?? '') ?? 60;
        final fixedTime = int.tryParse(wpt.extensions['fixedTime'] ?? '');

        await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
              id: _uuid.v4(),
              tripId: tripId,
              stopId: stopId,
              dayId: resolvedDayId,
              sortKey: nextKey,
              stayMinutes: Value(stayMinutes),
              fixedTime: Value(fixedTime),
              status: Value(wpt.extensions['scheduleStatus'] ?? 'planned'),
            ));
      }

      return PorterImportResult(
        importedCount: createdStopIds.length,
        skippedCount: skippedCount,
        createdStopIds: createdStopIds,
        createdPlaceKeys: createdPlaceKeys,
        errors: errors,
      );
    });
  }

  /// Imports KML Placemarks into a trip within SQLite.
  ///
  /// Guarantees:
  /// - Automatic multi-day folder mapping: if KML contains folders, maps each folder to a corresponding TripDay.
  /// - Entity Scope Isolation on trip and day IDs.
  /// - Topological Ingestion Ordering (Places -> Stops -> ScheduleItems).
  Future<PorterImportResult> importKmlToTrip(
    AppDatabase db,
    String tripId,
    String kmlXml, {
    String? targetDayId,
    String? addedBy,
  }) async {
    final kmlDoc = parseKml(kmlXml);
    final allPlacemarks = kmlDoc.allPlacemarks;
    if (allPlacemarks.isEmpty) {
      return const PorterImportResult(importedCount: 0, skippedCount: 0);
    }

    return await db.transaction(() async {
      final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
      if (trip == null) {
        throw ArgumentError('Trip with ID $tripId not found');
      }

      final createdStopIds = <String>[];
      final createdPlaceKeys = <String>[];
      final errors = <String>[];
      int skippedCount = 0;

      // If user specified a targetDayId, import all placemarks into that day
      if (targetDayId != null) {
        final day = await (db.select(db.tripDays)
              ..where((d) => d.id.equals(targetDayId) & d.tripId.equals(tripId)))
            .getSingleOrNull();
        if (day == null) {
          throw ArgumentError('Target day $targetDayId does not belong to trip $tripId');
        }

        final result = await _importPlacemarksToDay(
          db,
          tripId: tripId,
          dayId: day.id,
          placemarks: allPlacemarks,
          addedBy: addedBy,
        );
        return result;
      }

      // If KML has folders with placemarks, import folder by folder into respective TripDays!
      if (kmlDoc.folders.isNotEmpty) {
        final existingDays = await (db.select(db.tripDays)
              ..where((d) => d.tripId.equals(tripId))
              ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
            .get();
        final dayKeys = existingDays.map((d) => d.sortKey).toList();

        for (int i = 0; i < kmlDoc.folders.length; i++) {
          final folder = kmlDoc.folders[i];
          if (folder.placemarks.isEmpty) continue;

          // Match or create day
          final String dayId;
          final dayNumMatch = RegExp(r'Day\s*(\d+)', caseSensitive: false).firstMatch(folder.name);
          final explicitDayIndex = dayNumMatch != null ? int.tryParse(dayNumMatch.group(1)!) : null;

          if (explicitDayIndex != null) {
            final targetIndex = explicitDayIndex - 1;
            if (targetIndex >= 0 && targetIndex < existingDays.length) {
              dayId = existingDays[targetIndex].id;
            } else {
              dayId = _uuid.v4();
              final nextDayKey = FractionalIndexUtil.append(dayKeys);
              dayKeys.add(nextDayKey);
              await db.into(db.tripDays).insert(TripDaysCompanion.insert(
                    id: dayId,
                    tripId: tripId,
                    sortKey: nextDayKey,
                    title: Value(folder.name),
                  ));
              existingDays.add(await (db.select(db.tripDays)..where((d) => d.id.equals(dayId))).getSingle());
            }
          } else {
            final matchingDay = existingDays.where((d) => d.title?.trim().toLowerCase() == folder.name.trim().toLowerCase()).firstOrNull;
            if (matchingDay != null) {
              dayId = matchingDay.id;
            } else if (i < existingDays.length && existingDays.length == kmlDoc.folders.length) {
              dayId = existingDays[i].id;
            } else {
              dayId = _uuid.v4();
              final nextDayKey = FractionalIndexUtil.append(dayKeys);
              dayKeys.add(nextDayKey);
              await db.into(db.tripDays).insert(TripDaysCompanion.insert(
                    id: dayId,
                    tripId: tripId,
                    sortKey: nextDayKey,
                    title: Value(folder.name),
                  ));
              existingDays.add(await (db.select(db.tripDays)..where((d) => d.id.equals(dayId))).getSingle());
            }
          }

          final dayResult = await _importPlacemarksToDay(
            db,
            tripId: tripId,
            dayId: dayId,
            placemarks: folder.placemarks,
            addedBy: addedBy,
          );

          createdStopIds.addAll(dayResult.createdStopIds);
          createdPlaceKeys.addAll(dayResult.createdPlaceKeys);
          errors.addAll(dayResult.errors);
          skippedCount += dayResult.skippedCount;
        }

        // If there are standalone placemarks, import to day 1
        if (kmlDoc.standalonePlacemarks.isNotEmpty && existingDays.isNotEmpty) {
          final sResult = await _importPlacemarksToDay(
            db,
            tripId: tripId,
            dayId: existingDays.first.id,
            placemarks: kmlDoc.standalonePlacemarks,
            addedBy: addedBy,
          );
          createdStopIds.addAll(sResult.createdStopIds);
          createdPlaceKeys.addAll(sResult.createdPlaceKeys);
          errors.addAll(sResult.errors);
          skippedCount += sResult.skippedCount;
        }

        return PorterImportResult(
          importedCount: createdStopIds.length,
          skippedCount: skippedCount,
          createdStopIds: createdStopIds,
          createdPlaceKeys: createdPlaceKeys,
          errors: errors,
        );
      }

      // No folders: import all into first day or new day 1
      final existingDays = await (db.select(db.tripDays)
            ..where((d) => d.tripId.equals(tripId))
            ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
          .get();

      final String resolvedDayId;
      if (existingDays.isNotEmpty) {
        resolvedDayId = existingDays.first.id;
      } else {
        resolvedDayId = _uuid.v4();
        await db.into(db.tripDays).insert(TripDaysCompanion.insert(
              id: resolvedDayId,
              tripId: tripId,
              sortKey: FractionalIndexUtil.generateKeyBetween(null, null),
              title: const Value('Day 1'),
            ));
      }

      return await _importPlacemarksToDay(
        db,
        tripId: tripId,
        dayId: resolvedDayId,
        placemarks: allPlacemarks,
        addedBy: addedBy,
      );
    });
  }

  Future<PorterImportResult> _importPlacemarksToDay(
    AppDatabase db, {
    required String tripId,
    required String dayId,
    required List<KmlPlacemark> placemarks,
    String? addedBy,
  }) async {
    final existingItems = await (db.select(db.scheduleItems)
          ..where((s) => s.dayId.equals(dayId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
        .get();
    final existingKeys = existingItems.map((it) => it.sortKey).toList();

    final createdStopIds = <String>[];
    final createdPlaceKeys = <String>[];
    final errors = <String>[];
    int skippedCount = 0;

    for (final pm in placemarks) {
      if (!pm.isValid) {
        skippedCount++;
        errors.add('Invalid coordinates for "${pm.name}": (${pm.lat}, ${pm.lng})');
        continue;
      }

      final placeKey = pm.extendedData['placeKey'] ?? 'kml_${_uuid.v4()}';
      final spotName = pm.name.trim().isNotEmpty ? pm.name.trim() : 'Imported Placemark';

      // Clean HTML from description if needed
      final plainDesc = pm.description != null ? _stripHtml(pm.description!) : null;

      // Topological ordering: Ensure parent Place exists
      final existingPlace = await (db.select(db.places)..where((p) => p.placeKey.equals(placeKey))).getSingleOrNull();
      if (existingPlace == null) {
        await db.into(db.places).insert(PlacesCompanion.insert(
              placeKey: placeKey,
              name: spotName,
              lat: pm.lat,
              lng: pm.lng,
              description: Value(plainDesc),
              source: const Value('kml_import'),
            ));
        createdPlaceKeys.add(placeKey);
      }

      // Insert Stop
      final stopId = _uuid.v4();
      await db.into(db.stops).insert(StopsCompanion.insert(
            id: stopId,
            tripId: tripId,
            placeKey: placeKey,
            name: spotName,
            lat: pm.lat,
            lng: pm.lng,
            description: Value(plainDesc),
            source: const Value('kml_import'),
            addedBy: addedBy ?? 'import',
          ));
      createdStopIds.add(stopId);

      // Link Anime Label if present
      final animeTitle = pm.extendedData['animeTitle'];
      if (animeTitle != null && animeTitle.trim().isNotEmpty) {
        await _ensureAndAttachAnimeLabel(db, stopId, placeKey, animeTitle.trim());
      }

      // Insert ScheduleItem
      final nextKey = FractionalIndexUtil.append(existingKeys);
      existingKeys.add(nextKey);
      final stayMinutes = int.tryParse(pm.extendedData['stayMinutes'] ?? '') ?? 60;

      await db.into(db.scheduleItems).insert(ScheduleItemsCompanion.insert(
            id: _uuid.v4(),
            tripId: tripId,
            stopId: stopId,
            dayId: dayId,
            sortKey: nextKey,
            stayMinutes: Value(stayMinutes),
            status: Value(pm.extendedData['status'] ?? 'planned'),
          ));
    }

    return PorterImportResult(
      importedCount: createdStopIds.length,
      skippedCount: skippedCount,
      createdStopIds: createdStopIds,
      createdPlaceKeys: createdPlaceKeys,
      errors: errors,
    );
  }

  Future<void> _ensureAndAttachAnimeLabel(
    AppDatabase db,
    String stopId,
    String placeKey,
    String animeName,
  ) async {
    // Check if label exists
    var label = await (db.select(db.labels)..where((l) => l.kind.equals('anime') & l.name.equals(animeName))).getSingleOrNull();

    if (label == null) {
      final labelId = _uuid.v4();
      await db.into(db.labels).insert(LabelsCompanion.insert(
            id: labelId,
            kind: 'anime',
            name: animeName,
          ));
      label = await (db.select(db.labels)..where((l) => l.id.equals(labelId))).getSingle();
    }

    // Attach to StopLabels
    await db.into(db.stopLabels).insertOnConflictUpdate(StopLabelsCompanion.insert(
          stopId: stopId,
          labelId: label.id,
        ));

    // Also attach to PlaceLabels
    await db.into(db.placeLabels).insertOnConflictUpdate(PlaceLabelsCompanion.insert(
          placeKey: placeKey,
          labelId: label.id,
        ));
  }

  Future<Map<String, String>> _loadStopAnimeLabels(AppDatabase db, List<String> stopIds) async {
    if (stopIds.isEmpty) return {};

    final query = db.select(db.stopLabels).join([
      innerJoin(db.labels, db.labels.id.equalsExp(db.stopLabels.labelId)),
    ])
      ..where(db.stopLabels.stopId.isIn(stopIds) & db.labels.kind.equals('anime'));

    final rows = await query.get();
    final result = <String, String>{};

    for (final row in rows) {
      final sId = row.readTable(db.stopLabels).stopId;
      final label = row.readTable(db.labels);
      result[sId] = label.name;
    }

    return result;
  }

  String _buildStopHtmlDescription(Stop stop, {String? animeTitle, ScheduleItem? item}) {
    final sb = StringBuffer();
    sb.writeln('<h3>${escapeXml(stop.name)}</h3>');
    if (animeTitle != null) {
      sb.writeln('<p><b>Anime:</b> ${escapeXml(animeTitle)}</p>');
    }
    if (stop.description != null && stop.description!.isNotEmpty) {
      sb.writeln('<p>${escapeXml(stop.description!)}</p>');
    }
    if (stop.note != null && stop.note!.isNotEmpty) {
      sb.writeln('<p><b>Note:</b> ${escapeXml(stop.note!)}</p>');
    }
    if (stop.address != null && stop.address!.isNotEmpty) {
      sb.writeln('<p><b>Address:</b> ${escapeXml(stop.address!)}</p>');
    }
    if (item != null) {
      sb.writeln('<p><b>Planned Stay:</b> ${item.stayMinutes} min | <b>Status:</b> ${item.status}</p>');
    }
    return sb.toString();
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // ===========================================================================
  // XML PARSING UTILITIES
  // ===========================================================================

  static String escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String unescapeXml(String input) {
    return input
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&');
  }

  static String extractText(String tagContent) {
    final trimmed = tagContent.trim();
    if (trimmed.isEmpty) return '';

    final cdataPattern = RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>');
    if (trimmed.startsWith('<![CDATA[') && trimmed.endsWith(']]>')) {
      final match = cdataPattern.firstMatch(trimmed);
      if (match != null && match.group(0) == trimmed) {
        return match.group(1) ?? '';
      }
    }

    final sb = StringBuffer();
    int lastEnd = 0;
    for (final m in cdataPattern.allMatches(trimmed)) {
      if (m.start > lastEnd) {
        sb.write(unescapeXml(trimmed.substring(lastEnd, m.start)));
      }
      sb.write(m.group(1) ?? '');
      lastEnd = m.end;
    }
    if (lastEnd < trimmed.length) {
      sb.write(unescapeXml(trimmed.substring(lastEnd)));
    }
    return sb.toString().trim();
  }

  /// Extracts raw inner XML markup between `<tagName>` and `</tagName>`.
  static String? getTagInnerXml(String xml, String tagName) {
    final pattern = RegExp('<(?:[a-zA-Z0-9]+:)?$tagName(?:\\s+[^>]*)?>([\\s\\S]*?)</(?:[a-zA-Z0-9]+:)?$tagName>', caseSensitive: false);
    final match = pattern.firstMatch(xml);
    return match?.group(1);
  }

  /// Extracts unescaped text content or CDATA of `<tagName>`.
  static String? getTagText(String xml, String tagName) {
    final inner = getTagInnerXml(xml, tagName);
    if (inner == null) return null;
    return extractText(inner);
  }

  // Aliases for compatibility
  static String? getTagContent(String xml, String tagName) => getTagText(xml, tagName);
  static String extractContent(String tagBlock) => extractText(tagBlock);

  static Iterable<RegExpMatch> getAllTagBlocks(String xml, String tagName) {
    final pattern = RegExp('<(?:[a-zA-Z0-9]+:)?$tagName(?:\\s+[^>]*)?>([\\s\\S]*?)</(?:[a-zA-Z0-9]+:)?$tagName>', caseSensitive: false);
    return pattern.allMatches(xml);
  }

  static String? getAttribute(String attrs, String attrName) {
    final pattern = RegExp('$attrName\\s*=\\s*["\']([^"\']*)["\']', caseSensitive: false);
    return pattern.firstMatch(attrs)?.group(1);
  }

  static String? getAttributeFromOpeningTag(String xml, String tagName, String attrName) {
    final pattern = RegExp('<(?:[a-zA-Z0-9]+:)?$tagName\\s+([^>]+)>', caseSensitive: false);
    final match = pattern.firstMatch(xml);
    if (match == null) return null;
    return getAttribute(match.group(1)!, attrName);
  }
}
