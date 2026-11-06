import 'dart:collection';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/database/database.dart';
import '../../poi/services/anitabi_api_service.dart';
import '../../poi/services/anitabi_static_data.dart';
import '../repositories/place_repository.dart';

/// One of a work's spots on Anitabi, as the import list shows it.
class AnitabiSpot {
  final String id;
  final String name;

  /// Null when Anitabi has no coordinates for the spot; it can't become a
  /// place then.
  final double? lat;
  final double? lng;
  final String? episode;
  final int? seconds;
  final String? note;
  final String? imageUrl;

  /// Who the frame comes from, which the CC BY-NC-SA licence asks to keep.
  final String? origin;
  final String? originUrl;

  const AnitabiSpot({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.episode,
    this.seconds,
    this.note,
    this.imageUrl,
    this.origin,
    this.originUrl,
  });

  String get placeKey => 'anitabi:$id';
  bool get hasLocation => lat != null && lng != null;

  /// The small version of the frame (160 px high), for lists.
  String? get thumbnailUrl => imageUrl?.replaceAll('?plan=h360', '?plan=h160');

  /// "Ep 3 · 4:12", from what the data has, or null.
  String? get scene {
    final s = seconds;
    final parts = [
      if (episode != null) 'Ep $episode',
      if (s != null && s > 0) '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Reads a spot from Anitabi's static data, or null when it has no id or name.
  static AnitabiSpot? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    // The original-language name, which matches the signs on site; the
    // Chinese one only when there is none.
    final name = (json['name'] ?? json['cn'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty) return null;
    final geo = json['geo'];
    double? coord(int i) => geo is List && geo.length > i ? double.tryParse('${geo[i]}') : null;
    String? text(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
    final image = text(json['image']);
    return AnitabiSpot(
      id: id,
      name: name,
      lat: coord(0),
      lng: coord(1),
      episode: text(json['ep']),
      seconds: int.tryParse('${json['s']}'),
      note: text(json['mark']),
      imageUrl: image?.replaceAll('?plan=h160', '?plan=h360'),
      origin: text(json['origin']),
      originUrl: text(json['originURL']),
    );
  }
}

/// A work's title and spots on Anitabi.
class AnitabiWork {
  final String? title;
  final List<AnitabiSpot> spots;

  const AnitabiWork({required this.title, required this.spots});
}

/// What an import did.
class AnitabiImportSummary {
  final int added;
  final int alreadySaved;
  final int withoutLocation;

  /// Frames being downloaded: for new places, and for places already saved
  /// that have no frame, such as when the app closed during an earlier
  /// import's downloads.
  final int framesPending;

  /// Completes once every frame download has finished or failed.
  final Future<void> frames;

  const AnitabiImportSummary({
    required this.added,
    required this.alreadySaved,
    required this.withoutLocation,
    required this.framesPending,
    required this.frames,
  });
}

/// Imports Anitabi spots into the library: each picked spot becomes a saved
/// place (`anitabi:<id>`) with the work's anime label, and each place without
/// a frame gets its frame downloaded as a reference image.
///
/// The rules in CLAUDE.md apply: only Anitabi's static data and image hosts
/// are used, every request sends [AnitabiApiService.userAgent], a refusal is
/// never retried, and a frame is fetched only for a place that has none.
class AnitabiImport {
  static const _concurrency = 5;

  /// Loads [bangumiId]'s spots from Anitabi's static data, which is cached
  /// on the device. Throws [AnitabiUnavailableException] when Anitabi can't
  /// be reached or refuses this network.
  static Future<AnitabiWork?> loadWork(String bangumiId, {http.Client? client, Future<Directory> Function()? cacheDir}) async {
    final ownsClient = client == null;
    final httpClient = AnitabiApiService.identifiedClient(client);
    try {
      final work = await AnitabiStaticData(
        client: httpClient,
        cacheDir: cacheDir ?? AnitabiApiService.staticDataCacheDir,
      ).work(bangumiId);
      if (work == null) return null;
      return AnitabiWork(title: work.title, spots: [for (final raw in work.spots) ?AnitabiSpot.fromJson(raw)]);
    } on AnitabiStaticDataUnavailableException catch (e) {
      throw AnitabiUnavailableException(blocked: e.blocked);
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  /// Saves [spots] to the library under the anime [animeName] ([bangumiId]).
  /// Spots without a location are left out. Places already in the library
  /// keep their own facts and only get the anime label (and are saved again
  /// if they were trip-only), plus their frame when they have none: frames
  /// download in the background, so the app closing stops an import's
  /// downloads, and importing again fetches the rest. A place with any frame,
  /// such as one migrated from v0.1.x, isn't fetched again. [download]
  /// fetches a frame to a local file; the default uses Anitabi's image host
  /// and mirror.
  static Future<AnitabiImportSummary> importSpots({
    required PlaceRepository places,
    required String bangumiId,
    required String animeName,
    required List<AnitabiSpot> spots,
    Future<String?> Function(String url)? download,
  }) async {
    final label = await places.getOrCreateLabel(kind: 'anime', name: animeName, bangumiId: bangumiId);
    var added = 0;
    var alreadySaved = 0;
    var withoutLocation = 0;
    final framesToFetch = <AnitabiSpot>[];
    for (final spot in spots) {
      if (!spot.hasLocation) {
        withoutLocation++;
        continue;
      }
      final existing = await places.getPlace(spot.placeKey);
      if (existing == null) {
        await places.upsertPlace(PlacesCompanion.insert(
          placeKey: spot.placeKey,
          name: spot.name,
          lat: spot.lat!,
          lng: spot.lng!,
          description: Value(spot.note),
          source: const Value('Anitabi'),
          sourceUrl: Value(spot.originUrl),
          visibility: const Value('saved'),
        ));
        added++;
        if (spot.imageUrl != null) framesToFetch.add(spot);
      } else {
        alreadySaved++;
        if (existing.visibility != 'saved') await places.setPlaceVisibility(spot.placeKey, 'saved');
        if (spot.imageUrl != null && (await places.getReferenceImagesForPlace(spot.placeKey)).isEmpty) {
          framesToFetch.add(spot);
        }
      }
      await places.attachLabelToPlace(spot.placeKey, label.id);
    }

    final frames = _downloadFrames(places: places, spots: framesToFetch, animeLabelId: label.id, download: download);
    return AnitabiImportSummary(
      added: added,
      alreadySaved: alreadySaved,
      withoutLocation: withoutLocation,
      framesPending: framesToFetch.length,
      frames: frames,
    );
  }

  static Future<void> _downloadFrames({
    required PlaceRepository places,
    required List<AnitabiSpot> spots,
    required String animeLabelId,
    Future<String?> Function(String url)? download,
  }) async {
    if (spots.isEmpty) return;
    final client = download == null ? AnitabiApiService.identifiedClient() : null;
    final fetch = download ?? (url) => AnitabiApiService.downloadReferenceImage(url, client!);
    final queue = Queue<AnitabiSpot>.from(spots);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final spot = queue.removeFirst();
        try {
          final path = await fetch(spot.imageUrl!);
          if (path == null) continue;
          await places.addReferenceImage(
            placeKey: spot.placeKey,
            localPath: path,
            remoteUrl: spot.imageUrl,
            animeLabelId: animeLabelId,
            episode: spot.episode,
            timestampS: spot.seconds,
            source: spot.origin ?? 'Anitabi',
            sourceUrl: spot.originUrl,
          );
        } catch (e) {
          // One frame that fails to arrive leaves its place without one.
          debugPrint('[AnitabiImport] Frame for ${spot.placeKey} failed: $e');
        }
      }
    }

    try {
      await Future.wait([for (var i = 0; i < _concurrency; i++) worker()]);
    } finally {
      client?.close();
    }
  }
}
