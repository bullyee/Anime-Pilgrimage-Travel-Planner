import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/sync/providers/drive_upload_quality_provider.dart';
import 'package:trip_planner/features/sync/services/drive_upload_quality.dart';
import 'package:trip_planner/features/sync/widgets/drive_upload_quality_picker.dart';

void main() {
  test('the file store keeps the choice, and reads Original when there is none or it is unknown', () async {
    final dir = await Directory.systemTemp.createTemp('upload_quality');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileDriveUploadQualityStore(directory: () async => dir);
    expect(await store.read(), DriveUploadQuality.original);
    await store.write(DriveUploadQuality.smallest);
    expect(await FileDriveUploadQualityStore(directory: () async => dir).read(), DriveUploadQuality.smallest);
    await File('${dir.path}/drive_upload_quality.txt').writeAsString('huge');
    expect(await store.read(), DriveUploadQuality.original);
  });

  test('the provider starts from the saved choice and saves a new one', () async {
    final store = InMemoryDriveUploadQualityStore(DriveUploadQuality.smaller);
    final container = ProviderContainer(overrides: [driveUploadQualityStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);

    expect(await container.read(driveUploadQualityProvider.notifier).current(), DriveUploadQuality.smaller);
    expect(container.read(driveUploadQualityProvider), DriveUploadQuality.smaller);

    await container.read(driveUploadQualityProvider.notifier).choose(DriveUploadQuality.original);
    expect(container.read(driveUploadQualityProvider), DriveUploadQuality.original);
    expect(store.value, DriveUploadQuality.original);
  });

  testWidgets('the picker shows the three choices and saves a tap', (tester) async {
    final store = InMemoryDriveUploadQualityStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [driveUploadQualityStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDriveUploadQualityPicker(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Frame upload quality'), findsOneWidget);
    for (final q in DriveUploadQuality.values) {
      expect(find.text(q.label), findsOneWidget);
    }
    await tester.tap(find.text('Smaller'));
    await tester.pumpAndSettle();
    expect(store.value, DriveUploadQuality.smaller);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Frame upload quality'), findsNothing);
  });
}
