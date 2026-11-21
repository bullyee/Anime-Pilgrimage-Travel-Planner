import '../../../core/database/database.dart';
import '../../planner/models/planner_view.dart';
import 'place_spots.dart';
import 'stop_group.dart';

// The trip page is led by places: its days are optional categories (a
// title, maybe a date), each holding places, and the places on no day wait
// in Unsorted. A place is a stop, or a group of stops not folded into one
// yet, shown as one.

/// A place of the trip as the Places tab lists it.
class TripPlace {
  /// Its first stop's id, which the place page opens by.
  final String id;

  /// The stop's name, or the group's.
  final String name;

  /// The group's name, for a group of stops not folded into one yet.
  final String? group;

  /// Never empty.
  final List<Stop> stops;

  /// Its stops' schedule items on its day, in the day's order; empty in
  /// Unsorted.
  final List<String> itemIds;

  const TripPlace({required this.id, required this.name, required this.stops, this.group, this.itemIds = const []});

  Stop get stop => stops.first;
}

/// A day of the trip with its places, or Unsorted (no [day]).
class PlacesSection {
  final PlannerDay? day;
  final List<TripPlace> places;

  const PlacesSection({required this.day, required this.places});

  bool get isUnsorted => day == null;
  String? get dayId => day?.day.id;
}

/// Everything the Places tab lists for one trip.
class TripPlacesView {
  /// Every day in the trip's order, empty ones too.
  final List<PlacesSection> days;

  /// The places on no day.
  final PlacesSection unsorted;

  const TripPlacesView({required this.days, required this.unsorted});

  List<PlacesSection> get sections => [...days, unsorted];

  /// Every place once, in list order.
  List<TripPlace> get all {
    final seen = <String>{};
    return [
      for (final s in sections)
        for (final p in s.places)
          if (seen.add(p.id)) p,
    ];
  }

  /// The section the place with [stopId] is in (its first one).
  PlacesSection? sectionOf(String stopId) {
    for (final s in sections) {
      if (s.places.any((p) => p.stops.any((st) => st.id == stopId))) return s;
    }
    return null;
  }

  /// The day whose date is [today], when one is.
  PlacesSection? todaySection(DateTime today) {
    for (final s in days) {
      final d = s.day?.date;
      if (d != null && d.year == today.year && d.month == today.month && d.day == today.day) return s;
    }
    return null;
  }
}

/// [stops] as places, in their order: a group's stops make one place, where
/// its first stop comes.
List<TripPlace> placesOfStops(List<Stop> stops, {Map<String, String> itemOfStop = const {}}) {
  final out = <TripPlace>[];
  final groups = <String, int>{};
  for (final stop in stops) {
    final group = stopGroup(stop);
    final item = itemOfStop[stop.id];
    final at = group == null ? null : groups[group];
    if (at != null) {
      final p = out[at];
      out[at] = TripPlace(
        id: p.id,
        name: p.name,
        group: group,
        stops: [...p.stops, stop],
        itemIds: [...p.itemIds, ?item],
      );
      continue;
    }
    if (group != null) groups[group] = out.length;
    out.add(TripPlace(id: stop.id, name: group ?? stop.name, group: group, stops: [stop], itemIds: [?item]));
  }
  return out;
}

/// The Places tab's view of [view]: each day's places in the day's order,
/// then the ones on no day, by name.
TripPlacesView buildTripPlacesView(PlannerView view) => TripPlacesView(
      days: [
        for (final d in view.days)
          PlacesSection(
            day: d,
            places: placesOfStops(
              [for (final it in d.items) it.stop],
              itemOfStop: {for (final it in d.items) it.stop.id: it.item.id},
            ),
          ),
      ],
      unsorted: PlacesSection(day: null, places: placesOfStops(view.backlog)),
    );

/// The day's own name, or null when it has none.
String? dayTitleOf(PlannerDay day) {
  final t = day.day.title?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Where a search finds [query] in a place: its name, its spots' notes, its
/// frames' episodes or notes. Case doesn't matter.
class PlaceMatch {
  final bool name;
  final List<String> spots;
  final List<NewReferenceImage> frames;

  const PlaceMatch({required this.name, required this.spots, required this.frames});

  bool get any => name || spots.isNotEmpty || frames.isNotEmpty;
}

PlaceMatch matchPlace(TripPlace place, PlaceContent content, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const PlaceMatch(name: false, spots: [], frames: []);
  bool has(String? s) => s != null && s.toLowerCase().contains(q);
  return PlaceMatch(
    name: has(place.name) || place.stops.any((s) => has(s.name)),
    spots: [
      for (final s in content.spots)
        if (s.frames.any((f) => has(f.note))) s.label,
    ],
    frames: [
      for (final f in content.frames)
        if (has(f.episode)) f,
    ],
  );
}

/// Where [place] goes when it moves one up or down its day ([by] = -1 or
/// 1) among [places]: before the first item of the place it then comes
/// before, or at the end of the day when `before` is null. Null when it
/// can't move that way.
({String? before})? reorderTarget(List<TripPlace> places, TripPlace place, int by) {
  final i = places.indexWhere((p) => p.id == place.id);
  final j = i + by;
  if (i < 0 || j < 0 || j >= places.length) return null;
  if (by < 0) return (before: places[j].itemIds.firstOrNull);
  return (before: j + 1 < places.length ? places[j + 1].itemIds.firstOrNull : null);
}
