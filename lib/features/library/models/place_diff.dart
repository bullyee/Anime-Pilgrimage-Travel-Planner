/// Supported field types for diff comparison between different versions of a place.
enum PlaceFieldType {
  name,
  location,
  description,
  address,
  businessHours,
  contactInfo,
  accessTips,
  links,
  sourceUrl,
}

/// Represents the diff between the local and remote values of a single field.
class PlaceFieldDiff {
  final PlaceFieldType field;
  final String fieldLabel;
  final String? localValue;
  final String? remoteValue;
  final String changeSummary;
  final double? distanceMeters;
  final String? direction;

  const PlaceFieldDiff({
    required this.field,
    required this.fieldLabel,
    required this.localValue,
    required this.remoteValue,
    required this.changeSummary,
    this.distanceMeters,
    this.direction,
  });

  @override
  String toString() =>
      'PlaceFieldDiff(field: $field, summary: $changeSummary, local: $localValue, remote: $remoteValue)';
}

/// Represents all differences for a single place across its versions
/// (e.g., Library Place vs Trip Stop, or Library Place vs Anitabi).
class PlaceDiff {
  final String placeKey;
  final String localName;
  final String remoteName;
  final String? targetEntityId;
  final String targetSource;
  final List<PlaceFieldDiff> differences;

  const PlaceDiff({
    required this.placeKey,
    required this.localName,
    required this.remoteName,
    this.targetEntityId,
    required this.targetSource,
    required this.differences,
  });

  bool get hasDifferences => differences.isNotEmpty;

  /// Returns true if the location specifically moved.
  bool get hasLocationMoved =>
      differences.any((d) => d.field == PlaceFieldType.location);

  /// Returns the location diff if present.
  PlaceFieldDiff? get locationDiff {
    for (final diff in differences) {
      if (diff.field == PlaceFieldType.location) return diff;
    }
    return null;
  }

  @override
  String toString() =>
      'PlaceDiff(placeKey: $placeKey, diffCount: ${differences.length}, source: $targetSource)';
}

/// Summary of differences between a trip's stops and the user's personal library.
class TripLibraryDiffSummary {
  final String tripId;

  /// Stops in the trip whose `placeKey` does not exist in the personal library.
  final List<dynamic> missingFromLibrary;

  /// Stops whose facts differ from the corresponding entry in the personal library.
  final List<PlaceDiff> differingStops;

  /// Stops that match the personal library exactly.
  final List<String> identicalStopIds;

  const TripLibraryDiffSummary({
    required this.tripId,
    required this.missingFromLibrary,
    required this.differingStops,
    required this.identicalStopIds,
  });

  int get totalStopsCount =>
      missingFromLibrary.length + differingStops.length + identicalStopIds.length;

  bool get hasDifferences =>
      missingFromLibrary.isNotEmpty || differingStops.isNotEmpty;

  @override
  String toString() =>
      'TripLibraryDiffSummary(tripId: $tripId, missing: ${missingFromLibrary.length}, differing: ${differingStops.length}, identical: ${identicalStopIds.length})';
}

/// Result of a batch save/import of trip stops into the personal library.
class BatchSaveResult {
  final int newlyCreatedPlacesCount;
  final int promotedTripOnlyPlacesCount;
  final List<String> savedPlaceKeys;

  const BatchSaveResult({
    required this.newlyCreatedPlacesCount,
    required this.promotedTripOnlyPlacesCount,
    required this.savedPlaceKeys,
  });

  int get totalAffected =>
      newlyCreatedPlacesCount + promotedTripOnlyPlacesCount;

  @override
  String toString() =>
      'BatchSaveResult(created: $newlyCreatedPlacesCount, promoted: $promotedTripOnlyPlacesCount, total: $totalAffected)';
}
