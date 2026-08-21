import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../db/app_database.dart';
import '../providers/core_providers.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/widgets.dart';
import 'home_card.dart';

/// The dashboard (FR-DASH).
///
/// Owns the greeting, the layout and pull-to-refresh; owns none of the
/// content. Everything below the header is a [HomeCard] registered by a
/// feature, sorted by [HomeCard.order].
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<HomeCard> cards = <HomeCard>[...ref.watch(homeCardsProvider)]
      ..sort((HomeCard a, HomeCard b) => a.order.compareTo(b.order));

    return AppScaffold(
      showBack: false,
      padded: false,
      body: RefreshIndicator(
        // Pull-to-refresh means "push what I have", not "fetch". The device is
        // the source of truth, so there is nothing to pull down.
        onRefresh: () => ref.read(syncServiceProvider).syncNow(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            const _Greeting(),
            const SizedBox(height: AppSpacing.xl),
            if (cards.isEmpty)
              EmptyState(
                icon: Iconsax.heart,
                title: 'home.emptyTitle'.tr(),
                message: 'home.emptyBody'.tr(),
              )
            else
              for (final HomeCard card in cards) ...<Widget>[
                KeyedSubtree(
                  key: ValueKey<String>(card.id),
                  child: Builder(builder: card.builder),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
          ],
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CachedUser?> user = ref.watch(cachedUserProvider);
    final String? name = user.value?.name;
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name == null
                    ? 'home.greetingAnonymous'.tr()
                    : 'home.greeting'.tr(
                        namedArgs: <String, String>{
                          'name': name.split(' ').first,
                        },
                      ),
                style: text.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('home.subtitle'.tr(), style: text.bodyMedium),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.pushNamed(AppRoutes.profile),
          tooltip: 'profile.title'.tr(),
          icon: const CircleAvatar(
            backgroundColor: AppColors.surfaceAlt,
            child: Icon(Iconsax.user, color: AppColors.ink, size: 20),
          ),
        ),
      ],
    );
  }
}
