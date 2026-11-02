import 'package:flutter/material.dart';
// Add this
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:trip_planner/features/auth/providers/auth_provider.dart'; // Add this
import 'package:trip_planner/features/auth/screens/login_screen.dart'; // Add this

import '../../features/home/screens/home_screen.dart';
import '../../features/poi/screens/poi_map_screen.dart';
import '../../features/roi/screens/roi_list_screen.dart';
import '../../features/roi/screens/roi_detail_screen.dart';
import '../../features/roi/screens/roi_edit_screen.dart';
import '../../features/poi/screens/poi_detail_screen.dart';
import '../../features/poi/screens/poi_create_screen.dart';
import '../../features/poi/screens/poi_browse_screen.dart';
import '../../features/poi/screens/pois_by_filter_screen.dart';
import '../../features/poi/screens/photo_edit_screen.dart';
import '../../features/anime/screens/anime_edit_screen.dart';
import '../../features/anime/screens/bangumi_search_screen.dart';
import '../../features/tag/screens/tag_edit_screen.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/camera/screens/camera_screen.dart';
import '../../features/trip/screens/trip_list_screen.dart';
import '../../features/trip/screens/trip_overview_screen.dart';

part 'app_router.g.dart';

/// Wrap the existing router in a Provider to react to Auth state changes.
@Riverpod(keepAlive: true)
GoRouter router(RouterRef ref) {
  // Watch the auth state from our previously created provider.
  ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/',
    
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

      // 6. DEFAULT (Offline-first core): Allow all other navigation (e.g., '/', '/map', '/pois').
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
        builder: (context, state) => TripOverviewScreen(
          tripId: state.pathParameters['tripId']!,
        ),
      ),
      GoRoute(
        path: '/rois',
        builder: (context, state) => const RoiListScreen(),
      ),
      GoRoute(
        path: '/rois/:roiId',
        builder: (context, state) => RoiDetailScreen(
          roiId: state.pathParameters['roiId']!,
        ),
      ),
      GoRoute(
        path: '/rois/:roiId/edit',
        builder: (context, state) => RoiEditScreen(
          roiId: state.pathParameters['roiId']!,
        ),
      ),
      GoRoute(
        path: '/rois/:roiId/pois/new',
        builder: (context, state) => PoiCreateScreen(
          roiId: state.pathParameters['roiId'],
        ),
      ),
      GoRoute(
        // Pops with the new POI's id, which the photo editor's POI button
        // uses to save into it.
        path: '/pois/new',
        builder: (context, state) => const PoiCreateScreen(),
      ),
      GoRoute(
        path: '/pois/:poiId/edit',
        builder: (context, state) => PoiCreateScreen(
          editPoiId: state.pathParameters['poiId'],
        ),
      ),
      GoRoute(
        path: '/pois',
        builder: (context, state) => PoiBrowseScreen(
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: '/pois/:poiId',
        builder: (context, state) => PoiDetailScreen(
          poiId: state.pathParameters['poiId']!,
        ),
      ),
      GoRoute(
        // A photo with no POI yet: Edit Photo from the home screen, or an
        // Anime Camera shot taken without one. The editor's POI button can
        // pick one.
        path: '/photo-edit',
        builder: (context, state) => _photoEditScreen(state),
      ),
      GoRoute(
        path: '/pois/:poiId/photo-edit',
        builder: (context, state) =>
            _photoEditScreen(state, poiId: state.pathParameters['poiId']!),
      ),
      GoRoute(
        path: '/animes/:animeId/edit',
        builder: (context, state) => AnimeEditScreen(
          animeId: state.pathParameters['animeId'],
        ),
      ),
      GoRoute(
        path: '/anime/:animeId',
        builder: (context, state) => PoisByAnimeScreen(
          animeId: state.pathParameters['animeId']!,
        ),
      ),
      GoRoute(
        path: '/tags/:tagId/edit',
        builder: (context, state) => TagEditScreen(
          tagId: state.pathParameters['tagId'],
        ),
      ),
      GoRoute(
        path: '/tag/:tagId',
        builder: (context, state) => PoisByTagScreen(
          tagId: state.pathParameters['tagId']!,
        ),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => CameraScreen(
          poiId: state.uri.queryParameters['poiId'],
        ),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const PoiMapScreen(),
      ),
      GoRoute(
        path: '/import/bangumi',
        builder: (context, state) => const BangumiSearchScreen(),
      ),
    ],
  );
}

/// The photo editor for both of its routes, from the query: `path` (the
/// photo), `ref` / `refId` (its reference), `upload=1` (picked from the
/// gallery) and `capture=1` (just shot with the Anime Camera).
Widget _photoEditScreen(GoRouterState state, {String? poiId}) {
  final qp = state.uri.queryParameters;
  final source = qp['path'];
  if (source == null) {
    return const Scaffold(
      body: Center(child: Text('Missing source path.')),
    );
  }
  return PhotoEditScreen(
    poiId: poiId,
    sourcePath: Uri.decodeComponent(source),
    referencePath: qp['ref'] != null ? Uri.decodeComponent(qp['ref']!) : null,
    referenceImageId: qp['refId'],
    wasUpload: qp['upload'] == '1',
    isCapture: qp['capture'] == '1',
  );
}