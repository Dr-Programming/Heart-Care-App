import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'offline_banner.dart';

/// The page frame every screen uses.
///
/// Three things it centralises so five people's screens stay one app:
///
///  * the cream header band from the Figma frames, and the 30dp gutter that
///    gives the 342dp content column the design was drawn against;
///  * the offline / pending-sync strip, which appears on every screen without
///    anyone having to remember it;
///  * consistent back-button and title treatment.
///
/// Use `AppScaffold.banded` for a screen that opens a flow (login, a wizard
/// step, a tab root); the plain constructor for everything nested below one.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.title,
    this.actions,
    this.showBack = true,
    this.bottomBar,
    this.floatingActionButton,
    this.scrollable = false,
    this.padded = true,
    this.backgroundColor,
    super.key,
  }) : bandHeight = 0,
       bandChild = null;

  /// A screen topped by the brand's cream band.
  const AppScaffold.banded({
    required this.body,
    this.bandChild,
    this.bandHeight = AppSpacing.headerBandHeight,
    this.title,
    this.actions,
    this.showBack = true,
    this.bottomBar,
    this.floatingActionButton,
    this.scrollable = true,
    this.padded = true,
    this.backgroundColor,
    super.key,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final bool showBack;

  /// Pinned to the bottom, outside the scroll area — where a form's primary
  /// action goes so it stays reachable with the keyboard open.
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// Wraps [body] in a scroll view. Leave false when the body is itself a
  /// `ListView`, or the list will be unbounded.
  final bool scrollable;

  /// Applies the design's 30dp side gutter.
  final bool padded;
  final Color? backgroundColor;
  final double bandHeight;
  final Widget? bandChild;

  bool get _hasBand => bandHeight > 0;

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    Widget content = body;
    if (padded) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: content,
      );
    }
    if (scrollable) {
      content = SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.surface,
      appBar: !_hasAppBar
          ? null
          : AppBar(
              backgroundColor: _hasBand
                  ? AppColors.headerBand
                  : AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              automaticallyImplyLeading: showBack && canPop,
              title: title == null ? null : Text(title!),
              titleTextStyle: Theme.of(context).textTheme.headlineMedium,
              actions: actions,
            ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.lg,
              ),
              child: bottomBar!,
            ),
      body: Column(
        children: <Widget>[
          // A screen with a real AppBar (`title != null || showBack`) gets
          // its status-bar inset for free — the AppBar itself sits below it,
          // and this Column starts only after that. A screen with no AppBar
          // at all (`AppScaffold.banded(showBack: false, ...)`, used when a
          // feature draws its own back arrow/title inside the band instead)
          // has nothing else reserving that space, so without this the
          // offline banner and the band below it painted straight under the
          // system status bar, colliding with its time/wifi/battery icons.
          // Gating on `_hasAppBar` rather than wrapping unconditionally
          // matters: every existing `showBack: true` screen already has an
          // AppBar handling this, and wrapping those too would double the
          // inset, pushing their content down a second time.
          if (_hasAppBar)
            _bandColumn
          else
            SafeArea(top: true, bottom: false, child: _bandColumn),
          Expanded(child: SafeArea(top: false, child: content)),
        ],
      ),
    );
  }

  bool get _hasAppBar => title != null || showBack;

  Widget get _bandColumn => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      const OfflineBanner(),
      if (_hasBand)
        Container(
          width: double.infinity,
          height: bandHeight,
          color: AppColors.headerBand,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: bandChild,
        ),
    ],
  );
}
