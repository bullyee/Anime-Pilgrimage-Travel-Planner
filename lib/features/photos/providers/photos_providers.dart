import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

/// A photo with what the Photos tab shows beside it.
class PhotoEntry {
  final Photo photo;
  final Place? place;

  /// The frame it was taken against, if any.
  final NewReferenceImage? frame;

  /// Whether an edit of it has been saved.
  final bool hasEdit;

  const PhotoEntry({required this.photo, this.place, this.frame, this.hasEdit = false});

  /// When it was taken, as the tab sorts and groups it.
  DateTime get time => photo.takenAt ?? photo.createdAt;

  bool get isEdit => photo.kind != 'original';

  /// Waiting in To edit: an original, not kept as it is, with no edit yet.
  bool get toEdit => !isEdit && !photo.keepAsIs && !hasEdit;
}

/// Every photo, newest first, with its place and frame.
Stream<List<PhotoEntry>> watchPhotoEntries(AppDatabase db) {
  final query = db.select(db.photos)
    ..orderBy([(p) => OrderingTerm.desc(p.takenAt), (p) => OrderingTerm.desc(p.createdAt)]);
  return query.watch().asyncMap((photos) => _entries(db, photos));
}

/// One photo with its place and frame; null once it's gone.
Stream<PhotoEntry?> watchPhotoEntry(AppDatabase db, String photoId) {
  final query = db.select(db.photos)..where((p) => p.id.equals(photoId));
  return query.watch().asyncMap((rows) async => rows.isEmpty ? null : (await _entries(db, rows)).single);
}

Future<List<PhotoEntry>> _entries(AppDatabase db, List<Photo> photos) async {
  if (photos.isEmpty) return const [];
  final placeKeys = photos.map((p) => p.placeKey).toSet();
  final places = await (db.select(db.places)..where((p) => p.placeKey.isIn(placeKeys))).get();
  final placeMap = {for (final p in places) p.placeKey: p};

  final frameIds = photos.map((p) => p.referenceImageId).whereType<String>().toSet();
  final frames = frameIds.isEmpty
      ? const <NewReferenceImage>[]
      : await (db.select(db.newReferenceImages)..where((r) => r.id.isIn(frameIds))).get();
  final frameMap = {for (final f in frames) f.id: f};

  final ids = photos.map((p) => p.id).toSet();
  final edited = await (db.selectOnly(db.photos, distinct: true)
        ..addColumns([db.photos.derivedFromId])
        ..where(db.photos.derivedFromId.isIn(ids)))
      .map((r) => r.read(db.photos.derivedFromId))
      .get();
  final editedIds = edited.whereType<String>().toSet();

  return [
    for (final photo in photos)
      PhotoEntry(
        photo: photo,
        place: placeMap[photo.placeKey],
        frame: photo.referenceImageId == null ? null : frameMap[photo.referenceImageId],
        hasEdit: editedIds.contains(photo.id),
      ),
  ];
}

final allPhotosProvider = StreamProvider.autoDispose<List<PhotoEntry>>(
  (ref) => watchPhotoEntries(ref.watch(databaseProvider)),
);

final photoEntryProvider = StreamProvider.autoDispose.family<PhotoEntry?, String>(
  (ref, photoId) => watchPhotoEntry(ref.watch(databaseProvider), photoId),
);

/// [entries] split by the day they were taken, newest day first, keeping
/// their order within a day.
List<(DateTime, List<PhotoEntry>)> groupEntriesByDay(List<PhotoEntry> entries) {
  final groups = <DateTime, List<PhotoEntry>>{};
  for (final e in entries) {
    final t = e.time;
    groups.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(e);
  }
  return [for (final g in groups.entries) (g.key, g.value)]..sort((a, b) => b.$1.compareTo(a.$1));
}

/// [entries] split by place, the place with the newest photo first.
List<(Place?, List<PhotoEntry>)> groupEntriesByPlace(List<PhotoEntry> entries) {
  final groups = <String, List<PhotoEntry>>{};
  for (final e in entries) {
    groups.putIfAbsent(e.photo.placeKey, () => []).add(e);
  }
  DateTime newest(List<PhotoEntry> list) => list.map((e) => e.time).reduce((a, b) => a.isAfter(b) ? a : b);
  final list = [for (final g in groups.values) (g.first.place, g)];
  list.sort((a, b) => newest(b.$2).compareTo(newest(a.$2)));
  return list;
}
