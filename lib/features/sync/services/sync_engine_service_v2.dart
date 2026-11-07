import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import 'firestore_sync_v2_service.dart';

enum TripSyncStatus {
  synced,
  pending,
  offline,
  error,
}

/// Orchestrates two-way synchronization for V10 tables (Trips, Days, Stops, ScheduleItems).
class SyncEngineServiceV2 {
  bool _isPermanentError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('permission-denied') ||
        str.contains('permission_denied') ||
        str.contains('invalid-argument') ||
        str.contains('invalid_argument');
  }

  final AppDatabase localDb;
  final FirestoreSyncV2Service firestoreSync;
  final String currentUserId;

  StreamSubscription? _tripWatcherSub;
  StreamSubscription? _dayWatcherSub;
  StreamSubscription? _stopWatcherSub;
  StreamSubscription? _scheduleWatcherSub;
  StreamSubscription? _userTripsSub;

  final Map<String, StreamSubscription> _subcollectionSubs = {};
  final Map<String, TripSyncStatus> _tripStatuses = {};
  final StreamController<Map<String, TripSyncStatus>> _statusController =
      StreamController<Map<String, TripSyncStatus>>.broadcast();

  /// Buffers for subcollection snapshots that arrive before their parent rows exist locally.
  final Map<String, Map<String, dynamic>> _pendingRemoteDays = {};
  final Map<String, Map<String, dynamic>> _pendingRemoteStops = {};
  final Map<String, Map<String, dynamic>> _pendingRemoteItems = {};

  Timer? _debounceTimer;
  Timer? _retryTimer;
  final Set<String> _pendingTripIdsToPush = <String>{};
  bool _isPushing = false;
  bool _isStopped = false;

  /// Tracks trip IDs that have appeared in server snapshots for the current user session,
  /// used to safely detect access loss without misinterpreting local cache misses or trips
  /// belonging to other accounts on the same device.
  final Set<String> _knownServerTripIds = {};

  /// Chains to guarantee serialized processing of remote stream snapshots per collection.
  Future<void> _userTripsChain = Future.value();
  final Map<String, Future<void>> _subcollectionChains = {};

  SyncEngineServiceV2({
    required this.localDb,
    required this.firestoreSync,
    required this.currentUserId,
  });

  Stream<Map<String, TripSyncStatus>> get statusStream => _statusController.stream;

  TripSyncStatus getTripSyncStatus(String tripId) {
    return _tripStatuses[tripId] ?? TripSyncStatus.synced;
  }

  void _updateStatus(String tripId, TripSyncStatus status) {
    _tripStatuses[tripId] = status;
    if (!_statusController.isClosed) {
      _statusController.add(Map.unmodifiable(_tripStatuses));
    }
  }

  /// Start bidirectional synchronization.
  void startSync() {
    if (currentUserId.isEmpty || currentUserId == 'guest_local_user') {
      debugPrint('[SyncEngineV2] Unauthenticated or guest mode, sync idle.');
      return;
    }

    _isStopped = false;
    debugPrint('[SyncEngineV2] Starting V10 bidirectional sync orchestrator for user: $currentUserId');

    // 1. Upstream dirty Trips watcher (monitors any dirty trips owned by user, including unshared ones)
    final tripsQuery = localDb.select(localDb.trips)
      ..where((t) => t.syncStatus.equals(1) & (t.ownerId.equals(currentUserId) | t.sharing.equals('group')));
    _tripWatcherSub = tripsQuery.watch().listen((dirtyTrips) {
      if (_isStopped || dirtyTrips.isEmpty) return;
      for (final t in dirtyTrips) {
        _pendingTripIdsToPush.add(t.id);
        _updateStatus(t.id, TripSyncStatus.pending);
      }
      _scheduleDebouncedPush();
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error watching dirty trips: $error\n$stack');
    });

    // 2. Upstream dirty TripDays watcher
    final daysQuery = localDb.select(localDb.tripDays).join([
      innerJoin(localDb.trips, localDb.trips.id.equalsExp(localDb.tripDays.tripId)),
    ])
      ..where(localDb.tripDays.syncStatus.equals(1) &
          localDb.trips.sharing.equals('group'));
    _dayWatcherSub = daysQuery.watch().listen((rows) {
      if (_isStopped || rows.isEmpty) return;
      for (final row in rows) {
        final day = row.readTable(localDb.tripDays);
        _pendingTripIdsToPush.add(day.tripId);
        _updateStatus(day.tripId, TripSyncStatus.pending);
      }
      _scheduleDebouncedPush();
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error watching dirty days: $error\n$stack');
    });

    // 3. Upstream dirty Stops watcher
    final stopsQuery = localDb.select(localDb.stops).join([
      innerJoin(localDb.trips, localDb.trips.id.equalsExp(localDb.stops.tripId)),
    ])
      ..where(localDb.stops.syncStatus.equals(1) &
          localDb.trips.sharing.equals('group'));
    _stopWatcherSub = stopsQuery.watch().listen((rows) {
      if (_isStopped || rows.isEmpty) return;
      for (final row in rows) {
        final stop = row.readTable(localDb.stops);
        _pendingTripIdsToPush.add(stop.tripId);
        _updateStatus(stop.tripId, TripSyncStatus.pending);
      }
      _scheduleDebouncedPush();
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error watching dirty stops: $error\n$stack');
    });

    // 4. Upstream dirty ScheduleItems watcher
    final scheduleQuery = localDb.select(localDb.scheduleItems).join([
      innerJoin(localDb.trips, localDb.trips.id.equalsExp(localDb.scheduleItems.tripId)),
    ])
      ..where(localDb.scheduleItems.syncStatus.equals(1) &
          localDb.trips.sharing.equals('group'));
    _scheduleWatcherSub = scheduleQuery.watch().listen((rows) {
      if (_isStopped || rows.isEmpty) return;
      for (final row in rows) {
        final item = row.readTable(localDb.scheduleItems);
        _pendingTripIdsToPush.add(item.tripId);
        _updateStatus(item.tripId, TripSyncStatus.pending);
      }
      _scheduleDebouncedPush();
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error watching dirty schedule items: $error\n$stack');
    });

    // 5. Downstream watchUserTrips listener (serialized)
    _userTripsSub = firestoreSync.watchUserTrips(currentUserId).listen(
      (snapshot) {
        if (_isStopped) return;
        _userTripsChain = _userTripsChain.then((_) async {
          if (_isStopped) return;

          final remoteTrips = snapshot.trips;
          // Never cast blindly: a single malformed doc must not throw and stall the chain.
          final currentTripIds = remoteTrips.map((t) => t['id']).whereType<String>().where((id) => id.isNotEmpty).toSet();

          // Only server snapshots can confirm a removal. Local cache misses must never trigger conversions.
          // Furthermore, only trips that were previously part of this account's server snapshots are converted,
          // preventing cross-account contamination when switching accounts on the same device.
          if (!snapshot.isFromCache) {
            final lostTripIds = _knownServerTripIds.difference(currentTripIds);
            for (final tripId in lostTripIds) {
              final localTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
              if (localTrip != null && localTrip.sharing == 'group' && localTrip.ownerId != currentUserId) {
                try {
                  await _convertCollaboratorTripToPrivate(tripId, DateTime.now());
                } catch (e, stack) {
                  debugPrint('[SyncEngineV2] Error converting lost trip $tripId to private: $e\n$stack');
                }
              }
            }
            _knownServerTripIds
              ..removeAll(lostTripIds)
              ..addAll(currentTripIds);
          } else {
            _knownServerTripIds.addAll(currentTripIds);
          }

          for (final remoteTrip in remoteTrips) {
            final rawId = remoteTrip['id'];
            if (rawId is! String || rawId.isEmpty) continue;
            final tripId = rawId;

            try {
              final keepWatching = await _applyRemoteTrip(remoteTrip);
              if (keepWatching && !_isStopped) {
                _ensureSubcollectionWatchers(tripId);
              }
            } catch (e, stack) {
              debugPrint('[SyncEngineV2] Error applying remote trip $tripId: $e\n$stack');
            }
          }
        }).catchError((Object e, StackTrace stack) {
          // Keep the serialized chain alive: an errored Future here would make
          // every later snapshot's .then() a no-op until the app restarts.
          debugPrint('[SyncEngineV2] Error processing user trips snapshot: $e\n$stack');
        });
      },
      onError: (error, stack) {
        debugPrint('[SyncEngineV2] Error in watchUserTrips: $error\n$stack');
      },
    );
  }

  void _scheduleDebouncedPush() {
    if (_isStopped) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_isStopped) {
        _executePush();
      }
    });
  }

  /// Turn a private trip into a shared group trip.
  Future<void> shareTrip(String tripId) async {
    final trip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) return;

    // Mark trip and all contained components dirty with sharing = 'group'
    await localDb.transaction(() async {
      await (localDb.update(localDb.trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(
          sharing: const Value('group'),
          syncStatus: const Value(1),
          updatedAt: Value(DateTime.now()),
          updatedBy: Value(currentUserId),
        ),
      );

      await (localDb.update(localDb.tripDays)..where((d) => d.tripId.equals(tripId))).write(
        TripDaysCompanion(
          syncStatus: const Value(1),
          updatedAt: Value(DateTime.now()),
          updatedBy: Value(currentUserId),
        ),
      );

      await (localDb.update(localDb.stops)..where((s) => s.tripId.equals(tripId))).write(
        StopsCompanion(
          syncStatus: const Value(1),
          updatedAt: Value(DateTime.now()),
          updatedBy: Value(currentUserId),
        ),
      );

      await (localDb.update(localDb.scheduleItems)..where((i) => i.tripId.equals(tripId))).write(
        ScheduleItemsCompanion(
          syncStatus: const Value(1),
          updatedAt: Value(DateTime.now()),
          updatedBy: Value(currentUserId),
        ),
      );
    });

    _updateStatus(tripId, TripSyncStatus.pending);
    _pendingTripIdsToPush.add(tripId);
    _scheduleDebouncedPush();
  }

  /// Push dirty records to Firestore, chunking batches under Firestore's 500-op limit.
  /// Never await remote calls inside local transactions.
  Future<void> _executePush() async {
    if (_isStopped || _isPushing || _pendingTripIdsToPush.isEmpty) return;
    _isPushing = true;

    final tripIds = Set<String>.from(_pendingTripIdsToPush);
    _pendingTripIdsToPush.clear();

    const maxBatchOps = 450;
    bool hasOfflineErrors = false;

    for (final tripId in tripIds) {
      if (_isStopped) break;
      try {
        final trip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
        if (trip == null) continue;

        // If unshared (sharing != 'group'), push the unshared state to cloud if it was previously in cloud
        if (trip.sharing != 'group') {
          if (trip.syncStatus == 1) {
            final existsInCloud = await firestoreSync.tripExists(tripId);
            if (existsInCloud) {
              final batch = firestoreSync.createBatch();
              firestoreSync.buildTripBatchOperations(batch, trip);
              await firestoreSync.commitBatch(batch);
              if (_isStopped) break;
              _cancelSubcollectionWatchers(tripId);
            }
            await localDb.transaction(() async {
              await (localDb.update(localDb.trips)
                    ..where((t) => t.id.equals(tripId) & t.updatedAt.equalsValue(trip.updatedAt)))
                  .write(const TripsCompanion(syncStatus: Value(0)));
            });
            _updateStatus(tripId, TripSyncStatus.synced);
          }
          continue;
        }

        final dirtyDays = await (localDb.select(localDb.tripDays)
              ..where((d) => d.tripId.equals(tripId) & d.syncStatus.equals(1)))
            .get();

        final dirtyStops = await (localDb.select(localDb.stops)
              ..where((s) => s.tripId.equals(tripId) & s.syncStatus.equals(1)))
            .get();

        final dirtyItems = await (localDb.select(localDb.scheduleItems)
              ..where((i) => i.tripId.equals(tripId) & i.syncStatus.equals(1)))
            .get();

        if (trip.syncStatus != 1 && dirtyDays.isEmpty && dirtyStops.isEmpty && dirtyItems.isEmpty) {
          _updateStatus(tripId, TripSyncStatus.synced);
          continue;
        }

        // Ensure cloud trip and owner member doc exist before pushing subcollections
        if (!await firestoreSync.tripExists(tripId)) {
          await firestoreSync.initializeCloudTrip(trip, currentUserId);
        }

        if (_isStopped) break;

        var batch = firestoreSync.createBatch();
        var opCount = 0;

        Future<void> flushIfFull() async {
          if (opCount >= maxBatchOps) {
            await firestoreSync.commitBatch(batch);
            batch = firestoreSync.createBatch();
            opCount = 0;
          }
        }

        // 1. Trip doc
        if (trip.syncStatus == 1) {
          firestoreSync.buildTripBatchOperations(batch, trip);
          opCount++;
          await flushIfFull();
        }

        // 2. Days
        for (final day in dirtyDays) {
          firestoreSync.buildDayBatchOperations(batch, day);
          opCount++;
          await flushIfFull();
        }

        // 3. Stops (with labels and URL-backed reference images)
        for (final stop in dirtyStops) {
          final stopLabelLinks = await (localDb.select(localDb.stopLabels)
                ..where((sl) => sl.stopId.equals(stop.id)))
              .get();
          final labelIds = stopLabelLinks.map((sl) => sl.labelId).toList();
          final labels = labelIds.isEmpty
              ? <Label>[]
              : await (localDb.select(localDb.labels)
                    ..where((l) => l.id.isIn(labelIds)))
                  .get();

          final refImages = await (localDb.select(localDb.newReferenceImages)
                ..where((r) => r.stopId.equals(stop.id)))
              .get();

          firestoreSync.buildStopBatchOperations(
            batch,
            stop,
            labels: labels,
            referenceImages: refImages,
          );
          opCount++;
          await flushIfFull();
        }

        // 4. Schedule items
        for (final item in dirtyItems) {
          firestoreSync.buildScheduleItemBatchOperations(batch, item);
          opCount++;
          await flushIfFull();
        }

        // Remote commit outside transaction
        if (opCount > 0) {
          await firestoreSync.commitBatch(batch);
        }

        if (_isStopped) break;

        // Mark local records as synced ONLY if their updatedAt has not changed
        // since the snapshot was read (protects concurrent edits made during commitBatch).
        await localDb.transaction(() async {
          if (trip.syncStatus == 1) {
            await (localDb.update(localDb.trips)
                  ..where((t) => t.id.equals(tripId) & t.updatedAt.equalsValue(trip.updatedAt)))
                .write(const TripsCompanion(syncStatus: Value(0)));
          }

          for (final day in dirtyDays) {
            await (localDb.update(localDb.tripDays)
                  ..where((d) => d.id.equals(day.id) & d.updatedAt.equalsValue(day.updatedAt)))
                .write(const TripDaysCompanion(syncStatus: Value(0)));
          }

          for (final stop in dirtyStops) {
            await (localDb.update(localDb.stops)
                  ..where((s) => s.id.equals(stop.id) & s.updatedAt.equalsValue(stop.updatedAt)))
                .write(const StopsCompanion(syncStatus: Value(0)));
          }

          for (final item in dirtyItems) {
            await (localDb.update(localDb.scheduleItems)
                  ..where((i) => i.id.equals(item.id) & i.updatedAt.equalsValue(item.updatedAt)))
                .write(const ScheduleItemsCompanion(syncStatus: Value(0)));
          }
        });

        // Check if any concurrent edits occurred while the batch was in flight
        final remainingDirtyTrip = await (localDb.select(localDb.trips)
              ..where((t) => t.id.equals(tripId) & t.syncStatus.equals(1)))
            .getSingleOrNull();
        final remainingDirtyDays = await (localDb.select(localDb.tripDays)
              ..where((d) => d.tripId.equals(tripId) & d.syncStatus.equals(1)))
            .get();
        final remainingDirtyStops = await (localDb.select(localDb.stops)
              ..where((s) => s.tripId.equals(tripId) & s.syncStatus.equals(1)))
            .get();
        final remainingDirtyItems = await (localDb.select(localDb.scheduleItems)
              ..where((i) => i.tripId.equals(tripId) & i.syncStatus.equals(1)))
            .get();

        final hasRemainingDirty = remainingDirtyTrip != null ||
            remainingDirtyDays.isNotEmpty ||
            remainingDirtyStops.isNotEmpty ||
            remainingDirtyItems.isNotEmpty;

        if (hasRemainingDirty) {
          _pendingTripIdsToPush.add(tripId);
          _updateStatus(tripId, TripSyncStatus.pending);
        } else {
          _updateStatus(tripId, TripSyncStatus.synced);
        }
      } catch (e, stack) {
        debugPrint('[SyncEngineV2] Push failed for trip $tripId: $e\n$stack');
        if (_isPermanentError(e)) {
          _updateStatus(tripId, TripSyncStatus.error);
        } else {
          _updateStatus(tripId, TripSyncStatus.offline);
          _pendingTripIdsToPush.add(tripId);
          hasOfflineErrors = true;
        }
      }
    }

    _isPushing = false;
    if (_isStopped) return;

    if (hasOfflineErrors) {
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 1000), () {
        if (!_isStopped) _executePush();
      });
    } else if (_pendingTripIdsToPush.isNotEmpty) {
      _scheduleDebouncedPush();
    }
  }

  /// Stop all listeners and timers.
  void stopSync() {
    debugPrint('[SyncEngineV2] Stopping sync orchestrator...');
    _isStopped = true;
    _knownServerTripIds.clear();
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _pendingTripIdsToPush.clear();

    _tripWatcherSub?.cancel();
    _tripWatcherSub = null;
    _dayWatcherSub?.cancel();
    _dayWatcherSub = null;
    _stopWatcherSub?.cancel();
    _stopWatcherSub = null;
    _scheduleWatcherSub?.cancel();
    _scheduleWatcherSub = null;
    _userTripsSub?.cancel();
    _userTripsSub = null;

    for (final sub in _subcollectionSubs.values) {
      sub.cancel();
    }
    _subcollectionSubs.clear();
    _subcollectionChains.clear();
  }

  /// Parse Firestore Timestamp or ISO8601 string or DateTime.
  DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }

  /// Applies a remote trip document snapshot to Drift.
  /// Returns `true` if downstream subcollection listeners should remain active,
  /// or `false` if the trip was tombstoned/privatized.
  Future<bool> _applyRemoteTrip(Map<String, dynamic> remoteData) async {
    final rawId = remoteData['id'];
    if (rawId is! String || rawId.isEmpty) return false;
    final tripId = rawId;

    final remoteUpdatedAt = _parseTimestamp(remoteData['updatedAt']);
    final deletedAt = _parseTimestamp(remoteData['deletedAt']);
    final remoteOwnerId = remoteData['ownerId'] as String? ?? currentUserId;
    final remoteSharing = remoteData['sharing'] as String? ?? 'group';

    final localTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();

    // If local trip is already private and not owned by remoteOwner, it's a private collaborator copy.
    if (localTrip != null && localTrip.sharing == 'private' && remoteOwnerId != currentUserId) {
      _cancelSubcollectionWatchers(tripId);
      return false;
    }

    // Per `docs/trip-sharing.md` & `docs/mvp-plan.md`:
    // "When the owner stops sharing or deletes the trip, every other member keeps a private, unsynced copy."
    final isCollaboratorCopy = localTrip != null &&
        localTrip.ownerId != currentUserId &&
        remoteOwnerId != currentUserId;
    if (isCollaboratorCopy && (deletedAt != null || remoteSharing == 'private')) {
      await _convertCollaboratorTripToPrivate(tripId, remoteUpdatedAt);
      return false;
    }

    if (deletedAt != null) {
      _cancelSubcollectionWatchers(tripId);
      await localDb.transaction(() async {
        await (localDb.update(localDb.trips)..where((t) => t.id.equals(tripId))).write(
          TripsCompanion(
            deletedAt: Value(deletedAt),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            syncStatus: const Value(0),
          ),
        );
      });
      return false;
    }

    final tripCompanion = TripsCompanion(
      id: Value(tripId),
      title: Value(remoteData['title'] as String? ?? 'Untitled Trip'),
      description: Value(remoteData['description'] as String?),
      ownerId: Value(remoteOwnerId),
      sharing: Value(remoteSharing),
      startDate: Value(remoteData['startDate'] as String?),
      dayCount: Value((remoteData['dayCount'] as num?)?.toInt() ?? 1),
      updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
      updatedBy: Value(remoteData['updatedBy'] as String?),
      deletedAt: const Value(null),
      syncStatus: const Value(0),
    );

    await localDb.transaction(() async {
      final current = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
      if (current != null) {
        if (remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(current.updatedAt)) {
          return;
        }
        await (localDb.update(localDb.trips)
              ..where((t) => t.id.equals(tripId) & t.updatedAt.isSmallerThanValue((remoteUpdatedAt ?? DateTime.now()).millisecondsSinceEpoch)))
            .write(tripCompanion);
      } else {
        await localDb.into(localDb.trips).insert(tripCompanion, mode: InsertMode.insertOrIgnore);
      }
    });

    await _flushPendingForTrip(tripId);
    return true;
  }

  void _cancelSubcollectionWatchers(String tripId) {
    for (final suffix in ['days', 'stops', 'items']) {
      _subcollectionSubs.remove('$tripId:$suffix')?.cancel();
      _subcollectionChains.remove('$tripId:$suffix');
    }
  }

  /// Ensure downstream watchers for subcollections (days, stops, schedule_items).
  void _ensureSubcollectionWatchers(String tripId) {
    if (_subcollectionSubs.containsKey('$tripId:days')) return;

    // Days watcher
    _subcollectionChains['$tripId:days'] = Future.value();
    _subcollectionSubs['$tripId:days'] = firestoreSync.watchTripDays(tripId).listen((daysList) {
      if (_isStopped) return;
      final chain = _subcollectionChains['$tripId:days'] ?? Future.value();
      _subcollectionChains['$tripId:days'] = chain.then((_) async {
        if (_isStopped) return;
        for (final dayData in daysList) {
          try {
            await _applyRemoteDay(tripId, dayData);
          } catch (e, stack) {
            debugPrint('[SyncEngineV2] Error applying remote day: $e\n$stack');
          }
        }
      }).catchError((Object e, StackTrace stack) {
        debugPrint('[SyncEngineV2] Error in days chain for $tripId: $e\n$stack');
      });
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error in watchTripDays for $tripId: $error');
      if (_isPermanentError(error)) {
        _subcollectionSubs.remove('$tripId:days')?.cancel();
      }
    });

    // Stops watcher
    _subcollectionChains['$tripId:stops'] = Future.value();
    _subcollectionSubs['$tripId:stops'] = firestoreSync.watchTripStops(tripId).listen((stopsList) {
      if (_isStopped) return;
      final chain = _subcollectionChains['$tripId:stops'] ?? Future.value();
      _subcollectionChains['$tripId:stops'] = chain.then((_) async {
        if (_isStopped) return;
        for (final stopData in stopsList) {
          try {
            await _applyRemoteStop(tripId, stopData);
          } catch (e, stack) {
            debugPrint('[SyncEngineV2] Error applying remote stop: $e\n$stack');
          }
        }
      }).catchError((Object e, StackTrace stack) {
        debugPrint('[SyncEngineV2] Error in stops chain for $tripId: $e\n$stack');
      });
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error in watchTripStops for $tripId: $error');
      if (_isPermanentError(error)) {
        _subcollectionSubs.remove('$tripId:stops')?.cancel();
      }
    });

    // Schedule items watcher
    _subcollectionChains['$tripId:items'] = Future.value();
    _subcollectionSubs['$tripId:items'] = firestoreSync.watchTripScheduleItems(tripId).listen((itemsList) {
      if (_isStopped) return;
      final chain = _subcollectionChains['$tripId:items'] ?? Future.value();
      _subcollectionChains['$tripId:items'] = chain.then((_) async {
        if (_isStopped) return;
        for (final itemData in itemsList) {
          try {
            await _applyRemoteScheduleItem(tripId, itemData);
          } catch (e, stack) {
            debugPrint('[SyncEngineV2] Error applying remote schedule item: $e\n$stack');
          }
        }
      }).catchError((Object e, StackTrace stack) {
        debugPrint('[SyncEngineV2] Error in items chain for $tripId: $e\n$stack');
      });
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error in watchTripScheduleItems for $tripId: $error');
      if (_isPermanentError(error)) {
        _subcollectionSubs.remove('$tripId:items')?.cancel();
      }
    });
  }

  /// Flushes any buffered subcollection documents for [tripId] whose parent rows now exist.
  Future<void> _flushPendingForTrip(String tripId) async {
    final pendingDays = _pendingRemoteDays.values
        .where((d) => d['tripId'] == tripId)
        .toList();
    for (final dayData in pendingDays) {
      await _applyRemoteDay(tripId, dayData);
    }

    final pendingStops = _pendingRemoteStops.values
        .where((s) => s['tripId'] == tripId)
        .toList();
    for (final stopData in pendingStops) {
      await _applyRemoteStop(tripId, stopData);
    }

    final pendingItems = _pendingRemoteItems.values
        .where((i) => i['tripId'] == tripId)
        .toList();
    for (final itemData in pendingItems) {
      await _applyRemoteScheduleItem(tripId, itemData);
    }
  }

  Future<void> _applyRemoteDay(String tripId, Map<String, dynamic> data) async {
    final dayId = data['id'] as String?;
    if (dayId == null || dayId.isEmpty) return;

    // Ensure parent trip exists locally before inserting child day
    final parentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (parentTrip == null) {
      _pendingRemoteDays[dayId] = data;
      return;
    }
    if (parentTrip.sharing == 'private') {
      return;
    }
    _pendingRemoteDays.remove(dayId);

    final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);
    final deletedAt = _parseTimestamp(data['deletedAt']);

    final companion = TripDaysCompanion(
      id: Value(dayId),
      tripId: Value(tripId),
      sortKey: Value(data['sortKey'] as String? ?? 'a0'),
      title: Value(data['title'] as String?),
      pinnedDate: Value(data['pinnedDate'] as String?),
      updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
      updatedBy: Value(data['updatedBy'] as String?),
      deletedAt: Value(deletedAt),
      syncStatus: const Value(0),
    );

    await localDb.transaction(() async {
      final currentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
      if (currentTrip == null || currentTrip.sharing == 'private') return;

      final localDay = await (localDb.select(localDb.tripDays)..where((d) => d.id.equals(dayId))).getSingleOrNull();
      if (localDay != null) {
        if (localDay.tripId != tripId) return;
        if (remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localDay.updatedAt)) {
          return;
        }
        await (localDb.update(localDb.tripDays)
              ..where((d) => d.id.equals(dayId) & d.tripId.equals(tripId) & d.updatedAt.isSmallerThanValue((remoteUpdatedAt ?? DateTime.now()).millisecondsSinceEpoch)))
            .write(companion);
      } else {
        await localDb.into(localDb.tripDays).insert(companion, mode: InsertMode.insertOrIgnore);
      }
    });

    await _flushPendingScheduleItemsForParent(tripId);
  }

  Future<void> _applyRemoteStop(String tripId, Map<String, dynamic> data) async {
    final stopId = data['id'] as String?;
    if (stopId == null || stopId.isEmpty) return;

    // Ensure parent trip exists locally before inserting child stop
    final parentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (parentTrip == null) {
      _pendingRemoteStops[stopId] = data;
      return;
    }
    if (parentTrip.sharing == 'private') {
      return;
    }
    _pendingRemoteStops.remove(stopId);

    final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);
    final deletedAt = _parseTimestamp(data['deletedAt']);

    final companion = StopsCompanion(
      id: Value(stopId),
      tripId: Value(tripId),
      placeKey: Value(data['placeKey'] as String? ?? ''),
      name: Value(data['name'] as String? ?? ''),
      lat: Value((data['lat'] as num?)?.toDouble() ?? 0.0),
      lng: Value((data['lng'] as num?)?.toDouble() ?? 0.0),
      description: Value(data['description'] as String?),
      address: Value(data['address'] as String?),
      businessHours: Value(data['businessHours'] as String?),
      contactInfo: Value(data['contactInfo'] as String?),
      accessTips: Value(data['accessTips'] as String?),
      links: Value(data['links'] as String?),
      coverRemoteUrl: Value(data['coverRemoteUrl'] as String?),
      source: Value(data['source'] as String?),
      sourceUrl: Value(data['sourceUrl'] as String?),
      area: Value(data['area'] as String?),
      note: Value(data['note'] as String?),
      addedBy: Value(data['addedBy'] as String? ?? currentUserId),
      updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
      updatedBy: Value(data['updatedBy'] as String?),
      deletedAt: Value(deletedAt),
      syncStatus: const Value(0),
    );

    await localDb.transaction(() async {
      final currentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
      if (currentTrip == null || currentTrip.sharing == 'private') return;

      final localStop = await (localDb.select(localDb.stops)..where((s) => s.id.equals(stopId))).getSingleOrNull();
      if (localStop != null) {
        if (localStop.tripId != tripId) return;
        if (remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localStop.updatedAt)) {
          return;
        }
        final updated = await (localDb.update(localDb.stops)
              ..where((s) => s.id.equals(stopId) & s.tripId.equals(tripId) & s.updatedAt.isSmallerThanValue((remoteUpdatedAt ?? DateTime.now()).millisecondsSinceEpoch)))
            .write(companion);
        if (updated == 0) return;
      } else {
        await localDb.into(localDb.stops).insert(companion, mode: InsertMode.insertOrIgnore);
      }

      // Sync labels by natural key inside the same transaction
      final senderToLocalLabelId = <String, String>{};
      final matchedAnimeLabelIds = <String>[];
      final labelsRaw = data['labels'] as List?;
      if (labelsRaw != null) {
        await (localDb.delete(localDb.stopLabels)..where((sl) => sl.stopId.equals(stopId))).go();

        for (final raw in labelsRaw) {
          if (raw is! Map) continue;
          final kind = raw['kind'] as String? ?? 'tag';
          final name = raw['name'] as String? ?? '';
          final bangumiId = raw['bangumiId'] as String?;

          // Lookup existing label first with limit(1) to avoid Bad state: Too many elements (N1, N1b)
          Label? label;
          if (bangumiId != null && bangumiId.isNotEmpty) {
            label = await (localDb.select(localDb.labels)
                  ..where((l) => l.bangumiId.equals(bangumiId))
                  ..limit(1))
                .getSingleOrNull();
          }
          if (label == null) {
            label = await (localDb.select(localDb.labels)
                  ..where((l) => l.kind.equals(kind) & l.name.equals(name))
                  ..limit(1))
                .getSingleOrNull();
            if (label != null && label.bangumiId == null && bangumiId != null && bangumiId.isNotEmpty) {
              await (localDb.update(localDb.labels)..where((l) => l.id.equals(label!.id)))
                  .write(LabelsCompanion(bangumiId: Value(bangumiId)));
              label = label.copyWith(bangumiId: Value(bangumiId));
            }
          }

          if (label == null) {
            final newId = const Uuid().v4();
            await localDb.into(localDb.labels).insert(
                  LabelsCompanion(
                    id: Value(newId),
                    kind: Value(kind),
                    name: Value(name),
                    bangumiId: Value(bangumiId),
                    createdAt: Value(DateTime.now()),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
            label = await (localDb.select(localDb.labels)
                  ..where((l) => l.id.equals(newId))
                  ..limit(1))
                .getSingleOrNull();
          }

          if (label != null) {
            if (raw['id'] is String) {
              senderToLocalLabelId[raw['id'] as String] = label.id;
            }
            if (kind == 'anime') {
              matchedAnimeLabelIds.add(label.id);
            }
            await localDb.into(localDb.stopLabels).insert(
                  StopLabelsCompanion(
                    stopId: Value(stopId),
                    labelId: Value(label.id),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
          }
        }
      }

      // Sync URL-backed reference images
      final refImagesRaw = data['referenceImages'] as List?;
      if (refImagesRaw != null) {
        final existingRefs = await (localDb.select(localDb.newReferenceImages)
              ..where((r) => r.stopId.equals(stopId)))
            .get();
        final existingById = {for (final r in existingRefs) r.id: r};
        final existingByUrl = {
          for (final r in existingRefs)
            if (r.remoteUrl != null && r.remoteUrl!.isNotEmpty) r.remoteUrl!: r,
        };

        final incomingIds = <String>{};
        for (final raw in refImagesRaw) {
          if (raw is! Map) continue;
          final remoteUrl = raw['remoteUrl'] as String?;
          if (remoteUrl == null || remoteUrl.isEmpty) continue;
          final existingMatch = (raw['id'] is String ? existingById[raw['id']] : null) ??
              existingByUrl[remoteUrl];
          final imgId = existingMatch?.id ?? (raw['id'] as String?) ?? const Uuid().v4();
          incomingIds.add(imgId);

          // Resolve sender's animeLabelId to a valid local Labels.id
          final rawAnimeLabelId = raw['animeLabelId'] as String?;
          String? resolvedAnimeLabelId;
          if (rawAnimeLabelId != null && rawAnimeLabelId.isNotEmpty) {
            resolvedAnimeLabelId = senderToLocalLabelId[rawAnimeLabelId];
            if (resolvedAnimeLabelId == null) {
              final localLabel = await (localDb.select(localDb.labels)
                    ..where((l) => l.id.equals(rawAnimeLabelId))
                    ..limit(1))
                  .getSingleOrNull();
              resolvedAnimeLabelId = localLabel?.id;
            }
          }
          resolvedAnimeLabelId ??=
              matchedAnimeLabelIds.length == 1 ? matchedAnimeLabelIds.first : null;

          await localDb.into(localDb.newReferenceImages).insertOnConflictUpdate(
                NewReferenceImagesCompanion.insert(
                  id: imgId,
                  placeKey: Value(existingMatch?.placeKey),
                  stopId: Value(stopId),
                  localPath: Value(existingMatch?.localPath),
                  remoteUrl: Value(remoteUrl),
                  animeLabelId: Value(resolvedAnimeLabelId),
                  episode: Value(raw['episode'] as String?),
                  timestampS: Value((raw['timestampS'] as num?)?.toInt()),
                  source: Value(raw['source'] as String?),
                  sourceUrl: Value(raw['sourceUrl'] as String?),
                ),
              );
        }

        // Remove URL-backed reference images that were deleted remotely, keeping local-only ones
        for (final existing in existingRefs) {
          final isUrlBacked = existing.remoteUrl != null && existing.remoteUrl!.isNotEmpty;
          if (isUrlBacked && !incomingIds.contains(existing.id)) {
            await (localDb.delete(localDb.newReferenceImages)
                  ..where((r) => r.id.equals(existing.id)))
                .go();
          }
        }
      }
    });

    await _flushPendingScheduleItemsForParent(tripId);
  }

  Future<void> _flushPendingScheduleItemsForParent(String tripId) async {
    final pendingItems = _pendingRemoteItems.values
        .where((i) => i['tripId'] == tripId)
        .toList();
    for (final itemData in pendingItems) {
      await _applyRemoteScheduleItem(tripId, itemData);
    }
  }

  Future<void> _applyRemoteScheduleItem(String tripId, Map<String, dynamic> data) async {
    final itemId = data['id'] as String?;
    if (itemId == null || itemId.isEmpty) return;

    final stopId = data['stopId'] as String? ?? '';
    final dayId = data['dayId'] as String? ?? '';

    // Ensure parent trip, day, and stop exist locally before inserting schedule_item (FK safety)
    final parentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    final parentDay = await (localDb.select(localDb.tripDays)..where((d) => d.id.equals(dayId))).getSingleOrNull();
    final parentStop = await (localDb.select(localDb.stops)..where((s) => s.id.equals(stopId))).getSingleOrNull();
    if (parentTrip == null || parentDay == null || parentStop == null) {
      _pendingRemoteItems[itemId] = data;
      return;
    }
    if (parentTrip.sharing == 'private') {
      return;
    }
    _pendingRemoteItems.remove(itemId);

    final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);
    final deletedAt = _parseTimestamp(data['deletedAt']);
    final remoteStatus = data['status'] as String? ?? 'planned';

    await localDb.transaction(() async {
      final currentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
      if (currentTrip == null || currentTrip.sharing == 'private') return;

      final localItem =
          await (localDb.select(localDb.scheduleItems)..where((i) => i.id.equals(itemId))).getSingleOrNull();
      if (localItem != null) {
        if (localItem.tripId != tripId) return;
        if (remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localItem.updatedAt)) {
          return;
        }

        // If local user marked this item done while offline (syncStatus == 1),
        // preserve 'done' over remote 'planned', and keep syncStatus == 1 so the
        // check-in pushes upstream once online.
        final preserveLocalVisited = localItem.syncStatus == 1 &&
            localItem.status == 'done' &&
            remoteStatus == 'planned';

        final effectiveStatus = preserveLocalVisited ? 'done' : remoteStatus;
        final effectiveSyncStatus = preserveLocalVisited ? 1 : 0;
        final effectiveUpdatedAt = preserveLocalVisited
            ? DateTime.now()
            : (remoteUpdatedAt ?? DateTime.now());
        final effectiveUpdatedBy = preserveLocalVisited ? currentUserId : data['updatedBy'] as String?;

        final companion = ScheduleItemsCompanion(
          id: Value(itemId),
          tripId: Value(tripId),
          stopId: Value(stopId),
          dayId: Value(dayId),
          sortKey: Value(data['sortKey'] as String? ?? 'a0'),
          stayMinutes: Value((data['stayMinutes'] as num?)?.toInt() ?? 60),
          transitMinutes: Value((data['transitMinutes'] as num?)?.toInt() ?? 0),
          fixedTime: Value((data['fixedTime'] as num?)?.toInt()),
          status: Value(effectiveStatus),
          updatedAt: Value(effectiveUpdatedAt),
          updatedBy: Value(effectiveUpdatedBy),
          deletedAt: Value(deletedAt),
          syncStatus: Value(effectiveSyncStatus),
        );

        await (localDb.update(localDb.scheduleItems)
              ..where((i) => i.id.equals(itemId) & i.tripId.equals(tripId)))
            .write(companion);

        if (preserveLocalVisited) {
          _pendingTripIdsToPush.add(tripId);
          _scheduleDebouncedPush();
        }
      } else {
        final companion = ScheduleItemsCompanion(
          id: Value(itemId),
          tripId: Value(tripId),
          stopId: Value(stopId),
          dayId: Value(dayId),
          sortKey: Value(data['sortKey'] as String? ?? 'a0'),
          stayMinutes: Value((data['stayMinutes'] as num?)?.toInt() ?? 60),
          transitMinutes: Value((data['transitMinutes'] as num?)?.toInt() ?? 0),
          fixedTime: Value((data['fixedTime'] as num?)?.toInt()),
          status: Value(remoteStatus),
          updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
          updatedBy: Value(data['updatedBy'] as String?),
          deletedAt: Value(deletedAt),
          syncStatus: const Value(0),
        );
        await localDb.into(localDb.scheduleItems).insert(companion, mode: InsertMode.insertOrIgnore);
      }
    });
  }

  /// Converts a collaborator trip to an unsynced private trip when owner deletes or unshares.
  Future<void> _convertCollaboratorTripToPrivate(
    String tripId,
    DateTime? remoteUpdatedAt,
  ) async {
    _cancelSubcollectionWatchers(tripId);
    await localDb.transaction(() async {
      await (localDb.update(localDb.trips)..where((t) => t.id.equals(tripId))).write(
        TripsCompanion(
          ownerId: Value(currentUserId),
          sharing: const Value('private'),
          deletedAt: const Value(null),
          syncStatus: const Value(0),
          updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
        ),
      );
      await (localDb.update(localDb.tripDays)..where((d) => d.tripId.equals(tripId)))
          .write(const TripDaysCompanion(deletedAt: Value(null), syncStatus: Value(0)));
      await (localDb.update(localDb.stops)..where((s) => s.tripId.equals(tripId)))
          .write(const StopsCompanion(deletedAt: Value(null), syncStatus: Value(0)));
      await (localDb.update(localDb.scheduleItems)..where((i) => i.tripId.equals(tripId)))
          .write(const ScheduleItemsCompanion(deletedAt: Value(null), syncStatus: Value(0)));
    });
    _updateStatus(tripId, TripSyncStatus.synced);
  }
}
