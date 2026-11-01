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
}

/// Orchestrates two-way synchronization for V10 tables (Trips, Days, Stops, ScheduleItems).
class SyncEngineServiceV2 {
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

  /// Tracks trip IDs seen in `watchUserTrips` so we can detect when a collaborator
  /// is removed from `members` or the owner unshares the trip.
  final Set<String> _knownRemoteTripIds = <String>{};

  Timer? _debounceTimer;
  final Set<String> _pendingTripIdsToPush = <String>{};
  bool _isPushing = false;

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

    debugPrint('[SyncEngineV2] Starting V10 bidirectional sync orchestrator for user: $currentUserId');

    // 1. Upstream dirty Trips watcher
    final tripsQuery = localDb.select(localDb.trips)
      ..where((t) => t.syncStatus.equals(1) & t.sharing.equals('group'));
    _tripWatcherSub = tripsQuery.watch().listen((dirtyTrips) {
      if (dirtyTrips.isEmpty) return;
      for (final t in dirtyTrips) {
        _pendingTripIdsToPush.add(t.id);
        _updateStatus(t.id, TripSyncStatus.pending);
      }
      _scheduleDebouncedPush();
    });

    // 2. Upstream dirty TripDays watcher
    final daysQuery = localDb.select(localDb.tripDays).join([
      innerJoin(localDb.trips, localDb.trips.id.equalsExp(localDb.tripDays.tripId)),
    ])
      ..where(localDb.tripDays.syncStatus.equals(1) &
          localDb.trips.sharing.equals('group'));
    _dayWatcherSub = daysQuery.watch().listen((rows) {
      if (rows.isEmpty) return;
      for (final row in rows) {
        final day = row.readTable(localDb.tripDays);
        _pendingTripIdsToPush.add(day.tripId);
        _updateStatus(day.tripId, TripSyncStatus.pending);
      }
      _scheduleDebouncedPush();
    });

    // 3. Upstream dirty Stops watcher
    final stopsQuery = localDb.select(localDb.stops).join([
      innerJoin(localDb.trips, localDb.trips.id.equalsExp(localDb.stops.tripId)),
    ])
      ..where(localDb.stops.syncStatus.equals(1) &
          localDb.trips.sharing.equals('group'));
    _stopWatcherSub = stopsQuery.watch().listen((rows) {
      if (rows.isEmpty) return;
      for (final row in rows) {
        final stop = row.readTable(localDb.stops);
        _pendingTripIdsToPush.add(stop.tripId);
        _updateStatus(stop.tripId, TripSyncStatus.pending);
      }
      _scheduleDebouncedPush();
    });

    // 4. Upstream dirty ScheduleItems watcher
    final scheduleQuery = localDb.select(localDb.scheduleItems).join([
      innerJoin(localDb.trips, localDb.trips.id.equalsExp(localDb.scheduleItems.tripId)),
    ])
      ..where(localDb.scheduleItems.syncStatus.equals(1) &
          localDb.trips.sharing.equals('group'));
    _scheduleWatcherSub = scheduleQuery.watch().listen((rows) {
      if (rows.isEmpty) return;
      for (final row in rows) {
        final item = row.readTable(localDb.scheduleItems);
        _pendingTripIdsToPush.add(item.tripId);
        _updateStatus(item.tripId, TripSyncStatus.pending);
      }
      _scheduleDebouncedPush();
    });

    // 5. Downstream watchUserTrips listener
    _userTripsSub = firestoreSync.watchUserTrips(currentUserId).listen((remoteTrips) async {
      final currentRemoteTripIds = <String>{};
      for (final remoteTrip in remoteTrips) {
        final tripId = remoteTrip['id'] as String?;
        if (tripId == null || tripId.isEmpty) continue;
        currentRemoteTripIds.add(tripId);

        final keepWatching = await _applyRemoteTrip(remoteTrip);
        if (keepWatching) {
          _ensureSubcollectionWatchers(tripId);
        }
      }

      // Detect trips that vanished from watchUserTrips (e.g. collaborator was removed
      // from `members`, or owner unshared the trip setting `members: [ownerId]`).
      final disappearedIds = _knownRemoteTripIds.difference(currentRemoteTripIds);
      _knownRemoteTripIds
        ..clear()
        ..addAll(currentRemoteTripIds);

      final localCollaboratorTrips = await (localDb.select(localDb.trips)
            ..where((t) =>
                t.sharing.equals('group') &
                t.ownerId.isNotValue(currentUserId) &
                t.ownerId.isNotValue('guest_local_user')))
          .get();
      for (final localTrip in localCollaboratorTrips) {
        if (!currentRemoteTripIds.contains(localTrip.id)) {
          disappearedIds.add(localTrip.id);
        }
      }

      for (final removedTripId in disappearedIds) {
        final localTrip = await (localDb.select(localDb.trips)
              ..where((t) => t.id.equals(removedTripId)))
            .getSingleOrNull();
        if (localTrip != null && localTrip.ownerId != currentUserId) {
          await _convertCollaboratorTripToPrivate(removedTripId, null);
        } else {
          _cancelSubcollectionWatchers(removedTripId);
        }
      }
    });
  }

  void _scheduleDebouncedPush() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executePush();
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
        const TripDaysCompanion(syncStatus: Value(1)),
      );

      await (localDb.update(localDb.stops)..where((s) => s.tripId.equals(tripId))).write(
        const StopsCompanion(syncStatus: Value(1)),
      );

      await (localDb.update(localDb.scheduleItems)..where((i) => i.tripId.equals(tripId))).write(
        const ScheduleItemsCompanion(syncStatus: Value(1)),
      );
    });

    // Initialize cloud document
    final updatedTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingle();
    await firestoreSync.initializeCloudTrip(updatedTrip, currentUserId);

    _pendingTripIdsToPush.add(tripId);
    _scheduleDebouncedPush();
  }

  /// Push dirty records to Firestore, chunking batches under Firestore's 500-op limit.
  /// Never await remote calls inside local transactions.
  Future<void> _executePush() async {
    if (_isPushing || _pendingTripIdsToPush.isEmpty) return;
    _isPushing = true;

    final tripIds = Set<String>.from(_pendingTripIdsToPush);
    _pendingTripIdsToPush.clear();

    const maxBatchOps = 450;

    for (final tripId in tripIds) {
      try {
        final trip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
        if (trip == null || trip.sharing != 'group') continue;

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
        _updateStatus(tripId, TripSyncStatus.offline);
      }
    }

    _isPushing = false;
    if (_pendingTripIdsToPush.isNotEmpty) {
      _scheduleDebouncedPush();
    }
  }

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
          .write(const TripDaysCompanion(syncStatus: Value(0)));
      await (localDb.update(localDb.stops)..where((s) => s.tripId.equals(tripId)))
          .write(const StopsCompanion(syncStatus: Value(0)));
      await (localDb.update(localDb.scheduleItems)..where((i) => i.tripId.equals(tripId)))
          .write(const ScheduleItemsCompanion(syncStatus: Value(0)));
    });
    _updateStatus(tripId, TripSyncStatus.synced);
  }

  /// Downstream pull: apply remote trip metadata to local SQLite.
  /// Returns `true` if subcollection watchers should remain active for this trip.
  Future<bool> _applyRemoteTrip(Map<String, dynamic> remoteData) async {
    final tripId = remoteData['id'] as String;
    final remoteUpdatedAt = _parseTimestamp(remoteData['updatedAt']);
    final deletedAt = _parseTimestamp(remoteData['deletedAt']);
    final remoteOwnerId = remoteData['ownerId'] as String? ?? currentUserId;
    final remoteSharing = remoteData['sharing'] as String? ?? 'group';

    final localTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();

    // Per `docs/trip-sharing.md` & `docs/mvp-plan.md`:
    // "When the owner stops sharing or deletes the trip, every other member keeps a private, unsynced copy."
    final isCollaboratorCopy = localTrip != null &&
        localTrip.ownerId != currentUserId &&
        remoteOwnerId != currentUserId;
    if (isCollaboratorCopy && (deletedAt != null || remoteSharing == 'private')) {
      await _convertCollaboratorTripToPrivate(tripId, remoteUpdatedAt);
      return false;
    }

    if (localTrip != null && remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localTrip.updatedAt)) {
      // Local is equal or newer
      await _flushPendingForTrip(tripId);
      return true;
    }

    await localDb.into(localDb.trips).insertOnConflictUpdate(
          TripsCompanion(
            id: Value(tripId),
            title: Value(remoteData['title'] as String? ?? 'Untitled Trip'),
            description: Value(remoteData['description'] as String?),
            ownerId: Value(remoteOwnerId),
            sharing: Value(remoteSharing),
            startDate: Value(remoteData['startDate'] as String?),
            dayCount: Value((remoteData['dayCount'] as num?)?.toInt() ?? 1),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            updatedBy: Value(remoteData['updatedBy'] as String?),
            deletedAt: Value(deletedAt),
            syncStatus: const Value(0),
          ),
        );

    await _flushPendingForTrip(tripId);
    return true;
  }

  void _cancelSubcollectionWatchers(String tripId) {
    for (final suffix in ['days', 'stops', 'items']) {
      _subcollectionSubs.remove('$tripId:$suffix')?.cancel();
    }
  }

  /// Ensure downstream watchers for subcollections (days, stops, schedule_items).
  void _ensureSubcollectionWatchers(String tripId) {
    if (_subcollectionSubs.containsKey('$tripId:days')) return;

    // Days watcher
    _subcollectionSubs['$tripId:days'] = firestoreSync.watchTripDays(tripId).listen((daysList) async {
      for (final dayData in daysList) {
        await _applyRemoteDay(dayData);
      }
    });

    // Stops watcher
    _subcollectionSubs['$tripId:stops'] = firestoreSync.watchTripStops(tripId).listen((stopsList) async {
      for (final stopData in stopsList) {
        await _applyRemoteStop(stopData);
      }
    });

    // Schedule items watcher
    _subcollectionSubs['$tripId:items'] =
        firestoreSync.watchTripScheduleItems(tripId).listen((itemsList) async {
      for (final itemData in itemsList) {
        await _applyRemoteScheduleItem(itemData);
      }
    });
  }

  /// Flushes any buffered subcollection documents for [tripId] whose parent rows now exist.
  Future<void> _flushPendingForTrip(String tripId) async {
    final pendingDays = _pendingRemoteDays.values
        .where((d) => d['tripId'] == tripId)
        .toList();
    for (final dayData in pendingDays) {
      await _applyRemoteDay(dayData);
    }

    final pendingStops = _pendingRemoteStops.values
        .where((s) => s['tripId'] == tripId)
        .toList();
    for (final stopData in pendingStops) {
      await _applyRemoteStop(stopData);
    }

    final pendingItems = _pendingRemoteItems.values
        .where((i) => i['tripId'] == tripId)
        .toList();
    for (final itemData in pendingItems) {
      await _applyRemoteScheduleItem(itemData);
    }
  }

  Future<void> _applyRemoteDay(Map<String, dynamic> data) async {
    final dayId = data['id'] as String;
    final tripId = data['tripId'] as String;

    // Ensure parent trip exists locally before inserting child day
    final parentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (parentTrip == null) {
      _pendingRemoteDays[dayId] = data;
      return;
    }
    _pendingRemoteDays.remove(dayId);

    final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);

    final localDay = await (localDb.select(localDb.tripDays)..where((d) => d.id.equals(dayId))).getSingleOrNull();
    if (localDay != null && remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localDay.updatedAt)) {
      await _flushPendingScheduleItemsForParent(tripId);
      return;
    }

    final deletedAt = _parseTimestamp(data['deletedAt']);

    await localDb.into(localDb.tripDays).insertOnConflictUpdate(
          TripDaysCompanion(
            id: Value(dayId),
            tripId: Value(tripId),
            sortKey: Value(data['sortKey'] as String? ?? 'a0'),
            title: Value(data['title'] as String?),
            pinnedDate: Value(data['pinnedDate'] as String?),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            updatedBy: Value(data['updatedBy'] as String?),
            deletedAt: Value(deletedAt),
            syncStatus: const Value(0),
          ),
        );

    await _flushPendingScheduleItemsForParent(tripId);
  }

  Future<void> _applyRemoteStop(Map<String, dynamic> data) async {
    final stopId = data['id'] as String;
    final tripId = data['tripId'] as String;

    // Ensure parent trip exists locally before inserting child stop
    final parentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (parentTrip == null) {
      _pendingRemoteStops[stopId] = data;
      return;
    }
    _pendingRemoteStops.remove(stopId);

    final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);

    final localStop = await (localDb.select(localDb.stops)..where((s) => s.id.equals(stopId))).getSingleOrNull();
    if (localStop != null && remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localStop.updatedAt)) {
      await _flushPendingScheduleItemsForParent(tripId);
      return;
    }

    final deletedAt = _parseTimestamp(data['deletedAt']);

    await localDb.into(localDb.stops).insertOnConflictUpdate(
          StopsCompanion(
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
            addedBy: Value(data['addedBy'] as String? ?? currentUserId),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            updatedBy: Value(data['updatedBy'] as String?),
            deletedAt: Value(deletedAt),
            syncStatus: const Value(0),
          ),
        );

    // Sync labels by natural key (replace stop_labels so removed labels are detached)
    final senderToLocalLabelId = <String, String>{};
    final matchedAnimeLabelIds = <String>[];
    final labelsRaw = data['labels'] as List?;
    if (labelsRaw != null) {
      await (localDb.delete(localDb.stopLabels)..where((sl) => sl.stopId.equals(stopId))).go();

      for (final raw in labelsRaw) {
        if (raw is! Map) continue;
        final senderId = raw['id'] as String?;
        final kind = raw['kind'] as String? ?? 'tag';
        final name = raw['name'] as String? ?? '';
        final bangumiId = raw['bangumiId'] as String?;

        String? matchedLabelId;
        if (kind == 'anime' && bangumiId != null && bangumiId.isNotEmpty) {
          final existing = await (localDb.select(localDb.labels)
                ..where((l) => l.kind.equals('anime') & l.bangumiId.equals(bangumiId))
                ..limit(1))
              .getSingleOrNull();
          if (existing != null) {
            matchedLabelId = existing.id;
          } else {
            // Upgrade an existing anime label with the same name and null bangumiId if present
            final byNameNoBangumi = await (localDb.select(localDb.labels)
                  ..where((l) =>
                      l.kind.equals('anime') & l.name.equals(name) & l.bangumiId.isNull())
                  ..limit(1))
                .getSingleOrNull();
            if (byNameNoBangumi != null) {
              await (localDb.update(localDb.labels)..where((l) => l.id.equals(byNameNoBangumi.id)))
                  .write(LabelsCompanion(bangumiId: Value(bangumiId)));
              matchedLabelId = byNameNoBangumi.id;
            }
          }
        } else {
          final existing = await (localDb.select(localDb.labels)
                ..where((l) => l.kind.equals(kind) & l.name.equals(name))
                ..limit(1))
              .getSingleOrNull();
          matchedLabelId = existing?.id;
        }

        if (matchedLabelId == null) {
          matchedLabelId = const Uuid().v4();
          await localDb.into(localDb.labels).insert(
                LabelsCompanion.insert(
                  id: matchedLabelId,
                  kind: kind,
                  name: name,
                  bangumiId: Value(bangumiId),
                ),
              );
        }

        if (senderId != null && senderId.isNotEmpty) {
          senderToLocalLabelId[senderId] = matchedLabelId;
        }
        if (kind == 'anime') {
          matchedAnimeLabelIds.add(matchedLabelId);
        }

        // Link StopLabels
        await localDb.into(localDb.stopLabels).insertOnConflictUpdate(
              StopLabelsCompanion.insert(
                stopId: stopId,
                labelId: matchedLabelId,
              ),
            );
      }
    }

    // Sync URL-backed reference images for this stop while preserving cached localPath
    // and local-only (remoteUrl == null) reference images.
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

    await _flushPendingScheduleItemsForParent(tripId);
  }

  Future<void> _flushPendingScheduleItemsForParent(String tripId) async {
    final pendingItems = _pendingRemoteItems.values
        .where((i) => i['tripId'] == tripId)
        .toList();
    for (final itemData in pendingItems) {
      await _applyRemoteScheduleItem(itemData);
    }
  }

  Future<void> _applyRemoteScheduleItem(Map<String, dynamic> data) async {
    final itemId = data['id'] as String;
    final tripId = data['tripId'] as String;
    final stopId = data['stopId'] as String;
    final dayId = data['dayId'] as String;

    // Ensure parent trip, day, and stop exist locally before inserting schedule_item (FK safety)
    final parentTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    final parentDay = await (localDb.select(localDb.tripDays)..where((d) => d.id.equals(dayId))).getSingleOrNull();
    final parentStop = await (localDb.select(localDb.stops)..where((s) => s.id.equals(stopId))).getSingleOrNull();
    if (parentTrip == null || parentDay == null || parentStop == null) {
      _pendingRemoteItems[itemId] = data;
      return;
    }
    _pendingRemoteItems.remove(itemId);

    final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);

    final localItem =
        await (localDb.select(localDb.scheduleItems)..where((i) => i.id.equals(itemId))).getSingleOrNull();
    if (localItem != null && remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localItem.updatedAt)) {
      return;
    }

    final deletedAt = _parseTimestamp(data['deletedAt']);

    await localDb.into(localDb.scheduleItems).insertOnConflictUpdate(
          ScheduleItemsCompanion(
            id: Value(itemId),
            tripId: Value(tripId),
            stopId: Value(stopId),
            dayId: Value(dayId),
            sortKey: Value(data['sortKey'] as String? ?? 'a0'),
            stayMinutes: Value((data['stayMinutes'] as num?)?.toInt() ?? 60),
            transitMinutes: Value((data['transitMinutes'] as num?)?.toInt() ?? 0),
            fixedTime: Value((data['fixedTime'] as num?)?.toInt()),
            status: Value(data['status'] as String? ?? 'planned'),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            updatedBy: Value(data['updatedBy'] as String?),
            deletedAt: Value(deletedAt),
            syncStatus: const Value(0),
          ),
        );
  }

  DateTime? _parseTimestamp(dynamic val) {
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  void stopSync() {
    debugPrint('[SyncEngineV2] Stopping sync orchestrator...');
    _debounceTimer?.cancel();
    _tripWatcherSub?.cancel();
    _dayWatcherSub?.cancel();
    _stopWatcherSub?.cancel();
    _scheduleWatcherSub?.cancel();
    _userTripsSub?.cancel();
    for (final sub in _subcollectionSubs.values) {
      sub.cancel();
    }
    _subcollectionSubs.clear();
    _pendingRemoteDays.clear();
    _pendingRemoteStops.clear();
    _pendingRemoteItems.clear();
    _knownRemoteTripIds.clear();
    _statusController.close();
  }
}
