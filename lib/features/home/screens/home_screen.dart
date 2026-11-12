import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trip_planner/features/camera/services/anime_camera_launcher.dart';

import '../providers/home_providers.dart';
import '../widgets/near_you.dart';
import '../widgets/next_trip_card.dart';
import '../widgets/photos_to_edit_card.dart';
import '../widgets/today_card.dart';

/// Home (roadmap v0.3.0, version A): a column of cards where only the top
/// one follows the date. On a day of a trip it is today, with a small map
/// that opens the trip's day map; on other days it is the next trip. Under
/// it, the photos to edit when there are any; Near you is the same every
/// day. Shoot, Trips, Library and Photos are in the app's bottom bar
/// ([AppFrame]). There's no Sign in here: the app works without an account,
/// and sharing, inviting and joining a trip ask for one when they need it
/// (sign-out is in My Trips).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // A photo taken just before Android killed the app comes back here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) recoverLostCapture(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final focus = ref.watch(homeFocusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Planner'),
        actions: [
          // The floating window (Android). Editing a photo from the gallery
          // is in the Photos tab.
          if (floatingReferenceSupported)
            IconButton(
              tooltip: 'Float a frame over any app',
              icon: const Icon(Icons.picture_in_picture_alt_outlined),
              onPressed: () => floatReference(context, ref),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              focus.when(
                loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text("Couldn't load your trips: $e"),
                data: (focus) => switch (focus) {
                  HomeTripDay(:final trip) => TodayCard(key: ValueKey(trip.trip.id), tripId: trip.trip.id),
                  HomeNextTrip(:final trip) => NextTripCard(next: trip),
                },
              ),
              const PhotosToEditCard(),
              const SizedBox(height: 20),
              const NearYou(),
            ],
          ),
        ),
      ),
    );
  }
}
