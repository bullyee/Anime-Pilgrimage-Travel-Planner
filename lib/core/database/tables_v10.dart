import 'package:drift/drift.dart';

/// Sync status enum for local SQLite dirty tracking.
enum SyncStatusV10 {
  synced,
  dirty,
}

// ============================================================================
// PERSONAL LAYER (On device only; never synced directly to shared trip groups)
// ============================================================================

/// Personal library page for a real-world pilgrimage spot.
class Places extends Table {
  /// The spot's global identity: `anitabi:<pointId>` for Anitabi imports, UUID for user-created.
  TextColumn get placeKey => text()();

  TextColumn get name => text()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();

  TextColumn get description => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get businessHours => text().nullable()();
  TextColumn get contactInfo => text().nullable()();

  /// Tips on how to get there and optimal lighting/angles for photos.
  TextColumn get accessTips => text().nullable()();

  /// External links (Google Maps, Anitabi web page, etc.).
  TextColumn get links => text().nullable()();

  TextColumn get coverLocalPath => text().nullable()();
  TextColumn get coverRemoteUrl => text().nullable()();

  /// Attribution data (e.g. "Anitabi", origin URL for CC BY-NC-SA 4.0).
  TextColumn get source => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();

  /// Personal private notes (visible only to the device owner).
  TextColumn get privateNote => text().nullable()();

  /// Visibility: 'saved' (shown in library) or 'trip_only' (hidden library entry created for a trip).
  TextColumn get visibility => text().withDefault(const Constant('saved'))();

  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {placeKey};
}

/// Unified labels replacing separate anime/tag/roi tables: kind = 'anime' | 'tag' | 'region'.
class Labels extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // 'anime' | 'tag' | 'region'
  TextColumn get name => text()();
  TextColumn get bangumiId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Many-to-many junction between personal [Places] and [Labels].
class PlaceLabels extends Table {
  TextColumn get placeKey => text().references(Places, #placeKey, onDelete: KeyAction.cascade)();
  TextColumn get labelId => text().references(Labels, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {placeKey, labelId};
}

/// Photos taken by the user at a place.
class Photos extends Table {
  TextColumn get id => text()();
  TextColumn get placeKey => text().references(Places, #placeKey, onDelete: KeyAction.cascade)();
  TextColumn get tripId => text().nullable()();

  /// Photo type: 'original' | 'edited' | 'comparison' | 'composite'.
  TextColumn get kind => text().withDefault(const Constant('original'))();

  TextColumn get derivedFromId => text().nullable()();
  TextColumn get referenceImageId => text().nullable()();

  TextColumn get localPath => text()();
  TextColumn get remoteUrl => text().nullable()();

  /// Whether the user opted in to publish this photo to the shared trip.
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();

  DateTimeColumn get takenAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Personal visit history: "I visited this place on date X".
class PlaceVisits extends Table {
  TextColumn get id => text()();
  TextColumn get placeKey => text().references(Places, #placeKey, onDelete: KeyAction.cascade)();
  TextColumn get date => text()(); // 'YYYY-MM-DD'
  TextColumn get tripId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reference anime frames for camera overlay and comparison.
/// Owned by either a place or a stop.
class NewReferenceImages extends Table {
  @override
  String get tableName => 'v10_reference_images';

  TextColumn get id => text()();
  TextColumn get placeKey => text().nullable().references(Places, #placeKey, onDelete: KeyAction.cascade)();
  TextColumn get stopId => text().nullable()(); // Linked to Stops in shared trips

  TextColumn get localPath => text().nullable()();
  TextColumn get remoteUrl => text().nullable()();

  TextColumn get animeLabelId => text().nullable()();
  TextColumn get episode => text().nullable()();
  IntColumn get timestampS => integer().nullable()();

  TextColumn get source => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// SHARED LAYER (One trip, synced across collaborators)
// ============================================================================

/// A trip containing day blocks, stops, and schedule items.
class Trips extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get ownerId => text()();
  TextColumn get sharing => text().withDefault(const Constant('private'))(); // 'private' | 'group'

  TextColumn get startDate => text().nullable()(); // 'YYYY-MM-DD'
  IntColumn get dayCount => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();

  // Sync bookkeeping
  TextColumn get updatedBy => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))(); // 0: synced, 1: dirty

  @override
  Set<Column> get primaryKey => {id};
}

/// Day blocks within a trip (ordered by sort_key).
class TripDays extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get sortKey => text()(); // Fractional indexing
  TextColumn get title => text().nullable()();
  TextColumn get pinnedDate => text().nullable()(); // 'YYYY-MM-DD'

  // Sync bookkeeping
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get updatedBy => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Stops added to a trip (a self-contained copy of place facts).
class Stops extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get placeKey => text()();

  // Copied place facts
  TextColumn get name => text()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  TextColumn get description => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get businessHours => text().nullable()();
  TextColumn get contactInfo => text().nullable()();
  TextColumn get accessTips => text().nullable()();
  TextColumn get links => text().nullable()();
  TextColumn get coverLocalPath => text().nullable()();
  TextColumn get coverRemoteUrl => text().nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();

  TextColumn get addedBy => text()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  // Sync bookkeeping
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get updatedBy => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Many-to-many junction between trip [Stops] and [Labels].
class StopLabels extends Table {
  TextColumn get stopId => text().references(Stops, #id, onDelete: KeyAction.cascade)();
  TextColumn get labelId => text().references(Labels, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {stopId, labelId};
}

/// Scheduled stops on a specific day block.
class ScheduleItems extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get stopId => text().references(Stops, #id, onDelete: KeyAction.cascade)();
  TextColumn get dayId => text().references(TripDays, #id, onDelete: KeyAction.cascade)();
  TextColumn get sortKey => text()(); // Fractional indexing

  IntColumn get stayMinutes => integer().withDefault(const Constant(60))();
  IntColumn get transitMinutes => integer().withDefault(const Constant(0))();
  IntColumn get fixedTime => integer().nullable()(); // Minutes from midnight (e.g. 540 = 09:00, 1530 = 25:30)
  TextColumn get status => text().withDefault(const Constant('planned'))(); // 'planned' | 'done' | 'skipped'

  // Sync bookkeeping
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get updatedBy => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

