import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../sharing/providers/group_sharing_providers.dart';
import '../../sharing/widgets/signed_out_trip_notice.dart';
import '../models/stop_group.dart';
import '../providers/trip_place_providers.dart';
import '../providers/trip_providers.dart';

/// Offers to turn a trip's groups of stops into places
/// ([PlaceFoldService.foldTrip]) to the people who can edit it, while it has
/// any. Private trips are folded once by themselves when this version first
/// runs, so this mostly shows on shared trips, where a member has to choose
/// to: everyone's plan changes. A shared trip folds only while signed in and
/// with nothing waiting to upload, so the stop each group keeps is picked
/// from the plan everyone has.
class PlaceFoldBanner extends ConsumerStatefulWidget {
  final Trip trip;

  const PlaceFoldBanner({super.key, required this.trip});

  @override
  ConsumerState<PlaceFoldBanner> createState() => _PlaceFoldBannerState();
}

class _PlaceFoldBannerState extends ConsumerState<PlaceFoldBanner> {
  bool _busy = false;

  Future<void> _fold() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(placeFoldServiceProvider);
    final shared = widget.trip.sharing == 'group';
    if (shared && ref.read(signedOutProvider)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.placeFoldNeedsSignIn)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.placeFoldConfirmTitle),
        content: Text(l10n.placeFoldConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const Key('placeFoldConfirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.placeFoldBannerAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (shared && await service.hasUnsyncedChanges(widget.trip.id)) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.placeFoldNeedsSync)));
        return;
      }
      final count = await service.foldTrip(widget.trip.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.placeFoldDone(count))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.placeFoldFailed('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(canEditTripProvider(widget.trip.id));
    final stops = ref.watch(tripStopsProvider(widget.trip.id)).valueOrNull ?? const <Stop>[];
    if (!canEdit || !stops.any((s) => stopGroup(s) != null)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      key: const Key('placeFoldBanner'),
      width: double.infinity,
      color: theme.trip.teaSoft,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 18, color: theme.trip.tea),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.placeFoldBannerText, style: theme.textTheme.bodySmall)),
          TextButton(
            onPressed: _busy ? null : _fold,
            child: Text(l10n.placeFoldBannerAction),
          ),
        ],
      ),
    );
  }
}
