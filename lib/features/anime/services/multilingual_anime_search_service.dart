import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../poi/services/anitabi_api_service.dart';
import '../../poi/services/anitabi_static_data.dart';
import '../models/bangumi_subject.dart';
import '../models/indexed_anime_work.dart';
import 'bangumi_search_service.dart';

/// Multilingual anime and pilgrimage spot search engine.
///
/// Indexes Anitabi's static data (`g.json`) locally on device to allow
/// instant, completely offline search by:
/// - Traditional Chinese (e.g. "吹響吧！上低音號", "孤獨搖滾！", "輕音少女")
/// - Simplified Chinese (e.g. "吹响吧！上低音号", "孤独摇滚！", "轻音少女")
/// - Japanese Kanji & Kana (e.g. "けいおん!", "響け！ユーフォニアム")
/// - Common anime nicknames & abbreviations (e.g. "京吹", "芙莉蓮", "果青")
/// - Bangumi ID (e.g. "1424")
/// - City / Region (e.g. "京都市", "宇治市")
///
/// Falls back to [BangumiSearchService] when online if the query returns
/// zero results from the local Anitabi index.
class MultilingualAnimeSearchService {
  /// Default singleton instance across the application session.
  static final MultilingualAnimeSearchService instance =
      MultilingualAnimeSearchService();

  final http.Client? _client;
  final Future<Directory> Function() _cacheDir;
  final AnitabiStaticData? _staticData;

  List<IndexedAnimeWork>? _cachedIndex;
  bool _isIndexing = false;

  MultilingualAnimeSearchService({
    http.Client? client,
    Future<Directory> Function()? cacheDir,
    AnitabiStaticData? staticData,
  })  : _client = client,
        _cacheDir = cacheDir ?? AnitabiApiService.staticDataCacheDir,
        _staticData = staticData;

  /// Whether the in-memory index has been loaded and initialized.
  bool get isIndexLoaded => _cachedIndex != null;

  /// Number of indexed anime works currently in memory.
  int get indexedCount => _cachedIndex?.length ?? 0;

  /// Clears in-memory index (useful in tests or when refreshing).
  void clearMemoryIndex() {
    _cachedIndex = null;
  }

  /// Explicitly sets the in-memory index (primarily for fast unit testing).
  @visibleForTesting
  void setIndexForTesting(List<IndexedAnimeWork> index) {
    _cachedIndex = index;
  }

  /// Loads the Anitabi index (`g.json`), caching the parsed result in memory.
  ///
  /// Uses existing disk cache when available, otherwise downloads `g.json`.
  /// Runs JSON decoding and indexing in a background isolate via [compute].
  Future<List<IndexedAnimeWork>> loadIndex({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedIndex != null) {
      return _cachedIndex!;
    }

    if (_isIndexing) {
      while (_isIndexing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_cachedIndex != null) return _cachedIndex!;
    }

    _isIndexing = true;
    try {
      final dir = await _cacheDir();
      final file = File(p.join(dir.path, 'g.json'));

      String jsonString;
      if (!forceRefresh && await file.exists()) {
        jsonString = await file.readAsString();
      } else {
        final staticData = _staticData ??
            AnitabiStaticData(
              client: _client ?? http.Client(),
              cacheDir: _cacheDir,
            );
        try {
          // Use work lookup or internal download logic via AnitabiStaticData
          final raw = await file.exists() ? await file.readAsString() : null;
          if (raw != null && raw.isNotEmpty) {
            jsonString = raw;
          } else {
            // Trigger load through static data
            await staticData.work('0'); // touches/caches g.json
            if (await file.exists()) {
              jsonString = await file.readAsString();
            } else {
              jsonString = '[]';
            }
          }
        } catch (_) {
          if (await file.exists()) {
            jsonString = await file.readAsString();
          } else {
            jsonString = '[]';
          }
        }
      }

      final parsed = await compute(_parseIndexJson, jsonString);
      _cachedIndex = parsed;
      return parsed;
    } finally {
      _isIndexing = false;
    }
  }

  /// Searches anime by keyword with multilingual and fuzzy ranking.
  ///
  /// If the local index is loaded or can be loaded, searches offline.
  /// When [fallbackToBangumi] is true and offline search yields 0 results,
  /// queries [BangumiSearchService.searchByName] as an online fallback.
  Future<List<IndexedAnimeWork>> search(
    String query, {
    int limit = 30,
    bool fallbackToBangumi = true,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    List<IndexedAnimeWork> index;
    try {
      index = await loadIndex();
    } catch (_) {
      index = _cachedIndex ?? const [];
    }

    final scored = <({IndexedAnimeWork work, int score})>[];

    for (final work in index) {
      final score = work.calculateRelevance(trimmed);
      if (score > 0) {
        scored.add((work: work, score: score));
      }
    }

    if (scored.isNotEmpty) {
      scored.sort((a, b) {
        final cmp = b.score.compareTo(a.score);
        if (cmp != 0) return cmp;
        return b.work.spotCount.compareTo(a.work.spotCount);
      });

      return scored.take(limit).map((e) => e.work).toList();
    }

    // Fallback to Bangumi API if local index found nothing
    if (fallbackToBangumi) {
      try {
        final bgmResults = await BangumiSearchService.searchByName(
          trimmed,
          limit: limit,
          client: _client,
        );
        return bgmResults
            .map((b) => IndexedAnimeWork(
                  bangumiId: b.id,
                  japaneseTitle: b.name,
                  chineseTitle: b.nameCn ?? b.name,
                  traditionalTitle: b.nameCn ?? b.name,
                  spotCount: 0,
                  coverUrl: b.imageUrl,
                  platform: b.platform,
                ))
            .toList();
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  /// Convenience search returning [BangumiSubject]s for UI compatibility.
  Future<List<BangumiSubject>> searchAsSubjects(
    String query, {
    int limit = 30,
  }) async {
    final works = await search(query, limit: limit);
    return works.map((w) => w.toBangumiSubject()).toList();
  }
}

/// Parsing function executed in isolate via compute.
List<IndexedAnimeWork> _parseIndexJson(String jsonString) {
  if (jsonString.isEmpty || jsonString == '[]') return const [];
  try {
    final decoded = jsonDecode(jsonString);
    if (decoded is! List || decoded.isEmpty) return const [];

    final works = decoded[0];
    if (works is! List) return const [];

    final results = <IndexedAnimeWork>[];
    for (final row in works) {
      if (row is List && row.isNotEmpty) {
        results.add(IndexedAnimeWork.fromAnitabiRow(row));
      }
    }
    return results;
  } catch (_) {
    return const [];
  }
}
