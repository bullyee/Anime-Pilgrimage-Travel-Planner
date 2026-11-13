import 'dart:io';

import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:trip_planner/core/app_version.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/settings/screens/settings_screen.dart';
import 'package:trip_planner/features/settings/services/storage_usage.dart';
import 'package:trip_planner/features/sync/providers/drive_cleanup_providers.dart';
import 'package:trip_planner/features/sync/providers/drive_upload_quality_provider.dart';
import 'package:trip_planner/features/sync/services/drive_upload_quality.dart';

class _FakeUser extends Fake implements User {
  @override
  final String? displayName;
  @override
  final String? email;
  _FakeUser({this.displayName, this.email});
}

const _mb = 1024 * 1024;

void main() {
  late AppDatabase db;
  late List<Uri> opened;
  late int modelDeletes;
  late StorageUsage usage;
  var waiting = 0;
  var qualityStore = InMemoryDriveUploadQualityStore();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    opened = [];
    modelDeletes = 0;
    waiting = 0;
    qualityStore = InMemoryDriveUploadQualityStore();
    usage = const StorageUsage(total: 900 * _mb, mapTiles: 120 * _mb, cutoutModel: 176 * _mb);
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {User? user}) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authStateChangesProvider.overrideWith((ref) => Stream.value(user)),
        storageUsageProvider.overrideWith((ref) async => usage),
        driveRemovalsWaitingProvider.overrideWith((ref) => Stream.value(waiting)),
        driveUploadQualityStoreProvider.overrideWithValue(qualityStore),
        openLinkProvider.overrideWithValue((uri) async => opened.add(uri)),
        deleteCutoutModelProvider.overrideWithValue(() async {
          modelDeletes++;
          usage = StorageUsage(total: usage.total - usage.cutoutModel, mapTiles: usage.mapTiles, cutoutModel: 0);
        }),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('signed out: says sign-in is only for shared trips, and offers it', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('settingsSignedOut')), findsOneWidget);
    expect(find.textContaining('only for sharing trips'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('signed in: who, Sign out, and removing shared frames from Drive', (tester) async {
    await pump(tester, user: _FakeUser(displayName: 'Mika', email: 'mika@example.com'));
    expect(find.text('Mika'), findsOneWidget);
    expect(find.textContaining('mika@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Remove shared frames from my Google Drive'), findsOneWidget);
    expect(find.textContaining('waiting'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('removals still waiting to reach Drive are counted', (tester) async {
    waiting = 3;
    await pump(tester, user: _FakeUser(displayName: 'Mika', email: 'mika@example.com'));
    expect(find.textContaining('3 removals are waiting'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('Frame upload quality shows the choice and changes it', (tester) async {
    await pump(tester, user: _FakeUser(displayName: 'Mika', email: 'mika@example.com'));
    expect(find.textContaining('Original: Best quality'), findsOneWidget);
    await tester.tap(find.text('Frame upload quality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Smallest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(qualityStore.value, DriveUploadQuality.smallest);
    expect(find.textContaining('Smallest: 1280 px'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('signed out: no Drive row', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('settingsDriveRemoval')), findsNothing);
    expect(find.byKey(const Key('settingsUploadQuality')), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('your data: back up, restore, and what takes how much space', (tester) async {
    await pump(tester);
    expect(find.text('Back up to a file'), findsOneWidget);
    expect(find.text('Restore from a file'), findsOneWidget);
    // 900 − 120 − 176 MB.
    expect(find.descendant(of: find.byKey(const Key('settingsYourData')), matching: find.text('604 MB')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('settingsMapTiles')), matching: find.textContaining('120 MB')),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('settingsCutoutModel')), matching: find.textContaining('176 MB')),
        findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('deleting the cutout model asks first, then hides its row', (tester) async {
    await pump(tester);
    await tester.tap(find.descendant(of: find.byKey(const Key('settingsCutoutModel')), matching: find.text('Delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete the cutout model?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(modelDeletes, 0);

    await tester.tap(find.descendant(of: find.byKey(const Key('settingsCutoutModel')), matching: find.text('Delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(modelDeletes, 1);
    expect(find.byKey(const Key('settingsCutoutModel')), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('no map tiles kept: nothing to clear; no model: no row', (tester) async {
    usage = const StorageUsage(total: 50 * _mb, mapTiles: 0, cutoutModel: 0);
    await pump(tester);
    final clear = tester.widget<TextButton>(
        find.descendant(of: find.byKey(const Key('settingsMapTiles')), matching: find.byType(TextButton)));
    expect(clear.onPressed, isNull);
    expect(find.byKey(const Key('settingsCutoutModel')), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('settingsMapTiles')), matching: find.textContaining('\nUnder 1 MB')),
        findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('about: the version, the credits and the privacy policy', (tester) async {
    await pump(tester);
    expect(find.text('Version $appVersionLabel'), findsOneWidget);
    expect(find.text('Spots and frames from Anitabi'), findsOneWidget);
    expect(find.text('Maps from OpenStreetMap'), findsOneWidget);
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.text('Open-source licences'), findsOneWidget);
    await tester.tap(find.text('Privacy policy'));
    expect(opened.single.toString(), privacyPolicyUrl);
    await disposeApp(tester);
  });

  test('measureStorage counts a folder inside another root once, and splits out tiles and the model', () {
    final root = Directory.systemTemp.createTempSync('storage_usage_');
    addTearDown(() => root.deleteSync(recursive: true));
    void write(String rel, int bytes) {
      final f = File(p.join(root.path, rel))..createSync(recursive: true);
      f.writeAsBytesSync(List.filled(bytes, 0));
    }

    write('docs/app_photos/a.jpg', 300);
    write('support/map_tiles/t1', 100);
    write('support/models/isnet-anime.onnx', 50);
    write('support/trip_planner.sqlite', 25);
    final u = measureStorage(StorageFolders(
      roots: [p.join(root.path, 'support'), p.join(root.path, 'docs'), root.path],
      mapTiles: p.join(root.path, 'support', 'map_tiles'),
      cutoutModel: p.join(root.path, 'support', 'models'),
    ));
    expect(u.total, 475);
    expect(u.mapTiles, 100);
    expect(u.cutoutModel, 50);
    expect(u.yourData, 325);
  });
}
