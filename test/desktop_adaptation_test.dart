import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/features/anime/screens/cutout_editor_screen.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/camera/screens/camera_screen.dart';
import 'package:trip_planner/features/home/screens/home_screen.dart';

void main() {
  group('Desktop Platform Adaptation', () {
    test('mlkitCutoutSupported is false off mobile', () {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        expect(mlkitCutoutSupported, isFalse);
      }
    });

    test('AuthConfigurationException has formatted message', () {
      const ex = AuthConfigurationException('Test error message');
      expect(ex.toString(), 'Test error message');
      expect(ex.message, 'Test error message');
    });

    test('isDesktopAuthAvailable returns false when compile-time flags are absent', () {
      // In default test runner without --dart-define, this is false
      expect(isDesktopAuthAvailable, isFalse);
    });

    testWidgets('CameraScreen gracefully displays error on desktop/test environment',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CameraScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // CameraScreen should display an error message and Go Back button rather than a blank screen
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
    });

    testWidgets('HomeScreen renders with responsive max width constraint on wide screens',
        (WidgetTester tester) async {
      // Set wide viewport (desktop 1920x1080)
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ConstrainedBox with maxWidth 800 is present
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      final maxWidth800Box = constrainedBoxes.where(
        (box) => box.constraints.maxWidth == 800,
      );
      expect(maxWidth800Box, isNotEmpty);
      expect(find.text('Anime Pilgrimage'), findsOneWidget);
    });
  });
}
