import 'package:flutter/material.dart';

import '../models/place_diff.dart';

/// Which side of a [PlaceDiff] is the user's, on the page showing it.
///
/// On a place's page the place is the user's (the diff's local side) and
/// Anitabi the other. On a stop's page the stop is (the diff's remote side)
/// and the library the other.
class CompareSides {
  /// "Your place", "This stop".
  final String mine;

  /// "Anitabi", "Your library".
  final String other;

  /// True when the user's side is the diff's remote side.
  final bool mineIsRemote;

  const CompareSides({required this.mine, required this.other, required this.mineIsRemote});

  static const anitabi = CompareSides(mine: 'Your place', other: 'Anitabi', mineIsRemote: false);
  static const library = CompareSides(mine: 'This stop', other: 'Your library', mineIsRemote: true);

  String? mineValue(PlaceFieldDiff d) => mineIsRemote ? d.remoteValue : d.localValue;
  String? otherValue(PlaceFieldDiff d) => mineIsRemote ? d.localValue : d.remoteValue;

  /// Compass direction from the user's side to the other side. The diff
  /// measures from its local side to its remote side.
  String? directionToOther(PlaceFieldDiff d) => d.direction == null
      ? null
      : mineIsRemote
          ? _opposite[d.direction!] ?? d.direction
          : d.direction;

  static const _opposite = {'N': 'S', 'NE': 'SW', 'E': 'W', 'SE': 'NW', 'S': 'N', 'SW': 'NE', 'W': 'E', 'NW': 'SE'};
}

String _distance(double meters) => meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

const _fieldNouns = {
  PlaceFieldType.name: 'name',
  PlaceFieldType.description: 'description',
  PlaceFieldType.address: 'address',
  PlaceFieldType.businessHours: 'opening hours',
  PlaceFieldType.contactInfo: 'contact',
  PlaceFieldType.accessTips: 'way to get there',
  PlaceFieldType.links: 'links',
  PlaceFieldType.sourceUrl: 'source link',
};

/// The hint's one line: "Anitabi moved this spot 120 m SE",
/// "Your library has a different note", "Anitabi has 3 changes to this spot".
String compareHintText(PlaceDiff diff, CompareSides sides) {
  final location = diff.locationDiff;
  final others = diff.differences.where((d) => d.field != PlaceFieldType.location).toList();
  final String lead;
  if (location != null) {
    final where = '${_distance(location.distanceMeters ?? 0)} ${sides.directionToOther(location) ?? ''}'.trim();
    lead = sides.mineIsRemote ? '${sides.other} puts this spot $where' : '${sides.other} moved this spot $where';
    if (others.isEmpty) return lead;
    return '$lead, and ${others.length == 1 ? 'a different ${_fieldNouns[others.single.field]}' : '${others.length} more differences'}';
  }
  if (others.length == 1) return '${sides.other} has a different ${_fieldNouns[others.single.field]}';
  return sides.mineIsRemote
      ? '${sides.other} differs in ${others.length} things'
      : '${sides.other} has ${others.length} changes to this spot';
}

/// One tappable line under a page's title when the other version of the
/// place differs. Opens [showCompareSheet].
class PlaceCompareHint extends StatelessWidget {
  final PlaceDiff diff;
  final CompareSides sides;
  final VoidCallback onTap;

  const PlaceCompareHint({super.key, required this.diff, required this.sides, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('placeCompareHint'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(diff.hasLocationMoved ? Icons.wrong_location_outlined : Icons.compare_arrows, size: 20, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  compareHintText(diff, sides),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                ),
              ),
              Text('Compare', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
              Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a Keep mine or Use this did: null when it worked, else the message.
typedef CompareAction = Future<String?> Function(PlaceFieldDiff d);

/// The side-by-side: each field that differs, the user's value next to the
/// other one, with **Keep mine** and **Use this**. Without [onUse] (a viewer
/// of a shared trip) only Keep mine is offered. Closes when every field is
/// answered.
Future<void> showCompareSheet(
  BuildContext context, {
  required PlaceDiff diff,
  required CompareSides sides,
  required CompareAction onKeep,
  CompareAction? onUse,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CompareSheet(diff: diff, sides: sides, onKeep: onKeep, onUse: onUse),
  );
}

class _CompareSheet extends StatefulWidget {
  final PlaceDiff diff;
  final CompareSides sides;
  final CompareAction onKeep;
  final CompareAction? onUse;

  const _CompareSheet({required this.diff, required this.sides, required this.onKeep, this.onUse});

  @override
  State<_CompareSheet> createState() => _CompareSheetState();
}

class _CompareSheetState extends State<_CompareSheet> {
  late final List<PlaceFieldDiff> _left = [...widget.diff.differences];
  PlaceFieldType? _busy;

  Future<void> _answer(PlaceFieldDiff d, CompareAction action) async {
    setState(() => _busy = d.field);
    final error = await action(d);
    if (!mounted) return;
    setState(() {
      _busy = null;
      if (error == null) _left.remove(d);
    });
    if (error != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(error)));
    } else if (_left.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sides = widget.sides;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('${sides.mine} and ${sides.other.replaceFirst('Your ', 'your ')}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.onUse == null
                  ? 'You can only view this trip, so its stop stays as it is.'
                  : 'Use this copies ${sides.other == 'Anitabi' ? "Anitabi's" : "your library's"} value into ${sides.mine.toLowerCase()}. '
                      'Keep mine stops showing the difference.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final d in _left) ...[
              _FieldRow(
                diff: d,
                sides: sides,
                busy: _busy == d.field,
                onKeep: _busy != null ? null : () => _answer(d, widget.onKeep),
                onUse: widget.onUse == null || _busy != null ? null : () => _answer(d, widget.onUse!),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final PlaceFieldDiff diff;
  final CompareSides sides;
  final bool busy;
  final VoidCallback? onKeep;
  final VoidCallback? onUse;

  const _FieldRow({required this.diff, required this.sides, required this.busy, this.onKeep, this.onUse});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocation = diff.field == PlaceFieldType.location;
    Widget value(String title, String? text) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  text ?? 'Nothing',
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: text == null
                      ? theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant)
                      : theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
    return Column(
      key: Key('compareRow-${diff.field.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(diff.fieldLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (isLocation && diff.distanceMeters != null)
          Text(
            '${sides.other}: ${_distance(diff.distanceMeters!)} ${sides.directionToOther(diff) ?? ''} of ${sides.mine.toLowerCase()}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: 6),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              value(sides.mine, sides.mineValue(diff)),
              const SizedBox(width: 8),
              value(sides.other, sides.otherValue(diff)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (busy) const Padding(padding: EdgeInsets.all(8), child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            TextButton(key: Key('keepMine-${diff.field.name}'), onPressed: onKeep, child: const Text('Keep mine')),
            if (onUse != null || busy) ...[
              const SizedBox(width: 4),
              FilledButton.tonal(key: Key('useThis-${diff.field.name}'), onPressed: onUse, child: const Text('Use this')),
            ],
          ],
        ),
      ],
    );
  }
}
