import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../core/utils/fractional_index.dart';
import '../../trip/controllers/trips_controller.dart' show isoDate;
import '../../trip/providers/trip_providers.dart';

/// Everything the day planner changes: where stops go, how long they take,
/// and the days themselves.
final dayPlannerControllerProvider =
    NotifierProvider<DayPlannerController, AsyncValue<void>>(DayPlannerController.new);

class DayPlannerController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Moves a scheduled stop to [toDayId], before [beforeItemId], or to the
  /// end of that day when it's null.
  Future<AppResult<void>> moveItem({
    required String itemId,
    required String toDayId,
    String? beforeItemId,
  }) {
    return _run(() async {
      final repo = ref.read(tripRepositoryProvider);
      final others = (await repo.getScheduleItemsForDay(toDayId)).where((i) => i.id != itemId).toList();
      await repo.reorderScheduleItem(
        itemId: itemId,
        newSortKey: _keyBefore(others, beforeItemId),
        targetDayId: toDayId,
      );
    });
  }

  /// Puts a stop from the backlog on a day, before [beforeItemId] or at the end.
  Future<AppResult<void>> scheduleStop({
    required String tripId,
    required String stopId,
    required String dayId,
    String? beforeItemId,
  }) {
    return _run(() async {
      final repo = ref.read(tripRepositoryProvider);
      final others = await repo.getScheduleItemsForDay(dayId);
      await repo.scheduleStop(
        tripId: tripId,
        stopId: stopId,
        dayId: dayId,
        sortKey: _keyBefore(others, beforeItemId),
      );
    });
  }

  /// Takes a stop off its day. It goes back to the backlog.
  Future<AppResult<void>> unschedule(String itemId) =>
      _run(() => ref.read(tripRepositoryProvider).deleteScheduleItem(itemId));

  /// Undoes [unschedule]: the item comes back where it was, with its times.
  Future<AppResult<void>> restoreItem(String itemId) => _run(() => ref
      .read(tripRepositoryProvider)
      .updateScheduleItem(ScheduleItemsCompanion(id: Value(itemId), deletedAt: const Value(null))));

  Future<AppResult<void>> setStay(String itemId, int minutes) {
    if (minutes < 0) return Future.value(const Failure('A stay can\'t be negative.'));
    return _run(() => ref.read(tripRepositoryProvider).updateScheduleItem(
          ScheduleItemsCompanion(id: Value(itemId), stayMinutes: Value(minutes)),
        ));
  }

  Future<AppResult<void>> setVisited(String itemId, bool visited) => _run(() => ref
      .read(tripRepositoryProvider)
      .updateScheduleItemStatus(itemId: itemId, status: visited ? 'done' : 'planned'));

  /// Swaps two days: their stops trade places, and the dates stay with the
  /// positions. Pinned days stay where they are, so they can't be swapped.
  Future<AppResult<void>> swapDays({required TripDay a, required TripDay b}) {
    if (a.pinnedDate != null || b.pinnedDate != null) {
      return Future.value(const Failure('Pinned days stay in place. Unpin the day first.'));
    }
    return _run(() => ref.read(tripRepositoryProvider).swapDayBlocks(a.id, b.id));
  }

  /// Pins a day to [date], or unpins it when [date] is null.
  Future<AppResult<void>> pinDay(String dayId, DateTime? date) => _run(() => ref
      .read(tripRepositoryProvider)
      .pinDayBlockDate(dayId, date == null ? null : isoDate(date)));

  /// Adds a day and returns its id. A dated day goes right after the last
  /// dated day, before the backup days, and the trip gets one day longer.
  Future<AppResult<String>> addDay(String tripId, {required bool backup}) {
    return _run(() async {
      final repo = ref.read(tripRepositoryProvider);
      final trip = (await repo.getTrip(tripId))!;
      final days = await repo.getDaysForTrip(tripId);
      final added = await repo.addDayBlock(tripId);
      if (backup) return added.id;
      final dated = trip.dayCount.clamp(0, days.length);
      if (dated < days.length) {
        final before = dated == 0 ? null : days[dated - 1].sortKey;
        await repo.reorderDayBlock(added.id, FractionalIndexUtil.generateKeyBetween(before, days[dated].sortKey));
      }
      await repo.updateTrip(TripsCompanion(id: Value(tripId), dayCount: Value(trip.dayCount + 1)));
      return added.id;
    });
  }

  /// Makes a dated day a backup day, placed first among the backup days. The
  /// trip gets one day shorter and the days after it move up.
  Future<AppResult<void>> moveDayToBackup(String tripId, TripDay day) {
    if (day.pinnedDate != null) {
      return Future.value(const Failure('Pinned days stay in place. Unpin the day first.'));
    }
    return _run(() async {
      final repo = ref.read(tripRepositoryProvider);
      final trip = (await repo.getTrip(tripId))!;
      final days = await repo.getDaysForTrip(tripId);
      final dated = days.take(trip.dayCount).toList();
      if (!dated.any((d) => d.id == day.id)) return;
      if (dated.last.id != day.id) {
        final rest = dated.where((d) => d.id != day.id).toList();
        final backups = days.skip(trip.dayCount).toList();
        await repo.reorderDayBlock(
          day.id,
          FractionalIndexUtil.generateKeyBetween(
            rest.isEmpty ? null : rest.last.sortKey,
            backups.isEmpty ? null : backups.first.sortKey,
          ),
        );
      }
      await repo.updateTrip(TripsCompanion(id: Value(tripId), dayCount: Value(trip.dayCount - 1)));
    });
  }

  /// Makes a backup day the trip's last dated day. The trip gets one day longer.
  Future<AppResult<void>> moveDayToTrip(String tripId, TripDay day) {
    return _run(() async {
      final repo = ref.read(tripRepositoryProvider);
      final trip = (await repo.getTrip(tripId))!;
      final days = await repo.getDaysForTrip(tripId);
      final index = days.indexWhere((d) => d.id == day.id);
      if (index < trip.dayCount) return;
      if (index != trip.dayCount) {
        final backups = days.skip(trip.dayCount).where((d) => d.id != day.id).toList();
        await repo.reorderDayBlock(
          day.id,
          FractionalIndexUtil.generateKeyBetween(
            trip.dayCount == 0 ? null : days[trip.dayCount - 1].sortKey,
            backups.isEmpty ? null : backups.first.sortKey,
          ),
        );
      }
      await repo.updateTrip(TripsCompanion(id: Value(tripId), dayCount: Value(trip.dayCount + 1)));
    });
  }

  /// Removes a day, with anything still on it. Removing a dated day makes
  /// the trip one day shorter.
  Future<AppResult<void>> removeDay(String tripId, String dayId) {
    return _run(() async {
      final repo = ref.read(tripRepositoryProvider);
      final trip = (await repo.getTrip(tripId))!;
      final index = (await repo.getDaysForTrip(tripId)).indexWhere((d) => d.id == dayId);
      await repo.deleteDayBlock(dayId);
      if (index >= 0 && index < trip.dayCount) {
        await repo.updateTrip(TripsCompanion(id: Value(tripId), dayCount: Value(trip.dayCount - 1)));
      }
    });
  }

  String _keyBefore(List<ScheduleItem> ordered, String? beforeItemId) {
    final i = beforeItemId == null ? -1 : ordered.indexWhere((x) => x.id == beforeItemId);
    if (i < 0) {
      return FractionalIndexUtil.generateKeyBetween(ordered.isEmpty ? null : ordered.last.sortKey, null);
    }
    return FractionalIndexUtil.generateKeyBetween(i == 0 ? null : ordered[i - 1].sortKey, ordered[i].sortKey);
  }

  Future<AppResult<T>> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final value = await action();
      state = const AsyncData(null);
      return Success(value);
    } on ArgumentError catch (e, st) {
      state = AsyncError(e, st);
      return Failure(e.message?.toString() ?? e.toString(), st);
    } catch (e, st) {
      state = AsyncError(e, st);
      return Failure(e.toString(), st);
    }
  }
}
