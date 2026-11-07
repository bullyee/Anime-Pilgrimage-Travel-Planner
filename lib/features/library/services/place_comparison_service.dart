import 'dart:math' as math;
import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../trip/repositories/trip_repository.dart';
import '../models/place_diff.dart';
import '../repositories/place_repository.dart';
import 'anitabi_import.dart';

/// Service that computes differences across the three versions of a place:
/// 1. Anitabi community source ([AnitabiSpot])
/// 2. User's personal library ([Place])
/// 3. Collaborative trip itinerary ([Stop])
///
/// Also provides atomic resolution methods to update or save changes with
/// zero data loss and entity-scoped isolation.
class PlaceComparisonService {
  final AppDatabase _db;
  final PlaceRepository _placeRepo;
  final TripRepository _tripRepo;

  PlaceComparisonService({
    required AppDatabase db,
    required PlaceRepository placeRepo,
    required TripRepository tripRepo,
  })  : _db = db,
        _placeRepo = placeRepo,
        _tripRepo = tripRepo;

  // ==========================================================================
  // Geodesic Distance & Bearing Calculations
  // ==========================================================================

  /// Minimum distance threshold in meters before a coordinate change is considered
  /// significant (filters out minor GPS jitter and truncation).
  static const double distanceThresholdMeters = 15.0;

  /// Calculates geodesic distance between two points in meters using Haversine formula.
  static double calculateDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Calculates 8-point compass direction from point 1 to point 2 (N, NE, E, SE, S, SW, W, NW).
  static String calculateCompassDirection(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2 * math.pi / 180.0);
    final x = math.cos(lat1 * math.pi / 180.0) * math.sin(lat2 * math.pi / 180.0) -
        math.sin(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.cos(dLng);
    var bearing = math.atan2(y, x) * 180.0 / math.pi;
    bearing = (bearing + 360.0) % 360.0;

    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) ~/ 45) % 8;
    return directions[index];
  }

  /// Human-friendly distance summary (e.g., "Moved 120 m SE" or "Moved 1.2 km N").
  static String formatDistanceDifference(double distanceMeters, String direction) {
    if (distanceMeters < 1000) {
      return 'Moved ${distanceMeters.round()} m $direction';
    } else {
      return 'Moved ${(distanceMeters / 1000).toStringAsFixed(1)} km $direction';
    }
  }

  // ==========================================================================
  // Core Comparison Logic
  // ==========================================================================

  /// Compares a personal library [Place] with incoming [AnitabiSpot] updates.
  PlaceDiff? comparePlaceWithAnitabi(Place place, AnitabiSpot spot) {
    final diffs = <PlaceFieldDiff>[];

    // 1. Name
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

    // 2. Location
    if (spot.hasLocation) {
      final dist = calculateDistanceMeters(
        place.lat,
        place.lng,
        spot.lat!,
        spot.lng!,
      );
      if (dist >= distanceThresholdMeters) {
        final dir = calculateCompassDirection(
          place.lat,
          place.lng,
          spot.lat!,
          spot.lng!,
        );
        diffs.add(PlaceFieldDiff(
          field: PlaceFieldType.location,
          fieldLabel: 'Location',
          localValue: '${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)}',
          remoteValue: '${spot.lat!.toStringAsFixed(6)}, ${spot.lng!.toStringAsFixed(6)}',
          changeSummary: formatDistanceDifference(dist, dir),
          distanceMeters: dist,
          direction: dir,
        ));
      }
    }

    // 3. Description / Note
    final spotNote = spot.note?.trim();
    final localDesc = place.description?.trim();
    if (spotNote != null && spotNote.isNotEmpty && spotNote != localDesc) {
      diffs.add(PlaceFieldDiff(
        field: PlaceFieldType.description,
        fieldLabel: 'Description',
        localValue: localDesc,
        remoteValue: spotNote,
        changeSummary: 'Description updated on Anitabi',
      ));
    }

    // 4. Source URL
    final spotOriginUrl = spot.originUrl?.trim();
    final localSourceUrl = place.sourceUrl?.trim();
    if (spotOriginUrl != null &&
        spotOriginUrl.isNotEmpty &&
        spotOriginUrl != localSourceUrl) {
      diffs.add(PlaceFieldDiff(
        field: PlaceFieldType.sourceUrl,
        fieldLabel: 'Source URL',
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

  /// Compares a personal library [Place] with a trip [Stop].
  PlaceDiff? comparePlaceWithStop(Place place, Stop stop) {
    final diffs = <PlaceFieldDiff>[];

    // 1. Name
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

    // 2. Location
    final dist = calculateDistanceMeters(
      place.lat,
      place.lng,
      stop.lat,
      stop.lng,
    );
    if (dist >= distanceThresholdMeters) {
      final dir = calculateCompassDirection(
        place.lat,
        place.lng,
        stop.lat,
        stop.lng,
      );
      diffs.add(PlaceFieldDiff(
        field: PlaceFieldType.location,
        fieldLabel: 'Location',
        localValue: '${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)}',
        remoteValue: '${stop.lat.toStringAsFixed(6)}, ${stop.lng.toStringAsFixed(6)}',
        changeSummary: formatDistanceDifference(dist, dir),
        distanceMeters: dist,
        direction: dir,
      ));
    }

    // 3. Description
    _compareText(
      diffs: diffs,
      field: PlaceFieldType.description,
      fieldLabel: 'Description',
      localVal: place.description,
      remoteVal: stop.description,
    );

    // 4. Address
    _compareText(
      diffs: diffs,
      field: PlaceFieldType.address,
      fieldLabel: 'Address',
      localVal: place.address,
      remoteVal: stop.address,
    );

    // 5. Business Hours
    _compareText(
      diffs: diffs,
      field: PlaceFieldType.businessHours,
      fieldLabel: 'Business Hours',
      localVal: place.businessHours,
      remoteVal: stop.businessHours,
    );

    // 6. Contact Info
    _compareText(
      diffs: diffs,
      field: PlaceFieldType.contactInfo,
      fieldLabel: 'Contact Info',
      localVal: place.contactInfo,
      remoteVal: stop.contactInfo,
    );

    // 7. Access Tips
    _compareText(
      diffs: diffs,
      field: PlaceFieldType.accessTips,
      fieldLabel: 'Access Tips',
      localVal: place.accessTips,
      remoteVal: stop.accessTips,
    );

    // 8. Links
    _compareText(
      diffs: diffs,
      field: PlaceFieldType.links,
      fieldLabel: 'Links',
      localVal: place.links,
      remoteVal: stop.links,
    );

    // 9. Source URL
    _compareText(
      diffs: diffs,
      field: PlaceFieldType.sourceUrl,
      fieldLabel: 'Source URL',
      localVal: place.sourceUrl,
      remoteVal: stop.sourceUrl,
    );

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

  void _compareText({
    required List<PlaceFieldDiff> diffs,
    required PlaceFieldType field,
    required String fieldLabel,
    required String? localVal,
    required String? remoteVal,
  }) {
    final l = (localVal != null && localVal.trim().isNotEmpty) ? localVal.trim() : null;
    final r = (remoteVal != null && remoteVal.trim().isNotEmpty) ? remoteVal.trim() : null;
    if (l != r) {
      diffs.add(PlaceFieldDiff(
        field: field,
        fieldLabel: fieldLabel,
        localValue: l,
        remoteValue: r,
        changeSummary: '$fieldLabel differs',
      ));
    }
  }

  /// Compares all stops of a trip against the local personal library.
  Future<TripLibraryDiffSummary> compareTripWithLibrary(String tripId) async {
    final stops = await _tripRepo.getStopsForTrip(tripId);
    if (stops.isEmpty) {
      return TripLibraryDiffSummary(
        tripId: tripId,
        missingFromLibrary: const [],
        differingStops: const [],
        identicalStopIds: const [],
      );
    }

    final placeKeys = stops.map((s) => s.placeKey).toSet().toList();
    final placesQuery = _db.select(_db.places)
      ..where((tbl) => tbl.placeKey.isIn(placeKeys));
    final existingPlaces = await placesQuery.get();
    final placeMap = {for (final p in existingPlaces) p.placeKey: p};

    final missing = <Stop>[];
    final differing = <PlaceDiff>[];
    final identical = <String>[];

    for (final stop in stops) {
      final place = placeMap[stop.placeKey];
      if (place == null || place.visibility != 'saved') {
        missing.add(stop);
      } else {
        final diff = comparePlaceWithStop(place, stop);
        if (diff != null && diff.hasDifferences) {
          differing.add(diff);
        } else {
          identical.add(stop.id);
        }
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
  // Resolution & Mutation Methods
  // ==========================================================================

  /// Saves a single [Stop] from a trip into the user's personal library.
  /// If it already exists as `trip_only`, it is promoted to `saved`.
  /// Associated reference images are also preserved.
  Future<Place> saveStopToLibrary(Stop stop) async {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.places)
            ..where((tbl) => tbl.placeKey.equals(stop.placeKey)))
          .getSingleOrNull();

      if (existing != null) {
        if (existing.visibility != 'saved') {
          await (_db.update(_db.places)
                ..where((tbl) => tbl.placeKey.equals(stop.placeKey)))
              .write(
            const PlacesCompanion(visibility: Value('saved')),
          );
          return (await (_db.select(_db.places)
                ..where((tbl) => tbl.placeKey.equals(stop.placeKey)))
              .getSingle());
        }
        return existing;
      }

      final now = DateTime.now();
      final newPlace = PlacesCompanion.insert(
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
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await _db.into(_db.places).insert(newPlace);

      // Copy reference images associated with stop if personal place has none
      final stopRefImages = await (_db.select(_db.newReferenceImages)
            ..where((tbl) => tbl.placeKey.equals(stop.placeKey)))
          .get();

      for (final refImg in stopRefImages) {
        final existingRef = await (_db.select(_db.newReferenceImages)
              ..where((tbl) => tbl.id.equals(refImg.id)))
            .getSingleOrNull();
        if (existingRef == null) {
          await _db.into(_db.newReferenceImages).insert(
                refImg.toCompanion(true),
              );
        }
      }

      return (await (_db.select(_db.places)
            ..where((tbl) => tbl.placeKey.equals(stop.placeKey)))
          .getSingle());
    });
  }

  /// Batch imports all stops from a trip into the user's personal library.
  /// Any stops missing from the library are created as `saved`.
  /// Any stops that were `trip_only` are promoted to `saved`.
  Future<BatchSaveResult> saveAllTripStopsToLibrary(String tripId) async {
    final stops = await _tripRepo.getStopsForTrip(tripId);
    if (stops.isEmpty) {
      return const BatchSaveResult(
        newlyCreatedPlacesCount: 0,
        promotedTripOnlyPlacesCount: 0,
        savedPlaceKeys: [],
      );
    }

    return _db.transaction(() async {
      final placeKeys = stops.map((s) => s.placeKey).toSet().toList();
      final existingPlaces = await (_db.select(_db.places)
            ..where((tbl) => tbl.placeKey.isIn(placeKeys)))
          .get();

      final existingMap = {for (final p in existingPlaces) p.placeKey: p};

      var newlyCreated = 0;
      var promoted = 0;
      final savedKeys = <String>[];

      for (final stop in stops) {
        final existing = existingMap[stop.placeKey];
        if (existing == null) {
          final now = DateTime.now();
          await _db.into(_db.places).insert(
                PlacesCompanion.insert(
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
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
          newlyCreated++;
          savedKeys.add(stop.placeKey);
          existingMap[stop.placeKey] = await (_db.select(_db.places)
                ..where((tbl) => tbl.placeKey.equals(stop.placeKey)))
              .getSingle();
        } else if (existing.visibility != 'saved') {
          await (_db.update(_db.places)
                ..where((tbl) => tbl.placeKey.equals(stop.placeKey)))
              .write(
            const PlacesCompanion(visibility: Value('saved')),
          );
          promoted++;
          savedKeys.add(stop.placeKey);
        }
      }

      return BatchSaveResult(
        newlyCreatedPlacesCount: newlyCreated,
        promotedTripOnlyPlacesCount: promoted,
        savedPlaceKeys: savedKeys,
      );
    });
  }

  /// Updates a personal [Place] in the library using values from a [Stop].
  /// [fieldsToUpdate] specifies which fields to overwrite. If null, updates all matching facts.
  /// Preserves `privateNote`, `visibility`, and `createdAt`.
  Future<void> applyStopToPlace(
    String placeKey,
    Stop stop, {
    List<PlaceFieldType>? fieldsToUpdate,
  }) async {
    final fields = fieldsToUpdate ?? PlaceFieldType.values;
    final now = DateTime.now();

    final companion = PlacesCompanion(
      name: fields.contains(PlaceFieldType.name) ? Value(stop.name) : const Value.absent(),
      lat: fields.contains(PlaceFieldType.location) ? Value(stop.lat) : const Value.absent(),
      lng: fields.contains(PlaceFieldType.location) ? Value(stop.lng) : const Value.absent(),
      description: fields.contains(PlaceFieldType.description)
          ? Value(stop.description)
          : const Value.absent(),
      address: fields.contains(PlaceFieldType.address)
          ? Value(stop.address)
          : const Value.absent(),
      businessHours: fields.contains(PlaceFieldType.businessHours)
          ? Value(stop.businessHours)
          : const Value.absent(),
      contactInfo: fields.contains(PlaceFieldType.contactInfo)
          ? Value(stop.contactInfo)
          : const Value.absent(),
      accessTips: fields.contains(PlaceFieldType.accessTips)
          ? Value(stop.accessTips)
          : const Value.absent(),
      links: fields.contains(PlaceFieldType.links) ? Value(stop.links) : const Value.absent(),
      sourceUrl: fields.contains(PlaceFieldType.sourceUrl)
          ? Value(stop.sourceUrl)
          : const Value.absent(),
      updatedAt: Value(now),
    );

    await (_db.update(_db.places)..where((tbl) => tbl.placeKey.equals(placeKey)))
        .write(companion);
  }

  /// Updates a collaborative [Stop] using values from the personal [Place].
  /// Scoped by `tripId` and `stopId` to prevent cross-trip row hijacking (Rule 2).
  /// Sets `syncStatus = 1` and `updatedAt = now()` to trigger upstream sync.
  Future<void> applyPlaceToStop(
    String tripId,
    String stopId,
    Place place, {
    List<PlaceFieldType>? fieldsToUpdate,
    String? currentUserId,
  }) async {
    final fields = fieldsToUpdate ?? PlaceFieldType.values;
    final now = DateTime.now();

    final companion = StopsCompanion(
      name: fields.contains(PlaceFieldType.name) ? Value(place.name) : const Value.absent(),
      lat: fields.contains(PlaceFieldType.location) ? Value(place.lat) : const Value.absent(),
      lng: fields.contains(PlaceFieldType.location) ? Value(place.lng) : const Value.absent(),
      description: fields.contains(PlaceFieldType.description)
          ? Value(place.description)
          : const Value.absent(),
      address: fields.contains(PlaceFieldType.address)
          ? Value(place.address)
          : const Value.absent(),
      businessHours: fields.contains(PlaceFieldType.businessHours)
          ? Value(place.businessHours)
          : const Value.absent(),
      contactInfo: fields.contains(PlaceFieldType.contactInfo)
          ? Value(place.contactInfo)
          : const Value.absent(),
      accessTips: fields.contains(PlaceFieldType.accessTips)
          ? Value(place.accessTips)
          : const Value.absent(),
      links: fields.contains(PlaceFieldType.links) ? Value(place.links) : const Value.absent(),
      sourceUrl: fields.contains(PlaceFieldType.sourceUrl)
          ? Value(place.sourceUrl)
          : const Value.absent(),
      updatedAt: Value(now),
      updatedBy: currentUserId != null ? Value(currentUserId) : const Value.absent(),
      syncStatus: const Value(1), // Mark dirty for upstream sync
    );

    await (_db.update(_db.stops)
          ..where((tbl) => tbl.id.equals(stopId) & tbl.tripId.equals(tripId)))
        .write(companion);
  }

  /// Updates a personal [Place] using new data from [AnitabiSpot].
  Future<void> applyAnitabiToPlace(
    String placeKey,
    AnitabiSpot spot, {
    List<PlaceFieldType>? fieldsToUpdate,
  }) async {
    final fields = fieldsToUpdate ?? PlaceFieldType.values;
    final now = DateTime.now();

    final companion = PlacesCompanion(
      name: (fields.contains(PlaceFieldType.name) && spot.name.isNotEmpty)
          ? Value(spot.name)
          : const Value.absent(),
      lat: (fields.contains(PlaceFieldType.location) && spot.lat != null)
          ? Value(spot.lat!)
          : const Value.absent(),
      lng: (fields.contains(PlaceFieldType.location) && spot.lng != null)
          ? Value(spot.lng!)
          : const Value.absent(),
      description: (fields.contains(PlaceFieldType.description) && spot.note != null)
          ? Value(spot.note!)
          : const Value.absent(),
      sourceUrl: (fields.contains(PlaceFieldType.sourceUrl) && spot.originUrl != null)
          ? Value(spot.originUrl!)
          : const Value.absent(),
      updatedAt: Value(now),
    );

    await (_db.update(_db.places)..where((tbl) => tbl.placeKey.equals(placeKey)))
        .write(companion);
  }
}
