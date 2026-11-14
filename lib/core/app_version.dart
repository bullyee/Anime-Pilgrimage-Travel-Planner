/// The app's version as in `pubspec.yaml`, shown in Settings → About.
///
/// Kept here by hand instead of read at run time, so it needs no plugin;
/// `test/core/app_version_test.dart` fails when it differs from `pubspec.yaml`,
/// so a release that bumps one has to bump the other.
const appVersion = '0.3.0+6';

/// "0.3.0 (6)".
String get appVersionLabel {
  final parts = appVersion.split('+');
  return parts.length == 2 ? '${parts[0]} (${parts[1]})' : appVersion;
}
