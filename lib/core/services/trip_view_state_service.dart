import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages local view state tracking (such as `lastViewedAt` timestamps)
/// for trips on this device, with multi-account isolation.
///
/// Follows Stage 4 & Phase 2 specifications:
/// - Stored in a lightweight local JSON file (`trip_view_state.json`) in the
///   application support directory, avoiding disruptive SQLite migrations.
/// - Scoped per user ID (`"$userId:$tripId"`) to prevent state cross-contamination
///   when switching accounts on shared devices.
/// - In-memory cache for fast synchronous reads, with atomic file persistence.
/// - Broadcast stream for reactive UI updates across Riverpod providers.
class TripViewStateService {
  final Directory? _overrideDir;
  final StreamController<Map<String, DateTime>> _stateStreamController =
      StreamController<Map<String, DateTime>>.broadcast();

  final Map<String, DateTime> _viewTimestamps = {};
  bool _isLoaded = false;
  Completer<void>? _loadCompleter;

  TripViewStateService({Directory? overrideDir}) : _overrideDir = overrideDir;

  String _formatKey(String tripId, String? userId) {
    final effectiveUser = (userId != null && userId.trim().isNotEmpty) ? userId.trim() : 'guest';
    return '$effectiveUser:$tripId';
  }

  Future<File> _getFile() async {
    final dir = _overrideDir ?? await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'trip_view_state.json'));
  }

  /// Ensures that previously persisted timestamps are loaded into memory.
  Future<void> ensureLoaded() async {
    if (_isLoaded) return;
    if (_loadCompleter != null) return _loadCompleter!.future;

    final completer = Completer<void>();
    _loadCompleter = completer;

    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map) {
            decoded.forEach((key, val) {
              if (key is String && val is int) {
                _viewTimestamps[key] = DateTime.fromMillisecondsSinceEpoch(val);
              }
            });
          }
        }
      }
      _isLoaded = true;
      completer.complete();
    } catch (_) {
      // Graceful fallback to empty cache on read errors or malformed json
      _isLoaded = true;
      completer.complete();
    }
  }

  /// Marks a trip as viewed by [userId] at the given [at] timestamp (defaults to `DateTime.now()`).
  Future<void> markTripViewed(
    String tripId, {
    String? userId,
    DateTime? at,
  }) async {
    await ensureLoaded();
    final key = _formatKey(tripId, userId);
    final timestamp = at ?? DateTime.now();

    _viewTimestamps[key] = timestamp;
    _stateStreamController.add(Map.unmodifiable(_viewTimestamps));

    await _persist();
  }

  /// Synchronously returns the last viewed timestamp for [tripId] and [userId],
  /// or null if never viewed. Call [ensureLoaded] beforehand if invoking at startup.
  DateTime? getLastViewedAt(String tripId, {String? userId}) {
    final key = _formatKey(tripId, userId);
    return _viewTimestamps[key];
  }

  /// Streams the last viewed timestamp for [tripId] and [userId].
  Stream<DateTime?> watchLastViewedAt(String tripId, {String? userId}) async* {
    await ensureLoaded();
    final key = _formatKey(tripId, userId);
    yield _viewTimestamps[key];
    yield* _stateStreamController.stream.map((map) => map[key]);
  }

  /// Removes the view timestamp for a specific trip (e.g. on purge or deletion).
  Future<void> clearTrip(String tripId, {String? userId}) async {
    await ensureLoaded();
    final key = _formatKey(tripId, userId);
    if (_viewTimestamps.remove(key) != null) {
      _stateStreamController.add(Map.unmodifiable(_viewTimestamps));
      await _persist();
    }
  }

  /// Clears all local view state (e.g. during database reset or test cleanup).
  Future<void> clearAll() async {
    await ensureLoaded();
    _viewTimestamps.clear();
    _stateStreamController.add(const {});
    await _persist();
  }

  /// Atomically writes the in-memory view cache to disk using a temporary file.
  Future<void> _persist() async {
    try {
      final file = await _getFile();
      final data = <String, int>{};
      for (final entry in _viewTimestamps.entries) {
        data[entry.key] = entry.value.millisecondsSinceEpoch;
      }

      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonEncode(data), flush: true);

      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (_) {
      // Graceful error handling
    }
  }

  void dispose() {
    _stateStreamController.close();
  }
}
