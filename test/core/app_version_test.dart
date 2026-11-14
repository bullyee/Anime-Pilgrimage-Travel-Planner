import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/app_version.dart';

void main() {
  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(appVersion, version, reason: 'Bump lib/core/app_version.dart with pubspec.yaml');
  });

  test('the label puts the build number in brackets', () {
    final parts = appVersion.split('+');
    expect(appVersionLabel, '${parts[0]} (${parts[1]})');
  });
}
