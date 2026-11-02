import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/schedule_logic.dart' show normalizeDateOnly;
import '../../trip/models/trip_summary.dart';

/// The trip a photo of [placeKey] taken at [takenAt] belongs to: a live trip
/// with a stop at the place whose dated days include that day. When several
/// do, the one that started last wins. Null when none does, or when the
/// trips that use the place have no dates yet.
///
/// Photos are personal, so this only decides which trip the place page
/// groups a photo under; nothing is shared.
Future<String?> tripForPhoto(AppDatabase db, String placeKey, DateTime takenAt) async {
  final query = db.select(db.trips).join([innerJoin(db.stops, db.stops.tripId.equalsExp(db.trips.id))])
    ..where(db.stops.placeKey.equals(placeKey) & db.stops.deletedAt.isNull() & db.trips.deletedAt.isNull());
  final trips = {for (final row in await query.get()) row.readTable(db.trips).id: row.readTable(db.trips)};
  // The day as the trip's dates are kept: the calendar date at UTC midnight.
  final day = normalizeDateOnly(takenAt);
  String? best;
  DateTime? bestStart;
  for (final trip in trips.values) {
    if (trip.startDate == null) continue;
    final days = await (db.select(db.tripDays)
          ..where((d) => d.tripId.equals(trip.id) & d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm.asc(d.sortKey)]))
        .get();
    // Without day blocks, the dates follow from the start date and day count.
    final summary = TripSummary.from(trip: trip, days: days.isEmpty ? null : days, stopCount: 0, now: takenAt);
    final first = summary.firstDate;
    final last = summary.lastDate;
    if (first == null || last == null || day.isBefore(first) || day.isAfter(last)) continue;
    if (bestStart == null || first.isAfter(bestStart)) {
      best = trip.id;
      bestStart = first;
    }
  }
  return best;
}
