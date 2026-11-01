# Controller Integration Guide for Frontend (Stage 2 UI)

This guide documents the Riverpod Controllers and Services prepared for the frontend (`@bullyee`) to bind UI components directly to the data layer without worrying about SQLite/Drift or Firestore sync internals.

---

## 1. Trip List & Filtering (`TripListController`)

Used on the Home screen or "My Trips" screen to display trips with live sync status, stop counts, and category filters.

### Import
```dart
import 'package:trip_planner/features/trip/controllers/trip_list_controller.dart';
```

### Watching State
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(tripListControllerProvider);

  if (state.isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  return ListView.builder(
    itemCount: state.filteredTrips.length,
    itemBuilder: (context, index) {
      final item = state.filteredTrips[index];
      return ListTile(
        title: Text(item.trip.title),
        subtitle: Text('${item.dateRangeDisplay ?? "No dates"} • ${item.stopCount} spots'),
        trailing: item.isShared ? const Chip(label: Text('Shared')) : null,
        onTap: () => context.push('/trips/${item.trip.id}'),
      );
    },
  );
}
```

### Available Actions
```dart
final notifier = ref.read(tripListControllerProvider.notifier);

// Filter by tab ('All' | 'Shared' | 'Personal')
notifier.setFilter(TripFilter.all);
notifier.setFilter(TripFilter.shared);
notifier.setFilter(TripFilter.personal);

// Search query (matches title and description)
notifier.setSearchQuery('Akihabara');

// Delete trip (soft-delete with sync)
await notifier.deleteTrip(tripId);
```

---

## 2. Trip Planner & Timeline (`TripPlannerController`)

Used on the Trip Planner / Itinerary screen for day block reordering, date pinning, backlog spots, and timeline scheduling.

### Import
```dart
import 'package:trip_planner/features/trip/controllers/trip_planner_controller.dart';
```

### Watching State
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(tripPlannerControllerProvider(tripId));

  if (state.isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  // 1. Day Blocks (with resolved dates & backup status)
  final days = state.days; // List<ResolvedBlockDate>
  // days[i].block.id, days[i].date, days[i].isBackup

  // 2. Timeline items (continuous time calculation)
  final timeline = state.scheduledTimeline; // List<ComputedTimelineItem>
  // item.startTimeFormatted ("09:00"), item.endTimeFormatted ("10:30"), item.hasConflict

  // 3. Backlog stops (stops added to trip but not yet assigned to any day)
  final backlog = state.backlogStops; // List<Stop>
  
  // 4. Trip Status (planning | ongoing | finished)
  final status = state.tripStatus;
}
```

### Available Actions
```dart
final notifier = ref.read(tripPlannerControllerProvider(tripId).notifier);

// 1. Drag & drop reorder day blocks (e.g. ReorderableListView)
await notifier.swapDayBlocks(oldIndex, newIndex);

// 2. Pin calendar date to a day block (validates strictly increasing order)
try {
  await notifier.pinDate(dayId, '2027-05-01');
} on ArgumentError catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
}

// 3. Schedule a backlog stop into a day block
await notifier.scheduleStop(
  stopId,
  dayId,
  stayMinutes: 60,     // Default 60 mins
  transitMinutes: 15,  // Transit time to next stop
  fixedTime: 600,      // Optional fixed start time in minutes (600 = 10:00)
);

// 4. Remove schedule item (automatically moves stop back to backlog)
await notifier.removeScheduleItem(itemId);

// 5. Reorder schedule item within day or move across days
await notifier.reorderScheduleItem(
  itemId: itemId,
  newSortKey: newFractionalKey,
  targetDayId: newDayId, // Optional
);

// 6. Update schedule item status ('planned' | 'done' | 'skipped')
await notifier.updateScheduleItemStatus(itemId: itemId, status: 'done');
```

---

## 3. Join Shared Trip (`JoinTripController`)

Used in the "Join Trip" dialog or the deep link landing screen (`/join?code=...`).

### Import
```dart
import 'package:trip_planner/features/sharing/controllers/join_trip_controller.dart';
```

### Watching State & TextField Binding
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(joinTripControllerProvider);

  return Column(
    children: [
      // 6-Character code input field
      TextField(
        decoration: InputDecoration(
          labelText: 'Enter 6-character Code',
          errorText: state.errorMessage,
        ),
        onChanged: (val) {
          // Auto-sanitizes to uppercase and triggers preview fetch when 6 chars
          ref.read(joinTripControllerProvider.notifier).updateCode(val);
        },
      ),

      // Loading spinner while resolving preview
      if (state.isLoading) const CircularProgressIndicator(),

      // Live invite preview card
      if (state.invite != null) ...[
        Card(
          child: ListTile(
            title: Text(state.invite!.tripTitle),
            subtitle: Text('Invited by ${state.invite!.inviterName} • ${state.invite!.stopCount} spots'),
          ),
        ),
        ElevatedButton(
          onPressed: state.isJoining
              ? null
              : () async {
                  final member = await ref.read(joinTripControllerProvider.notifier).joinTrip();
                  if (member != null && context.mounted) {
                    context.go('/trips/${member.tripId}');
                  }
                },
          child: state.isJoining
              ? const CircularProgressIndicator()
              : const Text('Join Trip'),
        ),
      ],
    ],
  );
}
```

---

## 4. Offline Reference Image Cache (`ThumbnailCacheService`)

Used to cache anime reference images locally on disk so users have immediate access offline.

### Import
```dart
import 'package:trip_planner/core/providers/thumbnail_cache_provider.dart';
```

### Usage
```dart
final cacheService = ref.read(thumbnailCacheServiceProvider);

// Get cached image file or fetch if missing (deduplicates concurrent requests)
final File? imageFile = await cacheService.getThumbnail(imageUrl);

// Prefetch all reference images for a trip in the background
await cacheService.prefetchThumbnails([url1, url2, url3]);
```
