import '../../../core/database/database.dart';

/// The label kinds, in the order the library shows them.
const labelKinds = ['anime', 'tag', 'region'];

String labelKindTitle(String kind) => switch (kind) {
      'anime' => 'Anime',
      'tag' => 'Tags',
      'region' => 'Regions',
      _ => kind,
    };

/// A place in the library, with its labels and the trips it is a stop in.
class LibraryEntry {
  final Place place;
  final List<Label> labels;
  final Set<String> tripIds;

  const LibraryEntry({required this.place, required this.labels, required this.tripIds});

  bool get isSaved => place.visibility == 'saved';

  Iterable<Label> labelsOf(String kind) => labels.where((l) => l.kind == kind);
}

/// What the library is narrowed down to.
class LibraryFilter {
  final String query;

  /// Picked labels. A place needs one of the picked labels of each kind that
  /// has picks: any of the picked anime, and any of the picked tags.
  final Set<String> labelIds;

  /// Whether places that only back a trip's stops are listed too.
  final bool includeTripOnly;

  const LibraryFilter({this.query = '', this.labelIds = const {}, this.includeTripOnly = false});

  bool get narrows => query.trim().isNotEmpty || labelIds.isNotEmpty;

  LibraryFilter copyWith({String? query, Set<String>? labelIds, bool? includeTripOnly}) => LibraryFilter(
        query: query ?? this.query,
        labelIds: labelIds ?? this.labelIds,
        includeTripOnly: includeTripOnly ?? this.includeTripOnly,
      );
}

/// Joins places with their labels and the trips that use them, sorted by name.
List<LibraryEntry> buildLibraryEntries({
  required List<Place> places,
  required List<Label> labels,
  required List<PlaceLabel> links,
  required Iterable<(String placeKey, String tripId)> stops,
}) {
  final labelsById = {for (final l in labels) l.id: l};
  final labelsByPlace = <String, List<Label>>{};
  for (final link in links) {
    final label = labelsById[link.labelId];
    if (label != null) labelsByPlace.putIfAbsent(link.placeKey, () => []).add(label);
  }
  final tripsByPlace = <String, Set<String>>{};
  for (final (placeKey, tripId) in stops) {
    tripsByPlace.putIfAbsent(placeKey, () => {}).add(tripId);
  }
  final entries = [
    for (final p in places)
      LibraryEntry(
        place: p,
        labels: (labelsByPlace[p.placeKey] ?? [])..sort((a, b) => _labelOrder(a).compareTo(_labelOrder(b))),
        tripIds: tripsByPlace[p.placeKey] ?? const {},
      ),
  ]..sort((a, b) => a.place.name.toLowerCase().compareTo(b.place.name.toLowerCase()));
  return entries;
}

String _labelOrder(Label l) => '${labelKinds.indexOf(l.kind)}${l.name.toLowerCase()}';

/// The entries [filter] lets through. [labels] resolves picked label ids to
/// their kinds.
List<LibraryEntry> filterLibrary(List<LibraryEntry> entries, LibraryFilter filter, List<Label> labels) {
  final kindOf = {for (final l in labels) l.id: l.kind};
  final pickedByKind = <String, Set<String>>{};
  for (final id in filter.labelIds) {
    final kind = kindOf[id];
    if (kind != null) pickedByKind.putIfAbsent(kind, () => {}).add(id);
  }
  final q = filter.query.trim().toLowerCase();
  return [
    for (final e in entries)
      if ((e.isSaved || filter.includeTripOnly) &&
          pickedByKind.values.every((picked) => e.labels.any((l) => picked.contains(l.id))) &&
          (q.isEmpty ||
              e.place.name.toLowerCase().contains(q) ||
              (e.place.address?.toLowerCase().contains(q) ?? false) ||
              e.labels.any((l) => l.name.toLowerCase().contains(q))))
        e,
  ];
}
