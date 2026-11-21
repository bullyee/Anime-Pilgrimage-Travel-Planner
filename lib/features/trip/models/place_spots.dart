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

/// A trip's frames and the user's photos of them, indexed once, so any of
/// its places can be worked out without going through all of them again:
/// the place page uses it for one place, the Places tab for every place.
class TripFrameIndex {
  final Map<String, List<NewReferenceImage>> _ownByStop = {};
  final Map<String, List<NewReferenceImage>> _libraryByPlace = {};

  /// The newest photo shot against a frame, by the frame's id, file and
  /// link (`id:`, `path:`, `url:`), so a photo of one copy of a frame counts
  /// for the others, as [shotFrames] has it.
  final Map<String, Photo> _newestByKey = {};
  final Map<String, List<Photo>> _photosByPlace = {};

  TripFrameIndex({
    required List<NewReferenceImage> own,
    required List<NewReferenceImage> library,
    required List<Photo> photos,
  }) {
    for (final f in own) {
      if (f.stopId case final id?) _ownByStop.putIfAbsent(id, () => []).add(f);
    }
    for (final f in library) {
      if (f.placeKey case final key?) _libraryByPlace.putIfAbsent(key, () => []).add(f);
    }
    final byId = {for (final f in [...own, ...library]) f.id: f};
    final newestFirst = [...photos]..sort((a, b) => _takenAt(b).compareTo(_takenAt(a)));
    for (final photo in newestFirst) {
      _photosByPlace.putIfAbsent(photo.placeKey, () => []).add(photo);
      final against = byId[photo.referenceImageId];
      if (against == null) continue;
      for (final key in _keys(against)) {
        _newestByKey.putIfAbsent(key, () => photo);
      }
    }
  }

  static DateTime _takenAt(Photo p) => p.takenAt ?? p.createdAt;

  static List<String> _keys(NewReferenceImage f) => [
        'id:${f.id}',
        if (f.localPath?.isNotEmpty ?? false) 'path:${f.localPath}',
        if (f.remoteUrl?.isNotEmpty ?? false) 'url:${f.remoteUrl}',
      ];

  /// The newest of the user's photos of [frame] or a copy of it.
  Photo? shotOf(NewReferenceImage frame) {
    Photo? best;
    for (final key in _keys(frame)) {
      final p = _newestByKey[key];
      if (p != null && (best == null || _takenAt(p).isAfter(_takenAt(best)))) best = p;
    }
    return best;
  }

  /// The place made of [stops] (one, or a group named [group]).
  PlaceContent place(List<Stop> stops, {String? group}) {
    final spots = placeSpots(
      stops: stops,
      group: group,
      framesOf: (stop) => placeFramesOf(own: _ownByStop[stop.id] ?? const [], library: _libraryByPlace[stop.placeKey] ?? const []),
    );
    final shot = <String, Photo>{};
    for (final s in spots) {
      for (final f in s.frames) {
        if (shotOf(f) case final p?) shot[f.id] = p;
      }
    }
    return PlaceContent(
      spots: spots,
      shot: shot,
      photosAt: {for (final stop in stops) stop.placeKey: _photosByPlace[stop.placeKey] ?? const <Photo>[]},
    );
  }
}

/// What a place holds: its spots, with the user's photos of their frames.
class PlaceContent {
  final List<PlaceSpot> spots;

  /// The newest photo of each shot frame, by frame id.
  final Map<String, Photo> shot;

  /// The user's photos at each of the place's stops' places, newest first,
  /// by place key: a spot without frames counts as shot with one.
  final Map<String, List<Photo>> photosAt;

  const PlaceContent({required this.spots, required this.shot, required this.photosAt});

  List<NewReferenceImage> get frames => [for (final s in spots) ...s.frames];
  int get frameCount => spots.fold(0, (n, s) => n + s.frames.length);

  /// How many of its frames are shot.
  int get shotCount => frames.where((f) => shot.containsKey(f.id)).length;
  int get unshotCount => frameCount - shotCount;

  bool isShot(PlaceSpot spot) =>
      spotShot(shown: spot.frames, shot: {for (final f in spot.frames) if (shot[f.id] case final p?) f.id: p}, photos: photosAt[spot.stop.placeKey] ?? const []);

  int shotIn(PlaceSpot spot) => spot.frames.where((f) => shot.containsKey(f.id)).length;
  bool hasUnshot(PlaceSpot spot) => spot.frames.any((f) => !shot.containsKey(f.id));

  /// The newest photo of any of its frames, for its thumbnail.
  Photo? get latestShot {
    Photo? best;
    for (final p in shot.values) {
      if (best == null || (p.takenAt ?? p.createdAt).isAfter(best.takenAt ?? best.createdAt)) best = p;
    }
    return best;
  }

  NewReferenceImage? get firstFrame => frames.firstOrNull;

  /// The metres from ([lat], [lng]) to its nearest spot; null without a
  /// position or spots.
  double? distanceFrom(double? lat, double? lng) {
    if (lat == null || lng == null || spots.isEmpty) return null;
    return spots.map((s) => metresBetween(lat, lng, s.lat, s.lng)).reduce((a, b) => a < b ? a : b);
  }
}

/// The frames to shoot at a place, in the order the queue offers them: the
/// ones not shot yet, the nearest spot's first when there's a position,
/// else in the place's order. Nothing makes the user follow it.
List<NewReferenceImage> shootingQueue(PlaceContent place, {double? lat, double? lng}) => [
      for (final s in byDistance(place.spots, (s) => s.point, lat: lat, lng: lng))
        for (final f in s.frames)
          if (!place.shot.containsKey(f.id)) f,
    ];

/// What to shoot next at a place: the first frame of [shootingQueue], with
/// its spot and how far away it is. Null when everything is shot.
({PlaceSpot spot, NewReferenceImage frame, double? metres})? nextToShoot(PlaceContent place, {double? lat, double? lng}) {
  final frame = shootingQueue(place, lat: lat, lng: lng).firstOrNull;
  if (frame == null) return null;
  final spot = place.spots.firstWhere((s) => s.frames.contains(frame));
  return (
    spot: spot,
    frame: frame,
    metres: lat == null || lng == null ? null : metresBetween(lat, lng, spot.lat, spot.lng),
  );
}

/// The eight compass points, for "NE 40 m".
enum Compass { n, ne, e, se, s, sw, w, nw }

/// Which way ([toLat], [toLng]) is from ([lat], [lng]).
Compass compassTo(double lat, double lng, double toLat, double toLng) {
  final degrees = const Distance().bearing(LatLng(lat, lng), LatLng(toLat, toLng));
  return Compass.values[((degrees % 360 + 360) % 360 / 45).round() % 8];
}
