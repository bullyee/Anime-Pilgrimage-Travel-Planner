import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/screens/library_screen.dart';
import 'package:trip_planner/features/library/services/library_backup_service.dart';
import 'package:trip_planner/features/library/widgets/library_backup_flow.dart';

const _contents = BackupContents(places: 312, privateTrips: 2, photos: 1, frames: 2800, bytes: 600 * 1024 * 1024);

class _FakeBackup implements LibraryBackupService {
  /// Completes the running export or import; until then it reports one file of three.
  final job = Completer<void>();
  Object? failWith;
  BackupContents contents = _contents;
  Object? readError;

  @override
  Future<BackupContents> describeExport(AppDatabase db) async => contents;

  Future<void> _run(BackupProgress? onProgress, BackupCancel? cancel) async {
    onProgress?.call(1, 3);
    await Future.any([job.future, Future.doWhile(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return !(cancel?.isCancelled ?? false) && !job.isCompleted;
    })]);
    if (cancel?.isCancelled ?? false) throw const BackupCancelled();
    if (failWith != null) throw failWith!;
  }

  @override
  Future<File> exportLibraryArchive(AppDatabase db, {required String targetPath, BackupProgress? onProgress, BackupCancel? cancel}) async {
    await _run(onProgress, cancel);
    return File(targetPath);
  }

  @override
  Future<BackupContents> readContents(File zip) async {
    if (readError != null) throw readError!;
    return BackupContents(
        places: 312, privateTrips: 2, photos: 1, frames: 2800, bytes: 0, exportedAt: DateTime(2026, 11, 11));
  }

  @override
  Future<LibraryImportSummary> importLibraryArchive(AppDatabase db, File zip,
      {Directory? baseStorageDir, BackupProgress? onProgress, BackupCancel? cancel}) async {
    await _run(onProgress, cancel);
    return const LibraryImportSummary(places: 40, privateTrips: 1, photos: 1, frames: 300, alreadyHere: 272);
  }
}

void main() {
  late AppDatabase db;
  late _FakeBackup backup;
  late List<String> shared;
  String? picked;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    backup = _FakeBackup();
    shared = [];
    picked = '/backups/pilgrimage-backup.pilgrimage';
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/library', routes: [
      GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u1'),
        libraryBackupServiceProvider.overrideWithValue(backup),
        backupFolderProvider.overrideWithValue(() async => Directory.systemTemp.createTempSync('backup_flow_')),
        shareBackupFileProvider.overrideWithValue((path) async => shared.add(path)),
        pickBackupFileProvider.overrideWithValue(() async => picked),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Lets the flow's futures and dialogs run: real time for its awaits, frames for the dialogs.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  testWidgets('back up: says what goes in the file, shows progress, then shares it', (tester) async {
    await pump(tester);
    await openMenu(tester, 'Back up to a file');
    await settle(tester);
    expect(find.textContaining('312 places, 2 private trips, 1 photo and 2,800 frames, about 600 MB'), findsOneWidget);
    expect(find.textContaining("Shared trips aren't in the file"), findsOneWidget);

    await tester.tap(find.text('Back up'));
    await settle(tester);
    expect(find.text('Backing up'), findsOneWidget);
    expect(find.text('1 of 3 files'), findsOneWidget);

    backup.job.complete();
    await settle(tester);
    expect(find.text('Backing up'), findsNothing);
    expect(shared, hasLength(1));
    expect(shared.single, endsWith('.pilgrimage'));
    await disposeApp(tester);
  });

  testWidgets('a cancelled backup shares nothing and shows no error', (tester) async {
    await pump(tester);
    await openMenu(tester, 'Back up to a file');
    await settle(tester);
    await tester.tap(find.text('Back up'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Backing up'), findsNothing);
    expect(find.textContaining("Couldn't"), findsNothing);
    expect(shared, isEmpty);
    await disposeApp(tester);
  });

  testWidgets('a failed backup says so', (tester) async {
    backup.failWith = Exception('disk full');
    await pump(tester);
    await openMenu(tester, 'Back up to a file');
    await settle(tester);
    await tester.tap(find.text('Back up'));
    backup.job.complete();
    await settle(tester);
    expect(find.text("Couldn't back up"), findsOneWidget);
    expect(find.textContaining('disk full'), findsOneWidget);
    expect(shared, isEmpty);
    await disposeApp(tester);
  });

  testWidgets('restore from the empty library: what the file has, the rule, then what was added', (tester) async {
    await pump(tester);
    expect(find.text('Your library is empty'), findsOneWidget);
    await tester.tap(find.text('Restore from a backup file'));
    await settle(tester);
    expect(find.text('Restore from this backup?'), findsOneWidget);
    expect(find.textContaining('Nov 11, 2026'), findsOneWidget);
    expect(find.textContaining('312 places, 2 private trips'), findsOneWidget);
    expect(find.textContaining('Nothing on this phone is changed or removed'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    backup.job.complete();
    await settle(tester);
    expect(find.text('Restored'), findsOneWidget);
    expect(find.textContaining('Added 40 places, 1 private trip, 1 photo and 300 frames.'), findsOneWidget);
    expect(find.textContaining('272 places and trips were already here'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets("a file that isn't a backup is refused before anything happens", (tester) async {
    backup.readError = const BackupFormatException("This file isn't a backup from this app.");
    await pump(tester);
    await openMenu(tester, 'Restore from a file');
    await settle(tester);
    expect(find.text("Can't restore this file"), findsOneWidget);
    expect(find.textContaining("isn't a backup"), findsOneWidget);
    expect(find.text('Restore from this backup?'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('backing out of the file picker does nothing', (tester) async {
    picked = null;
    await pump(tester);
    await openMenu(tester, 'Restore from a file');
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    await disposeApp(tester);
  });

  test('summary text when everything was already there', () {
    expect(
      restoreSummaryText(const LibraryImportSummary(places: 0, privateTrips: 0, photos: 0, frames: 0, alreadyHere: 5)),
      startsWith('Nothing new to add'),
    );
    expect(formatBytes(1536 * 1024 * 1024), '1.5 GB');
    expect(formatBytes(0), 'under 1 MB');
  });
}
