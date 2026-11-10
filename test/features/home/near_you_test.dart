import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/core/database/database.dart';
import 'package:trip_planner/features/home/providers/home_providers.dart';
import 'package:trip_planner/features/home/widgets/near_you.dart';
import 'package:trip_planner/features/library/models/library_entry.dart';
import 'package:trip_planner/features/library/providers/library_providers.dart';

void main() {
  final bridge = LibraryEntry(
    place: Place(
      placeKey: 'bridge',
      name: 'Uji Bridge',
      lat: 34.8931,
      lng: 135.8063,
      visibility: 'saved',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    labels: const [],
    tripIds: const {},
  );

  testWidgets('with no fix, Near you says so and tries again on tap', (tester) async {
    var calls = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        libraryEntriesProvider.overrideWith((ref) => AsyncData([bridge])),
        homeWhereProvider.overrideWith((ref) async {
          calls++;
          // The first try finds nothing, the second finds the bridge.
          return calls == 1 ? (allowed: true, at: null) : (allowed: true, at: const LatLng(34.8930, 135.8062));
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: NearYou())),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't find where you are."), findsOneWidget);
    expect(find.text('Uji Bridge'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text("Couldn't find where you are."), findsNothing);
    expect(find.text('Uji Bridge'), findsOneWidget);
  });
}
