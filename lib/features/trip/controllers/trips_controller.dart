import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/trip_providers.dart';

/// Creates, edits and deletes trips for the trip list and the trip overview.
final tripsControllerProvider =
    NotifierProvider<TripsController, AsyncValue<void>>(TripsController.new);

class TripsController extends Notifier<AsyncValue<void>> {
  static const maxDays = 60;

  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<AppResult<Trip>> createTrip({
    required String title,
    DateTime? startDate,
    required int dayCount,
  }) async {
    final name = title.trim();
    if (name.isEmpty) return const Failure('Give the trip a name.');
    if (dayCount < 1 || dayCount > maxDays) {
      return Failure('A trip has 1 to $maxDays days.');
    }
    return _run(() => ref.read(tripRepositoryProvider).createTrip(
          title: name,
          ownerId: ref.read(currentUserIdProvider),
          startDate: startDate == null ? null : isoDate(startDate),
          dayCount: dayCount,
        ));
  }

  /// Renames the trip and sets or clears its start date. A start date that
  /// would put a pinned day before the day it follows is refused.
  Future<AppResult<void>> updateTrip({
    required String tripId,
    required String title,
    DateTime? startDate,
  }) async {
    final name = title.trim();
    if (name.isEmpty) return const Failure('Give the trip a name.');
    final repo = ref.read(tripRepositoryProvider);
    final trip = await repo.getTrip(tripId);
    if (trip == null) return const Failure('This trip no longer exists.');

    if (startDate != null) {
      final days = await repo.getDaysForTrip(tripId);
      final blocks = ScheduleLogicEngine.computeBlockDates(
        blocks: [
          for (final d in days)
            DayBlockInfo(
              id: d.id,
              sortKey: d.sortKey,
              pinnedDate: d.pinnedDate == null ? null : DateTime.tryParse(d.pinnedDate!),
            ),
        ],
        startDate: startDate,
        dayCount: trip.dayCount,
      );
      final clash = blocks.where((b) => b.hasConflict).firstOrNull;
      if (clash != null) {
        return Failure(
          'Day ${clash.index + 1} is pinned to ${clash.block.pinnedDate == null ? 'an earlier date' : isoDate(clash.block.pinnedDate!)}, '
          'which comes too early for this start date. Pick an earlier start date, or unpin that day first.',
        );
      }
    }

    return _run(() => repo.updateTrip(TripsCompanion(
          id: Value(tripId),
          title: Value(name),
          startDate: Value(startDate == null ? null : isoDate(startDate)),
        )));
  }

  Future<AppResult<void>> deleteTrip(String tripId) =>
      _run(() => ref.read(tripRepositoryProvider).deleteTrip(tripId));

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

/// Formats a date as the `YYYY-MM-DD` text stored in `trips.start_date`.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
