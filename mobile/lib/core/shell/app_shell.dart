import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../providers/core_providers.dart';
import '../theme/app_colors.dart';

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

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

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

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  /// How often queued records are retried while the app is open. A change in
  /// the radio state is not the only way back online: the network can stay up
  /// the whole time the server is down, and nothing else would notice it
  /// coming back.
  static const Duration _retryInterval = Duration(minutes: 2);

  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).syncNow();
    });
    _startRetrying();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncServiceProvider).syncNow();
      _startRetrying();
    } else if (state == AppLifecycleState.paused) {
      _retryTimer?.cancel();
    }
  }

  void _startRetrying() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      _retryInterval,
      (_) => unawaited(ref.read(syncServiceProvider).syncNow()),
    );
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
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}
