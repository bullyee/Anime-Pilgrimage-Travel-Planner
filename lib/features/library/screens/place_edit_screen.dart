import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_result.dart';
import '../controllers/place_controller.dart';
import '../providers/place_providers.dart';

/// Edits a library place's facts. Trips that already have the place keep
/// their own copy.
class PlaceEditScreen extends ConsumerStatefulWidget {
  final String placeKey;

  const PlaceEditScreen({super.key, required this.placeKey});

  @override
  ConsumerState<PlaceEditScreen> createState() => _PlaceEditScreenState();
}

class _PlaceEditScreenState extends ConsumerState<PlaceEditScreen> {
  final _fields = <String, TextEditingController>{};
  bool _loaded = false;
  bool _saving = false;
  String? _nameError;

  TextEditingController _field(String key) => _fields.putIfAbsent(key, TextEditingController.new);

  void _load(Place place) {
    if (_loaded) return;
    _loaded = true;
    _field('name').text = place.name;
    _field('address').text = place.address ?? '';
    _field('access').text = place.accessTips ?? '';
    _field('about').text = place.description ?? '';
    _field('hours').text = place.businessHours ?? '';
    _field('contact').text = place.contactInfo ?? '';
    _field('links').text = place.links ?? '';
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_field('name').text.trim().isEmpty) {
      setState(() => _nameError = 'Give the place a name.');
      return;
    }
    setState(() => _saving = true);
    final result = await ref.read(placeControllerProvider.notifier).updateFacts(
          widget.placeKey,
          PlaceFacts(
            name: _field('name').text,
            address: _field('address').text,
            accessTips: _field('access').text,
            description: _field('about').text,
            businessHours: _field('hours').text,
            contactInfo: _field('contact').text,
            links: _field('links').text,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/library/places/${Uri.encodeComponent(widget.placeKey)}');
        }
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = ref.watch(placeDetailProvider(widget.placeKey)).valueOrNull;
    if (place == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    _load(place);

    Widget field(String key, String label, {int lines = 1, String? hint, String? error}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: Key('placeField_$key'),
            controller: _field(key),
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label, hintText: hint, errorText: error),
            onChanged: key == 'name' && _nameError != null ? (_) => setState(() => _nameError = null) : null,
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Edit this spot')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'These are your own copy of the facts. Trips that already have this spot keep theirs.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          field('name', 'Name', error: _nameError),
          field('address', 'Address'),
          field('access', 'Getting there', lines: 3, hint: 'Nearest station, where to stand, the best time of day'),
          field('about', 'About', lines: 3),
          field('hours', 'Hours'),
          field('contact', 'Contact'),
          field('links', 'Links', lines: 2, hint: 'One link per line'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ),
      ),
    );
  }
}
