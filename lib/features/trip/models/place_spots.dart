import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../providers/trip_stop_providers.dart';
import 'stop_group.dart';

// A trip's places and the spots in them. A place is a group of stops (or a
// stop in no group), and it has the name. Its stops are spots: where in the
// place a frame is shot from, told apart by a note rather than a name of
// their own.

final _separators = RegExp(r'^[\s,、・·\-–—/(（:：]+');

/// What a spot in [group] is called on its place's page: its note, else its
/// name without the group's name in front ("三の間" for "宇治橋 三の間" in
/// "宇治橋"), else its whole name.
String spotLabel(Stop stop, String? group) {
  final note = stop.note?.trim();
  if (note != null && note.isNotEmpty) return note.split('\n').first.trim();
  final name = stop.name.trim();
  if (group != null && name.startsWith(group)) {
    final rest = name.substring(group.length).replaceFirst(_separators, '').trim();
    if (rest.isNotEmpty) return rest;
  }
  return name;
}

/// The place [stopId] is in, among [entries] in list order: its group's
/// stops, or just the stop when it's in no group. Empty when it's gone.
List<TripStopEntry> placeEntries(List<TripStopEntry> entries, String stopId) {
  final anchor = entries.where((e) => e.stop.id == stopId).firstOrNull;
  if (anchor == null) return const [];
  final group = stopGroup(anchor.stop);
  if (group == null) return [anchor];
  return [for (final e in entries) if (stopGroup(e.stop) == group) e];
}

/// Metres from ([lat], [lng]) to [stop].
double metresTo(Stop stop, double lat, double lng) =>
    const Distance().as(LengthUnit.Meter, LatLng(lat, lng), LatLng(stop.lat, stop.lng));

/// [stops] nearest first from ([lat], [lng]), or as they are without a
/// position. Ties keep their order.
List<T> byDistance<T>(List<T> stops, Stop Function(T) stopOf, {double? lat, double? lng}) {
  if (lat == null || lng == null) return stops;
  final indexed = [for (final (i, s) in stops.indexed) (i, s, metresTo(stopOf(s), lat, lng))];
  indexed.sort((a, b) {
    final c = a.$3.compareTo(b.$3);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// "40 m", "1.2 km".
String distanceText(double metres) {
  if (metres < 1000) return '${(metres / 5).round() * 5} m';
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

/// The newest of the user's [photos] shot against each of [shown]'s frames,
/// by frame id. A photo shot against a copy of a frame that [shown] leaves
/// out (the same file or link, among [all]) counts for the frame shown.
Map<String, Photo> shotFrames({
  required List<NewReferenceImage> shown,
  required List<NewReferenceImage> all,
  required List<Photo> photos,
}) {
  bool same(NewReferenceImage a, NewReferenceImage b) =>
      a.id == b.id ||
      ((a.localPath?.isNotEmpty ?? false) && a.localPath == b.localPath) ||
      ((a.remoteUrl?.isNotEmpty ?? false) && a.remoteUrl == b.remoteUrl);
  final byId = {for (final f in [...all, ...shown]) f.id: f};
  final newestFirst = [...photos]..sort((a, b) => (b.takenAt ?? b.createdAt).compareTo(a.takenAt ?? a.createdAt));
  final out = <String, Photo>{};
  for (final photo in newestFirst) {
    final against = byId[photo.referenceImageId];
    if (against == null) continue;
    for (final f in shown) {
      if (!out.containsKey(f.id) && same(f, against)) out[f.id] = photo;
    }
  }
  return out;
}

/// Whether a spot counts as shot: one of its frames is, or it has no frames
/// and the user has a photo there.
bool spotShot({required List<NewReferenceImage> shown, required Map<String, Photo> shot, required List<Photo> photos}) =>
    shot.isNotEmpty || (shown.isEmpty && photos.isNotEmpty);
