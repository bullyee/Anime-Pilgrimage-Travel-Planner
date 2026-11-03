import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/library_entry.dart';

/// Background and foreground for a label kind: wisteria for anime, tea for
/// tags, neutral for regions.
(Color, Color) labelColors(ThemeData theme, String kind) {
  final p = theme.trip;
  return switch (kind) {
    'anime' => (p.wisteriaSoft, p.wisteria),
    'tag' => (p.teaSoft, p.tea),
    _ => (theme.colorScheme.surfaceContainerHighest, theme.colorScheme.onSurfaceVariant),
  };
}

IconData labelKindIcon(String kind) => switch (kind) {
      'anime' => Icons.movie_outlined,
      'tag' => Icons.sell_outlined,
      _ => Icons.public,
    };

/// A label as a small colored pill, removable when [onRemove] is set.
class LabelPill extends StatelessWidget {
  final Label label;
  final VoidCallback? onRemove;

  const LabelPill({super.key, required this.label, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = labelColors(theme, label.kind);
    return Container(
      padding: EdgeInsets.fromLTRB(10, 4, onRemove == null ? 10 : 4, 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(labelKindIcon(label.kind), size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
          if (onRemove != null)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: foreground, semanticLabel: 'Remove ${label.name}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Asks for a label to put on a place: a kind and a name, picked from the
/// existing labels of that kind or typed as a new one. Returns (kind, name).
Future<(String, String)?> showAddLabelSheet(
  BuildContext context, {
  required List<Label> labels,
  Set<String> exclude = const {},
}) {
  return showModalBottomSheet<(String, String)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddLabelSheet(labels: labels, exclude: exclude),
  );
}

class _AddLabelSheet extends StatefulWidget {
  final List<Label> labels;
  final Set<String> exclude;

  const _AddLabelSheet({required this.labels, required this.exclude});

  @override
  State<_AddLabelSheet> createState() => _AddLabelSheetState();
}

class _AddLabelSheetState extends State<_AddLabelSheet> {
  final _name = TextEditingController();
  String _kind = 'anime';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typed = _name.text.trim();
    final q = typed.toLowerCase();
    final matches = [
      for (final l in widget.labels)
        if (l.kind == _kind && !widget.exclude.contains(l.id) && (q.isEmpty || l.name.toLowerCase().contains(q))) l,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final exact = widget.labels.any((l) => l.kind == _kind && l.name.toLowerCase() == q);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('Add a label', style: theme.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SegmentedButton<String>(
                  segments: [
                    for (final kind in labelKinds)
                      ButtonSegment(value: kind, label: Text(labelKindTitle(kind)), icon: Icon(labelKindIcon(kind))),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: TextField(
                  key: const Key('labelNameField'),
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.search)),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (typed.isNotEmpty) Navigator.pop(context, (_kind, typed));
                  },
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (typed.isNotEmpty && !exact)
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: Text('Create “$typed”'),
                        onTap: () => Navigator.pop(context, (_kind, typed)),
                      ),
                    for (final l in matches)
                      ListTile(
                        leading: Icon(labelKindIcon(l.kind), color: labelColors(theme, l.kind).$2),
                        title: Text(l.name),
                        onTap: () => Navigator.pop(context, (l.kind, l.name)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
