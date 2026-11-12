import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/database_provider.dart';
import '../services/library_backup_service.dart';

final libraryBackupServiceProvider = Provider<LibraryBackupService>((ref) => const LibraryBackupService());

/// Lets the user pick a backup file; null when they back out.
final pickBackupFileProvider = Provider<Future<String?> Function()>((ref) => () async {
      final file = await fs.openFile();
      return file?.path;
    });

/// Hands a finished backup to the system share sheet (Drive, Files, another app).
final shareBackupFileProvider = Provider<Future<void> Function(String path)>((ref) => (path) async {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path, mimeType: 'application/zip')],
        subject: 'Pilgrimage backup',
      ));
    });

/// Where a backup is written before it's shared.
final backupFolderProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final dir = Directory(p.join((await getTemporaryDirectory()).path, 'backups'));
      await dir.create(recursive: true);
      return dir;
    });

/// Library ⋮ → Back up to a file: confirm, write the file with progress, then share it.
Future<void> backUpLibrary(BuildContext context, WidgetRef ref) async {
  final svc = ref.read(libraryBackupServiceProvider);
  final db = ref.read(databaseProvider);
  final contents = await svc.describeExport(db);
  if (!context.mounted) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Back up to a file'),
      content: Text(
        '${describeContents(contents)}, about ${formatBytes(contents.bytes)}.\n\n'
        'Shared trips aren\'t in the file: they come back when you sign in on the new phone. '
        'Frames you added to them yourself are in it.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Back up')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;

  final dir = await ref.read(backupFolderProvider)();
  // An earlier backup has been shared by now, so its copy here can go.
  for (final old in dir.listSync().whereType<File>()) {
    try {
      old.deleteSync();
    } catch (_) {}
  }
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final name = 'pilgrimage-backup-${now.year}-${two(now.month)}-${two(now.day)}.${LibraryBackupService.fileExtension}';
  if (!context.mounted) return;
  final file = await runArchiveWithProgress<File>(
    context,
    title: 'Backing up',
    failure: "Couldn't back up",
    run: (onProgress, cancel) =>
        svc.exportLibraryArchive(db, targetPath: p.join(dir.path, name), onProgress: onProgress, cancel: cancel),
  );
  if (file == null) return;
  await ref.read(shareBackupFileProvider)(file.path);
}

/// Library ⋮ → Restore from a file: pick, read what's in it, confirm, restore with progress.
Future<void> restoreLibrary(BuildContext context, WidgetRef ref) async {
  final svc = ref.read(libraryBackupServiceProvider);
  final path = await ref.read(pickBackupFileProvider)();
  if (path == null || !context.mounted) return;
  final BackupContents contents;
  try {
    contents = await svc.readContents(File(path));
  } on BackupFormatException catch (e) {
    if (context.mounted) await tellArchiveMessage(context, "Can't restore this file", e.message);
    return;
  }
  if (!context.mounted) return;
  final when = contents.exportedAt;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restore from this backup?'),
      content: Text(
        '${when == null ? 'It has' : 'Backed up on ${MaterialLocalizations.of(context).formatMediumDate(when)}, ${when.year}:'} '
        '${describeContents(contents)}.\n\n'
        "Nothing on this phone is changed or removed: only what isn't here yet is added.",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  final db = ref.read(databaseProvider);
  final summary = await runArchiveWithProgress<LibraryImportSummary>(
    context,
    title: 'Restoring',
    failure: "Couldn't restore",
    run: (onProgress, cancel) => svc.importLibraryArchive(db, File(path), onProgress: onProgress, cancel: cancel),
  );
  if (summary == null || !context.mounted) return;
  await tellArchiveMessage(context, 'Restored', restoreSummaryText(summary));
}

/// "312 places, 2 private trips, 86 photos and 2,800 frames".
String describeContents(BackupContents c) => _list([
      _count(c.places, 'place'),
      if (c.privateTrips > 0) _count(c.privateTrips, 'private trip'),
      _count(c.photos, 'photo'),
      _count(c.frames, 'frame'),
    ]);

String restoreSummaryText(LibraryImportSummary s) {
  final added = [
    if (s.places > 0) _count(s.places, 'place'),
    if (s.privateTrips > 0) _count(s.privateTrips, 'private trip'),
    if (s.photos > 0) _count(s.photos, 'photo'),
    if (s.frames > 0) _count(s.frames, 'frame'),
  ];
  return [
    added.isEmpty ? 'Nothing new to add: this phone already had everything in the backup.' : 'Added ${_list(added)}.',
    if (s.alreadyHere > 0 && added.isNotEmpty)
      '${s.alreadyHere == 1 ? 'One place or trip was' : '${_thousands(s.alreadyHere)} places and trips were'} already here and left as ${s.alreadyHere == 1 ? 'it was' : 'they were'}.',
    'Shared trips come back when you sign in.',
  ].join(' ');
}

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return 'under 1 MB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).round()} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
String _count(int n, String noun) => '${_thousands(n)} $noun${n == 1 ? '' : 's'}';
String _list(List<String> parts) =>
    parts.length < 2 ? parts.join() : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';

Future<void> tellArchiveMessage(BuildContext context, String title, String message) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );

/// Shows a progress dialog while [run] works; null when cancelled or failed
/// (a failure is shown to the user).
Future<T?> runArchiveWithProgress<T>(
  BuildContext context, {
  required String title,
  required String failure,
  required Future<T> Function(BackupProgress onProgress, BackupCancel cancel) run,
}) async {
  final outcome = await showDialog<(T?, Object?)>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProgressDialog<T>(title: title, run: run),
  );
  if (outcome == null) return null;
  final (value, error) = outcome;
  if (error != null && error is! BackupCancelled && context.mounted) {
    await tellArchiveMessage(context, failure, error is BackupFormatException ? error.message : '$error');
  }
  return value;
}

class _ProgressDialog<T> extends StatefulWidget {
  final String title;
  final Future<T> Function(BackupProgress onProgress, BackupCancel cancel) run;

  const _ProgressDialog({required this.title, required this.run, super.key});

  @override
  State<_ProgressDialog<T>> createState() => _ProgressDialogState<T>();
}

class _ProgressDialogState<T> extends State<_ProgressDialog<T>> {
  final _cancel = BackupCancel();
  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    widget.run((done, total) {
      if (mounted) {
        setState(() {
          _done = done;
          _total = total;
        });
      }
    }, _cancel).then(
      (value) => _close((value, null)),
      onError: (Object e) => _close((null, e)),
    );
  }

  void _close((T?, Object?) outcome) {
    if (mounted) Navigator.pop(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
            const SizedBox(height: 12),
            Text(_total == 0 ? 'Getting ready…' : '${_thousands(_done)} of ${_count(_total, 'file')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancel.isCancelled ? null : () => setState(_cancel.cancel),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
