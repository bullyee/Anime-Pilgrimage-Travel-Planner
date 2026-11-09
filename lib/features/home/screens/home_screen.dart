import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trip_planner/features/auth/providers/auth_provider.dart';
import 'package:trip_planner/features/camera/services/anime_camera_launcher.dart';

import '../providers/home_providers.dart';
import '../widgets/near_you.dart';
import '../widgets/next_trip_card.dart';
import '../widgets/today_card.dart';

/// Home (roadmap v0.3.0, version A): a column of cards where only the top
/// one follows the date. On a day of a trip it is today, with a small map
/// that opens the trip's day map; on other days it is the next trip. Near
/// you is the same every day. Shoot sits in the middle of the bottom bar,
/// with Trips and Library either side.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum _More { floatReference, editPhoto, signIn, signOut }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // A photo taken just before Android killed the app comes back here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) recoverLostCapture(context);
    });
  }

  Future<void> _more(_More choice) async {
    switch (choice) {
      case _More.floatReference:
        await floatReference(context, ref);
      case _More.editPhoto:
        await editPhotoFromGallery(context, ref);
      case _More.signIn:
        context.push('/login');
      case _More.signOut:
        await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authStateChangesProvider).valueOrNull != null;
    final focus = ref.watch(homeFocusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Planner'),
        actions: [
          PopupMenuButton<_More>(
            tooltip: 'More',
            onSelected: _more,
            itemBuilder: (context) => [
              if (floatingReferenceSupported)
                const PopupMenuItem(value: _More.floatReference, child: Text('Float a frame over any app')),
              const PopupMenuItem(value: _More.editPhoto, child: Text('Edit a photo from the gallery')),
              signedIn
                  ? const PopupMenuItem(value: _More.signOut, child: Text('Sign out'))
                  : const PopupMenuItem(value: _More.signIn, child: Text('Sign in')),
            ],
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
            children: [
              focus.when(
                loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text("Couldn't load your trips: $e"),
                data: (focus) => switch (focus) {
                  HomeTripDay(:final trip) => TodayCard(key: ValueKey(trip.trip.id), tripId: trip.trip.id),
                  HomeNextTrip(:final trip) => NextTripCard(next: trip),
                },
              ),
              const SizedBox(height: 20),
              const NearYou(),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: animeCameraSupported
          ? FloatingActionButton.large(
              tooltip: 'Shoot',
              onPressed: () => openAnimeCamera(context, ref),
              child: const Icon(Icons.photo_camera),
            )
          : null,
      bottomNavigationBar: BottomAppBar(
        shape: animeCameraSupported ? const CircularNotchedRectangle() : null,
        child: Row(
          children: [
            Expanded(
              child: _BarButton(icon: Icons.flight_takeoff, label: 'Trips', onPressed: () => context.push('/trips')),
            ),
            if (animeCameraSupported) const SizedBox(width: 96),
            Expanded(
              child: _BarButton(
                icon: Icons.bookmarks_outlined,
                label: 'Library',
                onPressed: () => context.push('/library'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BarButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        minimumSize: const Size(64, 56),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), const SizedBox(height: 2), Text(label)],
      ),
    );
  }
}
