import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/utils/browser_info.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/firestore_sync_v2_service.dart';
import '../services/sync_engine_service_v2.dart';

part 'sync_v2_providers.g.dart';

@Riverpod(keepAlive: true)
FirestoreSyncV2Service firestoreSyncV2Service(Ref ref) {
  return FirestoreSyncV2Service(FirebaseFirestore.instance);
}

@Riverpod(keepAlive: true)
SyncEngineServiceV2? syncEngineServiceV2(Ref ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) {
    return null;
  }
  final db = ref.watch(databaseProvider);
  final firestoreSync = ref.watch(firestoreSyncV2ServiceProvider);


  final service = SyncEngineServiceV2(
    localDb: db,
    firestoreSync: firestoreSync,
    currentUserId: user.uid,
    confirmEveryTrip: kIsWeb,
  );

  // On the web, closing the tab while a trip is still coming down asks first.
  final arriving = kIsWeb
      ? service.arrivingStream.listen(
          (trips) => warnBeforeLeaving(trips.isNotEmpty),
          onError: (Object error, StackTrace stack) {
            debugPrint('[SyncEngineV2] Error watching arriving trips: $error\n$stack');
          },
        )
      : null;

  ref.onDispose(() {
    arriving?.cancel();
    if (kIsWeb) warnBeforeLeaving(false);
    service.stopSync();
  });

  service.startSync();
  return service;
}

/// Stream of sync status for a specific trip (synced, pending, offline or
/// error), starting with its current one.
@riverpod
Stream<TripSyncStatus> tripSyncStatus(Ref ref, String tripId) {
  final syncEngine = ref.watch(syncEngineServiceV2Provider);
  if (syncEngine == null) {
    return Stream.value(TripSyncStatus.synced);
  }
  // The engine's stream only reports changes, so a trip that failed before
  // anyone listened would never show it. Reading the current status and
  // subscribing happen in one go, so no change slips in between.
  return Stream<TripSyncStatus>.multi((controller) {
    controller.add(syncEngine.getTripSyncStatus(tripId));
    final sub = syncEngine.statusStream
        .map((statuses) => statuses[tripId] ?? TripSyncStatus.synced)
        .listen(controller.add, onError: controller.addError, onDone: controller.close);
    controller.onCancel = sub.cancel;
  }).distinct();
}
