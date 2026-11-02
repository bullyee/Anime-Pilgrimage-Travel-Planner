import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../controllers/trips_controller.dart';

/// What the trip form returns: the name, an optional start date and, for a
/// new trip, the number of days.
class TripFormResult {
  final String title;
  final DateTime? startDate;
  final int dayCount;

  const TripFormResult({required this.title, this.startDate, required this.dayCount});
}

/// Shows the new-trip form, or the edit form when [editing] is given. The day
/// count is only asked for a new trip; afterwards days are added and removed
/// in the planner.
Future<TripFormResult?> showTripForm(BuildContext context, {Trip? editing}) {
  return showModalBottomSheet<TripFormResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TripFormSheet(editing: editing),
  );
}

class TripFormSheet extends StatefulWidget {
  final Trip? editing;

  const TripFormSheet({super.key, this.editing});

  @override
  State<TripFormSheet> createState() => _TripFormSheetState();
}

class _TripFormSheetState extends State<TripFormSheet> {
  late final TextEditingController _title;
  DateTime? _startDate;
  int _dayCount = 3;
  String? _titleError;

  bool get _isNew => widget.editing == null;

  @override
  void initState() {
    super.initState();
    final trip = widget.editing;
    _title = TextEditingController(text: trip?.title ?? '');
    _startDate = trip?.startDate == null ? null : DateTime.tryParse(trip!.startDate!);
    if (trip != null) _dayCount = trip.dayCount;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5, 12, 31),
      helpText: 'First day of the trip',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give the trip a name.');
      return;
    }
    Navigator.of(context).pop(
      TripFormResult(title: title, startDate: _startDate, dayCount: _dayCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = _startDate;
    final lastDay = start == null ? null : start.add(Duration(days: _dayCount - 1));

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_isNew ? 'New trip' : 'Edit trip', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('tripTitleField'),
            controller: _title,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Kyoto pilgrimage',
              errorText: _titleError,
            ),
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          _FieldRow(
            label: 'Start date',
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('tripStartDateButton'),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text(
                      start == null ? 'Decide later' : DateFormat.yMMMEd().format(start),
                    ),
                  ),
                ),
                if (start != null)
                  IconButton(
                    tooltip: 'Clear the start date',
                    onPressed: () => setState(() => _startDate = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          if (_isNew) ...[
            const SizedBox(height: 12),
            _FieldRow(
              label: 'Days',
              child: Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'One day fewer',
                    onPressed: _dayCount > 1 ? () => setState(() => _dayCount--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '$_dayCount',
                      key: const Key('tripDayCount'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'One more day',
                    onPressed: _dayCount < TripsController.maxDays
                        ? () => setState(() => _dayCount++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _isNew
                ? lastDay == null
                    ? 'You can set the dates later. Days can be added or removed in the planner.'
                    : 'Ends ${DateFormat.MMMEd().format(lastDay)}. Days can be added or removed in the planner.'
                : 'Days are added and removed in the planner.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('tripFormSubmit'),
                onPressed: _submit,
                child: Text(_isNew ? 'Create trip' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        Expanded(child: child),
      ],
    );
  }
}
