import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/shell/home_card.dart';
import '../../../../core/widgets/widgets.dart';
import '../controllers/auth_controller.dart';

/// Sign-out, surfaced on Home.
///
/// M1 built the whole sign-out path — `Logout` → `AuthRepository.logout()` →
/// `clearSession()` → [AuthController.signOut] — but nothing called it, so
/// FR-AUTH-007 was covered by tests and unreachable by a user. The button it
/// was written for lives on M2's settings screen, which is not merged yet.
///
/// This is that missing affordance, owned by the slice that owns auth. It goes
/// through the Home card registry rather than editing `core/shell`, so no
/// foundation file changes and rule #1 holds.
///
/// **When M2 lands** its Settings screen becomes the canonical place to sign
/// out. Keep this or drop it then — it is one line in `app_wiring.dart` either
/// way — but do not leave the app with no way out again.
class SignOutCard extends ConsumerWidget {
  const SignOutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: AppButton(
        label: 'home.signOut'.tr(),
        icon: Iconsax.logout,
        variant: AppButtonVariant.danger,
        onPressed: () => _confirmAndSignOut(context, ref),
      ),
    );
  }

  Future<void> _confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmSheet.show(
      context,
      title: 'auth.signOut.title'.tr(),
      message: 'auth.signOut.body'.tr(),
      confirmLabel: 'home.signOut'.tr(),
      isDestructive: true,
    );
    if (!confirmed) return;

    // Clears the token and the cached user together. The router watches the
    // auth gate, so the redirect takes the user back to Login on its own —
    // there is deliberately no navigation call here.
    await ref.read(authControllerProvider.notifier).signOut();
  }
}

/// Registered in `lib/app/app_wiring.dart`. Order 900: below every data card,
/// since the dashboard is for the patient's readings first.
const HomeCard signOutCard = HomeCard(
  id: 'auth-sign-out',
  order: 900,
  builder: _build,
);

Widget _build(BuildContext context) => const SignOutCard();
