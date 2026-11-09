import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_planner/features/home/providers/home_providers.dart';
import 'package:trip_planner/main.dart';

void main() {
  testWidgets('App boots and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Home's trips come from the database, which a widget test can't
        // settle on; what Home shows has its own tests.
        overrides: [homeFocusProvider.overrideWith((ref) => const AsyncData(HomeNextTrip(null)))],
        child: const TripPlannerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trip Planner'), findsOneWidget);
  });
}
