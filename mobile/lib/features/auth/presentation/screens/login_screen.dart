import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_failure_text.dart';
import '../widgets/phone_field.dart';
import '../widgets/pin_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phone = TextEditingController(text: '+251');
  final TextEditingController _pin = TextEditingController();

  String? _phoneError;
  String? _pinError;
  bool _submitting = false;

  /// Held locally rather than read from `authControllerProvider.error` so a
  /// failed login here can never bleed onto the Register screen after
  /// navigating between them.
  Failure? _submitError;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String? phoneError = AuthValidators.phone(_phone.text);
    final String? pinError = AuthValidators.pin(_pin.text);
    setState(() {
      _phoneError = phoneError;
      _pinError = pinError;
    });
    if (phoneError != null || pinError != null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    await ref
        .read(authControllerProvider.notifier)
        .login(phone: _phone.text.trim(), pin: _pin.text.trim());
    if (!mounted) return;

    final Object? error = ref.read(authControllerProvider).error;
    setState(() {
      _submitting = false;
      _submitError = error is Failure ? error : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold.banded(
      bandChild: const _LoginLogo(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text('auth.login.title'.tr(), style: text.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('auth.login.subtitle'.tr(), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          if (_submitError != null) ...<Widget>[
            _ErrorBanner(text: authFailureText(_submitError!)),
            const SizedBox(height: AppSpacing.md),
          ],
          PhoneField(
            key: const Key('login_phone'),
            label: 'auth.login.phone'.tr(),
            hint: 'auth.login.phoneHint'.tr(),
            controller: _phone,
            errorText: _phoneError?.tr(),
            enabled: !_submitting,
          ),
          const SizedBox(height: AppSpacing.md),
          PinInput(
            key: const Key('login_pin'),
            label: 'auth.login.pin'.tr(),
            hint: 'auth.login.pinHint'.tr(),
            controller: _pin,
            errorText: _pinError?.tr(),
            enabled: !_submitting,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'auth.login.forgotPin'.tr(),
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: _submitting
                  ? null
                  : () => context.pushNamed(AppRoutes.forgotPin),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            key: const Key('login_submit'),
            label: 'auth.login.submit'.tr(),
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(child: Text('auth.login.or'.tr(), style: text.bodySmall)),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'auth.login.createAccount'.tr(),
            variant: AppButtonVariant.secondary,
            onPressed: _submitting
                ? null
                : () => context.pushNamed(AppRoutes.register),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _LanguageRow(),
          const SizedBox(height: AppSpacing.md),
          _WorksOfflinePill(label: 'auth.login.worksOffline'.tr()),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _LoginLogo extends StatelessWidget {
  const _LoginLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Iconsax.heart5, size: 40, color: AppColors.primary),
          const SizedBox(height: AppSpacing.xs),
          Text('app.name'.tr(), style: Theme.of(context).textTheme.titleMedium),
          Text(
            'app.tagline'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.criticalBg,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.critical),
      ),
    );
  }
}

/// Static, non-interactive — the actual language switcher is M2's settings
/// toggle (M1 spec Decision: language change after first run is out of
/// scope). This just mirrors the Figma content list showing both languages.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLanguage.values.map((AppLanguage l) => l.nativeLabel).join(' · '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _WorksOfflinePill extends StatelessWidget {
  const _WorksOfflinePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          border: Border.all(color: AppColors.accent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Iconsax.wifi, size: 16, color: AppColors.accent),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
