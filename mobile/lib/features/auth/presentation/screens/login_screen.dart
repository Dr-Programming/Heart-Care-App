import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../widgets/patient_switch.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth_providers.dart';
import '../../domain/repositories/pin_repository.dart';
import '../../domain/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/pin_box_input.dart';

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

    // The previous patient has records the server hasn't received: offer to
    // delete them, then try again.
    if (!mounted) return;
    final Object? error = ref.read(authControllerProvider).error;
    if (error is PatientSwitchFailure &&
        await offerToDiscardUnsent(context, ref, error) &&
        mounted) {
      await ref
          .read(authControllerProvider.notifier)
          .login(phone: _phoneController.text.trim(), pin: _pinController.text);
    }
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
    if (error is PatientSwitchFailure) return patientSwitchMessage(error);
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
    final SignOutReason? notice = ref.watch(signOutNoticeProvider);
    final TextTheme text = Theme.of(context).textTheme;

    return AppScaffold.banded(
      showBack: false,
      bandChild: BandHeader(
        title: 'auth.login.title'.tr(),
        subtitle: 'auth.login.subtitle'.tr(),
        showBack: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xl),
          if (notice == SignOutReason.pinChangedElsewhere) ...<Widget>[
            Text(
              'auth.errors.pinChangedElsewhere'.tr(),
              key: const Key('loginPinChangedElsewhere'),
              style: text.bodyMedium?.copyWith(color: AppColors.critical),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
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
          Text(
            'auth.login.pin'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Four boxes, as at sign-up, so the PIN looks the same everywhere.
          PinBoxInput(
            errorText: _pinErrorKey?.tr(),
            onCompleted: (String pin) {
              _pinController.text = pin;
              if (_pinErrorKey != null) setState(() => _pinErrorKey = null);
            },
            onIncomplete: () => _pinController.clear(),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('auth.login.or'.tr(), style: text.bodySmall),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'auth.login.createAccount'.tr(),
            variant: AppButtonVariant.secondary,
            onPressed: () => context.pushNamed(AppRoutes.register),
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
