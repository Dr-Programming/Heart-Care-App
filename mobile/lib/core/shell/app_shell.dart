import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../providers/core_providers.dart';
import '../theme/app_colors.dart';

/// One bottom-navigation destination.
class ShellTab {
  const ShellTab({
    required this.labelKey,
    required this.icon,
    required this.activeIcon,
  });

  final String labelKey;
  final IconData icon;
  final IconData activeIcon;
}

/// The signed-in frame: five tabs, each keeping its own navigation stack.
///
/// The tab set is fixed by the foundation slice so five feature branches never
/// renegotiate the navigation bar. Each tab's *contents* come from the feature
/// that owns it, registered in `lib/app/app_wiring.dart`.
///
/// Iconsax "linear" matches the Figma icon set exactly, and Iconsax "bold" is
/// used for the active tab — a shape change rather than colour alone, so the
/// current tab is still obvious on a washed-out screen in daylight
/// (FR-LOC-008).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// Order here is the order of the branches in `app_router.dart`. Changing
  /// one without the other silently sends users to the wrong tab.
  static const List<ShellTab> tabs = <ShellTab>[
    ShellTab(
      labelKey: 'nav.home',
      icon: Iconsax.home_2,
      activeIcon: Iconsax.home_25,
    ),
    ShellTab(
      labelKey: 'nav.medications',
      icon: Iconsax.health,
      activeIcon: Iconsax.health5,
    ),
    ShellTab(
      labelKey: 'nav.vitals',
      icon: Iconsax.activity,
      activeIcon: Iconsax.activity5,
    ),
    ShellTab(
      labelKey: 'nav.checkIn',
      icon: Iconsax.clipboard_text,
      activeIcon: Iconsax.clipboard_text5,
    ),
    ShellTab(
      labelKey: 'nav.learn',
      icon: Iconsax.book_1,
      activeIcon: Iconsax.book_15,
    ),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Reading the provider constructs the service, which subscribes to
    // connectivity and drains the queue on reconnect (FR-OFF-004). The shell
    // is the right place: it is mounted for the whole signed-in session and
    // torn down on sign-out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).syncNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        // 44dp minimum tap targets (FR-LOC-006); the default height is
        // already above that, but pin it so a theme change cannot shrink it.
        height: 68,
        destinations: <NavigationDestination>[
          for (final ShellTab tab in AppShell.tabs)
            NavigationDestination(
              icon: Icon(tab.icon, color: AppColors.textSecondary),
              selectedIcon: Icon(tab.activeIcon, color: AppColors.ink),
              label: tab.labelKey.tr(),
            ),
        ],
      ),
    );
  }

  void _onTap(int index) {
    // Tapping the tab you are already on pops that tab back to its root —
    // the behaviour users expect, and the cheapest escape from a deep stack.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}
