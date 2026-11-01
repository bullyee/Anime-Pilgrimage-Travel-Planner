import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/schedule_logic.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/trip_providers.dart';
import '../repositories/trip_repository.dart';

enum TripFilter { all, shared, personal }

class TripSummaryItem {
  final Trip trip;
  final int stopCount;
  final TripStatus status;
  final String? dateRangeDisplay;
  final bool isShared;

  const TripSummaryItem({
    required this.trip,
    this.stopCount = 0,
    this.status = TripStatus.planning,
    this.dateRangeDisplay,
    this.isShared = false,
  });
}

class TripListState {
  final List<TripSummaryItem> allTrips;
  final List<TripSummaryItem> filteredTrips;
  final TripFilter filter;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  const TripListState({
    this.allTrips = const [],
    this.filteredTrips = const [],
    this.filter = TripFilter.all,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  TripListState copyWith({
    List<TripSummaryItem>? allTrips,
    List<TripSummaryItem>? filteredTrips,
    TripFilter? filter,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TripListState(
      allTrips: allTrips ?? this.allTrips,
      filteredTrips: filteredTrips ?? this.filteredTrips,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TripListController extends StateNotifier<TripListState> {
  final TripRepository _repository;
  final String _currentUserId;
  StreamSubscription<List<Trip>>? _tripsSub;
  int _loadGeneration = 0;

  TripListController({
    required TripRepository repository,
    required String currentUserId,
  })  : _repository = repository,
        _currentUserId = currentUserId,
        super(const TripListState(isLoading: true)) {
    _init();
  }

  void _init() {
    _tripsSub = _repository.watchTrips().listen((trips) async {
      final gen = ++_loadGeneration;
      final summaryList = <TripSummaryItem>[];

      for (final trip in trips) {
        final stops = await _repository.getStopsForTrip(trip.id);
        final days = await _repository.getDaysForTrip(trip.id);
        if (!mounted || gen != _loadGeneration) return;

        final blockInfos = days.map((d) {
          return DayBlockInfo(
            id: d.id,
            sortKey: d.sortKey,
            title: d.title,
            pinnedDate: d.pinnedDate != null ? DateTime.tryParse(d.pinnedDate!) : null,
          );
        }).toList();

        final startDate = trip.startDate != null ? DateTime.tryParse(trip.startDate!) : null;

        List<ResolvedBlockDate> resolved = const [];
        try {
          resolved = ScheduleLogicEngine.computeBlockDates(
            blocks: blockInfos,
            startDate: startDate,
            dayCount: trip.dayCount,
          );
        } catch (_) {}

        final status = ScheduleLogicEngine.computeTripStatus(
          resolvedBlocks: resolved,
          now: DateTime.now(),
        );

        String? dateDisplay;
        final dated = resolved.where((b) => !b.isBackup && b.date != null).toList();
        if (dated.isNotEmpty) {
          final first = dated.first.date!.toIso8601String().substring(0, 10);
          final last = dated.last.date!.toIso8601String().substring(0, 10);
          dateDisplay = first == last ? first : '$first ~ $last';
        }

        final isShared = trip.sharing == 'group' ||
            (trip.ownerId != _currentUserId && trip.ownerId != 'guest_local_user');

        summaryList.add(TripSummaryItem(
          trip: trip,
          stopCount: stops.length,
          status: status,
          dateRangeDisplay: dateDisplay,
          isShared: isShared,
        ));
      }

      if (!mounted || gen != _loadGeneration) return;
      final filtered = _applyFilters(summaryList, state.filter, state.searchQuery);
      state = state.copyWith(
        allTrips: summaryList,
        filteredTrips: filtered,
        isLoading: false,
      );
    }, onError: (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    });
  }

  void setFilter(TripFilter filter) {
    final filtered = _applyFilters(state.allTrips, filter, state.searchQuery);
    state = state.copyWith(filter: filter, filteredTrips: filtered);
  }

  void setSearchQuery(String query) {
    final filtered = _applyFilters(state.allTrips, state.filter, query);
    state = state.copyWith(searchQuery: query, filteredTrips: filtered);
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      await _repository.deleteTrip(tripId);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  List<TripSummaryItem> _applyFilters(
    List<TripSummaryItem> trips,
    TripFilter filter,
    String query,
  ) {
    var result = trips;

    // 1. Filter by category
    switch (filter) {
      case TripFilter.shared:
        result = result.where((item) => item.isShared).toList();
        break;
      case TripFilter.personal:
        result = result.where((item) => !item.isShared).toList();
        break;
      case TripFilter.all:
        break;
    }

    // 2. Filter by search query
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      result = result.where((item) {
        final title = item.trip.title.toLowerCase();
        final desc = item.trip.description?.toLowerCase() ?? '';
        return title.contains(q) || desc.contains(q);
      }).toList();
    }

    return result;
  }

  @override
  void dispose() {
    _tripsSub?.cancel();
    super.dispose();
  }
}

/// Provider for TripListController.
final tripListControllerProvider =
    StateNotifierProvider.autoDispose<TripListController, TripListState>((ref) {
  final repo = ref.watch(tripRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  return TripListController(repository: repo, currentUserId: userId);
});
