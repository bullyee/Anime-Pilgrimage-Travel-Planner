import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../trip/repositories/trip_repository.dart';
import '../models/place_diff.dart';
import '../repositories/place_repository.dart';
import 'anitabi_import.dart';

/// Compares the versions of a place that can drift apart:
/// 1. Anitabi's spot ([AnitabiSpot]), as cached on this device,
/// 2. the user's library place ([Place]),
/// 3. a trip's copy of it ([Stop]).
///
/// Comparing never writes. The apply methods write one side only, the side
/// the user is looking at, and only the fields they chose: the library and
/// trips never change each other by themselves.
class PlaceComparisonService {
  final AppDatabase _db;
  final PlaceRepository _placeRepo;
  final TripRepository _tripRepo;
  final Uuid _uuid;

  PlaceComparisonService({
    required AppDatabase db,
    required PlaceRepository placeRepo,
    required TripRepository tripRepo,
    Uuid? uuid,
  })  : _db = db,
        _placeRepo = placeRepo,
        _tripRepo = tripRepo,
        _uuid = uuid ?? const Uuid();

  // ==========================================================================
  // Distance and direction
  // ==========================================================================

  /// Moves shorter than this are GPS noise or rounding, not a moved spot.
  static const double distanceThresholdMeters = 15.0;

  /// Great-circle distance in meters (haversine).
  static double calculateDistanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// 8-point compass direction from point 1 to point 2.
  static String calculateCompassDirection(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2 * math.pi / 180.0);
    final x = math.cos(lat1 * math.pi / 180.0) * math.sin(lat2 * math.pi / 180.0) -
        math.sin(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) * math.cos(dLng);
    final bearing = (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return directions[((bearing + 22.5) ~/ 45) % 8];
  }

  /// "120 m" or "1.2 km".
  static String formatDistance(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

  /// "Moved 120 m SE" or "Moved 1.2 km N".
  static String formatDistanceDifference(double distanceMeters, String direction) =>
      'Moved ${formatDistance(distanceMeters)} $direction';

  // ==========================================================================
  // Comparing
  // ==========================================================================

  /// What Anitabi's [spot] says differently from the library [place]: the
  /// local side is the place, the remote side Anitabi. Only fields the import
  /// fills from Anitabi are compared (name, location, description from the
  /// contributor's note, source link), and only when Anitabi has a value.
  PlaceDiff? comparePlaceWithAnitabi(Place place, AnitabiSpot spot) {
    final diffs = <PlaceFieldDiff>[];

    final spotName = spot.name.trim();
    if (spotName.isNotEmpty && spotName != place.name.trim()) {
      diffs.add(PlaceFieldDiff(
        field: PlaceFieldType.name,
        fieldLabel: 'Name',
        localValue: place.name,
        remoteValue: spotName,
        changeSummary: 'Name: "${place.name}" → "$spotName"',
      ));
    }

    if (spot.hasLocation) {
      final location = _locationDiff(place.lat, place.lng, spot.lat!, spot.lng!);
      if (location != null) diffs.add(location);
    }

    final spotNote = _clean(spot.note);
    final localDesc = _clean(place.description);
    if (spotNote != null && spotNote != localDesc) {
      diffs.add(PlaceFieldDiff(
        field: PlaceFieldType.description,
        fieldLabel: 'Description',
        localValue: localDesc,
        remoteValue: spotNote,
        changeSummary: 'Description updated on Anitabi',
      ));
    }

    final spotOriginUrl = _clean(spot.originUrl);
    final localSourceUrl = _clean(place.sourceUrl);
    if (spotOriginUrl != null && spotOriginUrl != localSourceUrl) {
      diffs.add(PlaceFieldDiff(
        field: PlaceFieldType.sourceUrl,
        fieldLabel: 'Source link',
        localValue: localSourceUrl,
        remoteValue: spotOriginUrl,
        changeSummary: 'Source link updated',
      ));
    }

    if (diffs.isEmpty) return null;
    return PlaceDiff(
      placeKey: place.placeKey,
      localName: place.name,
      remoteName: spot.name,
      targetEntityId: spot.id,
      targetSource: 'anitabi',
      differences: diffs,
    );
  }

  /// What a trip's [stop] says differently from the library [place]: the
  /// local side is the place, the remote side the stop. Notes aren't
  /// compared: the trip note and My note are different things on purpose.
  PlaceDiff? comparePlaceWithStop(Place place, Stop stop) {
    final diffs = <PlaceFieldDiff>[];

    final stopName = stop.name.trim();
    if (stopName.isNotEmpty && stopName != place.name.trim()) {
      diffs.add(PlaceFieldDiff(
        field: PlaceFieldType.name,
        fieldLabel: 'Name',
        localValue: place.name,
        remoteValue: stopName,
        changeSummary: 'Name: "${place.name}" → "$stopName"',
      ));
    }

    final location = _locationDiff(place.lat, place.lng, stop.lat, stop.lng);
    if (location != null) diffs.add(location);

    void text(PlaceFieldType field, String label, String? local, String? remote) {
      final l = _clean(local);
      final r = _clean(remote);
      if (l == r) return;
      diffs.add(PlaceFieldDiff(
        field: field,
        fieldLabel: label,
        localValue: l,
        remoteValue: r,
        changeSummary: '$label differs',
      ));
    }

    text(PlaceFieldType.description, 'Description', place.description, stop.description);
    text(PlaceFieldType.address, 'Address', place.address, stop.address);
    text(PlaceFieldType.businessHours, 'Opening hours', place.businessHours, stop.businessHours);
    text(PlaceFieldType.contactInfo, 'Contact', place.contactInfo, stop.contactInfo);
    text(PlaceFieldType.accessTips, 'Getting there', place.accessTips, stop.accessTips);
    text(PlaceFieldType.links, 'Links', place.links, stop.links);
    text(PlaceFieldType.sourceUrl, 'Source link', place.sourceUrl, stop.sourceUrl);

    if (diffs.isEmpty) return null;
    return PlaceDiff(
      placeKey: place.placeKey,
      localName: place.name,
      remoteName: stop.name,
      targetEntityId: stop.id,
      targetSource: 'stop',
      differences: diffs,
    );
  }

  PlaceFieldDiff? _locationDiff(double lat1, double lng1, double lat2, double lng2) {
    final dist = calculateDistanceMeters(lat1, lng1, lat2, lng2);
    if (dist < distanceThresholdMeters) return null;
    final dir = calculateCompassDirection(lat1, lng1, lat2, lng2);
    return PlaceFieldDiff(
      field: PlaceFieldType.location,
      fieldLabel: 'Location',
      localValue: '${lat1.toStringAsFixed(6)}, ${lng1.toStringAsFixed(6)}',
      remoteValue: '${lat2.toStringAsFixed(6)}, ${lng2.toStringAsFixed(6)}',
      changeSummary: formatDistanceDifference(dist, dir),
      distanceMeters: dist,
      direction: dir,
    );
  }

  static String? _clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  /// Sorts a trip's stops into those not in the library (no place, or only
  /// a hidden `trip_only` one), those whose facts differ from the library,
  /// and those that match.
  Future<TripLibraryDiffSummary> compareTripWithLibrary(String tripId) async {
    final stops = await _tripRepo.getStopsForTrip(tripId);
    if (stops.isEmpty) {
      return TripLibraryDiffSummary(tripId: tripId, missingFromLibrary: const [], differingStops: const [], identicalStopIds: const []);
    }
    final placeKeys = stops.map((s) => s.placeKey).toSet().toList();
    final existing = await (_db.select(_db.places)..where((tbl) => tbl.placeKey.isIn(placeKeys))).get();
    final placeMap = {for (final p in existing) p.placeKey: p};

    final missing = <Stop>[];
    final differing = <PlaceDiff>[];
    final identical = <String>[];
    for (final stop in stops) {
      final place = placeMap[stop.placeKey];
      if (place == null || place.visibility != 'saved') {
        missing.add(stop);
      } else if (comparePlaceWithStop(place, stop) case final diff?) {
        differing.add(diff);
      } else {
        identical.add(stop.id);
      }
    }
    return TripLibraryDiffSummary(
      tripId: tripId,
      missingFromLibrary: missing,
      differingStops: differing,
      identicalStopIds: identical,
    );
  }

  // ==========================================================================
  // Saving a trip's stops to the library
  // ==========================================================================

  /// Puts [stop]'s place in the library, so it gets a My note, visits and
  /// photos of its own, as when someone joined a trip and wants to keep its
  /// spots. A new place takes the stop's facts, frames and labels. A hidden
  /// `trip_only` place (made when shooting at the stop, or for a new spot) is
  /// saved, and its empty facts are filled from the stop. A place already in
  /// the library is left as it is. Returns true when the library changed.
  Future<bool> saveStopToLibrary(Stop stop) => _db.transaction(() => _saveStop(stop));

  /// [saveStopToLibrary] for every stop of [tripId] that isn't in the
  /// library yet. Stops of one place count once.
  Future<BatchSaveResult> saveAllTripStopsToLibrary(String tripId) async {
    final stops = await _tripRepo.getStopsForTrip(tripId);
    return _db.transaction(() async {
      var created = 0;
      var promoted = 0;
      final saved = <String>[];
      for (final stop in stops) {
        if (saved.contains(stop.placeKey)) continue;
        final before = await _placeRepo.getPlace(stop.placeKey);
        if (before?.visibility == 'saved') continue;
        if (await _saveStop(stop)) {
          before == null ? created++ : promoted++;
          saved.add(stop.placeKey);
        }
      }
      return BatchSaveResult(newlyCreatedPlacesCount: created, promotedTripOnlyPlacesCount: promoted, savedPlaceKeys: saved);
    });
  }

  Future<bool> _saveStop(Stop stop) async {
    final existing = await _placeRepo.getPlace(stop.placeKey);
    if (existing != null && existing.visibility == 'saved') return false;

    if (existing == null) {
      await _db.into(_db.places).insert(PlacesCompanion.insert(
            placeKey: stop.placeKey,
            name: stop.name,
            lat: stop.lat,
            lng: stop.lng,
            description: Value(stop.description),
            address: Value(stop.address),
            businessHours: Value(stop.businessHours),
            contactInfo: Value(stop.contactInfo),
            accessTips: Value(stop.accessTips),
            links: Value(stop.links),
            coverLocalPath: Value(stop.coverLocalPath),
            coverRemoteUrl: Value(stop.coverRemoteUrl),
            source: Value(stop.source),
            sourceUrl: Value(stop.sourceUrl),
            visibility: const Value('saved'),
          ));
    } else {
      // A stub keeps what it has, and takes what it lacks from the stop.
      Value<String?> fill(String? have, String? from) => _clean(have) == null && _clean(from) != null ? Value(from) : const Value.absent();
      await _placeRepo.updatePlace(PlacesCompanion(
        placeKey: Value(stop.placeKey),
        visibility: const Value('saved'),
        description: fill(existing.description, stop.description),
        address: fill(existing.address, stop.address),
        businessHours: fill(existing.businessHours, stop.businessHours),
        contactInfo: fill(existing.contactInfo, stop.contactInfo),
        accessTips: fill(existing.accessTips, stop.accessTips),
        links: fill(existing.links, stop.links),
        coverLocalPath: fill(existing.coverLocalPath, stop.coverLocalPath),
        coverRemoteUrl: fill(existing.coverRemoteUrl, stop.coverRemoteUrl),
        source: fill(existing.source, stop.source),
        sourceUrl: fill(existing.sourceUrl, stop.sourceUrl),
      ));
    }

    // The stop's frames become the place's, unless the place has that image.
    final placeFrames = await (_db.select(_db.newReferenceImages)..where((t) => t.placeKey.equals(stop.placeKey))).get();
    bool has(NewReferenceImage f) => placeFrames.any((p) =>
        ((f.localPath?.isNotEmpty ?? false) && p.localPath == f.localPath) ||
        ((f.remoteUrl?.isNotEmpty ?? false) && p.remoteUrl == f.remoteUrl));
    final stopFrames = await (_db.select(_db.newReferenceImages)..where((t) => t.stopId.equals(stop.id))).get();
    for (final f in stopFrames) {
      if (has(f)) continue;
      await _db.into(_db.newReferenceImages).insert(NewReferenceImagesCompanion.insert(
            id: _uuid.v4(),
            placeKey: Value(stop.placeKey),
            stopId: const Value(null),
            localPath: Value(f.localPath),
            remoteUrl: Value(f.remoteUrl),
            animeLabelId: Value(f.animeLabelId),
            episode: Value(f.episode),
            timestampS: Value(f.timestampS),
            source: Value(f.source),
            sourceUrl: Value(f.sourceUrl),
            lat: Value(f.lat),
            lng: Value(f.lng),
            note: Value(f.note),
            heading: Value(f.heading),
          ));
    }

    for (final label in await _tripRepo.getLabelsForStop(stop.id)) {
      await _placeRepo.attachLabelToPlace(stop.placeKey, label.id);
    }
    return true;
  }

  // ==========================================================================
  // Applying one side's values to the other
  // ==========================================================================

  /// Writes the chosen [fields] of [stop] into the library place [placeKey].
  /// My note, visibility and everything else stay.
  Future<void> applyStopToPlace(String placeKey, Stop stop, {List<PlaceFieldType>? fieldsToUpdate}) {
    final f = fieldsToUpdate ?? PlaceFieldType.values;
    Value<T> pick<T>(PlaceFieldType field, T value) => f.contains(field) ? Value(value) : const Value.absent();
    return _placeRepo.updatePlace(PlacesCompanion(
      placeKey: Value(placeKey),
      name: pick(PlaceFieldType.name, stop.name),
      lat: pick(PlaceFieldType.location, stop.lat),
      lng: pick(PlaceFieldType.location, stop.lng),
      description: pick(PlaceFieldType.description, stop.description),
      address: pick(PlaceFieldType.address, stop.address),
      businessHours: pick(PlaceFieldType.businessHours, stop.businessHours),
      contactInfo: pick(PlaceFieldType.contactInfo, stop.contactInfo),
      accessTips: pick(PlaceFieldType.accessTips, stop.accessTips),
      links: pick(PlaceFieldType.links, stop.links),
      sourceUrl: pick(PlaceFieldType.sourceUrl, stop.sourceUrl),
    ));
  }

  /// Writes the chosen [fields] of the library [place] into stop [stopId]
  /// of [tripId], for everyone in the trip (it syncs like any stop edit).
  /// Does nothing when the stop isn't in that trip any more. Whether the user
  /// may edit the trip is the caller's check.
  Future<void> applyPlaceToStop(String tripId, String stopId, Place place, {List<PlaceFieldType>? fieldsToUpdate}) async {
    final stop = await _tripRepo.getStop(stopId);
    if (stop == null || stop.tripId != tripId || stop.deletedAt != null) return;
    final f = fieldsToUpdate ?? PlaceFieldType.values;
    Value<T> pick<T>(PlaceFieldType field, T value) => f.contains(field) ? Value(value) : const Value.absent();
    await _tripRepo.updateStop(StopsCompanion(
      id: Value(stopId),
      name: pick(PlaceFieldType.name, place.name),
      lat: pick(PlaceFieldType.location, place.lat),
      lng: pick(PlaceFieldType.location, place.lng),
      description: pick(PlaceFieldType.description, place.description),
      address: pick(PlaceFieldType.address, place.address),
      businessHours: pick(PlaceFieldType.businessHours, place.businessHours),
      contactInfo: pick(PlaceFieldType.contactInfo, place.contactInfo),
      accessTips: pick(PlaceFieldType.accessTips, place.accessTips),
      links: pick(PlaceFieldType.links, place.links),
      sourceUrl: pick(PlaceFieldType.sourceUrl, place.sourceUrl),
    ));
  }

  /// Writes the chosen [fields] of Anitabi's [spot] into the library place
  /// [placeKey]. Fields Anitabi has no value for are left alone.
  Future<void> applyAnitabiToPlace(String placeKey, AnitabiSpot spot, {List<PlaceFieldType>? fieldsToUpdate}) {
    final f = fieldsToUpdate ?? PlaceFieldType.values;
    final name = spot.name.trim();
    final moved = f.contains(PlaceFieldType.location) && spot.hasLocation;
    final note = _clean(spot.note);
    final originUrl = _clean(spot.originUrl);
    return _placeRepo.updatePlace(PlacesCompanion(
      placeKey: Value(placeKey),
      name: f.contains(PlaceFieldType.name) && name.isNotEmpty ? Value(name) : const Value.absent(),
      lat: moved ? Value(spot.lat!) : const Value.absent(),
      lng: moved ? Value(spot.lng!) : const Value.absent(),
      description: f.contains(PlaceFieldType.description) && note != null ? Value(note) : const Value.absent(),
      sourceUrl: f.contains(PlaceFieldType.sourceUrl) && originUrl != null ? Value(originUrl) : const Value.absent(),
    ));
  }
}
