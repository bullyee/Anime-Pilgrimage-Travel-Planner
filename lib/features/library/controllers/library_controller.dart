import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/app_result.dart';
import '../models/library_entry.dart';
import '../providers/place_providers.dart';

/// What removing a place from the library did.
enum RemovedPlace {
  /// It is a stop in a trip, so it was only hidden from the library.
  hidden,

  /// It was in no trip, so it was deleted with its photos and notes.
  deleted,
}

/// Changes to the personal library: places and their labels.
final libraryControllerProvider = NotifierProvider<LibraryController, AsyncValue<void>>(LibraryController.new);

class LibraryController extends Notifier<AsyncValue<void>> {
  static const _uuid = Uuid();

  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Saves a place the user picked on the map.
  Future<AppResult<Place>> createPlace({
    required String name,
    required double lat,
    required double lng,
    String? address,
    String? description,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Failure('Give the place a name.');
    String? clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
    return _run(() async {
      final repo = ref.read(placeRepositoryProvider);
      final placeKey = _uuid.v4();
      await repo.upsertPlace(PlacesCompanion.insert(
        placeKey: placeKey,
        name: trimmed,
        lat: lat,
        lng: lng,
        address: Value(clean(address)),
        description: Value(clean(description)),
        visibility: const Value('saved'),
      ));
      return (await repo.getPlace(placeKey))!;
    });
  }

  /// Puts a label on a place, creating the label when it doesn't exist yet.
  Future<AppResult<Label>> addLabel(String placeKey, {required String kind, required String name}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value(const Failure('Give the label a name.'));
    return _run(() async {
      final repo = ref.read(placeRepositoryProvider);
      final label = await repo.getOrCreateLabel(kind: kind, name: trimmed);
      await repo.attachLabelToPlace(placeKey, label.id);
      return label;
    });
  }

  Future<AppResult<void>> removeLabel(String placeKey, String labelId) => _run(() async {
        await ref.read(placeRepositoryProvider).removeLabelFromPlace(placeKey, labelId);
        await _dropUnused([labelId]);
      });

  /// Deletes those of [labelIds] that nothing uses any more: no place, no
  /// trip stop and no anime frame. Only labels that a change just took off
  /// something are checked, so one made in the Labels screen for later stays.
  /// Stops and frames count because trips are shared with other people.
  Future<int> _dropUnused(Iterable<String> labelIds) async {
    final db = ref.read(databaseProvider);
    var dropped = 0;
    for (final id in labelIds.toSet()) {
      if (await _inUse(db, id)) continue;
      await ref.read(placeRepositoryProvider).deleteLabel(id);
      dropped++;
    }
    return dropped;
  }

  static Future<bool> _inUse(AppDatabase db, String labelId) async =>
      await (db.select(db.placeLabels)..where((l) => l.labelId.equals(labelId))..limit(1)).getSingleOrNull() != null ||
      await (db.select(db.stopLabels)..where((l) => l.labelId.equals(labelId))..limit(1)).getSingleOrNull() != null ||
      await (db.select(db.newReferenceImages)..where((r) => r.animeLabelId.equals(labelId))..limit(1)).getSingleOrNull() != null;

  /// Deletes every label that no place, trip stop or anime frame uses, and
  /// returns how many went.
  Future<AppResult<int>> deleteUnusedLabels() => _run(() async {
        final labels = await ref.read(placeRepositoryProvider).getLabels();
        return _dropUnused(labels.map((l) => l.id));
      });

  /// Creates a label, or returns the one that already has this name.
  Future<AppResult<Label>> createLabel({required String kind, required String name}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value(const Failure('Give the label a name.'));
    return _run(() => ref.read(placeRepositoryProvider).getOrCreateLabel(kind: kind, name: trimmed));
  }

  /// Renames a label. When another label of its kind already has the name,
  /// the two are merged and the surviving label is returned.
  Future<AppResult<Label>> renameLabel(String labelId, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return Future.value(const Failure('Give the label a name.'));
    return _run(() => ref.read(placeRepositoryProvider).renameLabel(labelId, trimmed));
  }

  /// Moves every place of [source] to [target] and deletes [source].
  Future<AppResult<void>> mergeLabels({required Label source, required Label target}) {
    if (source.kind != target.kind) return Future.value(const Failure('Only labels of the same kind can be merged.'));
    if (source.id == target.id) return Future.value(const Failure('Pick another label to merge into.'));
    return _run(() => ref.read(placeRepositoryProvider).mergeLabels(sourceLabelId: source.id, targetLabelId: target.id));
  }

  Future<AppResult<void>> deleteLabel(String labelId) => _run(() => ref.read(placeRepositoryProvider).deleteLabel(labelId));

  /// Takes a place out of the library. One that is a stop in a trip is only
  /// hidden, so the trip keeps it and its photos stay; otherwise it is deleted.
  Future<AppResult<RemovedPlace>> removeFromLibrary(LibraryEntry entry) {
    return _run(() async {
      final repo = ref.read(placeRepositoryProvider);
      if (entry.tripIds.isNotEmpty) {
        await repo.setPlaceVisibility(entry.place.placeKey, 'trip_only');
        return RemovedPlace.hidden;
      }
      await repo.deletePlace(entry.place.placeKey);
      await _dropUnused(entry.labels.map((l) => l.id));
      return RemovedPlace.deleted;
    });
  }

  /// Saves a place that so far only backed a trip's stop.
  Future<AppResult<void>> saveToLibrary(String placeKey) =>
      _run(() => ref.read(placeRepositoryProvider).setPlaceVisibility(placeKey, 'saved'));

  // Several places at once, each in one transaction so the library updates
  // once rather than once per place.

  /// Puts one label on every place in [placeKeys], creating it when needed.
  Future<AppResult<Label>> addLabelToPlaces(List<String> placeKeys, {required String kind, required String name}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value(const Failure('Give the label a name.'));
    return _run(() => ref.read(databaseProvider).transaction(() async {
          final repo = ref.read(placeRepositoryProvider);
          final label = await repo.getOrCreateLabel(kind: kind, name: trimmed);
          for (final key in placeKeys) {
            await repo.attachLabelToPlace(key, label.id);
          }
          return label;
        }));
  }

  /// Takes one label off every place in [placeKeys].
  Future<AppResult<void>> removeLabelFromPlaces(List<String> placeKeys, String labelId) {
    return _run(() => ref.read(databaseProvider).transaction(() async {
          final repo = ref.read(placeRepositoryProvider);
          for (final key in placeKeys) {
            await repo.removeLabelFromPlace(key, labelId);
          }
          await _dropUnused([labelId]);
        }));
  }

  /// Merges [others] into [keep], for the same spot saved twice. Their
  /// labels, frames, photos and visits move to [keep], their notes are added
  /// to its note, and trip stops that used them now point at [keep]. The
  /// kept place's facts stay as they are, and the others are deleted.
  Future<AppResult<void>> mergePlaces({required String keep, required List<String> others}) {
    final rest = [for (final k in others) if (k != keep) k];
    if (rest.isEmpty) return Future.value(const Failure('Pick at least two places to merge.'));
    return _run(() => ref.read(databaseProvider).transaction(() async {
          final db = ref.read(databaseProvider);
          final repo = ref.read(placeRepositoryProvider);
          final kept = await repo.getPlace(keep);
          if (kept == null) throw StateError('The place to keep is gone.');
          final notes = [if (kept.privateNote?.trim().isNotEmpty ?? false) kept.privateNote!.trim()];
          var cover = kept.coverLocalPath;
          final visitDates = {for (final v in await repo.getVisitsForPlace(keep)) v.date};
          final merged = <String>[];
          for (final key in rest) {
            final other = await repo.getPlace(key);
            if (other == null) continue;
            merged.add(key);
            if (other.privateNote?.trim().isNotEmpty ?? false) notes.add(other.privateNote!.trim());
            cover ??= other.coverLocalPath;
            for (final label in await repo.getLabelsForPlace(key)) {
              await repo.attachLabelToPlace(keep, label.id);
            }
            await (db.update(db.newReferenceImages)..where((r) => r.placeKey.equals(key)))
                .write(NewReferenceImagesCompanion(placeKey: Value(keep)));
            await (db.update(db.photos)..where((p) => p.placeKey.equals(key))).write(PhotosCompanion(placeKey: Value(keep)));
            // A visit on a day the kept place already has is the same visit.
            for (final v in await repo.getVisitsForPlace(key)) {
              if (visitDates.add(v.date)) {
                await (db.update(db.placeVisits)..where((x) => x.id.equals(v.id))).write(PlaceVisitsCompanion(placeKey: Value(keep)));
              }
            }
            await (db.update(db.stops)..where((s) => s.placeKey.equals(key))).write(StopsCompanion(
                  placeKey: Value(keep),
                  updatedAt: Value(DateTime.now()),
                  syncStatus: const Value(1),
                ));
          }
          // The kept place takes over the cover before the others go, so its
          // file counts as still in use when they are deleted.
          await repo.updatePlace(PlacesCompanion(
            placeKey: Value(keep),
            privateNote: Value(notes.isEmpty ? null : notes.join('\n\n')),
            coverLocalPath: Value(cover),
          ));
          for (final key in merged) {
            await repo.deletePlace(key);
          }
        }));
  }

  /// Takes several places out of the library, the way [removeFromLibrary]
  /// does each one. Returns how many were hidden and how many deleted.
  Future<AppResult<(int hidden, int deleted)>> removeManyFromLibrary(List<LibraryEntry> entries) {
    return _run(() => ref.read(databaseProvider).transaction(() async {
          final repo = ref.read(placeRepositoryProvider);
          var hidden = 0;
          var deleted = 0;
          for (final entry in entries) {
            if (entry.tripIds.isNotEmpty) {
              await repo.setPlaceVisibility(entry.place.placeKey, 'trip_only');
              hidden++;
            } else {
              await repo.deletePlace(entry.place.placeKey);
              deleted++;
            }
          }
          await _dropUnused([for (final e in entries) ...e.labels.map((l) => l.id)]);
          return (hidden, deleted);
        }));
  }

  Future<AppResult<T>> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final value = await action();
      state = const AsyncData(null);
      return Success(value);
    } catch (e, st) {
      state = AsyncError(e, st);
      return Failure(e.toString(), st);
    }
  }
}
