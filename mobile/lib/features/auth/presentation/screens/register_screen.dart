import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_failure_text.dart';
import '../widgets/language_choice.dart';
import '../widgets/phone_field.dart';
import '../widgets/pin_input.dart';

/// Registration is identity-only in this slice: name, phone, PIN and
/// language. The medical onboarding wizard (DOB, height, sex) is M2 — see
/// the M1 design doc's Decision on deferred scope.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController(text: '+251');
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _confirmPin = TextEditingController();

  AppLanguage _language = AppLanguage.en;

  String? _nameError;
  String? _phoneError;
  String? _pinError;
  String? _confirmPinError;
  bool _submitting = false;
  Failure? _submitError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String? nameError = AuthValidators.name(_name.text);
    final String? phoneError = AuthValidators.phone(_phone.text);
    final String? pinError = AuthValidators.pin(_pin.text);
    final String? confirmPinError = AuthValidators.confirmPin(
      _pin.text,
      _confirmPin.text,
    );
    setState(() {
      _nameError = nameError;
      _phoneError = phoneError;
      _pinError = pinError;
      _confirmPinError = confirmPinError;
    });
    if (nameError != null ||
        phoneError != null ||
        pinError != null ||
        confirmPinError != null) {
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    await ref
        .read(authControllerProvider.notifier)
        .register(
          phone: _phone.text.trim(),
          pin: _pin.text.trim(),
          name: _name.text.trim(),
          language: _language,
        );
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
      bandChild: const Center(
        child: Icon(Iconsax.heart5, size: 40, color: AppColors.primary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text('auth.register.title'.tr(), style: text.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('auth.register.subtitle'.tr(), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          if (_submitError != null) ...<Widget>[
            _ErrorBanner(text: authFailureText(_submitError!)),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            key: const Key('register_name'),
            label: 'auth.register.name'.tr(),
            hint: 'auth.register.nameHint'.tr(),
            controller: _name,
            errorText: _nameError?.tr(),
            enabled: !_submitting,
            prefixIcon: Iconsax.user,
          ),
          const SizedBox(height: AppSpacing.md),
          PhoneField(
            key: const Key('register_phone'),
            label: 'auth.login.phone'.tr(),
            hint: 'auth.login.phoneHint'.tr(),
            controller: _phone,
            errorText: _phoneError?.tr(),
            enabled: !_submitting,
          ),
          const SizedBox(height: AppSpacing.md),
          PinInput(
            key: const Key('register_pin'),
            label: 'auth.login.pin'.tr(),
            hint: 'auth.login.pinHint'.tr(),
            controller: _pin,
            errorText: _pinError?.tr(),
            enabled: !_submitting,
          ),
          const SizedBox(height: AppSpacing.md),
          PinInput(
            key: const Key('register_confirm_pin'),
            label: 'auth.register.confirmPin'.tr(),
            controller: _confirmPin,
            errorText: _confirmPinError?.tr(),
            enabled: !_submitting,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('auth.register.preferredLanguage'.tr(), style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          LanguageChoice(
            selected: _language,
            onChanged: _submitting
                ? (AppLanguage _) {}
                : (AppLanguage language) =>
                      setState(() => _language = language),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            key: const Key('register_submit'),
            label: 'auth.register.submit'.tr(),
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: <Widget>[
                Text('auth.register.haveAccount'.tr(), style: text.bodyMedium),
                AppButton(
                  label: 'auth.register.signIn'.tr(),
                  variant: AppButtonVariant.text,
                  expand: false,
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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
