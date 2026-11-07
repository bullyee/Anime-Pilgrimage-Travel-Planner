import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../models/travelogue_models.dart';
import '../services/pilgrimage_travelogue_service.dart';

/// Provider for the [PilgrimageTravelogueService] instance.
final pilgrimageTravelogueServiceProvider = Provider<PilgrimageTravelogueService>((ref) {
  return const PilgrimageTravelogueService();
});

/// Compiles and provides a [TravelogueDocument] for a given [tripId].
final tripTravelogueDocumentProvider =
    FutureProvider.autoDispose.family<TravelogueDocument, String>((ref, tripId) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageTravelogueServiceProvider);
  return service.compileTravelogue(db, tripId);
});

/// Compiles and generates Markdown export for a given [tripId].
final tripTravelogueMarkdownProvider =
    FutureProvider.autoDispose.family<String, String>((ref, tripId) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageTravelogueServiceProvider);
  return service.exportTravelogueMarkdown(db, tripId);
});

/// Compiles and generates HTML export for a given [tripId].
final tripTravelogueHtmlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, tripId) async {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(pilgrimageTravelogueServiceProvider);
  return service.exportTravelogueHtml(db, tripId);
});
