import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'offline_banner.dart';

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

  final Widget? bottomBar;
  final Widget? floatingActionButton;

  final bool scrollable;

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
        Stack(
          children: <Widget>[
            Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: bandHeight),
              color: AppColors.headerBand,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xs,
                AppSpacing.gutter,
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Image.asset(
                      'assets/images/logo_band.png',
                      height: 52,
                    ),
                  ),
                  ?bandChild,
                ],
              ),
            ),
            if (!_hasAppBar && actions != null && actions!.isNotEmpty)
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.sm,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ),
          ],
        ),
    ],
  );
}
