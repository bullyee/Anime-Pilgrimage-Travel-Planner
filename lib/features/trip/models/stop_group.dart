import '../../../core/database/database.dart';

/// The longest group name, in characters. The Firestore rules refuse a
/// longer `stops.area`, and with it the rest of the trip's upload.
const maxGroupNameLength = 100;

/// The group [stop] is in, or null when it's in none. A group is the stops of
/// a trip that share the same `area`, and the group's name is that `area`,
/// trimmed: one café can come into a trip as several stops, one per scene,
/// and grouping keeps them together as one slot of the plan.
String? stopGroup(Stop stop) {
  final area = stop.area?.trim();
  return area == null || area.isEmpty ? null : area;
}

/// "1 stop", "7 stops".
String stopCount(int n) => n == 1 ? '1 stop' : '$n stops';
