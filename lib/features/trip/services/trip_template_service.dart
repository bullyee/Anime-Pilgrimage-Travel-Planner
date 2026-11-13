import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../models/trip_template.dart';

/// Service managing export, publication, preview, and local cloning of Public Trip Templates (Phase 4).
class TripTemplateService {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final String currentUserId;
  final Uuid _uuid;

  TripTemplateService({
    required AppDatabase db,
    required FirebaseFirestore firestore,
    required this.currentUserId,
    Uuid? uuid,
  })  : _db = db,
        _firestore = firestore,
        _uuid = uuid ?? const Uuid();

  /// Generate a random 6-character uppercase alphanumeric short code (excluding ambiguous chars 0, O, 1, I).
  static String generateShortCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Export an existing trip into a sanitized [TripTemplate] snapshot.
  ///
  /// Automatically strips:
  /// - Private calendar dates (`startDate`, `pinnedDate`)
  /// - Backup days (`index >= trip.dayCount`) and their schedule items
  /// - Author UID (for privacy; only public [authorName] is kept)
  /// - Personal photos and device-local file paths (`coverLocalPath`, `localPath`)
  Future<TripTemplate> exportTripToTemplate(
    String tripId, {
    String? authorName,
  }) async {
    final trip = await (_db.select(_db.trips)
          ..where((t) => t.id.equals(tripId) & t.deletedAt.isNull()))
        .getSingleOrNull();

    if (trip == null) {
      throw StateError('Trip not found or deleted: $tripId');
    }

    // 1. Fetch active days, sorted by sortKey, and filter out backup days (index >= dayCount)
    final allDays = await (_db.select(_db.tripDays)
          ..where((d) => d.tripId.equals(tripId) & d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm(expression: d.sortKey)]))
        .get();

    final activeDays = allDays.take(trip.dayCount).toList();
    final dayIdToNumber = <String, int>{};
    final templateDays = <TemplateDay>[];

    for (int i = 0; i < activeDays.length; i++) {
      final dayNumber = i + 1;
      final day = activeDays[i];
      dayIdToNumber[day.id] = dayNumber;
      templateDays.add(TemplateDay(
        dayNumber: dayNumber,
        title: day.title,
      ));
    }

    // 2. Fetch active stops for the trip
    final stops = await (_db.select(_db.stops)
          ..where((s) => s.tripId.equals(tripId) & s.deletedAt.isNull())
          ..orderBy([
            (s) => OrderingTerm(expression: s.createdAt),
            (s) => OrderingTerm(expression: s.id),
          ]))
        .get();

    final templateStops = <TemplateStop>[];
    for (final stop in stops) {
      // Query labels attached to this stop
      final labelRows = await (_db.select(_db.stopLabels).join([
        innerJoin(_db.labels, _db.labels.id.equalsExp(_db.stopLabels.labelId)),
      ])..where(_db.stopLabels.stopId.equals(stop.id)))
          .get();

      final labels = labelRows.map((r) {
        final l = r.readTable(_db.labels);
        return TemplateLabel(name: l.name, kind: l.kind);
      }).toList();

      // Query reference images attached to this stop
      final refImages = await (_db.select(_db.newReferenceImages)
            ..where((r) => r.stopId.equals(stop.id)))
          .get();

      final templateRefImages = refImages
          .where((r) => r.remoteUrl != null && r.remoteUrl!.isNotEmpty)
          .map((r) => TemplateReferenceImage(
                remoteUrl: r.remoteUrl,
                source: r.source,
                sourceUrl: r.sourceUrl,
                episode: r.episode,
                timestampS: r.timestampS,
              ))
          .toList();

      templateStops.add(TemplateStop(
        id: stop.id,
        placeKey: stop.placeKey,
        name: stop.name,
        lat: stop.lat,
        lng: stop.lng,
        description: stop.description,
        address: stop.address,
        businessHours: stop.businessHours,
        contactInfo: stop.contactInfo,
        accessTips: stop.accessTips,
        links: stop.links,
        coverRemoteUrl: stop.coverRemoteUrl,
        source: stop.source,
        sourceUrl: stop.sourceUrl,
        area: stop.area,
        note: stop.note,
        labels: labels,
        referenceImages: templateRefImages,
      ));
    }

    // 3. Fetch active schedule items, excluding those mapped to backup days
    final scheduleItems = await (_db.select(_db.scheduleItems)
          ..where((si) => si.tripId.equals(tripId) & si.deletedAt.isNull())
          ..orderBy([(si) => OrderingTerm(expression: si.sortKey)]))
        .get();

    final templateScheduleItems = <TemplateScheduleItem>[];
    for (final item in scheduleItems) {
      final dayNumber = dayIdToNumber[item.dayId];
      if (dayNumber == null) {
        // Scheduled on a backup day; omit from template snapshot
        continue;
      }
      templateScheduleItems.add(TemplateScheduleItem(
        dayNumber: dayNumber,
        stopId: item.stopId,
        sortKey: item.sortKey,
        stayMinutes: item.stayMinutes,
        transitMinutes: item.transitMinutes,
        fixedTime: item.fixedTime,
        status: item.status,
      ));
    }

    final now = DateTime.now();
    return TripTemplate(
      id: _uuid.v4(),
      code: generateShortCode(),
      title: trip.title,
      description: trip.description,
      authorName: authorName ?? 'Pilgrim',
      dayCount: activeDays.length,
      stopCount: templateStops.length,
      days: templateDays,
      stops: templateStops,
      scheduleItems: templateScheduleItems,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Publish a [TripTemplate] to Firestore, generating a unique 6-character short code.
  Future<TripTemplate> publishTemplate(TripTemplate template) async {
    // Generate unique short code with collision retries
    String code = template.code;
    for (int retry = 0; retry < 5; retry++) {
      final existing =
          await _firestore.collection('template_codes').doc(code).get();
      if (!existing.exists) break;
      code = generateShortCode();
    }

    final published = TripTemplate(
      id: template.id,
      code: code,
      title: template.title,
      description: template.description,
      authorName: template.authorName,
      dayCount: template.dayCount,
      stopCount: template.stopCount,
      days: template.days,
      stops: template.stops,
      scheduleItems: template.scheduleItems,
      createdAt: template.createdAt,
      updatedAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    // 1. Write the template snapshot document
    final tplDoc = _firestore.collection('templates').doc(published.id);
    batch.set(tplDoc, published.toMap());

    // 2. Write the 6-character short code document linking to templateId
    final codeDoc = _firestore.collection('template_codes').doc(code);
    batch.set(codeDoc, {
      'code': code,
      'templateId': published.id,
      'createdAt': Timestamp.fromDate(published.createdAt),
    });

    await batch.commit();
    return published;
  }

  /// Fetch a template by its 6-character short code.
  Future<TripTemplate?> getTemplateByCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    final codeDoc =
        await _firestore.collection('template_codes').doc(cleanCode).get();
    if (!codeDoc.exists) return null;

    final templateId = codeDoc.data()?['templateId'] as String?;
    if (templateId == null) return null;

    final tplDoc =
        await _firestore.collection('templates').doc(templateId).get();
    if (!tplDoc.exists || tplDoc.data() == null) return null;

    return TripTemplate.fromMap(tplDoc.data()!, tplDoc.id);
  }

  /// Clones a public [TripTemplate] into the user's local database as a fresh independent private trip.
  ///
  /// Generates completely new IDs for Trip, Days, Stops, Reference Images, and Schedule Items,
  /// preserving topological relational consistency.
  Future<Trip> cloneTemplateToTrip(
    TripTemplate template, {
    String? ownerId,
    String? newTitle,
    String? startDate,
  }) async {
    final now = DateTime.now();
    final effectiveOwnerId = ownerId ?? currentUserId;
    final newTripId = _uuid.v4();

    return await _db.transaction(() async {
      // 1. Insert Trip
      await _db.into(_db.trips).insert(
            TripsCompanion.insert(
              id: newTripId,
              title: newTitle ?? template.title,
              description: Value(template.description),
              ownerId: effectiveOwnerId,
              sharing: const Value('private'),
              startDate: Value(startDate),
              dayCount: Value(template.dayCount),
              createdAt: Value(now),
              updatedAt: Value(now),
              updatedBy: Value(effectiveOwnerId),
              syncStatus: const Value(1),
            ),
          );

      // 2. Insert Trip Days
      final dayNumberToNewDayId = <int, String>{};
      for (final tDay in template.days) {
        final newDayId = _uuid.v4();
        dayNumberToNewDayId[tDay.dayNumber] = newDayId;
        // Generate a fractional index sortKey (e.g. 'a0', 'a1', etc.)
        final sortKey = 'a${tDay.dayNumber - 1}';

        await _db.into(_db.tripDays).insert(
              TripDaysCompanion.insert(
                id: newDayId,
                tripId: newTripId,
                sortKey: sortKey,
                title: Value(tDay.title),
                updatedAt: Value(now),
                updatedBy: Value(effectiveOwnerId),
                syncStatus: const Value(1),
              ),
            );
      }

      // 3. Insert Stops, Reference Images, and Labels
      final templateStopIdToNewStopId = <String, String>{};
      for (final tStop in template.stops) {
        final newStopId = _uuid.v4();
        templateStopIdToNewStopId[tStop.id] = newStopId;

        // Fallback Place record to satisfy foreign keys and search integration
        final existingPlace = await (_db.select(_db.places)
              ..where((p) => p.placeKey.equals(tStop.placeKey)))
            .getSingleOrNull();

        if (existingPlace == null) {
          await _db.into(_db.places).insert(
                PlacesCompanion.insert(
                  placeKey: tStop.placeKey,
                  name: tStop.name,
                  lat: tStop.lat,
                  lng: tStop.lng,
                  description: Value(tStop.description),
                  address: Value(tStop.address),
                  businessHours: Value(tStop.businessHours),
                  contactInfo: Value(tStop.contactInfo),
                  accessTips: Value(tStop.accessTips),
                  links: Value(tStop.links),
                  coverRemoteUrl: Value(tStop.coverRemoteUrl),
                  source: Value(tStop.source),
                  sourceUrl: Value(tStop.sourceUrl),
                  visibility: const Value('trip_only'),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }

        // Insert Stop
        await _db.into(_db.stops).insert(
              StopsCompanion.insert(
                id: newStopId,
                tripId: newTripId,
                placeKey: tStop.placeKey,
                name: tStop.name,
                lat: tStop.lat,
                lng: tStop.lng,
                description: Value(tStop.description),
                address: Value(tStop.address),
                businessHours: Value(tStop.businessHours),
                contactInfo: Value(tStop.contactInfo),
                accessTips: Value(tStop.accessTips),
                links: Value(tStop.links),
                coverRemoteUrl: Value(tStop.coverRemoteUrl),
                source: Value(tStop.source),
                sourceUrl: Value(tStop.sourceUrl),
                area: Value(tStop.area),
                note: Value(tStop.note),
                addedBy: effectiveOwnerId,
                createdAt: Value(now),
                updatedAt: Value(now),
                updatedBy: Value(effectiveOwnerId),
                syncStatus: const Value(1),
              ),
            );

        // Insert Reference Images
        for (final refImg in tStop.referenceImages) {
          await _db.into(_db.newReferenceImages).insert(
                NewReferenceImagesCompanion.insert(
                  id: _uuid.v4(),
                  stopId: Value(newStopId),
                  remoteUrl: Value(refImg.remoteUrl),
                  source: Value(refImg.source),
                  sourceUrl: Value(refImg.sourceUrl),
                  episode: Value(refImg.episode),
                  timestampS: Value(refImg.timestampS),
                  createdAt: Value(now),
                ),
              );
        }

        // Insert Labels
        for (final label in tStop.labels) {
          var existingLabel = await (_db.select(_db.labels)
                ..where((l) =>
                    l.name.equals(label.name) & l.kind.equals(label.kind)))
              .getSingleOrNull();

          String labelId;
          if (existingLabel == null) {
            labelId = _uuid.v4();
            await _db.into(_db.labels).insert(
                  LabelsCompanion.insert(
                    id: labelId,
                    name: label.name,
                    kind: label.kind,
                    createdAt: Value(now),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
          } else {
            labelId = existingLabel.id;
          }

          await _db.into(_db.stopLabels).insert(
                StopLabelsCompanion.insert(
                  stopId: newStopId,
                  labelId: labelId,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }

      // 4. Insert Schedule Items
      for (final sItem in template.scheduleItems) {
        final targetDayId = dayNumberToNewDayId[sItem.dayNumber];
        final targetStopId = templateStopIdToNewStopId[sItem.stopId];

        if (targetDayId != null && targetStopId != null) {
          await _db.into(_db.scheduleItems).insert(
                ScheduleItemsCompanion.insert(
                  id: _uuid.v4(),
                  tripId: newTripId,
                  dayId: targetDayId,
                  stopId: targetStopId,
                  sortKey: sItem.sortKey,
                  stayMinutes: Value(sItem.stayMinutes),
                  transitMinutes: Value(sItem.transitMinutes),
                  fixedTime: Value(sItem.fixedTime),
                  status: const Value('planned'),
                  updatedAt: Value(now),
                  updatedBy: Value(effectiveOwnerId),
                  syncStatus: const Value(1),
                ),
              );
        }
      }

      return (await (_db.select(_db.trips)..where((t) => t.id.equals(newTripId)))
              .getSingle());
    });
  }
}
