import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_provider.dart';
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
  );

  ref.onDispose(() {
    service.stopSync();
  });

  service.startSync();
  return service;
}

/// Stream of sync status for a specific trip (synced, pending, or offline).
@riverpod
Stream<TripSyncStatus> tripSyncStatus(Ref ref, String tripId) {
  final syncEngine = ref.watch(syncEngineServiceV2Provider);
  if (syncEngine == null) {
    return Stream.value(TripSyncStatus.synced);
  }
  return syncEngine.statusStream
      .map((statuses) => statuses[tripId] ?? TripSyncStatus.synced);
}
