import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        body: shell,
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
