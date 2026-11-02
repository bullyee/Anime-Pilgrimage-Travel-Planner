import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../controllers/trip_stops_controller.dart';
import '../providers/trip_providers.dart';

/// Adds a spot that isn't in the library: move the map until the pin sits on
/// it, then name it.
class NewSpotScreen extends ConsumerStatefulWidget {
  final String tripId;

  const NewSpotScreen({super.key, required this.tripId});

  @override
  ConsumerState<NewSpotScreen> createState() => _NewSpotScreenState();
}

class _NewSpotScreenState extends ConsumerState<NewSpotScreen> {
  static const _japan = LatLng(36.2048, 138.2529);

  final _map = MapController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _about = TextEditingController();
  late final ValueNotifier<LatLng> _center;
  late final LatLng _initialCenter;
  late final double _initialZoom;
  String? _nameError;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Start where the trip's other stops are, or over Japan for the first one.
    final stops = ref.read(tripStopsProvider(widget.tripId)).valueOrNull ?? const <Stop>[];
    if (stops.isEmpty) {
      _initialCenter = _japan;
      _initialZoom = 5;
    } else {
      final lat = stops.map((s) => s.lat).reduce((a, b) => a + b) / stops.length;
      final lng = stops.map((s) => s.lng).reduce((a, b) => a + b) / stops.length;
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
    _center.dispose();
    _map.dispose();
    super.dispose();
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
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Give the spot a name.');
      return;
    }
    setState(() => _saving = true);
    final at = _center.value;
    final result = await ref.read(tripStopsControllerProvider.notifier).createSpot(
          tripId: widget.tripId,
          name: _name.text,
          lat: at.latitude,
          lng: at.longitude,
          address: _address.text,
          description: _about.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success(:final value):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${value.name}.')));
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/trips/${widget.tripId}/stops');
        }
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't add the spot: $error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New spot')),
      body: Column(
        children: [
          Expanded(
            flex: 5,
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
                  child: IgnorePointer(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          'Move the map so the pin sits on the spot.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
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
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                ValueListenableBuilder<LatLng>(
                  valueListenable: _center,
                  builder: (_, at, _) => Text(
                    'Pin at ${at.latitude.toStringAsFixed(5)}, ${at.longitude.toStringAsFixed(5)}',
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
            child: const Text('Add to trip'),
          ),
        ),
      ),
    );
  }
}
