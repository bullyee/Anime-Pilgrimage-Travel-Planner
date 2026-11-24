import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp, WriteBatch;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../trip/models/stop_group.dart';
import '../../trip/services/trip_activity_log.dart';
import 'firestore_sync_v2_service.dart';

enum TripSyncStatus {
  synced,
  pending,
  offline,
  error,
}

/// Orchestrates two-way synchronization for V10 tables (Trips, Days, Stops, ScheduleItems).
/// A `frameShots` entry from a stop doc as the frame's fields, checked,
/// since any member of the trip writes the doc: a position only as a pair of
/// finite numbers in range, a heading in degrees (wrapped into 0..360), a
/// note of at most [maxFrameNoteLength] characters. A missing or bad value
/// clears the field.
NewReferenceImagesCompanion frameShotFromDoc(Map shot) {
  double? finite(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
  final lat = finite(shot['lat']);
  final lng = finite(shot['lng']);
  final placed = lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;
  final heading = finite(shot['heading']);
  final note = shot['note'] is String ? (shot['note'] as String).trim() : '';
  return NewReferenceImagesCompanion(
    lat: Value(placed ? lat : null),
    lng: Value(placed ? lng : null),
    note: Value(note.isEmpty ? null : clampText(note, maxFrameNoteLength)),
    heading: Value(heading == null ? null : (heading % 360 + 360) % 360),
  );
}

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

  /// Treat every trip as arriving until the server's days, stops and schedule
  /// have been applied, even one with days here already. On the web the
  /// local database (IndexedDB) keeps no promise of durability, so a tab
  /// closed mid-download can leave a trip half there.
  final bool confirmEveryTrip;

  StreamSubscription? _tripWatcherSub;
  StreamSubscription? _dayWatcherSub;
  StreamSubscription? _stopWatcherSub;
  StreamSubscription? _scheduleWatcherSub;
  StreamSubscription? _activityWatcherSub;
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

  /// Trips whose days, stops and schedule are coming down to this device for
  /// the first time (just joined), until the server has sent all three.
  final Set<String> _arriving = {};
  final Map<String, Set<String>> _arrivedParts = {};
  final StreamController<Set<String>> _arrivingController = StreamController<Set<String>>.broadcast();
  static const _parts = {'days', 'stops', 'items'};

  SyncEngineServiceV2({
    required this.localDb,
    required this.firestoreSync,
    required this.currentUserId,
    this.confirmEveryTrip = false,
  });

  Stream<Map<String, TripSyncStatus>> get statusStream => _statusController.stream;

  /// Changes to [isTripArriving], as the set of arriving trips.
  Stream<Set<String>> get arrivingStream => _arrivingController.stream;

  /// Whether [tripId] is new on this device and its plan is still coming down.
  bool isTripArriving(String tripId) => _arriving.contains(tripId);

  void _emitArriving() {
    if (!_arrivingController.isClosed) _arrivingController.add(Set.unmodifiable(_arriving));
  }

  /// A trip with no days here yet (any trip, with [confirmEveryTrip]) is
  /// arriving until each of its parts has come from the server. Parts may
  /// land before this check finishes.
  Future<void> _watchArrival(String tripId) async {
    if (!confirmEveryTrip) {
      final hasDays = await (localDb.select(localDb.tripDays)
            ..where((d) => d.tripId.equals(tripId))
            ..limit(1))
          .getSingleOrNull();
      if (hasDays != null) return;
    }
    if (_isStopped) return;
    if ((_arrivedParts[tripId] ?? const {}).containsAll(_parts)) return;
    _arriving.add(tripId);
    _emitArriving();
  }

  /// [part] of [tripId] is here: from the server, or given up on. A snapshot
  /// from the local cache doesn't count; a plain list (tests) does.
  void _partArrived(String tripId, String part, {List<Map<String, dynamic>>? docs}) {
    if (docs is RemoteDocList && docs.isFromCache) return;
    final parts = _arrivedParts.putIfAbsent(tripId, () => {})..add(part);
    if (parts.containsAll(_parts) && _arriving.remove(tripId)) _emitArriving();
  }

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

    // 4b. Activity entries waiting to go up (they normally ride with a change,
    // but one left behind, say by a crash between the two, still gets pushed).
    final activityQuery = localDb.select(localDb.tripActivities).join([
      innerJoin(localDb.trips, localDb.trips.id.equalsExp(localDb.tripActivities.tripId)),
    ])
      ..where(localDb.tripActivities.syncStatus.equals(1) &
          localDb.tripActivities.actorId.equals(currentUserId) &
          localDb.trips.sharing.equals('group'));
    _activityWatcherSub = activityQuery.watch().listen((rows) {
      if (_isStopped || rows.isEmpty) return;
      for (final row in rows) {
        _pendingTripIdsToPush.add(row.readTable(localDb.tripActivities).tripId);
      }
      _scheduleDebouncedPush();
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error watching activity entries: $error\n$stack');
    });
    TripActivityLog(localDb).expireOld().catchError((Object e) {
      debugPrint('[SyncEngineV2] Expiring old activity failed: $e');
      return 0;
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

        await _claimTombstones(tripId);

        final dirtyDays = await (localDb.select(localDb.tripDays)
              ..where((d) => d.tripId.equals(tripId) & d.syncStatus.equals(1)))
            .get();

        final dirtyStops = await (localDb.select(localDb.stops)
              ..where((s) => s.tripId.equals(tripId) & s.syncStatus.equals(1)))
            .get();

        final dirtyItems = await (localDb.select(localDb.scheduleItems)
              ..where((i) => i.tripId.equals(tripId) & i.syncStatus.equals(1)))
            .get();

        final dirtyActivities = await (localDb.select(localDb.tripActivities)
              ..where((a) => a.tripId.equals(tripId) & a.actorId.equals(currentUserId) & a.syncStatus.equals(1)))
            .get();

        if (trip.syncStatus != 1 &&
            dirtyDays.isEmpty &&
            dirtyStops.isEmpty &&
            dirtyItems.isEmpty &&
            dirtyActivities.isEmpty) {
          _updateStatus(tripId, TripSyncStatus.synced);
          continue;
        }

        // Ensure cloud trip and owner member doc exist before pushing subcollections
        if (!await firestoreSync.tripExists(tripId)) {
          await firestoreSync.initializeCloudTrip(trip, currentUserId);
        }

        if (_isStopped) break;

        // The writes, gathered first so a refused batch can be retried
        // without the activity log (below).
        final changeOps = <void Function(WriteBatch)>[];

        Future<void> commitAll(List<void Function(WriteBatch)> ops) async {
          for (var start = 0; start < ops.length; start += maxBatchOps) {
            final batch = firestoreSync.createBatch();
            for (final op in ops.skip(start).take(maxBatchOps)) {
              op(batch);
            }
            await firestoreSync.commitBatch(batch);
          }
        }

        // 1. Trip doc
        if (trip.syncStatus == 1) {
          changeOps.add((b) => firestoreSync.buildTripBatchOperations(b, trip));
        }

        // 2. Days
        for (final day in dirtyDays) {
          changeOps.add((b) => firestoreSync.buildDayBatchOperations(b, day));
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

          changeOps.add((b) => firestoreSync.buildStopBatchOperations(
                b,
                stop,
                labels: labels,
                referenceImages: refImages,
              ));
        }

        // 4. Schedule items
        for (final item in dirtyItems) {
          changeOps.add((b) => firestoreSync.buildScheduleItemBatchOperations(b, item));
        }

        // 5. Activity entries, in the same batch as the changes they describe
        void Function(WriteBatch) activityOp(TripActivity entry) =>
            (b) => firestoreSync.buildActivityBatchOperation(b, entry);

        // Entries the rules refused on their own: kept on this phone, not retried.
        final refusedActivities = <String>{};

        // Remote commit outside transaction
        try {
          await commitAll([...changeOps, for (final entry in dirtyActivities) activityOp(entry)]);
        } catch (e) {
          if (!_isPermanentError(e) || dirtyActivities.isEmpty) rethrow;
          // The log must never hold the trip back. An entry the rules refuse
          // (one already in Firestore from an older build, or too long for
          // them) would otherwise fail every push of the trip for good: send
          // the changes alone, then each entry on its own.
          await commitAll(changeOps);
          for (final entry in dirtyActivities) {
            try {
              await commitAll([activityOp(entry)]);
            } catch (e) {
              if (!_isPermanentError(e)) rethrow;
              refusedActivities.add(entry.id);
              debugPrint('[SyncEngineV2] Activity entry ${entry.id} refused; kept on this phone only: $e');
            }
          }
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

          // An entry merged with a newer edit while in flight (new createdAt)
          // stays waiting under a new id: the log is append-only in Firestore,
          // so writing the pushed id again would be refused as an update.
          for (final entry in dirtyActivities) {
            if (refusedActivities.contains(entry.id)) {
              await (localDb.update(localDb.tripActivities)..where((a) => a.id.equals(entry.id)))
                  .write(const TripActivitiesCompanion(syncStatus: Value(0)));
              continue;
            }
            final done = await (localDb.update(localDb.tripActivities)
                  ..where((a) => a.id.equals(entry.id) & a.createdAt.equalsValue(entry.createdAt)))
                .write(const TripActivitiesCompanion(syncStatus: Value(0)));
            if (done == 0) {
              await (localDb.update(localDb.tripActivities)
                    ..where((a) => a.id.equals(entry.id) & a.syncStatus.equals(1)))
                  .write(TripActivitiesCompanion(id: Value(const Uuid().v4())));
            }
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

        final remainingActivities = await (localDb.select(localDb.tripActivities)
              ..where((a) => a.tripId.equals(tripId) & a.actorId.equals(currentUserId) & a.syncStatus.equals(1)))
            .get();

        final hasRemainingDirty = remainingDirtyTrip != null ||
            remainingDirtyDays.isNotEmpty ||
            remainingDirtyStops.isNotEmpty ||
            remainingDirtyItems.isNotEmpty ||
            remainingActivities.isNotEmpty;

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

  /// Puts this user's name on the trip's deleted rows waiting to go up.
  ///
  /// A tombstone goes up with `expireAt`, which the rules accept only from the
  /// row's `updatedBy`. A row deleted before the trip was shared, signed out,
  /// or by a build older than `createInvite`'s stamping, can carry someone
  /// else's id or none, and then the rules refuse the whole batch on every
  /// try. Rows waiting on this device were deleted here, so they're ours.
  Future<void> _claimTombstones(String tripId) async {
    await localDb.transaction(() async {
      await (localDb.update(localDb.trips)
            ..where((t) =>
                t.id.equals(tripId) &
                t.syncStatus.equals(1) &
                t.deletedAt.isNotNull() &
                (t.updatedBy.isNull() | t.updatedBy.equals(currentUserId).not())))
          .write(TripsCompanion(updatedBy: Value(currentUserId)));
      await (localDb.update(localDb.tripDays)
            ..where((d) =>
                d.tripId.equals(tripId) &
                d.syncStatus.equals(1) &
                d.deletedAt.isNotNull() &
                (d.updatedBy.isNull() | d.updatedBy.equals(currentUserId).not())))
          .write(TripDaysCompanion(updatedBy: Value(currentUserId)));
      await (localDb.update(localDb.stops)
            ..where((s) =>
                s.tripId.equals(tripId) &
                s.syncStatus.equals(1) &
                s.deletedAt.isNotNull() &
                (s.updatedBy.isNull() | s.updatedBy.equals(currentUserId).not())))
          .write(StopsCompanion(updatedBy: Value(currentUserId)));
      await (localDb.update(localDb.scheduleItems)
            ..where((i) =>
                i.tripId.equals(tripId) &
                i.syncStatus.equals(1) &
                i.deletedAt.isNotNull() &
                (i.updatedBy.isNull() | i.updatedBy.equals(currentUserId).not())))
          .write(ScheduleItemsCompanion(updatedBy: Value(currentUserId)));
    });
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
    _activityWatcherSub?.cancel();
    _activityWatcherSub = null;
    _userTripsSub?.cancel();
    _userTripsSub = null;

    for (final sub in _subcollectionSubs.values) {
      sub.cancel();
    }
    _subcollectionSubs.clear();
    _subcollectionChains.clear();
    _arriving.clear();
    _arrivedParts.clear();
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

    // Re-joining check: if the local trip is marked private (e.g. from previously leaving or unsharing),
    // but the incoming remote snapshot confirms it is a shared group trip and this user is an active member,
    // reconnect the local trip to 'group' sharing so syncing resumes.
    final remoteMembers = (remoteData['members'] as List?)?.cast<String>() ?? const [];
    final isRejoining = localTrip != null &&
        localTrip.sharing == 'private' &&
        remoteOwnerId != currentUserId &&
        remoteSharing == 'group' &&
        remoteMembers.contains(currentUserId);

    if (isRejoining) {
      final dirtyDays = await (localDb.select(localDb.tripDays)..where((d) => d.tripId.equals(tripId) & d.syncStatus.equals(1))).get();
      final dirtyStops = await (localDb.select(localDb.stops)..where((s) => s.tripId.equals(tripId) & s.syncStatus.equals(1))).get();
      final dirtyItems = await (localDb.select(localDb.scheduleItems)..where((i) => i.tripId.equals(tripId) & i.syncStatus.equals(1))).get();
      final hasDirtyChanges = localTrip.syncStatus == 1 ||
          dirtyDays.isNotEmpty ||
          dirtyStops.isNotEmpty ||
          dirtyItems.isNotEmpty;

      if (hasDirtyChanges) {
        await _forkPrivateTrip(tripId, localTrip);
      }
    }

    if (!isRejoining && localTrip != null && localTrip.sharing == 'private' && remoteOwnerId != currentUserId) {
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
        if (!isRejoining &&
            remoteUpdatedAt != null &&
            remoteUpdatedAt.millisecondsSinceEpoch <= current.updatedAt.millisecondsSinceEpoch) {
          return;
        }
        await (localDb.update(localDb.trips)..where((t) => t.id.equals(tripId))).write(tripCompanion);
      } else {
        await localDb.into(localDb.trips).insert(tripCompanion, mode: InsertMode.insertOrIgnore);
      }
    });

    await _flushPendingForTrip(tripId);
    return true;
  }

  void _cancelSubcollectionWatchers(String tripId) {
    for (final suffix in ['days', 'stops', 'items', 'activity']) {
      _subcollectionSubs.remove('$tripId:$suffix')?.cancel();
      _subcollectionChains.remove('$tripId:$suffix');
    }
    _arrivedParts.remove(tripId);
    if (_arriving.remove(tripId)) _emitArriving();
  }

  static const _sqlInChunkSize = 400;

  Future<List<T>> _queryInChunks<T>(
    Iterable<String> ids,
    Future<List<T>> Function(List<String> chunk) query,
  ) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const [];
    final out = <T>[];
    for (var i = 0; i < list.length; i += _sqlInChunkSize) {
      final end = i + _sqlInChunkSize > list.length ? list.length : i + _sqlInChunkSize;
      out.addAll(await query(list.sublist(i, end)));
    }
    return out;
  }

  /// Ensure downstream watchers for subcollections (days, stops, schedule_items).
  void _ensureSubcollectionWatchers(String tripId) {
    if (_subcollectionSubs.containsKey('$tripId:days')) return;
    _arrivedParts.remove(tripId);
    unawaited(_watchArrival(tripId));

    // Days watcher
    _subcollectionChains['$tripId:days'] = Future.value();
    _subcollectionSubs['$tripId:days'] = firestoreSync.watchTripDays(tripId).listen((daysList) {
      if (_isStopped) return;
      final chain = _subcollectionChains['$tripId:days'] ?? Future.value();
      _subcollectionChains['$tripId:days'] = chain.then((_) async {
        if (_isStopped) return;
        // One transaction per snapshot, so its rows show up together.
        await localDb.transaction(() async {
          final applied = await _applyRemoteDaysBatchInTx(tripId, daysList);
          if (applied) {
            await _markRowsGoneFromServerInTx(tripId, 'days', daysList);
            await _flushPendingScheduleItemsInTx(tripId);
          }
        });
        _partArrived(tripId, 'days', docs: daysList);
      }).catchError((Object e, StackTrace stack) {
        debugPrint('[SyncEngineV2] Error in days chain for $tripId: $e\n$stack');
      });
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error in watchTripDays for $tripId: $error');
      if (_isPermanentError(error)) {
        _subcollectionSubs.remove('$tripId:days')?.cancel();
        _partArrived(tripId, 'days');
      }
    });

    // Stops watcher
    _subcollectionChains['$tripId:stops'] = Future.value();
    _subcollectionSubs['$tripId:stops'] = firestoreSync.watchTripStops(tripId).listen((stopsList) {
      if (_isStopped) return;
      final chain = _subcollectionChains['$tripId:stops'] ?? Future.value();
      _subcollectionChains['$tripId:stops'] = chain.then((_) async {
        if (_isStopped) return;
        // One transaction per snapshot, so its rows show up together.
        await localDb.transaction(() async {
          final applied = await _applyRemoteStopsBatchInTx(tripId, stopsList);
          if (applied) {
            await _markRowsGoneFromServerInTx(tripId, 'stops', stopsList);
            await _flushPendingScheduleItemsInTx(tripId);
          }
        });
        _partArrived(tripId, 'stops', docs: stopsList);
      }).catchError((Object e, StackTrace stack) {
        debugPrint('[SyncEngineV2] Error in stops chain for $tripId: $e\n$stack');
      });
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error in watchTripStops for $tripId: $error');
      if (_isPermanentError(error)) {
        _subcollectionSubs.remove('$tripId:stops')?.cancel();
        _partArrived(tripId, 'stops');
      }
    });

    // Schedule items watcher
    _subcollectionChains['$tripId:items'] = Future.value();
    _subcollectionSubs['$tripId:items'] = firestoreSync.watchTripScheduleItems(tripId).listen((itemsList) {
      if (_isStopped) return;
      final chain = _subcollectionChains['$tripId:items'] ?? Future.value();
      _subcollectionChains['$tripId:items'] = chain.then((_) async {
        if (_isStopped) return;
        // One transaction per snapshot, so its rows show up together.
        await localDb.transaction(() async {
          final applied = await _applyRemoteScheduleItemsBatchInTx(tripId, itemsList);
          if (applied) {
            await _markRowsGoneFromServerInTx(tripId, 'items', itemsList);
          }
        });
        _partArrived(tripId, 'items', docs: itemsList);
      }).catchError((Object e, StackTrace stack) {
        debugPrint('[SyncEngineV2] Error in items chain for $tripId: $e\n$stack');
      });
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error in watchTripScheduleItems for $tripId: $error');
      if (_isPermanentError(error)) {
        _subcollectionSubs.remove('$tripId:items')?.cancel();
        _partArrived(tripId, 'items');
      }
    });

    // Activity log watcher (What changed)
    _subcollectionChains['$tripId:activity'] = Future.value();
    _subcollectionSubs['$tripId:activity'] = firestoreSync.watchTripActivity(tripId).listen((entries) {
      if (_isStopped) return;
      final chain = _subcollectionChains['$tripId:activity'] ?? Future.value();
      _subcollectionChains['$tripId:activity'] = chain.then((_) async {
        if (_isStopped) return;
        await _applyRemoteActivity(tripId, entries);
      }).catchError((Object e, StackTrace stack) {
        debugPrint('[SyncEngineV2] Error in activity chain for $tripId: $e\n$stack');
      });
    }, onError: (error, stack) {
      debugPrint('[SyncEngineV2] Error in watchTripActivity for $tripId: $error');
      if (_isPermanentError(error)) {
        _subcollectionSubs.remove('$tripId:activity')?.cancel();
      }
    });
  }

  /// Copies other members' activity entries into the local log. Entries never
  /// change once written, so one already here (our own, pushed) is left as is.
  Future<void> _applyRemoteActivity(String tripId, List<Map<String, dynamic>> entries) async {
    final cutoff = DateTime.now().subtract(TripActivityLog.lifetime);
    await localDb.transaction(() async {
      final trip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
      if (trip == null || trip.sharing != 'group') return;
      final companions = <TripActivitiesCompanion>[];
      final seenIds = <String>{};
      for (final data in entries) {
        final id = data['id'];
        final createdAt = _parseTimestamp(data['createdAt']);
        if (id is! String || id.isEmpty || createdAt == null || createdAt.isBefore(cutoff)) continue;
        if (data['tripId'] != null && data['tripId'] != tripId) continue;
        if (!seenIds.add(id)) continue;
        companions.add(
          TripActivitiesCompanion.insert(
            id: id,
            tripId: tripId,
            actorId: data['actorId'] as String? ?? '',
            action: data['action'] as String? ?? '',
            entityType: data['entityType'] as String? ?? '',
            entityId: data['entityId'] as String? ?? '',
            summary: data['summary'] as String? ?? '',
            createdAt: createdAt,
            syncStatus: const Value(0),
          ),
        );
      }
      if (companions.isNotEmpty) {
        await localDb.batch((b) => b.insertAll(
              localDb.tripActivities,
              companions,
              mode: InsertMode.insertOrIgnore,
            ));
      }
    });
  }

  /// How old a clean local row must be before its absence on the server is
  /// read as "Firestore purged its tombstone". Tombstones live 30 days
  /// ([FirestoreSyncV2Service.tombstoneLifetime]), so anything changed within
  /// that time is still on the server, deleted or not.
  static const _goneAfter = Duration(days: 29);

  /// A device that was away longer than a tombstone's 30 days never sees the
  /// deletion: the document is simply gone. A snapshot from the server lists the
  /// whole subcollection, so a clean row (pushed, not edited since) that is old
  /// enough and isn't in it was deleted by someone else: hide it here too.
  /// Rows with local changes (syncStatus 1) are left alone; they're pushed next.
  ///
  /// Must run inside the caller's open transaction.
  Future<void> _markRowsGoneFromServerInTx(String tripId, String kind, List<Map<String, dynamic>> docs) async {
    if (docs is! RemoteDocList || docs.isFromCache || _isStopped) return;
    final remoteIds = {for (final d in docs) if (d['id'] is String) d['id'] as String};
    final cutoff = DateTime.now().subtract(_goneAfter).millisecondsSinceEpoch;
    final now = DateTime.now();
    final trip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null || trip.sharing != 'group') return;
    switch (kind) {
      case 'days':
        final gone = (await (localDb.select(localDb.tripDays)
                  ..where((d) =>
                      d.tripId.equals(tripId) &
                      d.syncStatus.equals(0) &
                      d.deletedAt.isNull() &
                      d.updatedAt.isSmallerThanValue(cutoff)))
                .get())
            .where((d) => !remoteIds.contains(d.id))
            .map((d) => d.id)
            .toList();
        for (var i = 0; i < gone.length; i += _sqlInChunkSize) {
          final chunk = gone.sublist(i, i + _sqlInChunkSize > gone.length ? gone.length : i + _sqlInChunkSize);
          await (localDb.update(localDb.tripDays)..where((d) => d.id.isIn(chunk) & d.tripId.equals(tripId)))
              .write(TripDaysCompanion(deletedAt: Value(now), updatedBy: const Value(null)));
          await (localDb.update(localDb.scheduleItems)
                ..where((item) => item.dayId.isIn(chunk) & item.tripId.equals(tripId) & item.syncStatus.equals(0) & item.deletedAt.isNull()))
              .write(ScheduleItemsCompanion(deletedAt: Value(now), updatedBy: const Value(null)));
        }
      case 'stops':
        final gone = (await (localDb.select(localDb.stops)
                  ..where((s) =>
                      s.tripId.equals(tripId) &
                      s.syncStatus.equals(0) &
                      s.deletedAt.isNull() &
                      s.updatedAt.isSmallerThanValue(cutoff)))
                .get())
            .where((s) => !remoteIds.contains(s.id))
            .map((s) => s.id)
            .toList();
        for (var i = 0; i < gone.length; i += _sqlInChunkSize) {
          final chunk = gone.sublist(i, i + _sqlInChunkSize > gone.length ? gone.length : i + _sqlInChunkSize);
          await (localDb.update(localDb.stops)..where((s) => s.id.isIn(chunk) & s.tripId.equals(tripId)))
              .write(StopsCompanion(deletedAt: Value(now), updatedBy: const Value(null)));
          await (localDb.update(localDb.scheduleItems)
                ..where((item) => item.stopId.isIn(chunk) & item.tripId.equals(tripId) & item.syncStatus.equals(0) & item.deletedAt.isNull()))
              .write(ScheduleItemsCompanion(deletedAt: Value(now), updatedBy: const Value(null)));
        }
      case 'items':
        final gone = (await (localDb.select(localDb.scheduleItems)
                  ..where((item) =>
                      item.tripId.equals(tripId) &
                      item.syncStatus.equals(0) &
                      item.deletedAt.isNull() &
                      item.updatedAt.isSmallerThanValue(cutoff)))
                .get())
            .where((item) => !remoteIds.contains(item.id))
            .map((item) => item.id)
            .toList();
        for (var i = 0; i < gone.length; i += _sqlInChunkSize) {
          final chunk = gone.sublist(i, i + _sqlInChunkSize > gone.length ? gone.length : i + _sqlInChunkSize);
          await (localDb.update(localDb.scheduleItems)..where((item) => item.id.isIn(chunk) & item.tripId.equals(tripId)))
              .write(ScheduleItemsCompanion(deletedAt: Value(now), updatedBy: const Value(null)));
        }
    }
  }

  /// Flushes any buffered subcollection documents for [tripId] whose parent rows now exist.
  Future<void> _flushPendingForTrip(String tripId) async {
    final pendingDays = _pendingRemoteDays.values.where((d) => d['tripId'] == tripId).toList();
    final pendingStops = _pendingRemoteStops.values.where((s) => s['tripId'] == tripId).toList();
    final hasPendingItems = _pendingRemoteItems.values.any((i) => i['tripId'] == tripId);
    if (pendingDays.isEmpty && pendingStops.isEmpty && !hasPendingItems) return;

    await localDb.transaction(() async {
      if (pendingDays.isNotEmpty) {
        await _applyRemoteDaysBatchInTx(tripId, pendingDays);
      }
      if (pendingStops.isNotEmpty) {
        await _applyRemoteStopsBatchInTx(tripId, pendingStops);
      }
      await _flushPendingScheduleItemsInTx(tripId);
    });
  }

  Future<void> _flushPendingScheduleItemsInTx(String tripId) async {
    final pendingItems = _pendingRemoteItems.values.where((i) => i['tripId'] == tripId).toList();
    if (pendingItems.isEmpty) return;
    await _applyRemoteScheduleItemsBatchInTx(tripId, pendingItems);
  }

  /// Applies a snapshot of remote days inside the caller's open transaction.
  /// Returns true when the parent trip exists locally and is shared.
  Future<bool> _applyRemoteDaysBatchInTx(String tripId, List<Map<String, dynamic>> daysList) async {
    final parentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (parentTrip == null) {
      for (final data in daysList) {
        final dayId = data['id'];
        if (dayId is String && dayId.isNotEmpty) {
          _pendingRemoteDays[dayId] = data;
        }
      }
      return false;
    }
    if (parentTrip.sharing == 'private') return false;

    final dayIds = <String>{};
    for (final data in daysList) {
      final dayId = data['id'];
      if (dayId is String && dayId.isNotEmpty) {
        _pendingRemoteDays.remove(dayId);
        dayIds.add(dayId);
      }
    }
    if (dayIds.isEmpty) return true;

    // Query without tripId filter so cross-trip PK collisions are still detected.
    final existingRows = await _queryInChunks(
      dayIds,
      (chunk) => (localDb.select(localDb.tripDays)..where((d) => d.id.isIn(chunk))).get(),
    );
    final existingById = {for (final d in existingRows) d.id: d};

    final daysToInsert = <String, TripDaysCompanion>{};
    for (final data in daysList) {
      try {
        final dayId = data['id'];
        if (dayId is! String || dayId.isEmpty) continue;

        final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);
        final deletedAt = _parseTimestamp(data['deletedAt']);
        final effectiveUpdatedAt = remoteUpdatedAt ?? DateTime.now();

        final companion = TripDaysCompanion(
          id: Value(dayId),
          tripId: Value(tripId),
          sortKey: Value(data['sortKey'] as String? ?? 'a0'),
          title: Value(data['title'] as String?),
          pinnedDate: Value(data['pinnedDate'] as String?),
          updatedAt: Value(effectiveUpdatedAt),
          updatedBy: Value(data['updatedBy'] as String?),
          deletedAt: Value(deletedAt),
          syncStatus: const Value(0),
        );

        final localDay = existingById[dayId];
        if (localDay != null) {
          if (localDay.tripId != tripId) continue;
          if (remoteUpdatedAt != null &&
              remoteUpdatedAt.millisecondsSinceEpoch <= localDay.updatedAt.millisecondsSinceEpoch) {
            continue;
          }
          await (localDb.update(localDb.tripDays)
                ..where((d) =>
                    d.id.equals(dayId) &
                    d.tripId.equals(tripId) &
                    d.updatedAt.isSmallerThanValue(effectiveUpdatedAt.millisecondsSinceEpoch)))
              .write(companion);
        } else {
          daysToInsert[dayId] = companion;
        }
      } catch (e, stack) {
        debugPrint('[SyncEngineV2] Error applying remote day: $e\n$stack');
      }
    }

    if (daysToInsert.isNotEmpty) {
      await localDb.batch((b) => b.insertAll(
            localDb.tripDays,
            daysToInsert.values.toList(),
            mode: InsertMode.insertOrIgnore,
          ));
    }
    return true;
  }

  /// Applies a snapshot of remote stops (with preloaded labels & reference images)
  /// inside the caller's open transaction. Returns true when parent trip is shared.
  Future<bool> _applyRemoteStopsBatchInTx(String tripId, List<Map<String, dynamic>> stopsList) async {
    final parentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (parentTrip == null) {
      for (final data in stopsList) {
        final stopId = data['id'];
        if (stopId is String && stopId.isNotEmpty) {
          _pendingRemoteStops[stopId] = data;
        }
      }
      return false;
    }
    if (parentTrip.sharing == 'private') return false;

    final stopIds = <String>{};
    for (final data in stopsList) {
      final stopId = data['id'];
      if (stopId is String && stopId.isNotEmpty) {
        _pendingRemoteStops.remove(stopId);
        stopIds.add(stopId);
      }
    }
    if (stopIds.isEmpty) return true;

    // Query without tripId filter so cross-trip PK collisions are still detected.
    final existingRows = await _queryInChunks(
      stopIds,
      (chunk) => (localDb.select(localDb.stops)..where((s) => s.id.isIn(chunk))).get(),
    );
    final existingById = {for (final s in existingRows) s.id: s};

    final actionable = <({String stopId, Map<String, dynamic> data, Stop? localStop, DateTime? remoteUpdatedAt})>[];
    for (final data in stopsList) {
      try {
        final stopId = data['id'];
        if (stopId is! String || stopId.isEmpty) continue;
        final localStop = existingById[stopId];
        final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);
        if (localStop != null) {
          if (localStop.tripId != tripId) continue;
          if (remoteUpdatedAt != null &&
              remoteUpdatedAt.millisecondsSinceEpoch <= localStop.updatedAt.millisecondsSinceEpoch) {
            continue;
          }
        }
        actionable.add((stopId: stopId, data: data, localStop: localStop, remoteUpdatedAt: remoteUpdatedAt));
      } catch (e, stack) {
        debugPrint('[SyncEngineV2] Error preparing remote stop: $e\n$stack');
      }
    }
    if (actionable.isEmpty) return true;

    final needsLabels = actionable.any((r) => r.data['labels'] is List);
    final refStopIds = <String>[
      for (final r in actionable)
        if (r.data['referenceImages'] is List || r.data['frameShots'] is Map) r.stopId,
    ];

    final labelsById = <String, Label>{};
    final labelsByBangumiId = <String, Label>{};
    final labelsByKindAndName = <(String, String), Label>{};
    if (needsLabels || refStopIds.isNotEmpty) {
      final allLabels = await localDb.select(localDb.labels).get();
      for (final label in allLabels) {
        labelsById[label.id] = label;
        final bId = label.bangumiId;
        if (bId != null && bId.isNotEmpty) {
          labelsByBangumiId.putIfAbsent(bId, () => label);
        }
        labelsByKindAndName.putIfAbsent((label.kind, label.name), () => label);
      }
    }

    final existingRefsByStop = <String, List<NewReferenceImage>>{};
    if (refStopIds.isNotEmpty) {
      final existingRefs = await _queryInChunks(
        refStopIds,
        (chunk) => (localDb.select(localDb.newReferenceImages)..where((r) => r.stopId.isIn(chunk))).get(),
      );
      for (final ref in existingRefs) {
        final sid = ref.stopId;
        if (sid != null) {
          existingRefsByStop.putIfAbsent(sid, () => []).add(ref);
        }
      }
    }

    // The frames the docs name by id, wherever they are on this phone, and
    // this trip's stops: a frame that moved to another stop (a merge on
    // another phone) is found where it was, keeping its cached file, and an
    // id this phone uses outside the trip (a library frame, another trip's)
    // is never taken over.
    final namedFrameIds = <String>{
      for (final r in actionable) ...[
        if (r.data['referenceImages'] case final List refs)
          for (final raw in refs)
            if (raw is Map && raw['id'] is String) raw['id'] as String,
        if (r.data['frameShots'] case final Map shots)
          for (final key in shots.keys)
            if (key is String) key,
      ],
    };
    final knownFrames = {
      for (final f in await _queryInChunks(
        namedFrameIds,
        (chunk) => (localDb.select(localDb.newReferenceImages)..where((r) => r.id.isIn(chunk))).get(),
      ))
        f.id: f,
    };
    final tripStopIds = knownFrames.isEmpty
        ? const <String>{}
        : {for (final s in await (localDb.select(localDb.stops)..where((s) => s.tripId.equals(tripId))).get()) s.id};
    bool inTrip(NewReferenceImage f) => f.stopId != null && tripStopIds.contains(f.stopId);

    final stopsToInsert = <String, StopsCompanion>{};
    final labelsToInsert = <LabelsCompanion>[];
    final labelBangumiBackfills = <({String id, String bangumiId})>[];
    final stopLabelClearIds = <String>[];
    final stopLabelsToInsert = <StopLabelsCompanion>[];
    final refImagesToUpsert = <NewReferenceImagesCompanion>[];
    final refImageIdsToDelete = <String>[];
    // Where frames are shot from (`frameShots`), by local frame id, with
    // the stop whose doc says so; written after the frames themselves, and
    // only to a frame that is on that stop by then.
    final frameShotWrites = <String, ({String stopId, Map shot})>{};

    for (final entry in actionable) {
      final stopId = entry.stopId;
      final data = entry.data;
      final localStop = entry.localStop;
      final remoteUpdatedAt = entry.remoteUpdatedAt;

      try {
        final deletedAt = _parseTimestamp(data['deletedAt']);
        final effectiveUpdatedAt = remoteUpdatedAt ?? DateTime.now();

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
          mergedInto: Value(data['mergedInto'] as String?),
          addedBy: Value(data['addedBy'] as String? ?? currentUserId),
          updatedAt: Value(effectiveUpdatedAt),
          updatedBy: Value(data['updatedBy'] as String?),
          deletedAt: Value(deletedAt),
          syncStatus: const Value(0),
        );

        if (localStop != null) {
          final updated = await (localDb.update(localDb.stops)
                ..where((s) =>
                    s.id.equals(stopId) &
                    s.tripId.equals(tripId) &
                    s.updatedAt.isSmallerThanValue(effectiveUpdatedAt.millisecondsSinceEpoch)))
              .write(companion);
          if (updated == 0) continue;
        }

        final senderToLocalLabelId = <String, String>{};
        final matchedAnimeLabelIds = <String>[];
        final pendingStopLabels = <StopLabelsCompanion>[];
        final pendingRefUpserts = <NewReferenceImagesCompanion>[];
        final pendingRefDeletes = <String>[];
        // The sender's frame ids, to this phone's ids for the same frames.
        final senderToLocalFrameId = <String, String>{};

        final labelsRaw = data['labels'] as List?;
        if (labelsRaw != null) {
          final seenStopLabelIds = <String>{};
          for (final raw in labelsRaw) {
            if (raw is! Map) continue;
            final kind = raw['kind'] as String? ?? 'tag';
            final name = raw['name'] as String? ?? '';
            final bangumiId = raw['bangumiId'] as String?;

            Label? label;
            if (bangumiId != null && bangumiId.isNotEmpty) {
              label = labelsByBangumiId[bangumiId];
            }
            if (label == null) {
              label = labelsByKindAndName[(kind, name)];
              if (label != null && label.bangumiId == null && bangumiId != null && bangumiId.isNotEmpty) {
                label = label.copyWith(bangumiId: Value(bangumiId));
                labelsById[label.id] = label;
                labelsByBangumiId.putIfAbsent(bangumiId, () => label!);
                labelsByKindAndName[(kind, name)] = label;
                labelBangumiBackfills.add((id: label.id, bangumiId: bangumiId));
              }
            }

            if (label == null) {
              final newId = const Uuid().v4();
              final now = DateTime.now();
              final created = Label(
                id: newId,
                kind: kind,
                name: name,
                bangumiId: bangumiId,
                createdAt: now,
              );
              labelsById[newId] = created;
              if (bangumiId != null && bangumiId.isNotEmpty) {
                labelsByBangumiId.putIfAbsent(bangumiId, () => created);
              }
              labelsByKindAndName.putIfAbsent((kind, name), () => created);
              labelsToInsert.add(
                LabelsCompanion(
                  id: Value(newId),
                  kind: Value(kind),
                  name: Value(name),
                  bangumiId: Value(bangumiId),
                  createdAt: Value(now),
                ),
              );
              label = created;
            }

            if (raw['id'] is String) {
              senderToLocalLabelId[raw['id'] as String] = label.id;
            }
            if (kind == 'anime') {
              matchedAnimeLabelIds.add(label.id);
            }
            if (seenStopLabelIds.add(label.id)) {
              pendingStopLabels.add(
                StopLabelsCompanion(
                  stopId: Value(stopId),
                  labelId: Value(label.id),
                ),
              );
            }
          }
        }

        final refImagesRaw = data['referenceImages'] as List?;
        if (refImagesRaw != null) {
          final existingRefs = existingRefsByStop[stopId] ?? const <NewReferenceImage>[];
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
            final rawId = raw['id'] is String && (raw['id'] as String).isNotEmpty ? raw['id'] as String : null;
            final known = rawId == null ? null : knownFrames[rawId];
            // This phone uses the id outside the trip: not the same frame.
            final foreign = known != null && !inTrip(known);
            final existingMatch = (rawId == null ? null : existingById[rawId]) ?? existingByUrl[remoteUrl] ?? (foreign ? null : known);
            final imgId = existingMatch?.id ?? (foreign ? null : rawId) ?? const Uuid().v4();
            incomingIds.add(imgId);
            if (rawId != null) senderToLocalFrameId[rawId] = imgId;

            final rawAnimeLabelId = raw['animeLabelId'] as String?;
            String? resolvedAnimeLabelId;
            if (rawAnimeLabelId != null && rawAnimeLabelId.isNotEmpty) {
              resolvedAnimeLabelId = senderToLocalLabelId[rawAnimeLabelId] ?? labelsById[rawAnimeLabelId]?.id;
            }
            resolvedAnimeLabelId ??= matchedAnimeLabelIds.length == 1 ? matchedAnimeLabelIds.first : null;

            pendingRefUpserts.add(
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

          for (final existing in existingRefs) {
            final isUrlBacked = existing.remoteUrl != null && existing.remoteUrl!.isNotEmpty;
            if (isUrlBacked && !incomingIds.contains(existing.id)) {
              pendingRefDeletes.add(existing.id);
            }
          }
        }

        // Where the frames are shot from. A stop uploaded by an older version
        // has no `frameShots` (or an old one its merge kept), and what this
        // phone knows stays; a frame the map doesn't name keeps its own, and
        // an empty entry clears it. A deleted stop's map is stale: its
        // frames went with it or to the stop it was merged into.
        final shotsRaw = data['frameShots'];
        if (shotsRaw is Map && deletedAt == null) {
          for (final MapEntry(:key, :value) in shotsRaw.entries) {
            if (key is! String || value is! Map) continue;
            final known = knownFrames[key];
            final localId = senderToLocalFrameId[key] ?? (known != null && inTrip(known) ? key : null);
            if (localId != null) frameShotWrites[localId] = (stopId: stopId, shot: value);
          }
        }

        if (localStop == null) {
          stopsToInsert[stopId] = companion;
        }
        if (labelsRaw != null && localStop != null) {
          stopLabelClearIds.add(stopId);
        }
        stopLabelsToInsert.addAll(pendingStopLabels);
        refImagesToUpsert.addAll(pendingRefUpserts);
        refImageIdsToDelete.addAll(pendingRefDeletes);
      } catch (e, stack) {
        debugPrint('[SyncEngineV2] Error applying remote stop: $e\n$stack');
      }
    }

    // Topological write order: Stops & Labels first, then junction StopLabels & ReferenceImages.
    if (stopsToInsert.isNotEmpty) {
      await localDb.batch((b) => b.insertAll(
            localDb.stops,
            stopsToInsert.values.toList(),
            mode: InsertMode.insertOrIgnore,
          ));
    }
    if (labelsToInsert.isNotEmpty) {
      await localDb.batch((b) => b.insertAll(
            localDb.labels,
            labelsToInsert,
            mode: InsertMode.insertOrIgnore,
          ));
    }
    for (final backfill in labelBangumiBackfills) {
      await (localDb.update(localDb.labels)..where((l) => l.id.equals(backfill.id)))
          .write(LabelsCompanion(bangumiId: Value(backfill.bangumiId)));
    }
    for (var i = 0; i < stopLabelClearIds.length; i += _sqlInChunkSize) {
      final chunk = stopLabelClearIds.sublist(
        i,
        i + _sqlInChunkSize > stopLabelClearIds.length ? stopLabelClearIds.length : i + _sqlInChunkSize,
      );
      await (localDb.delete(localDb.stopLabels)..where((sl) => sl.stopId.isIn(chunk))).go();
    }
    if (stopLabelsToInsert.isNotEmpty) {
      await localDb.batch((b) => b.insertAll(
            localDb.stopLabels,
            stopLabelsToInsert,
            mode: InsertMode.insertOrIgnore,
          ));
    }
    if (refImagesToUpsert.isNotEmpty) {
      await localDb.batch((b) => b.insertAllOnConflictUpdate(
            localDb.newReferenceImages,
            refImagesToUpsert,
          ));
    }
    // A frame one doc lets go of and another brings has moved between stops
    // (a merge on another phone), so it stays.
    final upsertedIds = {for (final r in refImagesToUpsert) r.id.value};
    refImageIdsToDelete.removeWhere(upsertedIds.contains);
    await _keepPhotosOfDeletedFrames(tripId, refImageIdsToDelete);
    for (var i = 0; i < refImageIdsToDelete.length; i += _sqlInChunkSize) {
      final chunk = refImageIdsToDelete.sublist(
        i,
        i + _sqlInChunkSize > refImageIdsToDelete.length ? refImageIdsToDelete.length : i + _sqlInChunkSize,
      );
      await (localDb.delete(localDb.newReferenceImages)..where((r) => r.id.isIn(chunk))).go();
    }
    // The frames only this phone has follow their stop's merge before the
    // spots are written, so the kept stop's doc reaches the ones it names.
    await _rehomeLocalFramesOfMergedStops(tripId);
    for (final MapEntry(key: frameId, value: (:stopId, :shot)) in frameShotWrites.entries) {
      await (localDb.update(localDb.newReferenceImages)..where((r) => r.id.equals(frameId) & r.stopId.equals(stopId)))
          .write(frameShotFromDoc(shot));
    }
    return true;
  }

  /// Points the user's photos of the frames [goingIds] at a copy of each
  /// that stays in [tripId] (the same link), the way a merge on this phone
  /// does: a merge on another phone drops the merged stop's copy of a frame
  /// the kept stop already shows, and the photos still count as shot.
  Future<void> _keepPhotosOfDeletedFrames(String tripId, List<String> goingIds) async {
    if (goingIds.isEmpty) return;
    final going = await _queryInChunks(
      goingIds,
      (chunk) => (localDb.select(localDb.newReferenceImages)..where((r) => r.id.isIn(chunk))).get(),
    );
    final tripStops = localDb.selectOnly(localDb.stops)
      ..addColumns([localDb.stops.id])
      ..where(localDb.stops.tripId.equals(tripId) & localDb.stops.deletedAt.isNull());
    final goingSet = goingIds.toSet();
    for (final frame in going) {
      final url = frame.remoteUrl;
      if (url == null || url.isEmpty) continue;
      final copies = await (localDb.select(localDb.newReferenceImages)
            ..where((r) => r.remoteUrl.equals(url) & r.stopId.isInQuery(tripStops)))
          .get();
      final copy = copies.where((c) => !goingSet.contains(c.id)).firstOrNull;
      if (copy == null) continue;
      await (localDb.update(localDb.photos)..where((p) => p.referenceImageId.equals(frame.id)))
          .write(PhotosCompanion(referenceImageId: Value(copy.id)));
    }
  }

  /// Moves the frames that only this phone has (no `remoteUrl`) off the
  /// trip's stops that were merged into another on some phone, onto the
  /// live stop at the end of the merge (`A` into `B` into `C` ends on `C`),
  /// giving each its old stop's position and spot name the way the merge
  /// there did. The uploaded frames come back on the kept stop from its own
  /// document. Run after every batch of stops, so a merge that arrives before
  /// the stop it went into (or a chain whose docs come in any order) is
  /// finished by a later batch; nothing moves until the kept stop is here.
  Future<void> _rehomeLocalFramesOfMergedStops(String tripId) async {
    final merged = {
      for (final s in await (localDb.select(localDb.stops)
            ..where((s) => s.tripId.equals(tripId) & s.deletedAt.isNotNull() & s.mergedInto.isNotNull()))
          .get())
        s.id: s,
    };
    if (merged.isEmpty) return;
    final frames = await _queryInChunks(
      merged.keys,
      (chunk) => (localDb.select(localDb.newReferenceImages)..where((r) => r.stopId.isIn(chunk))).get(),
    );
    for (final frame in frames) {
      if (frame.remoteUrl?.isNotEmpty ?? false) continue;
      final from = merged[frame.stopId]!;
      var target = from.mergedInto!;
      final seen = {from.id};
      while (merged.containsKey(target) && seen.add(target)) {
        target = merged[target]!.mergedInto!;
      }
      if (merged.containsKey(target)) continue; // a cycle
      final into = await (localDb.select(localDb.stops)
            ..where((s) => s.id.equals(target) & s.tripId.equals(tripId) & s.deletedAt.isNull()))
          .getSingleOrNull();
      if (into == null) continue;
      await (localDb.update(localDb.newReferenceImages)..where((r) => r.id.equals(frame.id)))
          .write(frameAsSpotOf(frame, from, stopGroup(from)).copyWith(stopId: Value(into.id)));
    }
  }

  /// Applies a snapshot of remote schedule items inside the caller's open transaction.
  /// Items whose parent day or stop is missing locally remain buffered in `_pendingRemoteItems`.
  Future<bool> _applyRemoteScheduleItemsBatchInTx(
    String tripId,
    List<Map<String, dynamic>> itemsList,
  ) async {
    final parentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (parentTrip == null) {
      for (final data in itemsList) {
        final itemId = data['id'];
        if (itemId is String && itemId.isNotEmpty) {
          _pendingRemoteItems[itemId] = data;
        }
      }
      return false;
    }
    if (parentTrip.sharing == 'private') return false;

    final dayRows = await (localDb.selectOnly(localDb.tripDays)
          ..addColumns([localDb.tripDays.id])
          ..where(localDb.tripDays.tripId.equals(tripId)))
        .get();
    final validDayIds = {for (final r in dayRows) r.read(localDb.tripDays.id)!};

    final stopRows = await (localDb.selectOnly(localDb.stops)
          ..addColumns([localDb.stops.id])
          ..where(localDb.stops.tripId.equals(tripId)))
        .get();
    final validStopIds = {for (final r in stopRows) r.read(localDb.stops.id)!};

    final readyItems = <Map<String, dynamic>>[];
    final readyIds = <String>{};
    for (final data in itemsList) {
      final itemId = data['id'];
      if (itemId is! String || itemId.isEmpty) continue;
      final stopId = data['stopId'] as String? ?? '';
      final dayId = data['dayId'] as String? ?? '';
      if (!validDayIds.contains(dayId) || !validStopIds.contains(stopId)) {
        _pendingRemoteItems[itemId] = data;
      } else {
        _pendingRemoteItems.remove(itemId);
        readyItems.add(data);
        readyIds.add(itemId);
      }
    }
    if (readyItems.isEmpty) return true;

    // Query without tripId filter so cross-trip PK collisions are still detected.
    final existingRows = await _queryInChunks(
      readyIds,
      (chunk) => (localDb.select(localDb.scheduleItems)..where((i) => i.id.isIn(chunk))).get(),
    );
    final existingById = {for (final item in existingRows) item.id: item};

    final itemsToInsert = <String, ScheduleItemsCompanion>{};
    var shouldReschedulePush = false;

    for (final data in readyItems) {
      try {
        final itemId = data['id'] as String;
        final stopId = data['stopId'] as String? ?? '';
        final dayId = data['dayId'] as String? ?? '';
        final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);
        final deletedAt = _parseTimestamp(data['deletedAt']);
        final remoteStatus = data['status'] as String? ?? 'planned';

        final localItem = existingById[itemId];
        if (localItem != null) {
          if (localItem.tripId != tripId) continue;
          if (remoteUpdatedAt != null &&
              remoteUpdatedAt.millisecondsSinceEpoch <= localItem.updatedAt.millisecondsSinceEpoch) {
            continue;
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
            shouldReschedulePush = true;
          }
        } else {
          itemsToInsert[itemId] = ScheduleItemsCompanion(
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
        }
      } catch (e, stack) {
        debugPrint('[SyncEngineV2] Error applying remote schedule item: $e\n$stack');
      }
    }

    if (itemsToInsert.isNotEmpty) {
      await localDb.batch((b) => b.insertAll(
            localDb.scheduleItems,
            itemsToInsert.values.toList(),
            mode: InsertMode.insertOrIgnore,
          ));
    }
    if (shouldReschedulePush) {
      _pendingTripIdsToPush.add(tripId);
      _scheduleDebouncedPush();
    }
    return true;
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

  /// Forks a leftover private copy into a new independent private trip when the user
  /// re-joins the shared group trip, preserving all edits made while away with zero data loss.
  Future<String> _forkPrivateTrip(String tripId, Trip localTrip) async {
    final forkedTripId = 'trip_${const Uuid().v4()}';
    final forkedTitle = '${localTrip.title} (your copy)';
    final now = DateTime.now();

    await localDb.transaction(() async {
      final days = await (localDb.select(localDb.tripDays)..where((d) => d.tripId.equals(tripId))).get();
      final stops = await (localDb.select(localDb.stops)..where((s) => s.tripId.equals(tripId))).get();
      final items = await (localDb.select(localDb.scheduleItems)..where((i) => i.tripId.equals(tripId))).get();

      final stopIds = stops.map((s) => s.id).toList();
      final stopLabels = stopIds.isEmpty
          ? <StopLabel>[]
          : await (localDb.select(localDb.stopLabels)..where((sl) => sl.stopId.isIn(stopIds))).get();
      final refImages = stopIds.isEmpty
          ? <NewReferenceImage>[]
          : await (localDb.select(localDb.newReferenceImages)..where((r) => r.stopId.isIn(stopIds))).get();

      // 1. Create the forked private trip
      await localDb.into(localDb.trips).insert(
        TripsCompanion(
          id: Value(forkedTripId),
          title: Value(forkedTitle),
          description: Value(localTrip.description),
          ownerId: Value(currentUserId),
          sharing: const Value('private'),
          startDate: Value(localTrip.startDate),
          dayCount: Value(localTrip.dayCount),
          createdAt: Value(localTrip.createdAt),
          updatedAt: Value(now),
          updatedBy: Value(currentUserId),
          syncStatus: const Value(0),
        ),
      );

      // 2. Clone days
      final dayIdMap = <String, String>{};
      for (final day in days) {
        final newDayId = const Uuid().v4();
        dayIdMap[day.id] = newDayId;
        await localDb.into(localDb.tripDays).insert(
          TripDaysCompanion(
            id: Value(newDayId),
            tripId: Value(forkedTripId),
            sortKey: Value(day.sortKey),
            title: Value(day.title),
            pinnedDate: Value(day.pinnedDate),
            updatedAt: Value(day.updatedAt),
            updatedBy: Value(day.updatedBy),
            deletedAt: Value(day.deletedAt),
            syncStatus: const Value(0),
          ),
        );
      }

      // 3. Clone stops
      final stopIdMap = <String, String>{};
      for (final stop in stops) {
        final newStopId = const Uuid().v4();
        stopIdMap[stop.id] = newStopId;
        await localDb.into(localDb.stops).insert(
          StopsCompanion(
            id: Value(newStopId),
            tripId: Value(forkedTripId),
            placeKey: Value(stop.placeKey),
            name: Value(stop.name),
            lat: Value(stop.lat),
            lng: Value(stop.lng),
            description: Value(stop.description),
            address: Value(stop.address),
            businessHours: Value(stop.businessHours),
            contactInfo: Value(stop.contactInfo),
            accessTips: Value(stop.accessTips),
            links: Value(stop.links),
            coverLocalPath: Value(stop.coverLocalPath),
            coverRemoteUrl: Value(stop.coverRemoteUrl),
            source: Value(stop.source),
            sourceUrl: Value(stop.sourceUrl),
            area: Value(stop.area),
            note: Value(stop.note),
            addedBy: Value(stop.addedBy),
            createdAt: Value(stop.createdAt),
            updatedAt: Value(stop.updatedAt),
            updatedBy: Value(stop.updatedBy),
            deletedAt: Value(stop.deletedAt),
            syncStatus: const Value(0),
          ),
        );
      }

      // 4. Clone stop labels
      for (final sl in stopLabels) {
        final newStopId = stopIdMap[sl.stopId];
        if (newStopId != null) {
          await localDb.into(localDb.stopLabels).insert(
            StopLabelsCompanion(
              stopId: Value(newStopId),
              labelId: Value(sl.labelId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }

      // 5. Clone reference images for stops
      for (final img in refImages) {
        final newStopId = stopIdMap[img.stopId];
        if (newStopId != null) {
          await localDb.into(localDb.newReferenceImages).insert(
            NewReferenceImagesCompanion(
              id: Value(const Uuid().v4()),
              placeKey: Value(img.placeKey),
              stopId: Value(newStopId),
              localPath: Value(img.localPath),
              remoteUrl: Value(img.remoteUrl),
              animeLabelId: Value(img.animeLabelId),
              episode: Value(img.episode),
              timestampS: Value(img.timestampS),
              source: Value(img.source),
              sourceUrl: Value(img.sourceUrl),
              lat: Value(img.lat),
              lng: Value(img.lng),
              note: Value(img.note),
              heading: Value(img.heading),
              createdAt: Value(img.createdAt),
            ),
          );
        }
      }

      // 6. Clone schedule items
      for (final item in items) {
        final newDayId = dayIdMap[item.dayId];
        final newStopId = stopIdMap[item.stopId];
        if (newDayId != null && newStopId != null) {
          await localDb.into(localDb.scheduleItems).insert(
            ScheduleItemsCompanion(
              id: Value(const Uuid().v4()),
              tripId: Value(forkedTripId),
              stopId: Value(newStopId),
              dayId: Value(newDayId),
              sortKey: Value(item.sortKey),
              stayMinutes: Value(item.stayMinutes),
              transitMinutes: Value(item.transitMinutes),
              fixedTime: Value(item.fixedTime),
              status: Value(item.status),
              updatedAt: Value(item.updatedAt),
              updatedBy: Value(item.updatedBy),
              deletedAt: Value(item.deletedAt),
              syncStatus: const Value(0),
            ),
          );
        }
      }

      // 7. Clean up the old private rows for tripId so the cloud trip can download fresh
      if (stopIds.isNotEmpty) {
        await (localDb.delete(localDb.newReferenceImages)..where((r) => r.stopId.isIn(stopIds))).go();
      }
      await (localDb.delete(localDb.trips)..where((t) => t.id.equals(tripId))).go();
    });

    return forkedTripId;
  }
}
