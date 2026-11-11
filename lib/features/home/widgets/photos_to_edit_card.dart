import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_theme.dart';
import '../../camera/providers/shooting_core_providers.dart';

/// Home's row for the photos kept on the spot and not edited yet, under the
/// top card; it opens the Photos to edit list. Nothing shows while there are
/// none.
class PhotosToEditCard extends ConsumerWidget {
  const PhotosToEditCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(photosToEditStreamProvider).valueOrNull?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final p = theme.trip;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        key: const Key('homePhotosToEdit'),
        elevation: 0,
        margin: EdgeInsets.zero,
        color: p.vermilionSoft,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(Icons.auto_fix_high_outlined, color: p.vermilion),
          title: Text(
            count == 1 ? '1 photo to edit' : '$count photos to edit',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Kept as shot on the spot'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/photos-to-edit'),
        ),
      ),
    );
  }
}
