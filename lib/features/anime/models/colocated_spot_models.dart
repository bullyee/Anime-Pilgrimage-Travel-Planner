/// A single pilgrimage spot / scene associated with a specific anime work.
class ColocatedSpotItem {
  final String spotId;
  final String? placeKey;
  final String name;
  final String animeTitle;
  final String? bangumiId;
  final double lat;
  final double lng;
  final String? coverUrl;
  final String? sceneDescription;
  final double? distanceToCentroidMeters;

  const ColocatedSpotItem({
    required this.spotId,
    this.placeKey,
    required this.name,
    required this.animeTitle,
    this.bangumiId,
    required this.lat,
    required this.lng,
    this.coverUrl,
    this.sceneDescription,
    this.distanceToCentroidMeters,
  });

  ColocatedSpotItem copyWith({
    String? spotId,
    String? placeKey,
    String? name,
    String? animeTitle,
    String? bangumiId,
    double? lat,
    double? lng,
    String? coverUrl,
    String? sceneDescription,
    double? distanceToCentroidMeters,
  }) {
    return ColocatedSpotItem(
      spotId: spotId ?? this.spotId,
      placeKey: placeKey ?? this.placeKey,
      name: name ?? this.name,
      animeTitle: animeTitle ?? this.animeTitle,
      bangumiId: bangumiId ?? this.bangumiId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      coverUrl: coverUrl ?? this.coverUrl,
      sceneDescription: sceneDescription ?? this.sceneDescription,
      distanceToCentroidMeters:
          distanceToCentroidMeters ?? this.distanceToCentroidMeters,
    );
  }

  @override
  String toString() =>
      'ColocatedSpotItem($spotId, name: $name, anime: $animeTitle, pos: ($lat, $lng))';
}

/// A cluster of spots that share the same physical location within a tight radius.
class ColocatedSpotGroup {
  final String id;
  final String primaryName;
  final double centroidLat;
  final double centroidLng;
  final List<ColocatedSpotItem> spots;
  final Set<String> animeTitles;
  final double maxDistanceMeters;
  final String? geohash;

  const ColocatedSpotGroup({
    required this.id,
    required this.primaryName,
    required this.centroidLat,
    required this.centroidLng,
    required this.spots,
    required this.animeTitles,
    required this.maxDistanceMeters,
    this.geohash,
  });

  /// The number of distinct anime works present at this physical landmark.
  int get animeCount => animeTitles.length;

  /// True if this location represents a shared landmark featured across 2 or more distinct anime.
  bool get isMultiAnime => animeTitles.length >= 2;

  /// Returns all spots in this hub belonging to a different anime than [targetAnime].
  List<ColocatedSpotItem> spotsFromOtherAnime(String targetAnime) {
    return spots.where((s) => s.animeTitle != targetAnime).toList();
  }

  @override
  String toString() =>
      'ColocatedSpotGroup($id, "$primaryName", anime: $animeCount, spots: ${spots.length})';
}

/// Comprehensive outcome of running co-located cross-anime discovery across a set of spots.
class CrossAnimeLinkResult {
  /// All co-located landmark groups that feature at least 2 different anime works.
  final List<ColocatedSpotGroup> hubs;

  /// All clustered groups regardless of anime diversity.
  final List<ColocatedSpotGroup> allGroups;

  /// Map from spotId to other scenes from different anime located at the same landmark.
  final Map<String, List<ColocatedSpotItem>> coLocatedMap;

  const CrossAnimeLinkResult({
    required this.hubs,
    required this.allGroups,
    required this.coLocatedMap,
  });

  /// Quick helper to retrieve cross-anime spots adjacent to [spotId].
  List<ColocatedSpotItem> crossAnimeSpotsFor(String spotId) =>
      coLocatedMap[spotId] ?? const [];
}
