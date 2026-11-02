import 'package:latlong2/latlong.dart';

import '../../../core/database/database.dart';

/// A saved place that may be the same spot as one being added.
class DuplicateMatch {
  final Place place;
  final double meters;

  const DuplicateMatch(this.place, this.meters);
}

String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s\p{P}\p{S}]', unicode: true), '');

/// Whether two names are alike once case, spaces and punctuation are
/// ignored, or one contains the other ("Uji Bridge" and "Uji Bridge (east)").
bool similarNames(String a, String b) {
  final x = _normalize(a);
  final y = _normalize(b);
  return x.isNotEmpty && y.isNotEmpty && (x.contains(y) || y.contains(x));
}

/// The closest of [places] that is probably the spot named [name] at [at]:
/// within 50 m with a similar name, or within 15 m whatever its name.
/// Anitabi keeps one point per anime even at the same bridge, so a nearby
/// place with an unrelated name only counts when it is very close.
DuplicateMatch? likelyDuplicate(Iterable<Place> places, {required String name, required LatLng at}) {
  const distance = Distance();
  DuplicateMatch? best;
  for (final p in places) {
    final meters = distance.as(LengthUnit.Meter, at, LatLng(p.lat, p.lng));
    final match = meters <= 15 || (meters <= 50 && similarNames(name, p.name));
    if (match && (best == null || meters < best.meters)) best = DuplicateMatch(p, meters);
  }
  return best;
}
