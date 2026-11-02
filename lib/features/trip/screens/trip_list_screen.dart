import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/app_result.dart';
import '../controllers/trips_controller.dart';
import '../providers/trip_list_providers.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_form_sheet.dart';

class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(tripSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Trips')),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text("Couldn't load your trips: $e", textAlign: TextAlign.center),
          ),
        ),
        data: (trips) {
          if (trips.isEmpty) return _EmptyTrips(onCreate: () => _createTrip(context, ref));
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: trips.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => TripCard(
                  summary: trips[i],
                  onTap: () => context.push('/trips/${trips[i].trip.id}'),
                ),
              ),
            ),
          );
        },
      ),
      // The empty state has its own button.
      floatingActionButton: (summaries.valueOrNull?.isEmpty ?? true)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createTrip(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New trip'),
            ),
    );
  }

  Future<void> _createTrip(BuildContext context, WidgetRef ref) async {
    final form = await showTripForm(context);
    if (form == null || !context.mounted) return;
    final result = await ref.read(tripsControllerProvider.notifier).createTrip(
          title: form.title,
          startDate: form.startDate,
          dayCount: form.dayCount,
        );
    if (!context.mounted) return;
    switch (result) {
      case Success(:final value):
        context.push('/trips/${value.id}');
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't create the trip: $error")),
        );
    }
  }
}

class _EmptyTrips extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyTrips({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.luggage_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No trips yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Name your trip and pick the dates, then add the spots you want to visit.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('New trip'),
            ),
          ],
        ),
      ),
    );
  }
}
