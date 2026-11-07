import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/travelogue_models.dart';

/// Service generating structured, beautiful pilgrimage travelogues and reports
/// in Markdown and self-contained offline HTML formats.
///
/// Features:
/// - Aggregates trip timeline, check-in timestamps, user photos, and anime reference cuts.
/// - Generates clean Markdown with YAML Frontmatter, blockquotes, and coordinates.
/// - Generates responsive self-contained HTML with print stylesheet support.
/// - Complies with Rule 2 (Entity Scope Isolation) and Rule 3 (Awaited queries).
class PilgrimageTravelogueService {
  const PilgrimageTravelogueService();

  /// Compiles a comprehensive [TravelogueDocument] from database records for a trip.
  Future<TravelogueDocument> compileTravelogue(
    AppDatabase db,
    String tripId, {
    String? authorName,
  }) async {
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
    final placeKeys = stops.map((s) => s.placeKey).toSet().toList();

    final scheduleItems = await (db.select(db.scheduleItems)
          ..where((s) => s.tripId.equals(tripId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortKey)]))
        .get();

    // Load Anime labels for stops
    final animeLabels = await _loadStopAnimeLabels(db, stops.map((s) => s.id).toList());

    // Load check-in visit history
    final visits = await _loadPlaceVisits(db, tripId, placeKeys);

    // Load user photos
    final photos = await _loadPhotos(db, tripId, placeKeys);

    // Load anime reference frames
    final refImages = await _loadReferenceImages(db, stops.map((s) => s.id).toList(), placeKeys);

    final daySections = <TravelogueDaySection>[];
    int totalCompleted = 0;
    final allAnimeSet = <String>{};

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final dayItems = scheduleItems.where((it) => it.dayId == day.id).toList();
      final stopEntries = <TravelogueStopEntry>[];

      for (final item in dayItems) {
        final stop = stopMap[item.stopId];
        if (stop == null) continue;

        final animeTitle = animeLabels[stop.id];
        if (animeTitle != null) allAnimeSet.add(animeTitle);

        final visit = visits[stop.placeKey];
        final stopPhotos = photos[stop.placeKey] ?? const [];
        final stopRefs = refImages[stop.id] ?? refImages[stop.placeKey] ?? const [];

        // Pair user photos and reference frames
        final photoPairs = <TraveloguePhotoItem>[];
        final maxCount = stopPhotos.length > stopRefs.length ? stopPhotos.length : stopRefs.length;

        for (int p = 0; p < maxCount; p++) {
          final userPhoto = p < stopPhotos.length ? stopPhotos[p] : null;
          final refImg = p < stopRefs.length ? stopRefs[p] : null;

          photoPairs.add(TraveloguePhotoItem(
            userPhotoPath: userPhoto?.localPath,
            refImageLocalPath: refImg?.localPath,
            refImageRemoteUrl: refImg?.remoteUrl,
            episode: refImg?.episode,
            caption: userPhoto?.takenAt != null
                ? 'Captured at ${userPhoto!.takenAt!.toIso8601String().substring(11, 16)}'
                : null,
          ));
        }

        final entry = TravelogueStopEntry(
          stopId: stop.id,
          placeKey: stop.placeKey,
          name: stop.name,
          lat: stop.lat,
          lng: stop.lng,
          animeTitle: animeTitle,
          description: stop.description,
          accessTips: stop.accessTips,
          note: stop.note,
          visitDate: visit?.date,
          visitedAt: visit?.createdAt,
          stayMinutes: item.stayMinutes,
          status: item.status,
          photos: photoPairs,
        );

        if (entry.isCompleted) {
          totalCompleted++;
        }
        stopEntries.add(entry);
      }

      daySections.add(TravelogueDaySection(
        dayId: day.id,
        title: day.title ?? 'Day ${i + 1}',
        pinnedDate: day.pinnedDate,
        stops: stopEntries,
      ));
    }

    return TravelogueDocument(
      tripId: tripId,
      title: trip.title,
      description: trip.description,
      author: authorName ?? trip.ownerId,
      startDate: trip.startDate,
      generatedAt: DateTime.now(),
      animeTitles: allAnimeSet.toList()..sort(),
      totalStops: scheduleItems.length,
      completedStops: totalCompleted,
      days: daySections,
    );
  }

  /// Generates a GitHub/Obsidian-compatible Markdown document from a [TravelogueDocument].
  String generateMarkdown(TravelogueDocument doc) {
    final sb = StringBuffer();

    // 1. YAML Frontmatter
    sb.writeln('---');
    sb.writeln('title: "${_escapeYaml(doc.title)}"');
    if (doc.startDate != null) {
      sb.writeln('date: ${doc.startDate}');
    } else {
      sb.writeln('date: ${doc.generatedAt.toIso8601String().substring(0, 10)}');
    }
    if (doc.author != null) {
      sb.writeln('author: "${_escapeYaml(doc.author!)}"');
    }
    sb.writeln('anime:');
    for (final anime in doc.animeTitles) {
      sb.writeln('  - "${_escapeYaml(anime)}"');
    }
    sb.writeln('completion_rate: "${doc.completionRatePercentage}"');
    sb.writeln('---');
    sb.writeln();

    // 2. Main Title & Overview
    sb.writeln('# ⛩️ ${doc.title}');
    sb.writeln();
    if (doc.description != null && doc.description!.isNotEmpty) {
      sb.writeln(doc.description!);
      sb.writeln();
    }

    // 3. Stats Summary Card
    sb.writeln('> 📍 **Total Stops**: ${doc.totalStops} | ✅ **Completed**: ${doc.completedStops} (${doc.completionRatePercentage})  ');
    if (doc.animeTitles.isNotEmpty) {
      sb.writeln('> 🎬 **Anime Works**: ${doc.animeTitles.join(", ")}  ');
    }
    sb.writeln('> 🗓️ **Report Date**: ${doc.generatedAt.toIso8601String().substring(0, 10)}');
    sb.writeln();

    // 4. Day-by-Day Sections
    for (int i = 0; i < doc.days.length; i++) {
      final day = doc.days[i];
      final dayHeader = day.pinnedDate != null
          ? '${day.title} (${day.pinnedDate})'
          : day.title;

      sb.writeln('## 📅 Day ${i + 1}: $dayHeader');
      sb.writeln();

      if (day.stops.isEmpty) {
        sb.writeln('*No pilgrimage stops scheduled for this day.*');
        sb.writeln();
        continue;
      }

      for (int j = 0; j < day.stops.length; j++) {
        final stop = day.stops[j];
        final statusIcon = stop.isCompleted ? '✅' : '⏳';

        sb.writeln('### ${j + 1}. $statusIcon ${stop.name}');
        if (stop.animeTitle != null) {
          sb.writeln('- **Anime**: *${stop.animeTitle}*');
        }
        sb.writeln('- **Status**: ${stop.isCompleted ? "Visited" : "Planned"}'
            '${stop.visitDate != null ? " on ${stop.visitDate}" : ""} (${stop.stayMinutes} min)');
        sb.writeln('- **Location**: [Open in Google Maps](${stop.googleMapsUrl})');

        if (stop.description != null && stop.description!.isNotEmpty) {
          sb.writeln();
          sb.writeln('> 📝 **Scene Info**: ${stop.description}');
        }
        if (stop.note != null && stop.note!.isNotEmpty) {
          sb.writeln();
          sb.writeln('> 💡 **Pilgrim Note**: ${stop.note}');
        }
        if (stop.accessTips != null && stop.accessTips!.isNotEmpty) {
          sb.writeln();
          sb.writeln('> 🚶 **Access Tips**: ${stop.accessTips}');
        }

        // Photos & Comparison
        if (stop.photos.isNotEmpty) {
          sb.writeln();
          for (final photo in stop.photos) {
            if (photo.userPhotoPath != null && photo.refImageLocalPath != null) {
              sb.writeln('| Anime Reference Cut (${photo.episode ?? "Frame"}) | Pilgrim Photo |');
              sb.writeln('| :---: | :---: |');
              sb.writeln('| ![](${photo.refImageLocalPath}) | ![](${photo.userPhotoPath}) |');
            } else if (photo.userPhotoPath != null) {
              sb.writeln('![Pilgrim Photo](${photo.userPhotoPath})');
            } else if (photo.refImageLocalPath != null) {
              sb.writeln('![Anime Frame](${photo.refImageLocalPath})');
            }
          }
        }
        sb.writeln();
      }
    }

    return sb.toString();
  }

  /// Generates a standalone, responsive, 100% offline HTML report from a [TravelogueDocument].
  String generateHtml(TravelogueDocument doc) {
    final sb = StringBuffer();
    sb.writeln('<!DOCTYPE html>');
    sb.writeln('<html lang="en">');
    sb.writeln('<head>');
    sb.writeln('  <meta charset="UTF-8">');
    sb.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    sb.writeln('  <title>${_escapeHtml(doc.title)} - Pilgrimage Report</title>');
    sb.writeln('  <style>');
    sb.writeln(_defaultCss());
    sb.writeln('  </style>');
    sb.writeln('</head>');
    sb.writeln('<body>');
    sb.writeln('  <div class="container">');
    sb.writeln('    <header class="report-header">');
    sb.writeln('      <div class="badge">Pilgrimage Travelogue</div>');
    sb.writeln('      <h1>⛩️ ${_escapeHtml(doc.title)}</h1>');
    if (doc.description != null && doc.description!.isNotEmpty) {
      sb.writeln('      <p class="subtitle">${_escapeHtml(doc.description!)}</p>');
    }
    sb.writeln('      <div class="meta-bar">');
    sb.writeln('        <div class="meta-item"><b>Total Stops:</b> ${doc.totalStops}</div>');
    sb.writeln('        <div class="meta-item"><b>Completed:</b> ${doc.completedStops} (${doc.completionRatePercentage})</div>');
    if (doc.author != null) {
      sb.writeln('        <div class="meta-item"><b>Author:</b> ${_escapeHtml(doc.author!)}</div>');
    }
    sb.writeln('        <div class="meta-item"><b>Date:</b> ${doc.generatedAt.toIso8601String().substring(0, 10)}</div>');
    sb.writeln('      </div>');
    if (doc.animeTitles.isNotEmpty) {
      sb.writeln('      <div class="anime-chips">');
      for (final anime in doc.animeTitles) {
        sb.writeln('        <span class="chip">🎬 ${_escapeHtml(anime)}</span>');
      }
      sb.writeln('      </div>');
    }
    sb.writeln('    </header>');

    sb.writeln('    <main class="timeline">');
    for (int i = 0; i < doc.days.length; i++) {
      final day = doc.days[i];
      sb.writeln('      <section class="day-section">');
      sb.writeln('        <div class="day-header">');
      sb.writeln('          <h2>Day ${i + 1}: ${_escapeHtml(day.title)}</h2>');
      if (day.pinnedDate != null) {
        sb.writeln('          <span class="date-badge">${day.pinnedDate}</span>');
      }
      sb.writeln('        </div>');

      if (day.stops.isEmpty) {
        sb.writeln('        <p class="empty-notice">No spots scheduled for this day.</p>');
      } else {
        sb.writeln('        <div class="stops-grid">');
        for (final stop in day.stops) {
          final completedClass = stop.isCompleted ? 'completed' : 'pending';
          sb.writeln('          <div class="stop-card $completedClass">');
          sb.writeln('            <div class="card-header">');
          sb.writeln('              <h3>${_escapeHtml(stop.name)}</h3>');
          sb.writeln('              <span class="status-indicator">${stop.isCompleted ? "✅ Done" : "⏳ Planned"}</span>');
          sb.writeln('            </div>');

          if (stop.animeTitle != null) {
            sb.writeln('            <div class="anime-tag">🎬 ${_escapeHtml(stop.animeTitle!)}</div>');
          }

          if (stop.description != null && stop.description!.isNotEmpty) {
            sb.writeln('            <p class="desc">${_escapeHtml(stop.description!)}</p>');
          }
          if (stop.note != null && stop.note!.isNotEmpty) {
            sb.writeln('            <p class="note"><b>Note:</b> ${_escapeHtml(stop.note!)}</p>');
          }

          sb.writeln('            <div class="card-footer">');
          sb.writeln('              <span class="stay-info">Stay: ${stop.stayMinutes}m</span>');
          sb.writeln('              <a href="${stop.googleMapsUrl}" target="_blank" rel="noopener" class="map-link">🗺️ Map</a>');
          sb.writeln('            </div>');
          sb.writeln('          </div>');
        }
        sb.writeln('        </div>');
      }
      sb.writeln('      </section>');
    }
    sb.writeln('    </main>');

    sb.writeln('    <footer class="report-footer">');
    sb.writeln('      <p>Generated with Anime Pilgrimage Travel Planner • Local-first & Zero Ad Tracking</p>');
    sb.writeln('    </footer>');
    sb.writeln('  </div>');
    sb.writeln('</body>');
    sb.writeln('</html>');

    return sb.toString();
  }

  /// Exports the markdown report directly from database.
  Future<String> exportTravelogueMarkdown(AppDatabase db, String tripId, {String? authorName}) async {
    final doc = await compileTravelogue(db, tripId, authorName: authorName);
    return generateMarkdown(doc);
  }

  /// Exports the HTML report directly from database.
  Future<String> exportTravelogueHtml(AppDatabase db, String tripId, {String? authorName}) async {
    final doc = await compileTravelogue(db, tripId, authorName: authorName);
    return generateHtml(doc);
  }

  // ===========================================================================
  // DATABASE LOADERS
  // ===========================================================================

  Future<Map<String, String>> _loadStopAnimeLabels(AppDatabase db, List<String> stopIds) async {
    if (stopIds.isEmpty) return {};
    final query = db.select(db.stopLabels).join([
      innerJoin(db.labels, db.labels.id.equalsExp(db.stopLabels.labelId)),
    ])..where(db.stopLabels.stopId.isIn(stopIds) & db.labels.kind.equals('anime'));

    final rows = await query.get();
    final result = <String, String>{};
    for (final row in rows) {
      result[row.readTable(db.stopLabels).stopId] = row.readTable(db.labels).name;
    }
    return result;
  }

  Future<Map<String, PlaceVisit>> _loadPlaceVisits(AppDatabase db, String tripId, List<String> placeKeys) async {
    if (placeKeys.isEmpty) return {};
    final rows = await (db.select(db.placeVisits)
          ..where((pv) => pv.placeKey.isIn(placeKeys) & (pv.tripId.equals(tripId) | pv.tripId.isNull())))
        .get();

    final result = <String, PlaceVisit>{};
    for (final visit in rows) {
      result[visit.placeKey] = visit;
    }
    return result;
  }

  Future<Map<String, List<Photo>>> _loadPhotos(AppDatabase db, String tripId, List<String> placeKeys) async {
    if (placeKeys.isEmpty) return {};
    final rows = await (db.select(db.photos)
          ..where((p) => p.placeKey.isIn(placeKeys) & (p.tripId.equals(tripId) | p.tripId.isNull())))
        .get();

    final result = <String, List<Photo>>{};
    for (final photo in rows) {
      result.putIfAbsent(photo.placeKey, () => []).add(photo);
    }
    return result;
  }

  Future<Map<String, List<NewReferenceImage>>> _loadReferenceImages(
    AppDatabase db,
    List<String> stopIds,
    List<String> placeKeys,
  ) async {
    final query = db.select(db.newReferenceImages)
      ..where((r) => (r.stopId.isNotNull() & r.stopId.isIn(stopIds)) | (r.placeKey.isNotNull() & r.placeKey.isIn(placeKeys)));

    final rows = await query.get();
    final result = <String, List<NewReferenceImage>>{};

    for (final ref in rows) {
      if (ref.stopId != null) {
        result.putIfAbsent(ref.stopId!, () => []).add(ref);
      }
      if (ref.placeKey != null) {
        result.putIfAbsent(ref.placeKey!, () => []).add(ref);
      }
    }
    return result;
  }

  String _escapeYaml(String input) {
    return input.replaceAll('"', r'\"');
  }

  String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _defaultCss() {
    return '''
    :root {
      --primary: #e53935;
      --bg: #f8fafc;
      --card-bg: #ffffff;
      --text: #1e293b;
      --muted: #64748b;
      --border: #e2e8f0;
      --success: #10b981;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #0f172a;
        --card-bg: #1e293b;
        --text: #f1f5f9;
        --muted: #94a3b8;
        --border: #334155;
      }
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; padding: 2rem 1rem; }
    .container { max-width: 900px; margin: 0 auto; }
    .report-header { background: var(--card-bg); border: 1px solid var(--border); border-radius: 12px; padding: 2rem; margin-bottom: 2rem; box-shadow: 0 2px 8px rgba(0,0,0,0.05); }
    .badge { display: inline-block; background: var(--primary); color: white; padding: 0.25rem 0.75rem; border-radius: 20px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; margin-bottom: 0.75rem; }
    h1 { font-size: 1.8rem; margin-bottom: 0.5rem; }
    .subtitle { color: var(--muted); margin-bottom: 1.5rem; }
    .meta-bar { display: flex; flex-wrap: wrap; gap: 1.5rem; padding-top: 1rem; border-top: 1px solid var(--border); font-size: 0.9rem; }
    .anime-chips { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-top: 1rem; }
    .chip { background: var(--bg); border: 1px solid var(--border); padding: 0.3rem 0.8rem; border-radius: 16px; font-size: 0.85rem; font-weight: 500; }
    .day-section { margin-bottom: 2.5rem; }
    .day-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; border-left: 4px solid var(--primary); padding-left: 0.75rem; }
    .date-badge { background: var(--border); color: var(--text); font-size: 0.8rem; padding: 0.2rem 0.6rem; border-radius: 4px; }
    .stops-grid { display: grid; grid-template-columns: 1fr; gap: 1rem; }
    @media (min-width: 640px) { .stops-grid { grid-template-columns: repeat(2, 1fr); } }
    .stop-card { background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px; padding: 1.25rem; display: flex; flex-direction: column; justify-content: space-between; }
    .stop-card.completed { border-left: 4px solid var(--success); }
    .card-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.5rem; }
    .card-header h3 { font-size: 1.1rem; }
    .status-indicator { font-size: 0.8rem; font-weight: 600; }
    .anime-tag { font-size: 0.8rem; color: var(--primary); font-weight: 500; margin-bottom: 0.5rem; }
    .desc { font-size: 0.9rem; color: var(--muted); margin-bottom: 0.5rem; }
    .note { font-size: 0.85rem; background: var(--bg); padding: 0.5rem; border-radius: 4px; margin-bottom: 0.75rem; }
    .card-footer { display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border); padding-top: 0.75rem; font-size: 0.85rem; color: var(--muted); }
    .map-link { color: var(--primary); text-decoration: none; font-weight: 500; }
    .report-footer { text-align: center; font-size: 0.85rem; color: var(--muted); margin-top: 3rem; padding-top: 1.5rem; border-top: 1px solid var(--border); }
    @media print {
      body { background: white; color: black; padding: 0; }
      .report-header, .stop-card { box-shadow: none; border-color: #ccc; }
      .map-link { display: none; }
    }
    ''';
  }
}
