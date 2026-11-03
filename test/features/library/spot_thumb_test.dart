import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/core/providers/database_provider.dart';
import 'package:trip_planner/features/library/repositories/place_repository.dart';
import 'package:trip_planner/features/library/widgets/spot_thumb.dart';

void main() {
  late AppDatabase db;
  late DriftPlaceRepository places;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    places = DriftPlaceRepository(db);
  });
  tearDown(() => db.close());

  group('SpotThumb', () {
    Future<void> pumpThumb(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: SpotThumb(placeKey: 'p1', fallback: Text('no preview')))),
      ));
      await tester.pumpAndSettle();
    }

    String? shownPath(WidgetTester tester) {
      var image = tester.widgetList<Image>(find.byType(Image)).firstOrNull?.image;
      // A cacheWidth wraps the file in a ResizeImage.
      if (image is ResizeImage) image = image.imageProvider;
      return image is FileImage ? image.file.path : null;
    }

    testWidgets('shows the cover, else the first frame, else the fallback', (tester) async {
      await db.into(db.places).insert(PlacesCompanion.insert(placeKey: 'p1', name: 'Uji Bridge', lat: 0, lng: 0));
      await pumpThumb(tester);
      expect(find.text('no preview'), findsOneWidget);

      await places.addReferenceImage(placeKey: 'p1', localPath: '/f/first.jpg');
      await tester.pumpAndSettle();
      expect(shownPath(tester), '/f/first.jpg');

      await places.updatePlace(const PlacesCompanion(placeKey: Value('p1'), coverLocalPath: Value('/f/cover.jpg')));
      await tester.pumpAndSettle();
      expect(shownPath(tester), '/f/cover.jpg');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
