import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Add this
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart'; // Add this
import 'package:trip_planner/features/auth/screens/login_screen.dart'; // Add this

import '../../features/home/screens/home_screen.dart';
import '../../features/poi/screens/photo_edit_screen.dart';
import '../../features/camera/screens/camera_screen.dart';
import '../../features/camera/screens/shot_series_screen.dart';
import '../../features/camera/services/photo_edit_route.dart';
import '../../features/library/screens/anitabi_import_screen.dart';
import '../../features/library/screens/labels_screen.dart';
import '../../features/library/screens/library_screen.dart';
import '../../features/library/screens/place_screen.dart';
import '../../features/sharing/invite_links.dart';
import '../../features/sharing/screens/join_trip_screen.dart';
import '../../features/trip/screens/library_picker_screen.dart';
import '../../features/trip/screens/new_spot_screen.dart';
import '../../features/trip/screens/pilgrimage_day_map_screen.dart';
import '../../features/trip/screens/stop_screen.dart';
import '../../features/trip/screens/trip_list_screen.dart';
import '../../features/trip/screens/trip_screen.dart';

part 'app_router.g.dart';

/// Where the app opens after the next sign-in, when a screen asks for it.
/// Signing in rebuilds the router, which would otherwise start over at home.
final signInReturnProvider = StateProvider<String?>((ref) => null);

/// Wrap the existing router in a Provider to react to Auth state changes.
@Riverpod(keepAlive: true)
GoRouter router(RouterRef ref) {
  // Watch the auth state from our previously created provider.
  ref.watch(authStateChangesProvider);
  final returnTo = ref.read(signInReturnProvider);
  if (returnTo != null) {
    // Only once: a later rebuild, such as signing out, starts at home.
    Future.microtask(() => ref.read(signInReturnProvider.notifier).state = null);
  }

  return GoRouter(
    initialLocation: returnTo ?? '/',
    
    // AUTH REDIRECT LOGIC
    redirect: (context, state) {
      final authState = ref.read(authStateChangesProvider);
      
      // 1. Loading state: Do not force redirect, wait for resolution.
      if (authState.isLoading) return null; 

      // 2. Safely check if user is logged in (handles both data and error states cleanly).
      final isLoggedIn = authState.valueOrNull != null;

      // 3. Define explicit cloud-only routes that require authentication.
      final isCloudRoute = state.uri.path.startsWith('/cloud-share');

      // 4. Gatekeeper: Unauthenticated users trying to access cloud routes.
      if (!isLoggedIn && isCloudRoute) {
        return '/login';
      }

      // 5. Anti-bounce: Authenticated users should not see the login screen.
      if (isLoggedIn && state.uri.path == '/login') {
        return '/';
      }

      // 6. DEFAULT (Offline-first core): Allow all other navigation (e.g., '/', '/library', '/trips').
      return null;
    },
    routes: [
      // Add the new Login route
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // --- Your Existing Routes Start Here ---
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/trips',
        builder: (context, state) => const TripListScreen(),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => TripScreen(
          tripId: state.pathParameters['tripId']!,
          initialTab: TripTab.fromQuery(state.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(
        path: '/trips/:tripId/map',
        builder: (context, state) => PilgrimageDayMapScreen(
          tripId: state.pathParameters['tripId']!,
          initialDayId: state.uri.queryParameters['day'],
        ),
      ),
      GoRoute(
        path: '/trips/:tripId/stops',
        builder: (context, state) => TripScreen(
          tripId: state.pathParameters['tripId']!,
          initialTab: TripTab.stops,
        ),
      ),
      GoRoute(
        path: '/trips/:tripId/stops/add',
        builder: (context, state) => LibraryPickerScreen(
          tripId: state.pathParameters['tripId']!,
        ),
      ),
      GoRoute(
        path: '/trips/:tripId/stops/new',
        builder: (context, state) => NewSpotScreen(
          tripId: state.pathParameters['tripId']!,
        ),
      ),
      GoRoute(
        path: '/trips/:tripId/stops/:stopId',
        builder: (context, state) => StopScreen(
          tripId: state.pathParameters['tripId']!,
          stopId: state.pathParameters['stopId']!,
        ),
      ),
      GoRoute(
        // Joining a trip: the code screen, or an invite link's preview
        // (`/join?token=…`, or `?code=` from the web page's button).
        path: '/join',
        builder: (context, state) => JoinTripScreen(invite: inviteFromQuery(state.uri.queryParameters)),
      ),
      GoRoute(
        // `/join/K7MQ2P`, which the web page understands too.
        path: '/join/:invite',
        builder: (context, state) => JoinTripScreen(
          invite: inviteFromQuery({'token': state.pathParameters['invite']!, 'code': state.pathParameters['invite']!}),
        ),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/library/labels',
        builder: (context, state) => const LabelsScreen(),
      ),
      GoRoute(
        // A place picked on the map and saved to the library.
        path: '/library/new',
        // `?pick=1`: hand the new place's key back instead of opening it.
        builder: (context, state) => NewSpotScreen(returnsPlaceKey: state.uri.queryParameters['pick'] == '1'),
      ),
      GoRoute(
        path: '/library/import',
        builder: (context, state) => const AnitabiImportScreen(),
      ),
      GoRoute(
        path: '/library/places/:placeKey',
        builder: (context, state) => PlaceScreen(placeKey: state.pathParameters['placeKey']!),
      ),
      GoRoute(
        path: '/library/places/:placeKey/location',
        builder: (context, state) => NewSpotScreen(movePlaceKey: state.pathParameters['placeKey']!),
      ),
      GoRoute(
        // The photo editor, for a place or for none yet: see PhotoEditArgs.
        path: '/photo-edit',
        builder: (context, state) => _photoEditScreen(state),
      ),
      GoRoute(
        // Several shots against one frame, then keep the ones you want.
        path: '/shots',
        builder: (context, state) => ShotSeriesScreen(args: ShotSeriesArgs.fromQuery(state.uri.queryParameters)),
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => CameraScreen(
          placeKey: state.uri.queryParameters['place'],
          tripId: state.uri.queryParameters['trip'],
        ),
      ),
    ],
  );
}

/// The photo editor, from the query ([PhotoEditArgs]).
Widget _photoEditScreen(GoRouterState state) {
  final args = PhotoEditArgs.fromQuery(state.uri.queryParameters);
  if (args == null) {
    return const Scaffold(
      body: Center(child: Text('Missing source path.')),
    );
  }
  return PhotoEditScreen(
    placeKey: args.placeKey,
    tripId: args.tripId,
    derivedFromId: args.photoId,
    sourcePath: args.path,
    referencePath: args.referencePath,
    referenceImageId: args.referenceImageId,
    wasUpload: args.upload,
    isCapture: args.capture,
  );
}