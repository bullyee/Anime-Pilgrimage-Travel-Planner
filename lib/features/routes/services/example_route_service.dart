import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../planner/models/planner_view.dart';
import '../../trip/models/trip_places_view.dart';
import '../../trip/repositories/trip_repository.dart';
import '../models/example_route.dart';

/// Hosts whose pictures a route may show: Anitabi's, which its licence lets
/// anyone share with the credit. Any other picture (a user's own frame, a
/// Google Drive link) stays off a route, and the frame keeps only its spot.
const routeImageHosts = {'image.anitabi.cn', 'img-tc.anitabi.cn'};

bool isRouteImage(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  return uri != null && uri.scheme == 'https' && routeImageHosts.contains(uri.host);
}

/// A trip as an example route, for making one from our own trips (a
/// developer tool: the file then goes into `web/routes/` by hand).
///
/// Each day is a group (with its name, without its date), the places on no
/// day come last as an untitled group, and a group of stops not folded yet
/// is one place. Frames keep an Anitabi picture and where they're shot from;
/// frames with neither are left out. Dates, members, photos and notes never
/// come along.
class ExampleRouteExport {
  final ExampleRoute route;

  /// Frames left out: no picture a route may show, and no spot.
  final int skippedFrames;

  /// Frames kept without their picture (a user's own, or a Drive link).
  final int framesWithoutPicture;

  const ExampleRouteExport({required this.route, required this.skippedFrames, required this.framesWithoutPicture});
}

ExampleRouteExport exportExampleRoute({
  required Trip trip,
  required PlannerView view,
  required List<NewReferenceImage> frames,
  Map<String, String> animeOfLabel = const {},
  List<String> anime = const [],
  DateTime? now,
}) {
  final places = buildTripPlacesView(view);
  final framesByStop = <String, List<NewReferenceImage>>{};
  for (final f in frames) {
    if (f.stopId case final id?) (framesByStop[id] ??= []).add(f);
  }
  var skipped = 0;
  var unpictured = 0;

  RoutePlace placeOf(TripPlace p) {
    final stop = p.stop;
    final out = <RouteFrame>[];
    for (final s in p.stops) {
      for (final f in framesByStop[s.id] ?? const <NewReferenceImage>[]) {
        final image = isRouteImage(f.remoteUrl) ? f.remoteUrl : null;
        final placed = f.lat != null && f.lng != null;
        final shot = placed || f.note != null
            ? RouteShot(lat: f.lat ?? s.lat, lng: f.lng ?? s.lng, heading: f.heading, note: f.note)
            : null;
        if (image == null && shot == null) {
          skipped++;
          continue;
        }
        if (image == null) unpictured++;
        out.add(RouteFrame(
          image: image,
          anime: f.animeLabelId == null ? null : animeOfLabel[f.animeLabelId],
          episode: f.episode,
          seconds: f.timestampS,
          shot: shot,
          source: f.source,
          sourceUrl: f.sourceUrl,
        ));
      }
    }
    return RoutePlace(name: p.group ?? stop.name, lat: stop.lat, lng: stop.lng, frames: out);
  }

  final groups = <RouteGroup>[
    for (final s in places.days)
      if (s.places.isNotEmpty) RouteGroup(title: s.day == null ? null : dayTitleOf(s.day!), places: [for (final p in s.places) placeOf(p)]),
    if (places.unsorted.places.isNotEmpty) RouteGroup(places: [for (final p in places.unsorted.places) placeOf(p)]),
  ];
  final date = (now ?? DateTime.now()).toUtc();
  final route = ExampleRoute(
    id: exampleRouteIdOf(trip.title),
    title: trip.title,
    description: trip.description,
    anime: anime,
    updated: '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    groups: groups,
    credits: const [RouteCredit.anitabi],
  );
  return ExampleRouteExport(route: route, skippedFrames: skipped, framesWithoutPicture: unpictured);
}

/// A route id from a title: its Latin letters and digits, or `route` when
/// it has none (a Chinese title); rename the file's id by hand.
String exampleRouteIdOf(String title) {
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final cut = slug.length > maxExampleRouteIdLength ? slug.substring(0, maxExampleRouteIdLength).replaceAll(RegExp(r'-+$'), '') : slug;
  return cut.isEmpty ? 'route' : cut;
}

/// Copies [route] into a new private trip of [ownerId]'s: a day per group,
/// named like it and without a date, each place a trip-only spot on its
/// day, with its frames and where they're shot from. Returns the new trip.
///
/// The places aren't added to the library; the trip's place pages offer
/// that, as for any trip-only spot.
Future<Trip> copyExampleRoute({
  required AppDatabase db,
  required TripRepository repo,
  required ExampleRoute route,
  required String ownerId,
}) {
  const uuid = Uuid();
  return db.transaction(() async {
    final groups = route.groups.where((g) => g.places.isNotEmpty).toList();
    final description = route.description;
    final trip = await repo.createTrip(
      title: route.title,
      description: description != null && description.length > 500 ? description.substring(0, 500) : description,
      ownerId: ownerId,
      dayCount: groups.isEmpty ? 1 : groups.length,
    );
    final days = await repo.getDaysForTrip(trip.id);
    for (var i = 0; i < groups.length && i < days.length; i++) {
      final group = groups[i];
      if (group.title != null) await repo.updateDayBlock(TripDaysCompanion(id: Value(days[i].id), title: Value(group.title)));
      for (final place in group.places) {
        final stop = await repo.createTripOnlySpot(
          tripId: trip.id,
          name: place.name,
          lat: place.lat,
          lng: place.lng,
          addedBy: ownerId,
          accessTips: place.about,
        );
        for (final f in place.frames) {
          await db.into(db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
                id: uuid.v4(),
                stopId: Value(stop.id),
                remoteUrl: Value(f.image),
                episode: Value(f.episode),
                timestampS: Value(f.seconds),
                source: Value(f.source),
                sourceUrl: Value(f.sourceUrl),
                lat: Value(f.shot?.lat),
                lng: Value(f.shot?.lng),
                note: Value(f.shot?.note),
                heading: Value(f.shot?.heading),
              ));
        }
        await repo.scheduleStop(tripId: trip.id, stopId: stop.id, dayId: days[i].id);
      }
    }
    return trip;
  });
}
