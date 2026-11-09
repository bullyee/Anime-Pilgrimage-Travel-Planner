import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/schedule_logic.dart';
import '../../library/models/library_entry.dart';
import '../../trip/models/trip_summary.dart';
import '../../trip/providers/trip_list_providers.dart';

/// What Home's top card shows: today's day of a trip, the next trip, or
/// neither.
sealed class HomeFocus {
  const HomeFocus();
}

/// Today is a day of [trip]: the top card is today.
class HomeTripDay extends HomeFocus {
  final TripSummary trip;
  const HomeTripDay(this.trip);
}

/// No trip today; [trip] is the next one, or null when there is none.
class HomeNextTrip extends HomeFocus {
  final TripSummary? trip;
  const HomeNextTrip(this.trip);
}

/// Today's date, as Home sees it; tests replace it.
final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Picks what Home shows from [trips] on [now]: the trip happening today
/// (the one that started last when several are), else the soonest trip
/// still to come, else a trip with no dates yet (the newest).
HomeFocus pickHomeFocus(List<TripSummary> trips, DateTime now) {
  final today = normalizeDateOnly(now);
  bool covers(TripSummary t) =>
      t.firstDate != null && t.lastDate != null && !today.isBefore(t.firstDate!) && !today.isAfter(t.lastDate!);

  final ongoing = trips.where(covers).toList()..sort((a, b) => b.firstDate!.compareTo(a.firstDate!));
  if (ongoing.isNotEmpty) return HomeTripDay(ongoing.first);

  final coming = trips.where((t) => t.firstDate != null && t.firstDate!.isAfter(today)).toList()
    ..sort((a, b) => a.firstDate!.compareTo(b.firstDate!));
  if (coming.isNotEmpty) return HomeNextTrip(coming.first);

  final undated = trips.where((t) => t.firstDate == null).toList()
    ..sort((a, b) => b.trip.createdAt.compareTo(a.trip.createdAt));
  return HomeNextTrip(undated.firstOrNull);
}

final homeFocusProvider = Provider.autoDispose<AsyncValue<HomeFocus>>((ref) {
  final now = ref.watch(homeClockProvider)();
  return ref.watch(tripSummariesProvider).whenData((trips) => pickHomeFocus(trips, now));
});

/// Where the phone is, for Near you. [allowed] is false when location is
/// off or the app may not use it yet; Home never asks on its own, only when
/// the user taps to see what's near.
typedef HomeWhere = ({bool allowed, LatLng? at});

final homeWhereProvider = FutureProvider.autoDispose<HomeWhere>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return (allowed: false, at: null);
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
      return (allowed: false, at: null);
    }
    final position = await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
        );
    return (allowed: true, at: LatLng(position.latitude, position.longitude));
  } catch (_) {
    return (allowed: true, at: null);
  }
});

/// Asks to use location, for the Near you card's button.
Future<void> allowHomeLocation(WidgetRef ref) async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) await Geolocator.openAppSettings();
  } catch (_) {
    // No location on this device; the card keeps its button.
  }
  ref.invalidate(homeWhereProvider);
}

/// A library place near the phone, [meters] away.
typedef NearbyPlace = ({LibraryEntry entry, double meters});

/// The saved places within [withinMeters] of [at], nearest first, at most
/// [limit] of them.
List<NearbyPlace> nearbyPlaces(List<LibraryEntry> entries, LatLng at, {double withinMeters = 3000, int limit = 3}) {
  const distance = Distance();
  final near = [
    for (final e in entries)
      if (e.isSaved) (entry: e, meters: distance.as(LengthUnit.Meter, at, LatLng(e.place.lat, e.place.lng))),
  ].where((n) => n.meters <= withinMeters).toList()
    ..sort((a, b) => a.meters.compareTo(b.meters));
  return near.take(limit).toList();
}

/// "350 m" or "1.2 km".
String formatMeters(double meters) =>
    meters < 1000 ? '${(meters / 10).round() * 10} m' : '${(meters / 1000).toStringAsFixed(1)} km';

/// Whether Home's small maps load map tiles; widget tests turn it off.
final homeMapTilesProvider = Provider<bool>((ref) => true);
