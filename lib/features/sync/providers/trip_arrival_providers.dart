import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_v2_providers.dart';

/// Whether [tripId] was just joined and its days, stops and schedule are
/// still coming down, starting with the current answer.
final tripArrivingProvider = StreamProvider.autoDispose.family<bool, String>((ref, tripId) {
  final engine = ref.watch(syncEngineServiceV2Provider);
  if (engine == null) return Stream.value(false);
  return Stream<bool>.multi((controller) {
    controller.add(engine.isTripArriving(tripId));
    final sub = engine.arrivingStream
        .map((trips) => trips.contains(tripId))
        .listen(controller.add, onError: controller.addError, onDone: controller.close);
    controller.onCancel = sub.cancel;
  }).distinct();
});

/// Trips whose "frames on Google Drive" offer was put off this session.
final drivePromptDismissedProvider = StateProvider<Set<String>>((ref) => const {});
