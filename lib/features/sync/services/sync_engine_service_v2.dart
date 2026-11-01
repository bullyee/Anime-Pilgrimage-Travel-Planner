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
      for (final remoteTrip in remoteTrips) {
        final tripId = remoteTrip['id'] as String?;
        if (tripId == null || tripId.isEmpty) continue;

        await _applyRemoteTrip(remoteTrip);
        _ensureSubcollectionWatchers(tripId);
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

  /// Push dirty records to Firestore. Never await remote calls inside local transactions.
  Future<void> _executePush() async {
    if (_isPushing || _pendingTripIdsToPush.isEmpty) return;
    _isPushing = true;

    final tripIds = Set<String>.from(_pendingTripIdsToPush);
    _pendingTripIdsToPush.clear();

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

        final batch = firestoreSync.createBatch();

        // 1. Trip doc
        if (trip.syncStatus == 1) {
          firestoreSync.buildTripBatchOperations(batch, trip);
        }

        // 2. Days
        for (final day in dirtyDays) {
          firestoreSync.buildDayBatchOperations(batch, day);
        }

        // 3. Stops (with labels)
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

          firestoreSync.buildStopBatchOperations(batch, stop, labels: labels);
        }

        // 4. Schedule items
        for (final item in dirtyItems) {
          firestoreSync.buildScheduleItemBatchOperations(batch, item);
        }

        // Remote commit outside transaction
        await firestoreSync.commitBatch(batch);

        // Mark local records as synced
        await localDb.transaction(() async {
          if (trip.syncStatus == 1) {
            await (localDb.update(localDb.trips)..where((t) => t.id.equals(tripId)))
                .write(const TripsCompanion(syncStatus: Value(0)));
          }

          if (dirtyDays.isNotEmpty) {
            final dayIds = dirtyDays.map((d) => d.id).toList();
            await (localDb.update(localDb.tripDays)..where((d) => d.id.isIn(dayIds)))
                .write(const TripDaysCompanion(syncStatus: Value(0)));
          }

          if (dirtyStops.isNotEmpty) {
            final stopIds = dirtyStops.map((s) => s.id).toList();
            await (localDb.update(localDb.stops)..where((s) => s.id.isIn(stopIds)))
                .write(const StopsCompanion(syncStatus: Value(0)));
          }

          if (dirtyItems.isNotEmpty) {
            final itemIds = dirtyItems.map((i) => i.id).toList();
            await (localDb.update(localDb.scheduleItems)..where((i) => i.id.isIn(itemIds)))
                .write(const ScheduleItemsCompanion(syncStatus: Value(0)));
          }
        });

        _updateStatus(tripId, TripSyncStatus.synced);
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

  /// Downstream pull: apply remote trip metadata to local SQLite.
  Future<void> _applyRemoteTrip(Map<String, dynamic> remoteData) async {
    final tripId = remoteData['id'] as String;
    final remoteUpdatedAt = _parseTimestamp(remoteData['updatedAt']);

    final localTrip = await (localDb.select(localDb.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();

    if (localTrip != null && remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localTrip.updatedAt)) {
      // Local is equal or newer
      return;
    }

    final deletedAt = _parseTimestamp(remoteData['deletedAt']);

    await localDb.into(localDb.trips).insertOnConflictUpdate(
          TripsCompanion(
            id: Value(tripId),
            title: Value(remoteData['title'] as String? ?? 'Untitled Trip'),
            description: Value(remoteData['description'] as String?),
            ownerId: Value(remoteData['ownerId'] as String? ?? currentUserId),
            sharing: Value(remoteData['sharing'] as String? ?? 'group'),
            startDate: Value(remoteData['startDate'] as String?),
            dayCount: Value((remoteData['dayCount'] as num?)?.toInt() ?? 1),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            updatedBy: Value(remoteData['updatedBy'] as String?),
            deletedAt: Value(deletedAt),
            syncStatus: const Value(0),
          ),
        );
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

  Future<void> _applyRemoteDay(Map<String, dynamic> data) async {
    final dayId = data['id'] as String;
    final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);

    final localDay = await (localDb.select(localDb.tripDays)..where((d) => d.id.equals(dayId))).getSingleOrNull();
    if (localDay != null && remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localDay.updatedAt)) {
      return;
    }

    final deletedAt = _parseTimestamp(data['deletedAt']);

    await localDb.into(localDb.tripDays).insertOnConflictUpdate(
          TripDaysCompanion(
            id: Value(dayId),
            tripId: Value(data['tripId'] as String),
            sortKey: Value(data['sortKey'] as String? ?? 'a0'),
            title: Value(data['title'] as String?),
            pinnedDate: Value(data['pinnedDate'] as String?),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            updatedBy: Value(data['updatedBy'] as String?),
            deletedAt: Value(deletedAt),
            syncStatus: const Value(0),
          ),
        );
  }

  Future<void> _applyRemoteStop(Map<String, dynamic> data) async {
    final stopId = data['id'] as String;
    final remoteUpdatedAt = _parseTimestamp(data['updatedAt']);

    final localStop = await (localDb.select(localDb.stops)..where((s) => s.id.equals(stopId))).getSingleOrNull();
    if (localStop != null && remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localStop.updatedAt)) {
      return;
    }

    final deletedAt = _parseTimestamp(data['deletedAt']);

    await localDb.into(localDb.stops).insertOnConflictUpdate(
          StopsCompanion(
            id: Value(stopId),
            tripId: Value(data['tripId'] as String),
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
            addedBy: Value(data['addedBy'] as String? ?? currentUserId),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            updatedBy: Value(data['updatedBy'] as String?),
            deletedAt: Value(deletedAt),
            syncStatus: const Value(0),
          ),
        );

    // Sync labels by natural key
    final labelsRaw = data['labels'] as List?;
    if (labelsRaw != null) {
      for (final raw in labelsRaw) {
        if (raw is! Map) continue;
        final kind = raw['kind'] as String? ?? 'tag';
        final name = raw['name'] as String? ?? '';
        final bangumiId = raw['bangumiId'] as String?;

        String? matchedLabelId;
        if (kind == 'anime' && bangumiId != null && bangumiId.isNotEmpty) {
          final existing = await (localDb.select(localDb.labels)
                ..where((l) => l.kind.equals('anime') & l.bangumiId.equals(bangumiId)))
              .getSingleOrNull();
          matchedLabelId = existing?.id;
        } else {
          final existing = await (localDb.select(localDb.labels)
                ..where((l) => l.kind.equals(kind) & l.name.equals(name)))
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

        // Link StopLabels
        await localDb.into(localDb.stopLabels).insertOnConflictUpdate(
              StopLabelsCompanion.insert(
                stopId: stopId,
                labelId: matchedLabelId,
              ),
            );
      }
    }
  }

  Future<void> _applyRemoteScheduleItem(Map<String, dynamic> data) async {
    final itemId = data['id'] as String;
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
            tripId: Value(data['tripId'] as String),
            stopId: Value(data['stopId'] as String),
            dayId: Value(data['dayId'] as String),
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
    _statusController.close();
  }
}
