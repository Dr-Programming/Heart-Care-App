import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/choice_pills.dart';
import '../widgets/failure_message.dart';
import '../widgets/header_band.dart';
import '../widgets/phone_field.dart';
import '../widgets/pin_input.dart';
import '../widgets/primary_button.dart';

/// Create account. Visual language from Figma Screen 2 (`368:632`); field set
/// is **identity only** per spec §3 — no DOB, height or sex (those belong to
/// `PUT /patients/me` in the patient-profile slice and `POST /auth/register`
/// would reject them). Confirm-PIN is added so a typo does not permanently
/// lock a patient out (there is no self-service reset).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController(text: '+251');
  final TextEditingController _name = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _confirmPin = TextEditingController();

  AppLanguage _language = AppLanguage.en;

  /// The last submit failure, held per-screen — see the note in `LoginScreen`.
  /// Reading the shared `authControllerProvider.error` here would show a stale
  /// Login failure (e.g. "Invalid phone or PIN") on this empty form.
  Failure? _submitError;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in <TextEditingController>[
      _phone,
      _name,
      _pin,
      _confirmPin,
    ]) {
      c.addListener(_clearSubmitError);
    }
    ref.read(languageStoreProvider).read().then((AppLanguage? stored) {
      if (stored != null && mounted) setState(() => _language = stored);
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  void _clearSubmitError() {
    if (_submitError != null) setState(() => _submitError = null);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).register(
          phone: _phone.text.trim(),
          pin: _pin.text.trim(),
          name: _name.text.trim(),
          language: _language,
        );
    if (!mounted) return;
    // `register()` swallows the error into the controller's AsyncError state
    // rather than rethrowing, so read it back here.
    final Object? err = ref.read(authControllerProvider).error;
    setState(() => _submitError = err is Failure ? err : null);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthState> auth = ref.watch(authControllerProvider);
    final Failure? error = _submitError;

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
                    Text('register.title'.tr(),
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text('register.subtitle'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.xl),
                    if (error is Failure) FailureMessage(error),
                    PhoneField(
                      fieldKey: const Key('register_phone'),
                      controller: _phone,
                      label: 'login.phone'.tr(),
                      hint: 'login.phoneHint'.tr(),
                      validator: (String? v) => AuthValidators.phone(v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('register.name'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('register_name'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'register.nameHint'.tr(),
                        prefixIcon: const Icon(Iconsax.user),
                      ),
                      validator: (String? v) => AuthValidators.name(v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PinInput(
                      fieldKey: const Key('register_pin'),
                      controller: _pin,
                      label: 'register.pin'.tr(),
                      hint: 'login.pinHint'.tr(),
                      validator: (String? v) => AuthValidators.pin(v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PinInput(
                      fieldKey: const Key('register_confirm_pin'),
                      controller: _confirmPin,
                      label: 'register.confirmPin'.tr(),
                      hint: 'login.pinHint'.tr(),
                      validator: (String? v) =>
                          AuthValidators.confirmPin(_pin.text, v)?.tr(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('register.preferredLanguage'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    ChoicePills<AppLanguage>(
                      values: AppLanguage.values,
                      selected: _language,
                      label: (AppLanguage l) => l.nativeLabel,
                      onChanged: (AppLanguage l) =>
                          setState(() => _language = l),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      key: const Key('register_submit'),
                      label: 'register.submit'.tr(),
                      isLoading: auth.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Text('register.haveAccount'.tr(),
                              style: Theme.of(context).textTheme.bodySmall),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Text(
                              ' ${'register.signIn'.tr()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.accent),
                            ),
                          ),
                        ],
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
