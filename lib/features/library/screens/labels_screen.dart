import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../controllers/library_controller.dart';
import '../models/library_entry.dart';
import '../providers/library_providers.dart';
import '../providers/place_providers.dart';
import '../widgets/label_widgets.dart';

/// The labels places are grouped by, one tab per kind: create, rename, merge
/// and delete them.
class LabelsScreen extends ConsumerWidget {
  const LabelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: labelKinds.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Labels'),
          bottom: TabBar(tabs: [for (final kind in labelKinds) Tab(text: labelKindTitle(kind))]),
        ),
        body: TabBarView(children: [for (final kind in labelKinds) _LabelList(kind: kind)]),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () => _create(context, ref, labelKinds[DefaultTabController.of(context).index]),
            icon: const Icon(Icons.add),
            label: const Text('New label'),
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref, String kind) async {
    final name = await askLabelName(context, title: 'New ${_singular(kind)} label', action: 'Create');
    if (name == null || !context.mounted) return;
    final result = await ref.read(libraryControllerProvider.notifier).createLabel(kind: kind, name: name);
    if (!context.mounted) return;
    _report(context, result, ok: 'Created “$name”.');
  }
}

String _singular(String kind) => switch (kind) {
      'anime' => 'anime',
      'tag' => 'tag',
      _ => 'region',
    };

String _placesText(int n) => n == 1 ? '1 place' : '$n places';

void _report(BuildContext context, AppResult<dynamic> result, {String? ok}) {
  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case Failure(:final error):
      messenger.showSnackBar(SnackBar(content: Text(error)));
    case Success():
      if (ok != null) messenger.showSnackBar(SnackBar(content: Text(ok)));
  }
}

class _LabelList extends ConsumerWidget {
  final String kind;

  const _LabelList({required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labelsAsync = ref.watch(labelsListProvider(kind));
    final counts = ref.watch(labelPlaceCountsProvider);
    final (background, foreground) = labelColors(theme, kind);

    return labelsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Couldn't load the labels: $e")),
      data: (labels) {
        if (labels.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No ${labelKindTitle(kind).toLowerCase()} yet. Add labels on a place, or create them here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }
        final sorted = [...labels]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final l in sorted)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: background,
                  foregroundColor: foreground,
                  child: Icon(labelKindIcon(kind), size: 20),
                ),
                title: Text(l.name),
                subtitle: Text(_placesText(counts[l.id] ?? 0)),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Label options',
                  onSelected: (action) => switch (action) {
                    'rename' => _rename(context, ref, l),
                    'merge' => _merge(context, ref, l, sorted),
                    _ => _delete(context, ref, l, counts[l.id] ?? 0),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'merge', enabled: sorted.length > 1, child: const Text('Merge into…')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => _rename(context, ref, l),
              ),
          ],
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Label label) async {
    final name = await askLabelName(context, title: 'Rename label', action: 'Rename', initial: label.name);
    if (name == null || name == label.name || !context.mounted) return;
    final result = await ref.read(libraryControllerProvider.notifier).renameLabel(label.id, name);
    if (!context.mounted) return;
    switch (result) {
      case Success(:final value) when value.id != label.id:
        _report(context, result, ok: '“${value.name}” already existed, so the two were merged.');
      case _:
        _report(context, result, ok: 'Renamed to “$name”.');
    }
  }

  Future<void> _merge(BuildContext context, WidgetRef ref, Label source, List<Label> all) async {
    final target = await showModalBottomSheet<Label>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Merge “${source.name}” into…', style: Theme.of(context).textTheme.titleLarge),
              ),
              for (final l in all)
                if (l.id != source.id)
                  ListTile(
                    leading: Icon(labelKindIcon(l.kind)),
                    title: Text(l.name),
                    onTap: () => Navigator.pop(context, l),
                  ),
            ],
          ),
        ),
      ),
    );
    if (target == null || !context.mounted) return;
    final result = await ref.read(libraryControllerProvider.notifier).mergeLabels(source: source, target: target);
    if (!context.mounted) return;
    _report(context, result, ok: 'Merged “${source.name}” into “${target.name}”.');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Label label, int places) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${label.name}”?'),
        content: Text(places == 0 ? 'No place has this label.' : 'It comes off ${_placesText(places)}. The places stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(libraryControllerProvider.notifier).deleteLabel(label.id);
    if (!context.mounted) return;
    _report(context, result, ok: 'Deleted “${label.name}”.');
  }
}

/// Asks for a label name. Returns it trimmed, or null when cancelled.
Future<String?> askLabelName(BuildContext context, {required String title, required String action, String initial = ''}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, action: action, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  final String title;
  final String action;
  final String initial;

  const _NameDialog({required this.title, required this.action, required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('labelDialogField'),
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
