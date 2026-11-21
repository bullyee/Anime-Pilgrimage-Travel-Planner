import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';
import '../providers/trip_stop_providers.dart';
import 'stop_group.dart';

export 'stop_group.dart' show spotLabel;

// A trip's places and the spots in them. A place is a stop, and it has the
// name. Its spots are where in the place its frames are shot from: not
// stored, but the frames grouped by their note and position. A group of
// stops not yet folded into one (see PlaceFoldService) is still one place,
// each stop's frames taking the stop's position and short name.

/// How far apart, in metres, frames with the same note can be and still be
/// one spot.
const spotRadiusMetres = 15.0;

/// A spot of a place: the frames shot from about the same position under the
/// same note, or a stop that has no frames.
class PlaceSpot {
  /// Stays the same while the spot keeps its first frame: that frame's id, or
  /// `stop:<id>` for a stop without frames.
  final String key;

  /// The frames' note, else the stop's name.
  final String label;

  /// The stop the spot's first frame belongs to.
  final Stop stop;
  final List<NewReferenceImage> frames;

  /// The mean position of its frames.
  final double lat;
  final double lng;

  /// None of its frames says where it's shot from, so [lat] and [lng] are
  /// its stop's.
  final bool estimated;

  const PlaceSpot({
    required this.key,
    required this.label,
    required this.stop,
    required this.frames,
    required this.lat,
    required this.lng,
    required this.estimated,
  });

  LatLng get point => LatLng(lat, lng);
}

/// The frames a place's page shows for a stop: its own, then the library's
/// of its place that it has no copy of. Unlike the stop's page, a copy wins
/// over the library's frame, since the copy carries where it's shot from.
List<NewReferenceImage> placeFramesOf({required List<NewReferenceImage> own, required List<NewReferenceImage> library}) {
  bool same(NewReferenceImage a, NewReferenceImage b) =>
      ((a.localPath?.isNotEmpty ?? false) && a.localPath == b.localPath) ||
      ((a.remoteUrl?.isNotEmpty ?? false) && a.remoteUrl == b.remoteUrl);
  bool shows(NewReferenceImage f) => (f.localPath?.isNotEmpty ?? false) || (f.remoteUrl?.isNotEmpty ?? false);
  return [
    for (final f in own)
      if (shows(f)) f,
    for (final f in library)
      if (shows(f) && !own.any((o) => same(o, f))) f,
  ];
}

/// The spots of the place made of [stops] (one, or a group named [group]),
/// in the order their first frames come. [framesOf] gives each stop's
/// frames ([placeFramesOf]). A frame without a position counts as shot from
/// its stop's (and its spot is [PlaceSpot.estimated] when all its frames
/// are); in a group, a frame without a note takes its stop's short name
/// ([spotLabel]). Frames with the same note within [spotRadiusMetres] of the
/// spot's mean position are one spot.
List<PlaceSpot> placeSpots({
  required List<Stop> stops,
  String? group,
  required List<NewReferenceImage> Function(Stop stop) framesOf,
}) {
  final builders = <_SpotBuilder>[];
  for (final stop in stops) {
    final frames = framesOf(stop);
    if (frames.isEmpty) {
      builders.add(_SpotBuilder(
        key: 'stop:${stop.id}',
        note: group == null ? null : spotLabel(stop, group),
        stop: stop,
      )..add(null, stop.lat, stop.lng, estimated: false));
      continue;
    }
    for (final frame in frames) {
      final placed = frame.lat != null && frame.lng != null;
      final lat = placed ? frame.lat! : stop.lat;
      final lng = placed ? frame.lng! : stop.lng;
      final own = frame.note?.trim();
      final note = own != null && own.isNotEmpty ? own : (group == null ? null : spotLabel(stop, group));
      var spot = builders
          .where((b) => b.hasFrames && b.note == note && metresBetween(b.lat, b.lng, lat, lng) <= spotRadiusMetres)
          .firstOrNull;
      if (spot == null) builders.add(spot = _SpotBuilder(key: frame.id, note: note, stop: stop));
      spot.add(frame, lat, lng, estimated: !placed);
    }
  }
  return [for (final b in builders) b.build()];
}

class _SpotBuilder {
  final String key;
  final String? note;
  final Stop stop;
  final frames = <NewReferenceImage>[];
  double _latSum = 0;
  double _lngSum = 0;
  int _count = 0;
  bool _estimated = true;

  _SpotBuilder({required this.key, required this.note, required this.stop});

  bool get hasFrames => frames.isNotEmpty;
  double get lat => _latSum / _count;
  double get lng => _lngSum / _count;

  void add(NewReferenceImage? frame, double lat, double lng, {required bool estimated}) {
    if (frame != null) frames.add(frame);
    _latSum += lat;
    _lngSum += lng;
    _count++;
    _estimated = _estimated && estimated;
  }

  PlaceSpot build() => PlaceSpot(
        key: key,
        label: note ?? stop.name,
        stop: stop,
        frames: List.unmodifiable(frames),
        lat: lat,
        lng: lng,
        estimated: _estimated,
      );
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

/// Metres from ([lat], [lng]) to ([toLat], [toLng]).
double metresBetween(double lat, double lng, double toLat, double toLng) =>
    const Distance().as(LengthUnit.Meter, LatLng(lat, lng), LatLng(toLat, toLng));

/// [items] nearest first from ([lat], [lng]), or as they are without a
/// position. Ties keep their order.
List<T> byDistance<T>(List<T> items, LatLng Function(T) at, {double? lat, double? lng}) {
  if (lat == null || lng == null) return items;
  final indexed = [
    for (final (i, s) in items.indexed) (i, s, metresBetween(lat, lng, at(s).latitude, at(s).longitude)),
  ];
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
