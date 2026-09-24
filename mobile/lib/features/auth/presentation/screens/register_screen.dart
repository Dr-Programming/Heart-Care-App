import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/network/server_reachability.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/pin_box_input.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String? _pin;
  AppLanguage _selectedLanguage = AppLanguage.en;

  String? _phoneErrorKey;
  String? _nameErrorKey;
  String? _pinErrorKey;

  @override
  void initState() {
    super.initState();
    // Re-check on every visit. The provider is not auto-disposed, so a patient
    // who backs out, turns their data on and comes back would otherwise be
    // met by the stale "no connection" answer from their first visit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The first read is what creates the provider, and creating it already
      // starts a probe; only a provider that has settled needs a new one.
      if (ref.read(serverReachabilityProvider) != ServerReachability.checking) {
        unawaited(ref.read(serverReachabilityProvider.notifier).refresh());
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Tapping anything on a blocked form says why, and quietly re-probes — so
  /// the form unlocks itself the moment the connection comes back, without the
  /// patient having to find the "try again" button.
  void _reportBlocked(ServerReachability reachability) {
    final String? key = reachability.messageKey;
    if (key == null) return;
    showAppToast(
      context,
      key.tr(),
      icon: reachability == ServerReachability.noInternet
          ? Icons.wifi_off_rounded
          : Icons.cloud_off_rounded,
      isError: reachability != ServerReachability.checking,
    );
    if (reachability != ServerReachability.checking) {
      unawaited(ref.read(serverReachabilityProvider.notifier).refresh());
    }
  }

  Future<void> _submit() async {
    final ServerReachability reachability = ref.read(
      serverReachabilityProvider,
    );
    if (!reachability.isOnline) {
      _reportBlocked(reachability);
      return;
    }

    final String? phoneKey = validatePhone(_phoneController.text.trim());
    final String? nameKey = validateName(_nameController.text);
    final String? pinKey = _pin == null
        ? 'auth.errors.pinRequired'
        : validatePin(_pin!);
    setState(() {
      _phoneErrorKey = phoneKey;
      _nameErrorKey = nameKey;
      _pinErrorKey = pinKey;
    });
    if (phoneKey != null || nameKey != null || pinKey != null) return;

    await ref
        .read(authControllerProvider.notifier)
        .register(
          phone: _phoneController.text.trim(),
          pin: _pin!,
          name: _nameController.text.trim(),
          preferredLanguage: _selectedLanguage.code,
        );

    if (!mounted) return;
    final AsyncValue<AuthState> asyncState = ref.read(authControllerProvider);
    if (asyncState.hasValue && (asyncState.value?.isAuthenticated ?? false)) {
      if (GoRouter.maybeOf(context) != null) {
        context.goNamed(AppRoutes.home);
      }
      return;
    }
    // The probe said the server was there a moment ago and the request still
    // could not reach it. Re-probe so the form locks itself rather than
    // letting the patient retype into a connection that is gone.
    if (asyncState.error is NetworkFailure) {
      unawaited(ref.read(serverReachabilityProvider.notifier).refresh());
    }
  }

  String? _errorMessage(AsyncValue<AuthState> asyncState) {
    if (!asyncState.hasError) return null;
    final Object? error = asyncState.error;
    if (error is PhoneAlreadyRegisteredFailure) {
      return 'auth.errors.phoneTaken'.tr();
    }
    if (error is NetworkFailure) {
      return 'errors.offline'.tr();
    }
    return 'errors.generic'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthState> asyncState = ref.watch(authControllerProvider);
    final bool isLoading = asyncState.isLoading;
    final String? formError = _errorMessage(asyncState);
    final TextTheme text = Theme.of(context).textTheme;

    // Registration is the one thing this app cannot do offline: the account
    // only exists once the server has written it. So instead of letting the
    // patient fill in three fields and then losing them to an error, the form
    // is sealed until the server has actually answered.
    final ServerReachability reachability = ref.watch(
      serverReachabilityProvider,
    );
    final bool blocked = !reachability.isOnline;

    return AppScaffold.banded(
      showBack: false,
      bandChild: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            // Popping the only page on the stack leaves a black screen, so
            // fall back to login when this screen was reached with `go`.
            onPressed: () => context.canPop()
                ? context.pop()
                : context.goNamed(AppRoutes.login),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('auth.register.title'.tr(), style: text.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('auth.register.subtitle'.tr(), style: text.bodyMedium),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          if (blocked) ...<Widget>[
            _ConnectionNotice(
              reachability: reachability,
              onRetry: () =>
                  ref.read(serverReachabilityProvider.notifier).refresh(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _BlockedFormGate(
            blocked: blocked,
            onBlockedTap: () => _reportBlocked(reachability),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  label: 'auth.login.phone'.tr(),
                  controller: _phoneController,
                  hint: 'auth.login.phoneHint'.tr(),
                  errorText: _phoneErrorKey?.tr(),
                  enabled: !blocked,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.call_outlined,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_phoneErrorKey != null) {
                      setState(() => _phoneErrorKey = null);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('auth.login.pin'.tr(), style: text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                PinBoxInput(
                  errorText: _pinErrorKey?.tr(),
                  enabled: !blocked,
                  onCompleted: (String pin) {
                    setState(() {
                      _pin = pin;
                      _pinErrorKey = null;
                    });
                  },
                  onIncomplete: () => setState(() => _pin = null),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'auth.register.name'.tr(),
                  controller: _nameController,
                  hint: 'auth.register.nameHint'.tr(),
                  errorText: _nameErrorKey?.tr(),
                  enabled: !blocked,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_nameErrorKey != null) {
                      setState(() => _nameErrorKey = null);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'auth.register.preferredLanguage'.tr(),
                  style: text.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    for (final AppLanguage language
                        in AppLanguage.values) ...<Widget>[
                      if (language != AppLanguage.values.first)
                        const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _LanguageOption(
                          label: language.nativeLabel,
                          selected: _selectedLanguage == language,
                          onTap: () =>
                              setState(() => _selectedLanguage = language),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (formError != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              formError,
              style: text.bodyMedium?.copyWith(color: AppColors.critical),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('registerSubmitButton'),
              // Stays pressable while blocked — a dead button explains nothing,
              // whereas `_submit` turns the press into the toast that does.
              onPressed: isLoading ? null : _submit,
              style: blocked
                  ? FilledButton.styleFrom(
                      backgroundColor: AppColors.borderStrong,
                      foregroundColor: AppColors.surface,
                    )
                  : null,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('auth.register.submit'.tr()),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: Alignment.center,
            child: Wrap(
              alignment: WrapAlignment.center,
              children: <Widget>[
                Text('auth.register.haveAccount'.tr(), style: text.bodyMedium),
                AppButton(
                  label: 'auth.register.signIn'.tr(),
                  variant: AppButtonVariant.text,
                  expand: false,
                  onPressed: () => context.goNamed(AppRoutes.login),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seals the sign-up fields while the server is out of reach.
///
/// The fields are already passed `enabled: false`, which is what truly stops
/// the typing — a disabled field refuses focus, so no keyboard can come up over
/// it. This adds the part that disabling alone cannot: a disabled `TextField`
/// ignores pointers, so a tap on it would vanish silently and leave the patient
/// with nothing but a form that does not respond.
///
/// So the tap is caught instead. The transparent layer sits above the whole
/// group and turns every press anywhere on it into the toast that says why.
/// [AbsorbPointer] underneath is belt-and-braces for the parts of the group
/// that have no `enabled` flag of their own — the language buttons.
class _BlockedFormGate extends StatelessWidget {
  const _BlockedFormGate({
    required this.blocked,
    required this.onBlockedTap,
    required this.child,
  });

  final bool blocked;
  final VoidCallback onBlockedTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!blocked) return child;

    return Semantics(
      enabled: false,
      child: Stack(
        children: <Widget>[
          // Dimmed so the form reads as "not yet", not as broken.
          Opacity(opacity: 0.6, child: AbsorbPointer(child: child)),
          Positioned.fill(
            child: GestureDetector(
              key: const Key('registerBlockedOverlay'),
              behavior: HitTestBehavior.opaque,
              onTap: onBlockedTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// The standing explanation above the sealed form, with a way out.
///
/// The toast says the same thing, but it disappears; a patient who looked away
/// for a moment would be left with a dimmed form and no reason for it.
class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice({required this.reachability, required this.onRetry});

  final ServerReachability reachability;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool isChecking = reachability == ServerReachability.checking;
    final Color foreground = isChecking
        ? AppColors.textSecondary
        : AppColors.critical;
    final Color background = isChecking
        ? AppColors.surfaceAlt
        : AppColors.criticalBg;

    return Container(
      key: const Key('registerConnectionNotice'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // A spinner would read better here, but it never stops animating,
          // and a screen that never settles makes `pumpAndSettle` time out in
          // every widget test that touches this form. The state is brief and
          // the text already says it is in progress.
          Icon(
            switch (reachability) {
              ServerReachability.noInternet => Icons.wifi_off_rounded,
              ServerReachability.checking => Icons.sync_rounded,
              _ => Icons.cloud_off_rounded,
            },
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (reachability.messageKey ?? 'errors.generic').tr(),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: foreground),
                ),
                if (!isChecking)
                  AppButton(
                    key: const Key('registerRetryConnectionButton'),
                    label: 'errors.tryAgain'.tr(),
                    variant: AppButtonVariant.text,
                    expand: false,
                    onPressed: onRetry,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.borderStrong,
          ),
        ),
        child: Text(
          label,
          style: text.titleMedium?.copyWith(
            color: selected ? AppColors.surface : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
