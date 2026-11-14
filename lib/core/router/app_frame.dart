import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../database/connection/connection.dart' as db_connection;
import '../../features/camera/services/anime_camera_launcher.dart';

/// The main tabs, in the order of [AppFrame]'s branches.
enum AppTab {
  home('Home', Icons.home_outlined, Icons.home),
  trips('Trips', Icons.flight_takeoff_outlined, Icons.flight_takeoff),
  library('Library', Icons.bookmarks_outlined, Icons.bookmarks),
  photos('Photos', Icons.photo_library_outlined, Icons.photo_library);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const AppTab(this.label, this.icon, this.selectedIcon);
}

/// The app's frame (roadmap v0.4.0): a bottom bar on every main screen with
/// Home, Trips, Library and Photos, and Shoot as the big button in the middle.
/// Each tab keeps where it was while another is shown. Pages opened from a
/// tab (a trip, a place, the day map, the camera, the editor) open full screen
/// over the frame, and back returns to the tab they came from.
class AppFrame extends ConsumerWidget {
  final StatefulNavigationShell shell;

  const AppFrame({super.key, required this.shell});

  void _select(int index) {
    // Tapping the tab that's shown takes it back to its start.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = shell.currentIndex;
    final shoot = animeCameraSupported;

    return PopScope(
      // Back on another tab goes to Home first, then leaves the app.
      canPop: current == AppTab.home.index,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(AppTab.home.index);
      },
      child: Scaffold(
        body: Column(
          children: [
            const _WebStorageBanner(),
            Expanded(child: shell),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: shoot
            ? FloatingActionButton.large(
                key: const Key('appFrameShoot'),
                tooltip: 'Shoot',
                onPressed: () => openAnimeCamera(context, ref),
                child: const Icon(Icons.photo_camera),
              )
            : null,
        bottomNavigationBar: BottomAppBar(
          shape: shoot ? const CircularNotchedRectangle() : null,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              for (final tab in AppTab.values) ...[
                if (shoot && tab == AppTab.library) const SizedBox(width: 88),
                Expanded(
                  child: _TabButton(
                    tab: tab,
                    selected: tab.index == current,
                    onPressed: () => _select(tab.index),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final AppTab tab;
  final bool selected;
  final VoidCallback onPressed;

  const _TabButton({required this.tab, required this.selected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        key: Key('appTab:${tab.name}'),
        onTap: onPressed,
        radius: 40,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? tab.selectedIcon : tab.icon, color: color),
              const SizedBox(height: 2),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebStorageBanner extends StatefulWidget {
  const _WebStorageBanner();

  @override
  State<_WebStorageBanner> createState() => _WebStorageBannerState();
}

class _WebStorageBannerState extends State<_WebStorageBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<db_connection.WebStorageStatus?>(
      valueListenable: db_connection.webStorageStatusNotifier,
      builder: (context, status, _) {
        if (status == db_connection.WebStorageStatus.inMemory) {
          return MaterialBanner(
            backgroundColor: Colors.amber.shade900,
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.white),
            content: const Text(
              'Storage is in-memory only (e.g. private window). Places and trips will not be saved on this device across reloads.',
              style: TextStyle(color: Colors.white),
            ),
            actions: const [SizedBox.shrink()],
          );
        }
        if (status == db_connection.WebStorageStatus.unsafeIndexedDb && !_dismissed) {
          return MaterialBanner(
            backgroundColor: Colors.amber.shade800,
            leading: const Icon(Icons.info_outline, color: Colors.white),
            content: const Text(
              'Cross-tab lock is unavailable. Avoid editing in multiple browser tabs simultaneously to prevent data loss.',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => setState(() => _dismissed = true),
                child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
