import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/archive_isolate.dart';
import 'transfer_foreground_service.dart';

/// What a background frame transfer does.
enum TransferKind {
  /// A shared trip's local-only frames up to the user's Google Drive.
  driveUpload,

  /// Photos picked for one stop, up to Google Drive.
  stopUpload,

  /// A trip's linked frames down into the cache, for offline.
  download,

  /// A `.pilgrimage-frames` pack's frames onto a trip.
  packImport;

  bool get isUpload => this == driveUpload || this == stopUpload;

  /// The notification's and the progress strip's headline.
  String get headline => switch (this) {
    driveUpload || stopUpload => 'Uploading frames to Google Drive',
    download => 'Downloading frames',
    packImport => 'Importing frames',
  };
}

/// Thrown by a job that can't go on without the user, e.g. Google wants the
/// user to sign in again while the app is in the background. The job ends
/// and the user is asked to open the app and continue.
class TransferNeedsUserException implements Exception {
  final String message;
  final Object? cause;

  const TransferNeedsUserException(this.message, {this.cause});

  @override
  String toString() => message;
}

/// What a running job can see and report.
class TransferContext {
  final void Function(int done, int total) progress;
  final BackupCancel cancel;
  final bool Function() isAppVisible;

  const TransferContext({required this.progress, required this.cancel, required this.isAppVisible});
}

/// A job for the queue: what it is, and how to run it. [run] returns the
/// sentence to show when it is done.
class TransferJobSpec {
  final TransferKind kind;
  final String tripId;
  final String tripTitle;
  final Future<String> Function(TransferContext ctx) run;

  /// Remembered on disk until it finishes, so a run the system cut short can
  /// be offered again on the next start (see [TransferJournal]).
  final bool journaled;

  /// A second job of the same kind for the same trip joins the first rather
  /// than queueing again.
  final bool dedupe;

  /// Leaves no notice and no final notification (automatic downloads).
  final bool quiet;

  const TransferJobSpec({
    required this.kind,
    required this.tripId,
    required this.tripTitle,
    required this.run,
    this.journaled = false,
    this.dedupe = true,
    this.quiet = false,
  });
}

/// A queued or running job, as the screens show it.
@immutable
class TransferJobView {
  final String id;
  final TransferKind kind;
  final String tripId;
  final String tripTitle;
  final int done;
  final int total;
  final bool cancelling;

  const TransferJobView({
    required this.id,
    required this.kind,
    required this.tripId,
    required this.tripTitle,
    this.done = 0,
    this.total = 0,
    this.cancelling = false,
  });

  double? get fraction => total <= 0 ? null : (done / total).clamp(0.0, 1.0);

  /// "120 of 405", or "Getting ready…" before the total is known.
  String get countText => total <= 0 ? 'Getting ready…' : '$done of $total';

  TransferJobView copyWith({int? done, int? total, bool? cancelling}) => TransferJobView(
    id: id,
    kind: kind,
    tripId: tripId,
    tripTitle: tripTitle,
    done: done ?? this.done,
    total: total ?? this.total,
    cancelling: cancelling ?? this.cancelling,
  );
}

enum TransferNoticeType { done, failed, cancelled, needsUser, resumable }

/// A finished job's outcome (or an offer to resume), until dismissed.
@immutable
class TransferNotice {
  final String id;
  final TransferKind kind;
  final String tripId;
  final String tripTitle;
  final TransferNoticeType type;
  final String message;

  const TransferNotice({
    required this.id,
    required this.kind,
    required this.tripId,
    required this.tripTitle,
    required this.type,
    required this.message,
  });

  bool get isError => type == TransferNoticeType.failed;

  /// Whether the way on is to open the trip and start the upload again.
  bool get offersResume => type == TransferNoticeType.needsUser || type == TransferNoticeType.resumable;
}

@immutable
class FrameTransferState {
  final TransferJobView? current;
  final List<TransferJobView> queued;
  final List<TransferNotice> notices;

  const FrameTransferState({this.current, this.queued = const [], this.notices = const []});

  bool get isBusy => current != null;

  /// The running or queued job of [kind] for [tripId], if any.
  TransferJobView? jobFor(String tripId, TransferKind kind) {
    final c = current;
    if (c != null && c.tripId == tripId && c.kind == kind) return c;
    for (final q in queued) {
      if (q.tripId == tripId && q.kind == kind) return q;
    }
    return null;
  }

  /// The running or queued jobs for [tripId].
  List<TransferJobView> jobsForTrip(String tripId) => [
    if (current != null && current!.tripId == tripId) current!,
    for (final q in queued)
      if (q.tripId == tripId) q,
  ];

  FrameTransferState copyWith({
    TransferJobView? current,
    bool clearCurrent = false,
    List<TransferJobView>? queued,
    List<TransferNotice>? notices,
  }) => FrameTransferState(
    current: clearCurrent ? null : (current ?? this.current),
    queued: queued ?? this.queued,
    notices: notices ?? this.notices,
  );
}

/// A job remembered on disk while it runs.
@immutable
class TransferJournalEntry {
  final TransferKind kind;
  final String tripId;
  final String tripTitle;

  const TransferJournalEntry({required this.kind, required this.tripId, required this.tripTitle});

  Map<String, Object?> toJson() => {'kind': kind.name, 'tripId': tripId, 'tripTitle': tripTitle};

  static TransferJournalEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = TransferKind.values.where((k) => k.name == raw['kind']).firstOrNull;
    final tripId = raw['tripId'];
    if (kind == null || tripId is! String || tripId.isEmpty) return null;
    return TransferJournalEntry(kind: kind, tripId: tripId, tripTitle: raw['tripTitle'] as String? ?? '');
  }

  @override
  bool operator ==(Object other) => other is TransferJournalEntry && other.kind == kind && other.tripId == tripId;

  @override
  int get hashCode => Object.hash(kind, tripId);
}

/// The jobs that were running or waiting, kept on disk so the next start can
/// tell which trips were cut short. The work itself is always derived from
/// the database again (frames without a link, links not cached yet).
abstract class TransferJournal {
  Future<List<TransferJournalEntry>> read();
  Future<void> add(TransferJournalEntry entry);
  Future<void> remove(TransferJournalEntry entry);
}

class InMemoryTransferJournal implements TransferJournal {
  final entries = <TransferJournalEntry>[];

  @override
  Future<List<TransferJournalEntry>> read() async => List.of(entries);

  @override
  Future<void> add(TransferJournalEntry entry) async {
    if (!entries.contains(entry)) entries.add(entry);
  }

  @override
  Future<void> remove(TransferJournalEntry entry) async => entries.remove(entry);
}

/// A small JSON file in the app's support folder.
class FileTransferJournal implements TransferJournal {
  final Future<Directory> Function() _dir;
  Future<void> _chain = Future.value();

  FileTransferJournal({Future<Directory> Function()? dir}) : _dir = dir ?? getApplicationSupportDirectory;

  Future<File> _file() async => File(p.join((await _dir()).path, 'frame_transfers.json'));

  Future<List<TransferJournalEntry>> _readNow() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return [];
      return [for (final e in raw) ?TransferJournalEntry.fromJson(e)];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<TransferJournalEntry> entries) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode([for (final e in entries) e.toJson()]), flush: true);
    } catch (e) {
      debugPrint('[FileTransferJournal] write failed: $e');
    }
  }

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _chain.then((_) => op());
    _chain = next.then((_) {}, onError: (_) {});
    return next;
  }

  @override
  Future<List<TransferJournalEntry>> read() => _serial(_readNow);

  @override
  Future<void> add(TransferJournalEntry entry) => _serial(() async {
    final entries = await _readNow();
    if (entries.contains(entry)) return;
    await _write([...entries, entry]);
  });

  @override
  Future<void> remove(TransferJournalEntry entry) => _serial(() async {
    final entries = await _readNow();
    if (!entries.contains(entry)) return;
    await _write([
      for (final e in entries)
        if (e != entry) e,
    ]);
  });
}

final transferJournalProvider = Provider<TransferJournal>((ref) => FileTransferJournal());

/// Runs frame uploads, downloads and pack imports one at a time, off the
/// screen that started them, and keeps the platform's foreground service
/// (Android) up while there is work, so they go on with the screen off, in
/// another app, or after the app is swiped away.
class FrameTransferQueue extends Notifier<FrameTransferState> {
  /// How often the notification may change; the strip in the app updates on
  /// every frame.
  static const notificationInterval = Duration(milliseconds: 500);

  final _specs = <String, TransferJobSpec>{};
  final _pending = <String>[];
  BackupCancel? _currentCancel;
  Completer<void>? _currentEnded;
  var _pumping = false;
  var _serviceUp = false;
  var _askedForNotifications = false;
  var _seq = 0;
  DateTime _lastNotified = DateTime.fromMillisecondsSinceEpoch(0);

  /// Completes when the queue next becomes idle (for tests and callers that
  /// want to wait).
  Completer<void>? _idle;

  TransferForegroundService get _service => ref.read(transferForegroundServiceProvider);
  TransferJournal get _journal => ref.read(transferJournalProvider);

  @override
  FrameTransferState build() {
    final service = ref.watch(transferForegroundServiceProvider);
    service.onCancel = cancelCurrent;
    ref.onDispose(() {
      service.onCancel = null;
      _currentCancel?.cancel();
    });
    return const FrameTransferState();
  }

  /// Completes once nothing is running or queued.
  Future<void> whenIdle() {
    if (!state.isBusy && _pending.isEmpty) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  /// Queues [spec] and returns its job ID; a job of the same kind for the
  /// same trip already running or queued is returned instead (if [dedupe]).
  String enqueue(TransferJobSpec spec) {
    if (spec.dedupe) {
      final existing = state.jobFor(spec.tripId, spec.kind);
      if (existing != null) return existing.id;
    }
    final id = 'job${++_seq}';
    _specs[id] = spec;
    _pending.add(id);
    final view = TransferJobView(id: id, kind: spec.kind, tripId: spec.tripId, tripTitle: spec.tripTitle);
    // A new run of this trip's job replaces its old outcome.
    state = state.copyWith(
      queued: [...state.queued, view],
      notices: [
        for (final n in state.notices)
          if (!(n.tripId == spec.tripId && n.kind == spec.kind)) n,
      ],
    );
    if (spec.journaled) {
      unawaited(_journal.add(TransferJournalEntry(kind: spec.kind, tripId: spec.tripId, tripTitle: spec.tripTitle)));
    }
    if (!_askedForNotifications) {
      _askedForNotifications = true;
      unawaited(_service.requestNotificationPermission());
    }
    unawaited(_pump());
    return id;
  }

  /// Cancels [jobId]: a queued one is dropped, the running one stops after
  /// the frame in flight.
  void cancel(String jobId) {
    if (state.current?.id == jobId) {
      cancelCurrent();
      return;
    }
    if (!_pending.remove(jobId)) return;
    final spec = _specs.remove(jobId);
    state = state.copyWith(
      queued: [
        for (final q in state.queued)
          if (q.id != jobId) q,
      ],
    );
    if (spec != null && spec.journaled) unawaited(_journal.remove(_entryOf(spec)));
    _completeIdleIfDone();
  }

  /// Cancels the running job (the notification's Cancel).
  void cancelCurrent() {
    final c = state.current;
    if (c == null) return;
    _currentCancel?.cancel();
    state = state.copyWith(current: c.copyWith(cancelling: true));
  }

  /// Cancels the uploads of [tripId] (every trip's when null), queued and
  /// running, and completes once the running one has stopped (after the
  /// frames in flight are committed), so its files can be removed safely.
  Future<void> cancelUploads({String? tripId}) async {
    bool matches(TransferJobView j) => j.kind.isUpload && (tripId == null || j.tripId == tripId);
    for (final q in List.of(state.queued)) {
      if (matches(q)) cancel(q.id);
    }
    final c = state.current;
    if (c != null && matches(c)) {
      final ended = _currentEnded;
      cancelCurrent();
      await ended?.future;
    }
  }

  /// Cancels everything: the running job and the queue.
  void cancelAll() {
    for (final id in List.of(_pending)) {
      cancel(id);
    }
    cancelCurrent();
  }

  void dismissNotice(String noticeId) {
    state = state.copyWith(
      notices: [
        for (final n in state.notices)
          if (n.id != noticeId) n,
      ],
    );
  }

  /// Adds a notice from outside a job (e.g. "N frames left to upload ·
  /// Resume" on start). Replaces one of the same kind for the same trip.
  void addNotice({
    required TransferKind kind,
    required String tripId,
    required String tripTitle,
    required TransferNoticeType type,
    required String message,
  }) {
    final notice = TransferNotice(
      id: 'notice${++_seq}',
      kind: kind,
      tripId: tripId,
      tripTitle: tripTitle,
      type: type,
      message: message,
    );
    state = state.copyWith(
      notices: [
        for (final n in state.notices)
          if (!(n.tripId == tripId && n.kind == kind)) n,
        notice,
      ],
    );
  }

  /// Forgets a journaled job (e.g. its trip has nothing left to do).
  Future<void> forgetJournaled(TransferKind kind, String tripId) =>
      _journal.remove(TransferJournalEntry(kind: kind, tripId: tripId, tripTitle: ''));

  TransferJournalEntry _entryOf(TransferJobSpec s) =>
      TransferJournalEntry(kind: s.kind, tripId: s.tripId, tripTitle: s.tripTitle);

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    TransferNotice? lastOutcome;
    try {
      while (_pending.isNotEmpty) {
        final id = _pending.removeAt(0);
        final spec = _specs.remove(id);
        if (spec == null) continue;
        final view = state.queued.firstWhere(
          (q) => q.id == id,
          orElse: () => TransferJobView(id: id, kind: spec.kind, tripId: spec.tripId, tripTitle: spec.tripTitle),
        );
        state = state.copyWith(
          current: view,
          queued: [
            for (final q in state.queued)
              if (q.id != id) q,
          ],
        );
        final cancel = BackupCancel();
        _currentCancel = cancel;
        final ended = _currentEnded = Completer<void>();
        await _showProgress(view, force: true);

        final outcome = await _runOne(id, spec, cancel);
        _currentCancel = null;
        _currentEnded = null;
        ended.complete();
        if (!spec.quiet) lastOutcome = outcome;
        state = state.copyWith(clearCurrent: true, notices: [...state.notices, if (!spec.quiet) outcome]);
      }
    } finally {
      _pumping = false;
      await _stopService(lastOutcome);
      _completeIdleIfDone();
    }
  }

  Future<TransferNotice> _runOne(String id, TransferJobSpec spec, BackupCancel cancel) async {
    TransferNotice outcome(TransferNoticeType type, String message) => TransferNotice(
      id: 'notice${++_seq}',
      kind: spec.kind,
      tripId: spec.tripId,
      tripTitle: spec.tripTitle,
      type: type,
      message: message,
    );
    final ctx = TransferContext(
      cancel: cancel,
      isAppVisible: ref.read(appVisibleProvider),
      progress: (done, total) {
        final c = state.current;
        if (c == null || c.id != id) return;
        final next = c.copyWith(done: done, total: total);
        state = state.copyWith(current: next);
        unawaited(_showProgress(next));
      },
    );
    try {
      final message = await spec.run(ctx);
      if (spec.journaled) await _journal.remove(_entryOf(spec));
      return outcome(TransferNoticeType.done, message);
    } on BackupCancelled {
      if (spec.journaled) await _journal.remove(_entryOf(spec));
      return outcome(TransferNoticeType.cancelled, '${_what(spec.kind)} cancelled.');
    } on TransferNeedsUserException catch (e) {
      return outcome(TransferNoticeType.needsUser, e.message);
    } catch (e, st) {
      debugPrint('[FrameTransferQueue] ${spec.kind.name} for ${spec.tripId} failed: $e\n$st');
      if (cancel.isCancelled) {
        if (spec.journaled) await _journal.remove(_entryOf(spec));
        return outcome(TransferNoticeType.cancelled, '${_what(spec.kind)} cancelled.');
      }
      return outcome(TransferNoticeType.failed, '${_what(spec.kind)} stopped: ${_errorText(e)}');
    }
  }

  Future<void> _showProgress(TransferJobView job, {bool force = false}) async {
    final now = DateTime.now();
    final finished = job.total > 0 && job.done >= job.total;
    if (!force && !finished && now.difference(_lastNotified) < notificationInterval) return;
    _lastNotified = now;
    final more = state.queued.length;
    final n = TransferNotification(
      jobId: job.id,
      title: job.kind.headline,
      text: [
        job.total <= 0 ? 'Getting ready…' : '${job.done} of ${job.total}',
        if (job.tripTitle.isNotEmpty) job.tripTitle,
        if (more > 0) '+$more more',
      ].join(' · '),
      done: job.done,
      total: job.total,
      upload: job.kind.isUpload,
    );
    if (!_serviceUp) {
      _serviceUp = true;
      await _service.start(n);
    } else {
      await _service.update(n);
    }
  }

  Future<void> _stopService(TransferNotice? last) async {
    if (!_serviceUp) return;
    _serviceUp = false;
    // On screen, the app shows the outcome itself; otherwise leave a note.
    final visible = ref.read(appVisibleProvider)();
    if (visible || last == null || last.type == TransferNoticeType.cancelled) {
      await _service.stop();
      return;
    }
    final title = switch (last.type) {
      TransferNoticeType.needsUser => 'Open Trip Planner to continue',
      TransferNoticeType.failed => '${_what(last.kind)} stopped',
      _ =>
        last.kind.isUpload
            ? 'Frames uploaded'
            : (last.kind == TransferKind.download ? 'Frames downloaded' : 'Frames imported'),
    };
    await _service.stop(title: title, text: last.message);
  }

  void _completeIdleIfDone() {
    if (state.isBusy || _pending.isNotEmpty || _pumping) return;
    final idle = _idle;
    _idle = null;
    if (idle != null && !idle.isCompleted) idle.complete();
  }

  static String _what(TransferKind kind) => switch (kind) {
    TransferKind.driveUpload || TransferKind.stopUpload => 'Upload',
    TransferKind.download => 'Download',
    TransferKind.packImport => 'Import',
  };

  static String _errorText(Object e) {
    if (e is BackupFormatException) return e.message;
    final s = '$e';
    return s.startsWith('Exception: ') ? s.substring('Exception: '.length) : s;
  }
}

final frameTransferQueueProvider = NotifierProvider<FrameTransferQueue, FrameTransferState>(FrameTransferQueue.new);
