import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../models/pilgrimage_stats_models.dart';
import '../services/pilgrimage_analytics_service.dart';

/// Provider for the singleton [PilgrimageAnalyticsService].
final pilgrimageAnalyticsServiceProvider =
    Provider<PilgrimageAnalyticsService>((ref) {
  return const PilgrimageAnalyticsService();
});

/// FutureProvider computing overall quantitative library stats.
final overallPilgrimageSummaryProvider =
    FutureProvider<OverallPilgrimageSummary>((ref) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageAnalyticsServiceProvider);
  return service.getLibrarySummary(db);
});

/// FutureProvider computing completion metrics for a single anime by [animeLabelId].
final animeCompletionProvider =
    FutureProvider.family<AnimeCompletionStat?, String>((ref, animeLabelId) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageAnalyticsServiceProvider);
  return service.getAnimeCompletion(db, animeLabelId);
});

/// FutureProvider computing execution stats for a specific [tripId].
final tripCompletionProvider =
    FutureProvider.family<TripCompletionStat, String>((ref, tripId) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageAnalyticsServiceProvider);
  return service.getTripCompletion(db, tripId);
});
