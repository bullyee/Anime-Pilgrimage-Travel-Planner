import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

typedef BackupProgress = void Function(int done, int total);

/// A file that isn't a backup or frame pack this app can read.
class BackupFormatException implements Exception {
  final String message;

  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// Thrown by an export or import stopped with [BackupCancel.cancel].
class BackupCancelled implements Exception {
  const BackupCancelled();
}

/// Lets the screen stop an archive export or import while its files are copied.
class BackupCancel {
  final _listeners = <void Function()>[];
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void onCancel(void Function() listener) => _listeners.add(listener);
}

/// Runs [worker] in a background isolate with progress and cancellation support.
///
/// The worker first sends a [SendPort] that takes `'cancel'`, then `[done, total]`
/// progress updates, and finishes with `'done'`, `'cancelled'`, or `['error', message]`.
Future<void> runArchiveIsolate(
  Future<void> Function(List<Object?>) worker,
  List<Object?> args, {
  BackupProgress? onProgress,
  BackupCancel? cancel,
}) async {
  if (cancel?.isCancelled ?? false) throw const BackupCancelled();
  final port = ReceivePort();
  final done = Completer<void>();
  SendPort? control;
  var cancelRequested = false;
  await Isolate.spawn(worker, [...args, port.sendPort], onExit: port.sendPort);
  port.listen((msg) {
    if (done.isCompleted) return;
    switch (msg) {
      case final SendPort p:
        control = p;
        if (cancelRequested) p.send('cancel');
      case [final int n, final int total]:
        onProgress?.call(n, total);
      case 'done':
        done.complete();
      case 'cancelled':
        done.completeError(const BackupCancelled());
      case ['error', final String message]:
        done.completeError(Exception(message));
      default:
        done.completeError(Exception('The archive operation stopped unexpectedly.'));
    }
  });
  cancel?.onCancel(() {
    cancelRequested = true;
    control?.send('cancel');
  });
  try {
    await done.future;
  } finally {
    port.close();
  }
}

/// Gives a worker its control port and polls between files for cancellation.
Future<bool Function()> _listenForCancel(SendPort send) async {
  final control = ReceivePort();
  var cancelled = false;
  control.listen((msg) {
    if (msg == 'cancel') cancelled = true;
  });
  send.send(control.sendPort);
  return () => cancelled;
}

/// Isolate worker that streams [textEntries] (JSON metadata) and `[sourcePath, entryName]`
/// media files (stored uncompressed) into a single zip archive at `targetPath`.
Future<void> zipStreamWorker(List<Object?> args) async {
  final [
    targetPath as String,
    textEntries as Map,
    files as List,
    send as SendPort,
  ] = args;
  final cancelled = await _listenForCancel(send);
  ZipFileEncoder? zip;
  try {
    zip = ZipFileEncoder()..create(targetPath);
    for (final entry in textEntries.entries) {
      zip.addArchiveFile(ArchiveFile.string(entry.key as String, entry.value as String));
    }
    for (var i = 0; i < files.length; i++) {
      await Future<void>.delayed(Duration.zero);
      if (cancelled()) {
        zip.closeSync();
        send.send('cancelled');
        Isolate.exit();
      }
      final [source as String, entry as String] = files[i] as List;
      final input = InputFileStream(source);
      try {
        zip.addArchiveFile(ArchiveFile.stream(entry, input)..compression = CompressionType.none);
      } finally {
        input.closeSync();
      }
      send.send([i + 1, files.length]);
    }
    zip.closeSync();
    send.send('done');
  } catch (e) {
    try {
      zip?.closeSync();
    } catch (_) {}
    send.send(['error', '$e']);
  }
  Isolate.exit();
}

/// Isolate worker that extracts `[entryName, targetPath]` jobs one file at a time.
Future<void> unzipStreamWorker(List<Object?> args) async {
  final [zipPath as String, jobs as List, send as SendPort] = args;
  final cancelled = await _listenForCancel(send);
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final byName = {for (final f in archive.files) f.name: f};
    for (var i = 0; i < jobs.length; i++) {
      await Future<void>.delayed(Duration.zero);
      if (cancelled()) {
        send.send('cancelled');
        return;
      }
      final [entry as String, target as String] = jobs[i] as List;
      final file = byName[entry];
      if (file == null) throw 'The archive is missing $entry';
      Directory(p.dirname(target)).createSync(recursive: true);
      final out = OutputFileStream(target);
      try {
        file.writeContent(out);
      } finally {
        out.closeSync();
      }
      send.send([i + 1, jobs.length]);
    }
    send.send('done');
  } catch (e) {
    send.send(['error', '$e']);
  } finally {
    input.closeSync();
    Isolate.exit();
  }
}

/// Reads small UTF-8 text entries ([names]) from [zipPath] without extracting files.
Future<Map<String, String>> readZipEntriesInIsolate(String zipPath, List<String> names) =>
    Isolate.run(() => _readEntries(zipPath, names));

Map<String, String> _readEntries(String zipPath, List<String> names) {
  final input = InputFileStream(zipPath);
  try {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } catch (_) {
      throw const BackupFormatException("This file isn't a backup from this app.");
    }
    return {
      for (final f in archive.files)
        if (names.contains(f.name)) f.name: utf8.decode(f.readBytes() ?? const []),
    };
  } finally {
    input.closeSync();
  }
}

/// Returns a non-colliding file path inside [dir] based on [name], tracking [taken].
String freeArchivePath(Directory dir, String name, Set<String> taken) {
  var candidate = p.join(dir.path, name);
  final stem = p.basenameWithoutExtension(name);
  final ext = p.extension(name);
  for (var n = 1; taken.contains(candidate) || File(candidate).existsSync(); n++) {
    candidate = p.join(dir.path, '${stem}_$n$ext');
  }
  return candidate;
}

/// Deletes temporary/orphaned files cleanly, ignoring missing or locked paths.
Future<void> deleteFilesQuietly(Iterable<String> paths) async {
  for (final path in paths) {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}
