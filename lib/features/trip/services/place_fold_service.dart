import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database.dart';
import '../models/stop_group.dart';
import '../providers/trip_stop_providers.dart';
import '../repositories/trip_repository.dart';

// A trip is place-led: a place is one stop, and the spots inside it are where
// its frames are shot from. Before that, one place came into a trip as a
// group of stops sharing `stops.area`, one stop per spot. Folding turns each
// group into one stop, its members' positions and short names going onto
// their frames.

/// One group of a trip and the stop it folds into.
class PlaceFold {
  /// The group's name, which the kept stop takes.
  final String name;
  final Stop keep;

  /// The group's other stops, which go.
  final List<Stop> others;

  const PlaceFold({required this.name, required this.keep, required this.others});
}

/// The stop a group folds into: the first in the plan, by day and place in
/// the day ([stopToKeep]'s rule), else the smallest id. Ties go by id too, and
/// unplanned stops don't go by when they were added, which isn't synced: every
/// phone of a shared trip has to pick the same stop from the same data, so two
/// members converting at once agree.
TripStopEntry placeStopToKeep(List<TripStopEntry> members) {
  int byId(TripStopEntry a, TripStopEntry b) => a.stop.id.compareTo(b.stop.id);
  final planned = members.where((e) => e.isPlanned).toList()
    ..sort((a, b) {
      final byDay = a.dayIndex!.compareTo(b.dayIndex!);
      if (byDay != 0) return byDay;
      final byPosition = (a.position ?? 0).compareTo(b.position ?? 0);
      return byPosition != 0 ? byPosition : byId(a, b);
    });
  if (planned.isNotEmpty) return planned.first;
  return ([...members]..sort(byId)).first;
}

/// The groups of a trip's [entries] (in plan order) as folds.
List<PlaceFold> placeFolds(List<TripStopEntry> entries) {
  final groups = <String, List<TripStopEntry>>{};
  for (final e in entries) {
    final group = stopGroup(e.stop);
    if (group != null) groups.putIfAbsent(group, () => []).add(e);
  }
  return [
    for (final MapEntry(key: name, value: members) in groups.entries)
      if (placeStopToKeep(members) case final keep)
        PlaceFold(name: name, keep: keep.stop, others: [for (final e in members) if (e != keep) e.stop]),
  ];
}

/// Folds the groups of a trip into places.
class PlaceFoldService {
  final AppDatabase _db;
  final TripRepository _trips;

  PlaceFoldService(this._db, this._trips);

  /// The groups of [tripId] that [foldTrip] would fold.
  Future<List<PlaceFold>> foldsOf(String tripId) async {
    final trip = await _trips.getTrip(tripId);
    if (trip == null || trip.deletedAt != null) return const [];
    final days = await _trips.getDaysForTrip(tripId);
    final entries = buildStopEntries(
      stops: await _trips.getStopsForTrip(tripId),
      days: days,
      items: await _trips.getScheduleItemsForTrip(tripId),
      dayCount: trip.dayCount,
    );
    return placeFolds(entries);
  }

  /// Turns every group of [tripId] into one place; returns how many. Running
  /// it again does nothing, since a folded trip has no groups.
  Future<int> foldTrip(String tripId) async {
    final folds = await foldsOf(tripId);
    for (final fold in folds) {
      await _trips.foldStopsIntoPlace(
        keepId: fold.keep.id,
        otherIds: [for (final o in fold.others) o.id],
        name: fold.name,
      );
    }
    return folds.length;
  }

  /// Whether [tripId] has changes this phone hasn't uploaded yet. A shared
  /// trip folds only without any: the fold reads the plan to pick the stop
  /// each group keeps, and another member picks from what the cloud has.
  Future<bool> hasUnsyncedChanges(String tripId) async {
    Future<bool> any(TableInfo table, Expression<bool> where) async =>
        (await (_db.selectOnly(table)
                  ..addColumns([countAll()])
                  ..where(where))
                .getSingle())
            .read(countAll())! >
        0;
    return await any(_db.trips, _db.trips.id.equals(tripId) & _db.trips.syncStatus.equals(1)) ||
        await any(_db.tripDays, _db.tripDays.tripId.equals(tripId) & _db.tripDays.syncStatus.equals(1)) ||
        await any(_db.stops, _db.stops.tripId.equals(tripId) & _db.stops.syncStatus.equals(1)) ||
        await any(_db.scheduleItems, _db.scheduleItems.tripId.equals(tripId) & _db.scheduleItems.syncStatus.equals(1));
  }

  /// Folds the groups of every private trip once, the first time this
  /// version runs (shared trips ask an owner or editor first, see
  /// `PlaceFoldBanner`). A trip made after that first run isn't folded: its
  /// groups were made on purpose with this version, and its banner offers
  /// the same.
  Future<int> foldPrivateTripsOnce(PlaceFoldStore store, {DateTime? now}) async {
    final state = await store.read();
    final since = state.since ?? now ?? DateTime.now();
    final done = {...state.done};
    var folded = 0;
    final trips = await (_db.select(_db.trips)..where((t) => t.sharing.equals('private') & t.deletedAt.isNull())).get();
    for (final trip in trips) {
      if (done.contains(trip.id)) continue;
      if (!trip.createdAt.isAfter(since)) {
        try {
          folded += await foldTrip(trip.id);
        } catch (e, stack) {
          debugPrint('[PlaceFold] could not fold ${trip.id}: $e\n$stack');
          continue;
        }
      }
      done.add(trip.id);
    }
    await store.write(PlaceFoldState(since: since, done: done));
    return folded;
  }
}

/// Which private trips [PlaceFoldService.foldPrivateTripsOnce] has seen, and
/// when it first ran.
class PlaceFoldState {
  final DateTime? since;
  final Set<String> done;

  const PlaceFoldState({this.since, this.done = const {}});
}

abstract class PlaceFoldStore {
  /// The state, or the empty one before the first run. Throws when it can't
  /// tell (a file it can't read), so nothing is folded on a guess.
  Future<PlaceFoldState> read();
  Future<void> write(PlaceFoldState state);
}

/// Keeps [PlaceFoldState] in a small file in application support storage,
/// like the app's other settings.
class FilePlaceFoldStore implements PlaceFoldStore {
  FilePlaceFoldStore({Future<Directory> Function()? directory}) : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File(p.join((await _directory()).path, 'place_fold.json'));

  @override
  Future<PlaceFoldState> read() async {
    final f = await _file();
    if (!await f.exists()) return const PlaceFoldState();
    // A file that's there but unreadable throws: read as empty, it would
    // fold every private trip again, groups made on purpose since included.
    final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final since = json['since'];
    return PlaceFoldState(
      since: since is int ? DateTime.fromMillisecondsSinceEpoch(since) : null,
      done: {for (final id in json['done'] as List? ?? const []) if (id is String) id},
    );
  }

  @override
  Future<void> write(PlaceFoldState state) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    // Written aside and renamed over, so a write cut short leaves the old one.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({'since': state.since?.millisecondsSinceEpoch, 'done': [...state.done]}),
      flush: true,
    );
    await tmp.rename(f.path);
  }
}

/// For tests and anywhere without a file system.
class InMemoryPlaceFoldStore implements PlaceFoldStore {
  PlaceFoldState state;

  InMemoryPlaceFoldStore([this.state = const PlaceFoldState()]);

  @override
  Future<PlaceFoldState> read() async => state;

  @override
  Future<void> write(PlaceFoldState state) async => this.state = state;
}
