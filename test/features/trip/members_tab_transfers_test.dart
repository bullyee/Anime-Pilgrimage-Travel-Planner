import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/library/providers/place_providers.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/sharing/models/trip_member.dart';
import 'package:trip_planner/features/sharing/providers/group_sharing_providers.dart';
import 'package:trip_planner/features/sync/providers/drive_cleanup_providers.dart';
import 'package:trip_planner/features/sync/providers/frame_transfer_providers.dart';
import 'package:trip_planner/features/sync/services/drive_cleanup_journal.dart';
import 'package:trip_planner/features/sync/services/frame_transfer_queue.dart';
import 'package:trip_planner/features/sync/services/google_drive_frame_service.dart';
import 'package:trip_planner/features/sync/services/transfer_foreground_service.dart';
import 'package:trip_planner/features/sync/widgets/frame_transfer_widgets.dart';
import 'package:trip_planner/features/trip/providers/trip_providers.dart';
import 'package:trip_planner/features/trip/repositories/trip_repository.dart';
import 'package:trip_planner/features/trip/screens/trip_screen.dart';
import 'package:trip_planner/shared/theme/app_theme.dart';

import '../sync/fake_transfer_service.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;
  late DriftPlaceRepository placeRepo;
  late DriftTripRepository tripRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    placeRepo = DriftPlaceRepository(db);
    tripRepo = DriftTripRepository(db, null, 'u1', placeRepo);
  });

  tearDown(() => db.close());

  testWidgets('Sync via my Google Drive runs in the background: no modal progress, a strip with Cancel',
      (tester) async {
    final trip = await tripRepo.createTrip(title: 'Kansai', ownerId: 'u1', dayCount: 1);
    await (db.update(db.trips)..where((t) => t.id.equals(trip.id)))
        .write(const TripsCompanion(sharing: Value('group')));
    await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'pl1', name: 'Uji', lat: 34.9, lng: 135.8));
    final stop = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'pl1', addedBy: 'u1');
    // One more than the uploads that run at once, so a cancel leaves one.
    for (final id in ['f1', 'f2', 'f3', 'f4']) {
      await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: id,
            stopId: Value(stop.id),
            localPath: Value('/phone/$id.jpg'),
          ));
    }

    // The uploads hang until the test lets them go.
    final release = Completer<void>();
    var uploads = 0;
    final client = MockClient((req) async {
      if (req.method == 'GET') return http.Response(jsonEncode({'files': [{'id': 'folder'}]}), 200);
      if (req.url.path == '/upload/drive/v3/files') {
        uploads++;
        await release.future;
        return http.Response(jsonEncode({'id': 'drv_$uploads'}), 200);
      }
      return http.Response('{}', 200);
    });
    final drive = GoogleDriveFrameService(
      client: client,
      getToken: ({bool interactive = true}) async => 'tok',
      compress: (b) async => b,
      readFile: (path) async => utf8.encode(path),
    );
    final service = FakeTransferService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          placeRepositoryProvider.overrideWithValue(placeRepo),
          tripRepositoryProvider.overrideWithValue(tripRepo),
          currentUserIdProvider.overrideWithValue('u1'),
          myTripRoleProvider(trip.id).overrideWithValue(TripMemberRole.owner),
          tripMembersProvider(trip.id).overrideWith(
            (_) => Stream.value([
              TripMember(userId: 'u1', tripId: trip.id, role: TripMemberRole.owner, displayName: 'U1', joinedAt: DateTime(2026)),
            ]),
          ),
          googleDriveFrameServiceProvider.overrideWithValue(drive),
          driveCleanupJournalProvider.overrideWithValue(InMemoryDriveCleanupJournal()),
          // Its count checks files on disk, which a widget test can't wait for.
          pendingFrameDownloadCountProvider(trip.id).overrideWith((_) => Stream.value(0)),
          transferForegroundServiceProvider.overrideWithValue(service),
          transferJournalProvider.overrideWithValue(InMemoryTransferJournal()),
          appVisibleProvider.overrideWithValue(() => true),
        ],
        child: MaterialApp(theme: AppTheme.light, home: TripScreen(tripId: trip.id, initialTab: TripTab.members)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("4 frames on this phone aren't on Google Drive yet."), findsOneWidget);
    final sync = find.text('Sync via my Google Drive');
    await tester.ensureVisible(sync);
    await tester.tap(sync);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload & sync'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // the confirm dialog's exit

    // No dialog holds the screen: the progress is a strip in the card.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TransferJobStrip), findsOneWidget);
    expect(find.text('0 of 4'), findsOneWidget);
    expect(find.text('Uploading 4 frames to Google Drive in the background.'), findsOneWidget);
    expect(service.calls.where((c) => c.startsWith('start')), hasLength(1), reason: 'the foreground service is up');
    // The rest of the tab stays usable.
    expect(find.text('Share local frames'), findsOneWidget);

    final cancel = find.descendant(of: find.byType(TransferJobStrip), matching: find.text('Cancel'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    expect(find.text('Cancelling…'), findsOneWidget);

    release.complete();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(TransferJobStrip), findsNothing);
    expect(find.text('Upload cancelled.'), findsOneWidget);
    expect(uploads, GoogleDriveFrameService.uploadConcurrency, reason: 'stops after the frames in flight');
    expect(service.calls.last, 'stop');
    final frames = await (db.select(db.newReferenceImages)..where((r) => r.stopId.equals(stop.id))).get();
    expect(frames.where((f) => f.remoteUrl != null), hasLength(3), reason: 'the frames that finished are kept');
    expect(frames.where((f) => f.remoteUrl == null), hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the global indicator shows the running transfer with Cancel', (tester) async {
    final service = FakeTransferService();
    final gate = Completer<void>();
    final container = ProviderContainer(overrides: [
      transferForegroundServiceProvider.overrideWithValue(service),
      transferJournalProvider.overrideWithValue(InMemoryTransferJournal()),
      appVisibleProvider.overrideWithValue(() => true),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => TransferStatusOverlay(child: child!),
        home: const Scaffold(body: Text('Home')),
      ),
    ));
    expect(find.textContaining('Downloading frames'), findsNothing);

    container.read(frameTransferQueueProvider.notifier).enqueue(TransferJobSpec(
          kind: TransferKind.download,
          tripId: 't1',
          tripTitle: 'Kansai',
          run: (ctx) async {
            ctx.progress(30, 180);
            await gate.future;
            if (ctx.cancel.isCancelled) throw Exception('should be cancelled');
            return 'done';
          },
        ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Downloading frames · 30 of 180'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Cancelling…'), findsOneWidget);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Downloading frames'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Remove my frames from Google Drive asks, deletes the files and resets the frames', (tester) async {
    final trip = await tripRepo.createTrip(title: 'Kansai', ownerId: 'u1', dayCount: 1);
    await (db.update(db.trips)..where((t) => t.id.equals(trip.id))).write(const TripsCompanion(sharing: Value('group')));
    await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'pl1', name: 'Uji', lat: 34.9, lng: 135.8));
    final stop = await tripRepo.addPlaceToTrip(tripId: trip.id, placeKey: 'pl1', addedBy: 'u1');
    await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
          id: 'f1',
          stopId: Value(stop.id),
          localPath: const Value('/phone/f1.jpg'),
          remoteUrl: Value(GoogleDriveFrameService.downloadUrlForFileId('d1')),
        ));
    final journal = InMemoryDriveCleanupJournal();
    await journal.recordFile('d1', trip.id);
    final deleted = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'GET') return http.Response(jsonEncode({'files': []}), 200);
      if (req.method == 'DELETE') {
        deleted.add(req.url.pathSegments.last);
        return http.Response('', 204);
      }
      return http.Response('{}', 200);
    });
    final drive = GoogleDriveFrameService(client: client, getToken: ({bool interactive = true}) async => 'tok', journal: journal);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          placeRepositoryProvider.overrideWithValue(placeRepo),
          tripRepositoryProvider.overrideWithValue(tripRepo),
          currentUserIdProvider.overrideWithValue('u1'),
          myTripRoleProvider(trip.id).overrideWithValue(TripMemberRole.owner),
          tripMembersProvider(trip.id).overrideWith(
            (_) => Stream.value([
              TripMember(userId: 'u1', tripId: trip.id, role: TripMemberRole.owner, displayName: 'U1', joinedAt: DateTime(2026)),
            ]),
          ),
          googleDriveFrameServiceProvider.overrideWithValue(drive),
          driveCleanupJournalProvider.overrideWithValue(journal),
          pendingFrameDownloadCountProvider(trip.id).overrideWith((_) => Stream.value(0)),
          transferForegroundServiceProvider.overrideWithValue(FakeTransferService()),
          transferJournalProvider.overrideWithValue(InMemoryTransferJournal()),
          appVisibleProvider.overrideWithValue(() => true),
        ],
        child: MaterialApp(theme: AppTheme.light, home: TripScreen(tripId: trip.id, initialTab: TripTab.members)),
      ),
    );
    await tester.pumpAndSettle();

    final remove = find.text('Remove my frames from Google Drive');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.textContaining('Other members lose those frames'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    for (var i = 0; i < 20 && deleted.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(deleted, ['d1']);
    expect(find.text('Removed 1 item from your Google Drive. 1 frame is now only on this phone.'), findsOneWidget);
    final f1 = await (db.select(db.newReferenceImages)..where((r) => r.id.equals('f1'))).getSingle();
    expect(f1.remoteUrl, isNull);
    expect((await journal.read()).isEmpty, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });
}
