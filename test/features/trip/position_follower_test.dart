import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trip_planner/features/trip/widgets/position_follower.dart';

class _FakeGeolocator extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission answer = LocationPermission.denied;
  bool lastThrows = false;
  int asked = 0;
  int streams = 0;
  final positions = StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    asked++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return permission = answer;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async {
    if (lastThrows) throw UnsupportedError('not on the web');
    return null;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streams++;
    return positions.stream;
  }
}

Position _at(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 11, 24),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeGeolocator geo;

  setUp(() {
    geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;
  });

  test('a refusal is asked once, however often the app comes back', () async {
    final follower = PositionFollower();
    addTearDown(follower.dispose);
    await Future.wait([follower.start(), follower.start()]);
    follower.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await follower.start();
    expect(geo.asked, 1);
    expect(geo.streams, 0);
    expect(follower.position, isNull);
  });

  test('without a last position (the web) it still follows', () async {
    geo
      ..permission = LocationPermission.whileInUse
      ..lastThrows = true;
    final follower = PositionFollower();
    addTearDown(follower.dispose);
    await follower.start();
    expect(geo.streams, 1);
    geo.positions.add(_at(34.89, 135.80));
    await Future<void>.delayed(Duration.zero);
    expect(follower.position?.latitude, 34.89);
  });

  test('paused while asking, it doesn\'t start', () async {
    geo.answer = LocationPermission.whileInUse;
    final follower = PositionFollower();
    addTearDown(follower.dispose);
    final starting = follower.start();
    follower.pause();
    await starting;
    expect(geo.streams, 0);
  });
}
