import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/pin_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  String? _phoneErrorKey;
  String? _pinErrorKey;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String? phoneKey = validatePhone(_phoneController.text.trim());
    final String? pinKey = validatePin(_pinController.text);
    setState(() {
      _phoneErrorKey = phoneKey;
      _pinErrorKey = pinKey;
    });
    if (phoneKey != null || pinKey != null) return;

    await ref
        .read(authControllerProvider.notifier)
        .login(phone: _phoneController.text.trim(), pin: _pinController.text);
  }

  String? _errorMessage(AsyncValue<AuthState> asyncState) {
    if (!asyncState.hasError) return null;
    final Object? error = asyncState.error;
    if (error is InvalidCredentialsFailure) {
      return 'auth.errors.invalidCredentials'.tr();
    }
    if (error is AccountLockedFailure) {
      return error.minutesRemaining != null
          ? 'auth.errors.locked'.tr(
              namedArgs: <String, String>{
                'minutes': '${error.minutesRemaining}',
              },
            )
          : 'auth.errors.lockedNoTime'.tr();
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

    return AppScaffold.banded(
      showBack: false,
      bandChild: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('auth.login.title'.tr(), style: text.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('auth.login.subtitle'.tr(), style: text.bodyMedium),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'auth.login.phone'.tr(),
            controller: _phoneController,
            hint: 'auth.login.phoneHint'.tr(),
            errorText: _phoneErrorKey?.tr(),
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.call_outlined,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_phoneErrorKey != null) setState(() => _phoneErrorKey = null);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          PinField(
            controller: _pinController,
            label: 'auth.login.pin'.tr(),
            errorText: _pinErrorKey?.tr(),
            onChanged: (_) {
              if (_pinErrorKey != null) setState(() => _pinErrorKey = null);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'auth.login.forgotPin'.tr(),
              variant: AppButtonVariant.text,
              expand: false,
              onPressed: () => context.pushNamed(AppRoutes.forgotPin),
            ),
          ),
          if (formError != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              formError,
              style: text.bodyMedium?.copyWith(color: AppColors.critical),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: const Key('loginSubmitButton'),
            label: 'auth.login.submit'.tr(),
            isLoading: isLoading,
            onPressed: isLoading ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              const Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                child: Text('auth.login.or'.tr(), style: text.bodySmall),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'auth.login.createAccount'.tr(),
            variant: AppButtonVariant.secondary,
            onPressed: () => context.goNamed(AppRoutes.register),
          ),
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'auth.login.worksOffline'.tr(),
                    style: text.bodySmall?.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
