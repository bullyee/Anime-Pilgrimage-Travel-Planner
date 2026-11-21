import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/platform_media.dart';
import '../../../shared/map/app_map.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/up_button.dart';
import '../../camera/services/anime_camera_launcher.dart';
import '../../library/providers/place_providers.dart';
import '../../library/widgets/place_page_parts.dart';
import '../models/place_spots.dart';
import '../models/stop_group.dart';
import '../providers/trip_providers.dart';
import '../providers/trip_stop_providers.dart';
import 'stop_screen.dart' show stopFrames;

/// A place of a trip: the stops of a group (or one stop in none), shown as
/// spots on a small map and in a list nearest first, each with its frames and
/// the user's photos of them. Reached by any of its stops, so renaming the
/// group keeps it open.
class TripPlaceScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String stopId;

  const TripPlaceScreen({super.key, required this.tripId, required this.stopId});

  @override
  ConsumerState<TripPlaceScreen> createState() => _TripPlaceScreenState();
}

/// What the place's page knows about one spot.
class _Spot {
  final Stop stop;
  final String label;
  final List<NewReferenceImage> frames;
  final Map<String, Photo> shot;
  final List<Photo> photos;

  const _Spot({required this.stop, required this.label, required this.frames, required this.shot, required this.photos});

  bool get isShot => spotShot(shown: frames, shot: shot, photos: photos);
}

class _TripPlaceScreenState extends ConsumerState<TripPlaceScreen> with WidgetsBindingObserver {
  final _map = MapController();
  Position? _position;
  StreamSubscription<Position>? _positionSub;
  bool _onlyUnshot = false;
  String? _selected;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _map.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startLocation();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopLocation();
    }
  }

  void _stopLocation() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// Follows the user's position when the device allows it; the page works
  /// without it, in list order.
  Future<void> _startLocation() async {
    if (_positionSub != null) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) setState(() => _position = last);
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen(
        (pos) {
          if (mounted) setState(() => _position = pos);
        },
        onError: (_) {},
      );
    } catch (_) {
      // No geolocation here (desktop, tests): the list stays in its order.
    }
  }

  _Spot _spot(Stop stop, String? group) {
    final placeFrames = ref.watch(placeDetailProvider(stop.placeKey)).valueOrNull == null
        ? const <NewReferenceImage>[]
        : ref.watch(placeReferenceImagesProvider(stop.placeKey)).valueOrNull ?? const <NewReferenceImage>[];
    final ownFrames = ref.watch(stopReferenceImagesProvider(stop.id)).valueOrNull ?? const <NewReferenceImage>[];
    final frames = stopFrames(place: placeFrames, stop: ownFrames);
    final photos = [
      for (final p in ref.watch(placePhotosProvider(stop.placeKey)).valueOrNull ?? const <Photo>[])
        if (p.tripId == widget.tripId || p.tripId == null) p,
    ];
    return _Spot(
      stop: stop,
      label: spotLabel(stop, group),
      frames: frames,
      shot: shotFrames(shown: frames, all: [...placeFrames, ...ownFrames], photos: photos),
      photos: photos,
    );
  }

  Future<void> _shoot(_Spot spot, int index) async {
    if (_launching || !animeCameraSupported) return;
    _launching = true;
    _stopLocation();
    try {
      await shootWithFrames(context, ref, placeKey: spot.stop.placeKey, tripId: widget.tripId, frames: spot.frames, index: index);
    } finally {
      _launching = false;
      if (mounted) _startLocation();
    }
  }

  void _openStop(Stop stop) => context.push('/trips/${widget.tripId}/stops/${stop.id}');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final entries = ref.watch(tripStopEntriesProvider(widget.tripId));
    final members = placeEntries(entries.valueOrNull ?? const [], widget.stopId);
    final group = members.isEmpty ? null : stopGroup(members.first.stop);
    final title = group ?? (members.isEmpty ? 'Place' : members.single.stop.name);

    Widget scaffold(Widget body, {String? subtitle}) => Scaffold(
          appBar: AppBar(
            leading: UpButton.ifAlone(context, fallback: '/trips/${widget.tripId}'),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          body: body,
        );

    if (entries.isLoading && !entries.hasValue) return scaffold(const Center(child: CircularProgressIndicator()));
    if (members.isEmpty) return scaffold(const Center(child: Text('This place is no longer in the trip.')));

    final spots = [for (final e in members) _spot(e.stop, group)];
    final shotCount = spots.where((s) => s.isShot).length;
    final unshot = spots.length - shotCount;
    final pos = _position;
    var shown = byDistance(spots, (s) => s.stop, lat: pos?.latitude, lng: pos?.longitude);
    if (_onlyUnshot) shown = [for (final s in shown) if (!s.isShot) s];
    if (_selected != null) {
      final sel = shown.where((s) => s.stop.id == _selected).firstOrNull;
      if (sel != null) shown = [sel, for (final s in shown) if (s != sel) s];
    }

    final subtitle = '${spots.length == 1 ? '1 spot' : '${spots.length} spots'} · $shotCount shot';
    return scaffold(
      subtitle: subtitle,
      Column(
        children: [
          SizedBox(
            height: 220,
            child: AppMap(
              key: const Key('placeMap'),
              controller: _map,
              fitMaxZoom: 19,
              fitPadding: const EdgeInsets.all(40),
              nameUnderSelected: true,
              pins: [
                for (final s in spots)
                  MapPin(
                    id: s.stop.id,
                    point: LatLng(s.stop.lat, s.stop.lng),
                    name: s.label,
                    color: p.tea,
                    done: s.isShot,
                    selected: s.stop.id == _selected,
                  ),
              ],
              center: LatLng(spots.first.stop.lat, spots.first.stop.lng),
              onPinTap: (pin) => setState(() => _selected = _selected == pin.id ? null : pin.id),
              onTap: (_) {
                if (_selected != null) setState(() => _selected = null);
              },
              overPins: [
                if (pos != null)
                  Marker(
                    key: const ValueKey('me'),
                    point: LatLng(pos.latitude, pos.longitude),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F7FD1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: const Color(0xFF2F7FD1).withValues(alpha: 0.3), spreadRadius: 5)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('All ${spots.length}'),
                  selected: !_onlyUnshot,
                  onSelected: (_) => setState(() => _onlyUnshot = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('placeUnshotChip'),
                  label: Text('Not shot $unshot'),
                  selected: _onlyUnshot,
                  onSelected: (_) => setState(() => _onlyUnshot = true),
                ),
                const Spacer(),
                if (pos != null)
                  Text('Nearest first', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(_onlyUnshot ? 'Every spot here is shot.' : 'No spots.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final s = shown[i];
                      return _SpotTile(
                        key: ValueKey('spot-${s.stop.id}'),
                        spot: s,
                        selected: s.stop.id == _selected,
                        distance: pos == null ? null : distanceText(metresTo(s.stop, pos.latitude, pos.longitude)),
                        onOpen: () => _openStop(s.stop),
                        onFrame: animeCameraSupported ? (index) => _shoot(s, index) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A spot in the place's list: its note or short name, how far it is, and a
/// strip of its frames, each replaced by the user's photo once shot.
class _SpotTile extends StatelessWidget {
  final _Spot spot;
  final bool selected;
  final String? distance;
  final VoidCallback onOpen;

  /// Opens the camera on a frame; null where there's no camera.
  final ValueChanged<int>? onFrame;

  const _SpotTile({super.key, required this.spot, required this.selected, required this.distance, required this.onOpen, required this.onFrame});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    final status = spot.isShot ? 'Shot' : 'Not shot';
    final line = [?distance, status, if (spot.frames.isNotEmpty) spot.frames.length == 1 ? '1 frame' : '${spot.frames.length} frames'].join(' · ');
    return Material(
      color: selected ? p.teaSoft : Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spot.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: spot.isShot ? p.tea : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (spot.frames.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: spot.frames.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final frame = spot.frames[i];
                      final photo = spot.shot[frame.id];
                      return _FrameCell(
                        frame: frame,
                        photo: photo,
                        onTap: onFrame == null ? null : () => onFrame!(i),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One frame of a spot, or the user's photo of it once shot, with the frame
/// small in the corner so the two can be compared.
class _FrameCell extends StatelessWidget {
  final NewReferenceImage frame;
  final Photo? photo;
  final VoidCallback? onTap;

  const _FrameCell({required this.frame, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shot = photo;
    return Semantics(
      button: onTap != null,
      label: shot == null ? 'Frame, not shot. Shoot it' : 'Your photo of this frame',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 106,
            height: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (shot == null)
                  FrameImage(frame: frame, cacheWidth: 320)
                else
                  PlatformImage(
                    shot.localPath,
                    fit: BoxFit.cover,
                    cacheWidth: 320,
                    errorBuilder: (_, _, _) => FrameImage(frame: frame, cacheWidth: 320),
                  ),
                if (shot != null)
                  Positioned(
                    right: 3,
                    bottom: 3,
                    width: 36,
                    height: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5), borderRadius: BorderRadius.circular(3)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(2), child: FrameImage(frame: frame, cacheWidth: 120)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
