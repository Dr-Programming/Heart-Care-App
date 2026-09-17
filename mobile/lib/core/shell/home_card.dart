import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One block on the Home dashboard, contributed by a feature.
///
/// Home shows the latest BP, today's adherence, today's activity and the last
/// check-in (FR-DASH-001 … FR-DASH-009) — data owned by four different
/// features. Rather than have Home import all four (architectural rule #1),
/// each feature builds its own card and registers it here; Home only knows how
/// to lay out a list of them.
///
/// A card must render something offline and must never throw: the dashboard
/// has to work from local data alone (FR-DASH-009). Show "—" for a metric that
/// has no reading yet rather than hiding the card, so the user can see what
/// the app is able to track for them.
class HomeCard {
  const HomeCard({
    required this.id,
    required this.order,
    required this.builder,
  });

  /// Stable identifier, used as the widget key. Kebab-case, feature-prefixed:
  /// `vitals-latest`, `meds-today`.
  final String id;

  /// Ascending. Conventional bands, so slices do not have to negotiate:
  /// 0–99 alerts and anything urgent · 100–199 today's actions (doses, check-in)
  /// · 200–299 latest readings · 300+ progress and encouragement.
  final int order;

  final WidgetBuilder builder;
}

/// Every card Home should render.
///
/// Defaults to empty so the shell runs before any feature exists. Feature
/// slices add theirs in `lib/app/app_wiring.dart`, which is the one file where
/// features are allowed to meet.
final Provider<List<HomeCard>> homeCardsProvider = Provider<List<HomeCard>>(
  (Ref ref) => const <HomeCard>[],
);
