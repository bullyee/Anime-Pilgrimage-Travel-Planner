import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/services/analytics_service.dart';

void main() {
  group('AnalyticsService Tests', () {
    test('instantiates with desktop fallback (null analytics) and logs without throwing', () async {
      final service = AnalyticsService();

      // Should complete without throwing on non-supported platforms or null instances
      await expectLater(service.logAppOpen(), completes);
      await expectLater(service.logScreenView(screenName: 'HomeScreen'), completes);
      await expectLater(service.logEvent(name: 'test_event', parameters: {'key': 'val'}), completes);
      await expectLater(service.setAnalyticsCollectionEnabled(true), completes);
    });
  });
}
