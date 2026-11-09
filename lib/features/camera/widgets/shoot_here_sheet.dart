import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/database/database.dart';
import '../../../core/services/locate.dart';
import '../../library/models/frames.dart';
import '../../library/widgets/place_page_parts.dart';
import '../../trip/screens/stop_screen.dart' show stopFrames;
import '../models/shooting_core_models.dart';
import '../providers/shooting_core_providers.dart';

/// What the user picked on the Shoot here sheet ([pickShootHere]).
sealed class ShootHereChoice {
  const ShootHereChoice();
}

/// A place near the user, with the frame to float over the camera (none when
/// the place has no frame yet) and all its [frames], in the order offered,
/// to switch between in the camera. [tripId] is the trip when the place is
/// one of its stops.
class ShootAtPlace extends ShootHereChoice {
  final String placeKey;
  final String? tripId;
  final NewReferenceImage? frame;
  final List<NewReferenceImage> frames;

  const ShootAtPlace(this.placeKey, {this.tripId, this.frame, this.frames = const []});
}

/// The ways to shoot that don't depend on where the user is: another
/// place's frames, a reference from the gallery, or no reference at all.
enum ShootHereOther { anotherPlace, gallery, noReference }

class ShootWithoutPlace extends ShootHereChoice {
  final ShootHereOther kind;

  const ShootWithoutPlace(this.kind);
}

/// How far around the user Shoot here looks (roadmap v0.3.0).
const shootHereRadius = 150.0;

/// How long the sheet waits before opening the camera on its own when only
/// one place with at most one frame is near, so a wrong guess can be stopped.
const shootHereAutoOpen = Duration(seconds: 2);

/// What Shoot here offers at one position: [first] is what the day offers
/// first (the day's stops on a trip day, else the library places), [others]
/// wait behind "Other places nearby" (the trip's other stops and the
/// library places, on a trip day only).
class ShootHereSuggestions {
  final bool tripDay;
  final List<NearbyShootingPlace> first;
  final List<NearbyShootingPlace> others;

  const ShootHereSuggestions({required this.tripDay, required this.first, required this.others});

  /// The one place to go straight to the camera with: the only place
  /// offered first, when it has at most one frame. Null otherwise.
  NearbyShootingPlace? get single {
    if (first.length != 1) return null;
    return shootHereFrames(first.single).length <= 1 ? first.single : null;
  }
}

/// Splits the places near [query] into what the day offers first and the
/// rest, nearest first in each (the order [findNearbyPlaces] gives).
final shootHereProvider = FutureProvider.autoDispose.family<ShootHereSuggestions, NearbyPlacesQuery>((
  ref,
  query,
) async {
  final today = await ref.watch(todayTripProvider.future);
  final near = [
    for (final place in await ref.watch(nearbyShootingPlacesProvider(query).future))
      if (place.placeKey.isNotEmpty) place,
  ];
  if (today == null) return ShootHereSuggestions(tripDay: false, first: near, others: const []);
  return ShootHereSuggestions(
    tripDay: true,
    first: [
      for (final p in near)
        if (p.isTargetDayStop) p,
    ],
    others: [
      for (final p in near)
        if (!p.isTargetDayStop) p,
    ],
  );
});

/// The frames to offer for [place]: the library place's own first, then the
/// stop's copies that aren't among them (frames someone else in a shared
/// trip added), oldest first in each.
List<NewReferenceImage> shootHereFrames(NearbyShootingPlace place) {
  int byAge(NewReferenceImage a, NewReferenceImage b) => a.createdAt.compareTo(b.createdAt);
  return stopFrames(
    place: [
      for (final f in place.referenceFrames)
        if (f.stopId == null) f,
    ]..sort(byAge),
    stop: [
      for (final f in place.referenceFrames)
        if (f.stopId != null) f,
    ]..sort(byAge),
  );
}

/// Shoot here (roadmap v0.3.0): finds where the user is (asking for location
/// only now) and offers the frames of the places within about 150 m,
/// nearest first. On a day of a trip the day's stops come first, and the
/// trip's other stops and the library places wait behind "Other places
/// nearby", which opens by itself when none of the day's stops is near.
///
/// GPS is off by tens of metres in town, so the sheet only suggests: with
/// one place it counts down before opening the camera, and the ways to shoot
/// without a place are always there. With [plainCameraOnly] (iOS, whose
/// in-app camera picks its own reference) those ways are one: open the
/// camera. Null when the sheet is dismissed.
Future<ShootHereChoice?> pickShootHere(BuildContext context, {bool plainCameraOnly = false}) {
  return showModalBottomSheet<ShootHereChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.grey[900],
    builder: (_) => ShootHereSheet(plainCameraOnly: plainCameraOnly),
  );
}

class ShootHereSheet extends ConsumerStatefulWidget {
  final bool plainCameraOnly;

  const ShootHereSheet({super.key, this.plainCameraOnly = false});

  @override
  ConsumerState<ShootHereSheet> createState() => _ShootHereSheetState();
}

class _ShootHereSheetState extends ConsumerState<ShootHereSheet> with SingleTickerProviderStateMixin {
  /// A fix rougher than this may leave out places that are there.
  static const _roughAccuracy = 50.0;

  static const _dim = TextStyle(color: Colors.white60);

  late final AnimationController _countdown;

  bool _locating = true;
  LocateResult? _found;

  /// The place the countdown is for, while it runs.
  NearbyShootingPlace? _single;

  /// The fix the countdown was decided for, so it starts at most once per fix.
  NearbyPlacesQuery? _autoDone;

  /// Whether the user opened "Other places nearby" (or closed it).
  bool? _othersOpen;

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(vsync: this, duration: shootHereAutoOpen)
      ..addStatusListener((status) {
        final single = _single;
        if (status == AnimationStatus.completed && single != null && mounted) {
          _pick(single, shootHereFrames(single).firstOrNull);
        }
      });
    _locate();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    _stopCountdown();
    setState(() {
      _locating = true;
      _othersOpen = null;
    });
    LocateResult found;
    try {
      found = await ref.read(locateProvider)();
    } catch (_) {
      found = const LocateResult.failed(LocateProblem.noFix);
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _found = found;
    });
  }

  void _stopCountdown() {
    if (_single == null) return;
    _countdown.stop();
    if (mounted) setState(() => _single = null);
  }

  void _pick(NearbyShootingPlace place, NewReferenceImage? frame) {
    _countdown.stop();
    Navigator.pop(
      context,
      ShootAtPlace(place.placeKey, tripId: place.todayStop?.tripId, frame: frame, frames: shootHereFrames(place)),
    );
  }

  NearbyPlacesQuery? get _query {
    final position = _found?.position;
    if (position == null) return null;
    return NearbyPlacesQuery(lat: position.latitude, lng: position.longitude, maxDistanceMeters: shootHereRadius);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    if (query != null) {
      // Once per fix: one place with at most one frame goes to the camera by
      // itself after a moment, unless the user stops it.
      ref.listen<AsyncValue<ShootHereSuggestions>>(shootHereProvider(query), (_, next) {
        if (!next.hasValue || _autoDone == query) return;
        _autoDone = query;
        final single = next.value!.single;
        if (single == null) return;
        setState(() => _single = single);
        _countdown.forward(from: 0);
      });
    }
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Shoot here',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Find where I am again',
                    onPressed: _locating ? null : _locate,
                    icon: const Icon(Icons.my_location),
                    color: Colors.white,
                    disabledColor: Colors.white24,
                  ),
                ],
              ),
            ),
            _nearby(query),
            const Divider(color: Colors.white12, height: 24),
            if (widget.plainCameraOnly)
              _other(Icons.photo_camera, 'Shoot without a place', ShootHereOther.noReference)
            else ...[
              _other(Icons.bookmarks_outlined, "Another place's frames", ShootHereOther.anotherPlace),
              _other(Icons.photo_library, 'A reference from the gallery', ShootHereOther.gallery),
              _other(Icons.photo_camera, 'No reference', ShootHereOther.noReference),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _other(IconData icon, String title, ShootHereOther kind) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        _countdown.stop();
        Navigator.pop(context, ShootWithoutPlace(kind));
      },
    );
  }

  Widget _nearby(NearbyPlacesQuery? query) {
    final found = _found;
    if (_locating || found == null) return _status('Finding where you are…', busy: true);
    final position = found.position;
    if (position == null || query == null) return _problem(found.problem ?? LocateProblem.noFix);

    final rough = position.accuracy > _roughAccuracy
        ? ' Your location is rough (±${position.accuracy.round()} m), so some may be missing.'
        : '';
    final radius = '${shootHereRadius.round()} m';
    return ref
        .watch(shootHereProvider(query))
        .when(
          loading: () => _status('Looking for places nearby…', busy: true),
          error: (e, _) => _status("Couldn't look up the places nearby: $e"),
          data: (s) {
            if (s.first.isEmpty && s.others.isEmpty) {
              return _status(
                s.tripDay
                    ? 'Nothing from your trip or library is within $radius.$rough'
                    : 'None of your saved places is within $radius.$rough',
              );
            }
            final single = _single;
            final String heading;
            if (single != null) {
              heading = 'Opening the camera for ${single.name}…';
            } else if (s.first.isEmpty) {
              heading = "None of today's stops is within $radius.$rough";
            } else {
              final n = s.first.length;
              heading = switch ((s.tripDay, n)) {
                (true, 1) => "One of today's stops is within $radius.$rough",
                (true, _) => "$n of today's stops are within $radius, nearest first.$rough",
                (false, 1) => 'One place within $radius.$rough',
                (false, _) => '$n places within $radius, nearest first.$rough',
              };
            }
            final othersOpen = _othersOpen ?? s.first.isEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _status(heading),
                if (single != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: AnimatedBuilder(
                      animation: _countdown,
                      builder: (_, _) => LinearProgressIndicator(value: _countdown.value),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('shootHereStop'),
                      onPressed: _stopCountdown,
                      child: const Text('Not this place'),
                    ),
                  ),
                ] else
                  const SizedBox(height: 8),
                if (s.first.isNotEmpty) _row('shootHereFirst', s.first, tripDay: s.tripDay),
                if (s.others.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    key: const Key('shootHereOthers'),
                    dense: true,
                    title: Text(
                      'Other places nearby (${s.others.length})',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(othersOpen ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                    onTap: () {
                      _stopCountdown();
                      setState(() => _othersOpen = !othersOpen);
                    },
                  ),
                  if (othersOpen) _row('shootHereOtherFrames', s.others, tripDay: s.tripDay),
                ],
              ],
            );
          },
        );
  }

  /// A row of frames, one card per frame (or one without a frame) for each
  /// place.
  Widget _row(String key, List<NearbyShootingPlace> places, {required bool tripDay}) {
    final cards = [
      for (final place in places)
        for (final frame in _framesOrNone(place))
          _FrameCard(
            key: Key('shootHere:${place.placeKey}:${frame?.id ?? '-'}'),
            place: place,
            frame: frame,
            where: _where(place, tripDay: tripDay),
            onTap: () => _pick(place, frame),
          ),
    ];
    return SizedBox(
      height: _FrameCard.height,
      child: ListView.separated(
        key: Key(key),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }

  static List<NewReferenceImage?> _framesOrNone(NearbyShootingPlace place) {
    final frames = shootHereFrames(place);
    return frames.isEmpty ? const [null] : frames;
  }

  /// Where a place stands in the trip, for its card: the day of another
  /// stop, or that it's from the library.
  static String? _where(NearbyShootingPlace place, {required bool tripDay}) {
    if (!tripDay || place.isTargetDayStop) return null;
    if (place.todayStop == null) return 'Library';
    final day = place.dayNumber;
    return day == null ? 'In the trip' : 'Day $day';
  }

  Widget _status(String text, {bool busy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (busy) ...[
            const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(text, style: _dim)),
        ],
      ),
    );
  }

  /// Why the places around can't be found, with what to do about it. The
  /// ways to shoot without a place stay below.
  Widget _problem(LocateProblem problem) {
    final (text, action, onPressed) = switch (problem) {
      LocateProblem.serviceOff => (
        "Location is turned off, so the places around you can't be found. You can still shoot below.",
        'Open settings',
        () async {
          await Geolocator.openLocationSettings();
        },
      ),
      LocateProblem.denied => (
        'Allow location access to see the places around you. You can still shoot below.',
        'Allow',
        _locate,
      ),
      LocateProblem.deniedForever => (
        "Location access is off for Trip Planner. Turn it on in the app's settings to see the places around you. "
            'You can still shoot below.',
        'Open settings',
        () async {
          await Geolocator.openAppSettings();
        },
      ),
      LocateProblem.noFix => ("Couldn't find where you are. Try again in the open.", 'Try again', _locate),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(text, style: _dim)),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    );
  }
}

class _FrameCard extends StatelessWidget {
  static const width = 200.0;
  static const height = width * 9 / 16 + 52;

  final NearbyShootingPlace place;
  final NewReferenceImage? frame;
  final String? where;
  final VoidCallback onTap;

  const _FrameCard({super.key, required this.place, required this.frame, required this.where, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final frame = this.frame;
    final details = [
      ?where,
      '${place.distanceMeters.round()} m',
      frame == null ? 'No frame yet' : frameCaption(frame),
    ].nonNulls.join(' · ');
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: frame == null
                    ? const ColoredBox(
                        color: Colors.white10,
                        child: Center(child: Icon(Icons.photo_camera, color: Colors.white38)),
                      )
                    : FrameImage(frame: frame, cacheWidth: 400),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            Text(
              details,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
