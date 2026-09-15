import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
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
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
            onPressed: () => Navigator.of(context).pop(),
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
          Text('auth.login.pin'.tr(), style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PinBoxInput(
            errorText: _pinErrorKey?.tr(),
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
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_nameErrorKey != null) setState(() => _nameErrorKey = null);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('auth.register.preferredLanguage'.tr(), style: text.titleMedium),
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
                    onTap: () => setState(() => _selectedLanguage = language),
                  ),
                ),
              ],
            ],
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
              onPressed: isLoading ? null : _submit,
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
