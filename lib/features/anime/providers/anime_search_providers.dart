import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bangumi_subject.dart';
import '../models/indexed_anime_work.dart';
import '../services/multilingual_anime_search_service.dart';

/// Provider for the singleton/shared [MultilingualAnimeSearchService].
final multilingualAnimeSearchServiceProvider =
    Provider<MultilingualAnimeSearchService>((ref) {
  return MultilingualAnimeSearchService.instance;
});

/// Reactive family provider for searching anime works by query.
final animeSearchQueryProvider =
    FutureProvider.autoDispose.family<List<IndexedAnimeWork>, String>(
        (ref, query) async {
  if (query.trim().isEmpty) return const [];
  final service = ref.watch(multilingualAnimeSearchServiceProvider);
  return service.search(query);
});

/// Reactive family provider for searching anime as [BangumiSubject]s
/// (ready for UI components like AnitabiImportScreen).
final animeSubjectSearchProvider =
    FutureProvider.autoDispose.family<List<BangumiSubject>, String>(
        (ref, query) async {
  if (query.trim().isEmpty) return const [];
  final service = ref.watch(multilingualAnimeSearchServiceProvider);
  return service.searchAsSubjects(query);
});
