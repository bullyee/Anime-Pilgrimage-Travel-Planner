import 'dart:ui'; // Added for PlatformDispatcher
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trip_planner/core/providers/sync_provider.dart';
import 'firebase_options.dart';

import 'core/router/app_router.dart';
import 'features/poi/services/background_photo_save.dart';
import 'features/sync/providers/sync_v2_providers.dart';
import 'shared/theme/app_theme.dart';
// Added for custom error monitoring
import 'core/utils/app_logger.dart';
import 'core/providers/app_provider_observer.dart';


void main() async {
  // Ensure bindings are initialized before calling native code (e.g., Firebase)
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Catch Flutter framework errors (e.g., UI rendering or widget lifecycle errors)
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'Flutter Framework Error Captured',
      error: details.exception,
      stackTrace: details.stack,
      name: 'FlutterError',
    );
  };

  // 2. Catch unhandled asynchronous Dart errors (e.g., unawaited Futures)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error(
      'Unhandled Async Error Captured',
      error: error,
      stackTrace: stack,
      name: 'PlatformDispatcher',
    );
    // Return true to indicate the error was handled, preventing an app crash
    return true; 
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    AppLogger.error(
      'Firebase initialization failed — running in local-only mode',
      error: e,
      stackTrace: st,
      name: 'FirebaseInit',
    );
  }

  // 3. Inject AppProviderObserver into ProviderScope to monitor Riverpod state
  runApp(
    ProviderScope(
      observers: [AppProviderObserver()],
      child: const TripPlannerApp(),
    ),
  );
}

class TripPlannerApp extends ConsumerWidget {
  const TripPlannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);
    ref.watch(syncEngineProvider);
    ref.watch(syncEngineServiceV2Provider);

    return MaterialApp.router(
      title: 'Trip Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
      // Background photo saves report back here after their editor closed.
      scaffoldMessengerKey: rootMessengerKey,
    );
  }
}