import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../library/controllers/library_controller.dart';
import '../../library/controllers/place_controller.dart';
import '../../library/models/duplicates.dart';
import '../../library/providers/place_providers.dart';
import '../../library/services/place_search.dart';
import '../controllers/trip_stops_controller.dart';
import '../providers/trip_providers.dart';

/// Picks a spot on the map: move the map until the pin sits on it, or
/// search for it, then name it. With a [tripId] the spot becomes a stop of
/// that trip and stays out of the library; without one it is saved to the
/// library. With [movePlaceKey] it moves that library place's pin instead.
class NewSpotScreen extends ConsumerStatefulWidget {
  final String? tripId;
  final String? movePlaceKey;

  const NewSpotScreen({super.key, this.tripId, this.movePlaceKey});

  @override
  ConsumerState<NewSpotScreen> createState() => _NewSpotScreenState();
}

class _NewSpotScreenState extends ConsumerState<NewSpotScreen> {
  static const _japan = LatLng(36.2048, 138.2529);

  final _map = MapController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _about = TextEditingController();
  final _query = TextEditingController();
  final _searcher = PlaceSearch();
  late final ValueNotifier<LatLng> _center;
  late final LatLng _initialCenter;
  late final double _initialZoom;
  String? _nameError;
  bool _locating = false;
  bool _searching = false;
  bool _saving = false;

  bool get _moving => widget.movePlaceKey != null;

  @override
  void initState() {
    super.initState();
    final moving = widget.movePlaceKey == null ? null : ref.read(placeDetailProvider(widget.movePlaceKey!)).valueOrNull;
    if (moving != null) {
      _initialCenter = LatLng(moving.lat, moving.lng);
      _initialZoom = 17;
      _center = ValueNotifier(_initialCenter);
      return;
    }
    // Start where the trip's other stops (or the library's places) are, or
    // over Japan for the first one.
    final tripId = widget.tripId;
    final points = tripId != null
        ? [for (final s in ref.read(tripStopsProvider(tripId)).valueOrNull ?? const <Stop>[]) LatLng(s.lat, s.lng)]
        : [
            for (final p in ref.read(placesListProvider(null)).valueOrNull ?? const <Place>[])
              if (p.visibility == 'saved') LatLng(p.lat, p.lng),
          ];
    if (points.isEmpty) {
      _initialCenter = _japan;
      _initialZoom = 5;
    } else {
      final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
      final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
      _initialCenter = LatLng(lat, lng);
      _initialZoom = 14;
    }
    _center = ValueNotifier(_initialCenter);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _about.dispose();
    _query.dispose();
    _searcher.close();
    _center.dispose();
    _map.dispose();
    super.dispose();
  }

  void _say(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// Finds what the user typed: a Google Maps link, coordinates, or a name
  /// (searched with OpenStreetMap's Nominatim, only on submit).
  Future<void> _search(String text) async {
    final query = text.trim();
    if (query.isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final link = firstLink(query);
      if (link != null) {
        final at = isShortMapsLink(link) ? await _searcher.resolveShortLink(link) : coordinatesInMapsLink(link);
        if (!mounted) return;
        if (at == null) {
          _say('That link has no location in it. Share the place from Google Maps and paste that link.');
        } else {
          _map.move(at, 17);
        }
        return;
      }
      final typed = typedCoordinates(query);
      if (typed != null) {
        _map.move(typed, 17);
        return;
      }
      final found = await _searcher.search(query);
      if (!mounted) return;
      if (found.isEmpty) {
        _say('Nothing found for “$query”. Try the name in Japanese, or paste a Google Maps link.');
        return;
      }
      final picked = await showModalBottomSheet<FoundPlace>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final f in found)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(f.name),
                    subtitle: Text(f.detail, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, f),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'Search by Nominatim · data © OpenStreetMap contributors',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (picked == null || !mounted) return;
      _map.move(picked.at, 17);
      if (!_moving && _name.text.trim().isEmpty) _name.text = picked.name;
    } catch (e) {
      if (mounted) _say(e is PlaceSearchException ? e.message : "Couldn't search right now. Check the connection and try again.");
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _saveMove() async {
    setState(() => _saving = true);
    final at = _center.value;
    final result = await ref.read(placeControllerProvider.notifier).moveTo(widget.movePlaceKey!, at.latitude, at.longitude);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        _say('Moved the pin.');
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/library/places/${Uri.encodeComponent(widget.movePlaceKey!)}');
        }
      case Failure(:final error):
        _say(error);
    }
  }

  /// Offers a saved place that looks like the one being added: close by and
  /// with a similar name. True to go on adding the new one.
  Future<bool> _confirmNotDuplicate(LatLng at) async {
    final places = ref.read(placesListProvider(null)).valueOrNull ?? const <Place>[];
    final match = likelyDuplicate(places.where((p) => p.visibility == 'saved'), name: _name.text, at: at);
    if (match == null) return true;
    final tripId = widget.tripId;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('“${match.place.name}” is already in your library'),
        content: Text('It is ${match.meters.round()} m from this pin. '
            '${tripId == null ? 'Open it instead of adding a second one?' : 'Add it to the trip instead of a new spot?'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'new'), child: const Text('Add a new one')),
          FilledButton(onPressed: () => Navigator.pop(context, 'existing'), child: Text(tripId == null ? 'Open it' : 'Use it')),
        ],
      ),
    );
    if (choice != 'existing' || !mounted) return choice == 'new';
    final key = match.place.placeKey;
    if (tripId == null) {
      context.pushReplacement('/library/places/${Uri.encodeComponent(key)}');
    } else {
      final result = await ref.read(tripStopsControllerProvider.notifier).addFromLibrary(tripId: tripId, placeKeys: [key], repeat: true);
      if (!mounted) return false;
      if (result is Success) {
        _say('Added ${match.place.name} from your library.');
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/trips/$tripId/stops');
        }
      } else {
        _say((result as Failure).error);
      }
    }
    return false;
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    String? problem;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = 'Location is turned off on this device.';
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          problem = 'Allow location access to use your position.';
        } else {
          // Ask for a fresh fix: the cached one can be from wherever the
          // phone was hours ago. Fall back to it only if none comes in time.
          Position? position;
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 8),
              ),
            );
          } on TimeoutException {
            position = await Geolocator.getLastKnownPosition();
          }
          if (position == null) {
            problem = "Couldn't find your position. Try again in the open.";
          } else if (mounted) {
            _map.move(LatLng(position.latitude, position.longitude), 17);
          }
        }
      }
    } catch (e) {
      problem = "Couldn't find your position: $e";
    }
    if (!mounted) return;
    setState(() => _locating = false);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  Future<void> _save() async {
    if (_moving) return _saveMove();
    final tripId = widget.tripId;
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = tripId == null ? 'Give the place a name.' : 'Give the spot a name.');
      return;
    }
    final at = _center.value;
    if (!await _confirmNotDuplicate(at) || !mounted) return;
    setState(() => _saving = true);
    final AppResult<String> result = tripId != null
        ? switch (await ref.read(tripStopsControllerProvider.notifier).createSpot(
            tripId: tripId,
            name: _name.text,
            lat: at.latitude,
            lng: at.longitude,
            address: _address.text,
            description: _about.text,
          )) {
            Success(:final value) => Success('Added ${value.name}.'),
            Failure(:final error) => Failure("Couldn't add the spot: $error"),
          }
        : switch (await ref.read(libraryControllerProvider.notifier).createPlace(
            name: _name.text,
            lat: at.latitude,
            lng: at.longitude,
            address: _address.text,
            description: _about.text,
          )) {
            Success(:final value) => Success('Saved ${value.name} to your library.'),
            Failure(:final error) => Failure("Couldn't save the place: $error"),
          };
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success(:final value):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(tripId == null ? '/library' : '/trips/$tripId/stops');
        }
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forTrip = widget.tripId != null;
    return Scaffold(
      appBar: AppBar(title: Text(_moving ? 'Move the pin' : forTrip ? 'New spot' : 'New place')),
      body: Column(
        children: [
          Expanded(
            flex: _moving ? 1 : 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: _initialZoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onPositionChanged: (camera, _) => _center.value = camera.center,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.trip_planner',
                    ),
                    const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                  ],
                ),
                // The pin's tip marks the map's center.
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -22),
                      child: Icon(Icons.location_on, size: 44, color: theme.colorScheme.error),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(28),
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: TextField(
                      key: const Key('placeSearchField'),
                      controller: _query,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        hintText: 'Search a place, or paste a Google Maps link',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        prefixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Search',
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () => _search(_query.text),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 36,
                  child: FloatingActionButton.small(
                    heroTag: 'newSpotLocate',
                    tooltip: 'Use my location',
                    onPressed: _locating ? null : _locate,
                    child: _locating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          if (_moving)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: ValueListenableBuilder<LatLng>(
                valueListenable: _center,
                builder: (_, at, _) => Text(
                  'Move the map so the pin sits on the spot. Pin at ${at.latitude.toStringAsFixed(5)}, ${at.longitude.toStringAsFixed(5)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                ValueListenableBuilder<LatLng>(
                  valueListenable: _center,
                  builder: (_, at, _) => Text(
                    'Move the map so the pin sits on the spot. Pin at ${at.latitude.toStringAsFixed(5)}, ${at.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('spotNameField'),
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Name', errorText: _nameError),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Address (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _about,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            key: const Key('spotSave'),
            onPressed: _saving ? null : _save,
            child: Text(_moving ? 'Save location' : forTrip ? 'Add to trip' : 'Save to library'),
          ),
        ),
      ),
    );
  }
}
