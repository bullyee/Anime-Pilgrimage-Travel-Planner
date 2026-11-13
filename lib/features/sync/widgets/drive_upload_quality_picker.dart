import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/drive_upload_quality_provider.dart';
import '../services/drive_upload_quality.dart';

/// The upload quality choices as radio rows. A choice is saved at once and
/// used for every upload after it (also by the upload dialogs).
class DriveUploadQualityOptions extends ConsumerWidget {
  const DriveUploadQualityOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = ref.watch(driveUploadQualityProvider);
    return RadioGroup<DriveUploadQuality>(
      groupValue: quality,
      onChanged: (q) {
        if (q != null) ref.read(driveUploadQualityProvider.notifier).choose(q);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final q in DriveUploadQuality.values)
            RadioListTile<DriveUploadQuality>(
              key: ValueKey('driveUploadQuality-${q.name}'),
              value: q,
              contentPadding: EdgeInsets.zero,
              title: Text(q.label),
              subtitle: Text(q.detail),
            ),
        ],
      ),
    );
  }
}

/// Settings → Frame upload quality.
Future<void> showDriveUploadQualityPicker(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Frame upload quality'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For frames you share with a trip through your Google Drive. '
                'Trip members see the frames at this quality.'),
            SizedBox(height: 8),
            DriveUploadQualityOptions(),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    ),
  );
}
