import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/failure_message.dart';
import '../widgets/header_band.dart';
import '../widgets/phone_field.dart';
import '../widgets/pin_input.dart';
import '../widgets/primary_button.dart';

/// Figma Screen 1, node `368:680`.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController(text: '+251');
  final TextEditingController _pin = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).login(
          phone: _phone.text.trim(),
          pin: _pin.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthState> auth = ref.watch(authControllerProvider);
    final Object? error = auth.error;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const HeaderBand(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Text('login.title'.tr(),
                        style: Theme.of(context).textTheme.headlineLarge),
                    Text('login.subtitle'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.xl),
                    if (error is Failure) FailureMessage(error),
                    PhoneField(
                      fieldKey: const Key('login_phone'),
                      controller: _phone,
                      label: 'login.phone'.tr(),
                      hint: 'login.phoneHint'.tr(),
                      validator: (String? v) => AuthValidators.phone(v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PinInput(
                      fieldKey: const Key('login_pin'),
                      controller: _pin,
                      label: 'login.pin'.tr(),
                      hint: 'login.pinHint'.tr(),
                      validator: (String? v) => AuthValidators.pin(v)?.tr(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push(Routes.forgotPin),
                        child: Text('login.forgotPin'.tr(),
                            style: const TextStyle(color: AppColors.accent)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      key: const Key('login_submit'),
                      label: 'login.submit'.tr(),
                      isLoading: auth.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text('login.or'.tr(),
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton(
                      onPressed: () => context.push(Routes.register),
                      child: Text('login.createAccount'.tr()),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text('login.language'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.accentBg,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.fieldRadius),
                          border: Border.all(color: AppColors.accent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Iconsax.wifi,
                                size: 16, color: AppColors.accent),
                            const SizedBox(width: AppSpacing.sm),
                            Text('login.worksOffline'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.accent)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
