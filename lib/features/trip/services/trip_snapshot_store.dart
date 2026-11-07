import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/trip_snapshot_models.dart';

/// Abstract storage interface for itinerary snapshots.
abstract class TripSnapshotStore {
  /// Persists a snapshot payload to storage.
  Future<void> saveSnapshot(TripSnapshotPayload snapshot);

  /// Lists metadata for all snapshots belonging to [tripId], ordered by createdAt descending.
  Future<List<TripSnapshotMetadata>> listSnapshots(String tripId);

  /// Retrieves a specific snapshot by its ID.
  Future<TripSnapshotPayload?> getSnapshot(String snapshotId);

  /// Deletes a specific snapshot by its ID.
  Future<bool> deleteSnapshot(String snapshotId);

  /// Clears all snapshots belonging to [tripId].
  Future<void> clearSnapshots(String tripId);
}

/// In-memory implementation of [TripSnapshotStore] for tests and fast sessions.
class InMemoryTripSnapshotStore implements TripSnapshotStore {
  final Map<String, TripSnapshotPayload> _snapshots = {};

  @override
  Future<void> saveSnapshot(TripSnapshotPayload snapshot) async {
    _snapshots[snapshot.metadata.id] = snapshot;
  }

  @override
  Future<List<TripSnapshotMetadata>> listSnapshots(String tripId) async {
    final list = _snapshots.values
        .where((s) => s.metadata.tripId == tripId)
        .map((s) => s.metadata)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<TripSnapshotPayload?> getSnapshot(String snapshotId) async {
    return _snapshots[snapshotId];
  }

  @override
  Future<bool> deleteSnapshot(String snapshotId) async {
    return _snapshots.remove(snapshotId) != null;
  }

  @override
  Future<void> clearSnapshots(String tripId) async {
    _snapshots.removeWhere((id, payload) => payload.metadata.tripId == tripId);
  }
}

/// Local file-system implementation of [TripSnapshotStore] storing JSON files per trip.
class LocalDiskTripSnapshotStore implements TripSnapshotStore {
  final String? _customBasePath;

  LocalDiskTripSnapshotStore({String? customBasePath}) : _customBasePath = customBasePath;

  Future<Directory> _getBaseDirectory() async {
    if (_customBasePath != null) {
      final dir = Directory(_customBasePath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDocDir.path, 'itinerary_snapshots'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _getFile(String tripId, String snapshotId) async {
    final baseDir = await _getBaseDirectory();
    final tripDir = Directory(p.join(baseDir.path, tripId));
    if (!await tripDir.exists()) {
      await tripDir.create(recursive: true);
    }
    return File(p.join(tripDir.path, '$snapshotId.json'));
  }

  @override
  Future<void> saveSnapshot(TripSnapshotPayload snapshot) async {
    final file = await _getFile(snapshot.metadata.tripId, snapshot.metadata.id);
    final jsonString = snapshot.toJsonString();
    await file.writeAsString(jsonString, flush: true);
  }

  @override
  Future<List<TripSnapshotMetadata>> listSnapshots(String tripId) async {
    final baseDir = await _getBaseDirectory();
    final tripDir = Directory(p.join(baseDir.path, tripId));
    if (!await tripDir.exists()) {
      return const [];
    }

    final metadataList = <TripSnapshotMetadata>[];
    final entities = await tripDir.list().toList();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          final meta = TripSnapshotMetadata.fromJson(jsonMap['metadata'] as Map<String, dynamic>);
          metadataList.add(meta);
        } catch (e) {
          debugPrint('Error reading snapshot ${entity.path}: $e');
        }
      }
    }

    metadataList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return metadataList;
  }

  @override
  Future<TripSnapshotPayload?> getSnapshot(String snapshotId) async {
    final baseDir = await _getBaseDirectory();
    if (!await baseDir.exists()) return null;

    final tripDirs = await baseDir.list().toList();
    for (final tripDir in tripDirs) {
      if (tripDir is Directory) {
        final candidate = File(p.join(tripDir.path, '$snapshotId.json'));
        if (await candidate.exists()) {
          final content = await candidate.readAsString();
          return TripSnapshotPayload.fromJsonString(content);
        }
      }
    }
    return null;
  }

  @override
  Future<bool> deleteSnapshot(String snapshotId) async {
    final baseDir = await _getBaseDirectory();
    if (!await baseDir.exists()) return false;

    final tripDirs = await baseDir.list().toList();
    for (final tripDir in tripDirs) {
      if (tripDir is Directory) {
        final candidate = File(p.join(tripDir.path, '$snapshotId.json'));
        if (await candidate.exists()) {
          await candidate.delete();
          return true;
        }
      }
    }
    return false;
  }

  @override
  Future<void> clearSnapshots(String tripId) async {
    final baseDir = await _getBaseDirectory();
    final tripDir = Directory(p.join(baseDir.path, tripId));
    if (await tripDir.exists()) {
      await tripDir.delete(recursive: true);
    }
  }
}
