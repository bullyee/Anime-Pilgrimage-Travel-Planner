import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

/// Who the trip is shared with. A placeholder until group sharing (#83)
/// lands: invites by link, QR code or short code, and owner / editor /
/// viewer roles.
class TripMembersTab extends StatelessWidget {
  const TripMembersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.trip;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: p.wisteriaSoft, shape: BoxShape.circle),
                child: Icon(Icons.group_outlined, size: 44, color: p.wisteria),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: p.wisteriaSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  'In development',
                  style: theme.textTheme.labelLarge?.copyWith(color: p.wisteria, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text('Plan this trip together', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Invite friends with a link, a QR code or a short code, and choose who can edit and who can only view.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
