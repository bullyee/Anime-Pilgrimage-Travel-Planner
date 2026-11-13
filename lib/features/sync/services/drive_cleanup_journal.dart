import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// What this user put on their Google Drive for trips, and the removals
/// still to do. Kept per user on the phone (not in the database, which a
/// teammate's sync also writes): the files listed here are known to be this
/// user's own, so they can be removed without asking Drive whose they are.
@immutable
class DriveCleanupState {
  /// Uploaded frame files: Drive file ID → trip ID.
  final Map<String, String> files;

  /// Trip folders created for link sharing: Drive folder ID → trip ID.
  final Map<String, String> folders;

  /// Trips whose removal was asked for and hasn't finished yet.
  final List<String> pendingTrips;

  /// "Remove all my shared frames" was asked for and hasn't finished yet.
  final bool pendingAll;

  const DriveCleanupState({
    this.files = const {},
    this.folders = const {},
    this.pendingTrips = const [],
    this.pendingAll = false,
  });

  bool get isEmpty => files.isEmpty && folders.isEmpty && pendingTrips.isEmpty && !pendingAll;

  DriveCleanupState copyWith({
    Map<String, String>? files,
    Map<String, String>? folders,
    List<String>? pendingTrips,
    bool? pendingAll,
  }) => DriveCleanupState(
    files: files ?? this.files,
    folders: folders ?? this.folders,
    pendingTrips: pendingTrips ?? this.pendingTrips,
    pendingAll: pendingAll ?? this.pendingAll,
  );

  Map<String, Object?> toJson() => {
    'files': files,
    'folders': folders,
    'pendingTrips': pendingTrips,
    'pendingAll': pendingAll,
  };

  static DriveCleanupState fromJson(Object? raw) {
    if (raw is! Map) return const DriveCleanupState();
    Map<String, String> strings(Object? m) => {
      if (m is Map)
        for (final e in m.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
    };
    return DriveCleanupState(
      files: strings(raw['files']),
      folders: strings(raw['folders']),
      pendingTrips: [
        if (raw['pendingTrips'] is List)
          for (final t in raw['pendingTrips'] as List)
            if (t is String && t.isNotEmpty) t,
      ],
      pendingAll: raw['pendingAll'] == true,
    );
  }
}

/// Where [DriveCleanupState] is kept. Changes are serialized.
abstract class DriveCleanupJournal {
  Future<DriveCleanupState> read();

  /// Applies [change] to the stored state.
  Future<void> update(DriveCleanupState Function(DriveCleanupState state) change);

  /// Fires after each change.
  Stream<void> get changes;

  Future<void> recordFile(String fileId, String tripId) =>
      update((s) => s.copyWith(files: {...s.files, fileId: tripId}));

  Future<void> recordFolder(String folderId, String tripId) => update(
    (s) => s.folders[folderId] == tripId ? s : s.copyWith(folders: {...s.folders, folderId: tripId}),
  );

  /// Forgets files and folders that are gone (or not this user's).
  Future<void> forget(Iterable<String> ids) {
    final gone = ids.toSet();
    if (gone.isEmpty) return Future.value();
    return update(
      (s) => s.copyWith(
        files: {for (final e in s.files.entries) if (!gone.contains(e.key)) e.key: e.value},
        folders: {for (final e in s.folders.entries) if (!gone.contains(e.key)) e.key: e.value},
      ),
    );
  }

  Future<void> addPendingTrip(String tripId) =>
      update((s) => s.pendingTrips.contains(tripId) ? s : s.copyWith(pendingTrips: [...s.pendingTrips, tripId]));

  Future<void> removePendingTrip(String tripId) => update(
    (s) => s.pendingTrips.contains(tripId)
        ? s.copyWith(pendingTrips: [for (final t in s.pendingTrips) if (t != tripId) t])
        : s,
  );

  Future<void> setPendingAll(bool pending) => update((s) => s.pendingAll == pending ? s : s.copyWith(pendingAll: pending));
}

class InMemoryDriveCleanupJournal extends DriveCleanupJournal {
  DriveCleanupState state;
  final _changes = StreamController<void>.broadcast();

  InMemoryDriveCleanupJournal([this.state = const DriveCleanupState()]);

  @override
  Future<DriveCleanupState> read() async => state;

  @override
  Future<void> update(DriveCleanupState Function(DriveCleanupState state) change) async {
    final next = change(state);
    if (identical(next, state)) return;
    state = next;
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;
}

/// A small JSON file per user in the app's support folder.
class FileDriveCleanupJournal extends DriveCleanupJournal {
  final String userId;
  final Future<Directory> Function() _dir;
  final _changes = StreamController<void>.broadcast();
  Future<void> _chain = Future.value();

  FileDriveCleanupJournal(this.userId, {Future<Directory> Function()? dir})
    : _dir = dir ?? getApplicationSupportDirectory;

  Future<File> _file() async {
    final safe = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File(p.join((await _dir()).path, 'drive_cleanup_$safe.json'));
  }

  Future<DriveCleanupState> _readNow() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const DriveCleanupState();
      return DriveCleanupState.fromJson(jsonDecode(await f.readAsString()));
    } catch (_) {
      return const DriveCleanupState();
    }
  }

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _chain.then((_) => op());
    _chain = next.then((_) {}, onError: (_) {});
    return next;
  }

  @override
  Future<DriveCleanupState> read() => _serial(_readNow);

  @override
  Future<void> update(DriveCleanupState Function(DriveCleanupState state) change) => _serial(() async {
    final current = await _readNow();
    final next = change(current);
    if (identical(next, current)) return;
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(next.toJson()), flush: true);
    } catch (e) {
      debugPrint('[FileDriveCleanupJournal] write failed: $e');
    }
    _changes.add(null);
  });

  @override
  Stream<void> get changes => _changes.stream;
}
