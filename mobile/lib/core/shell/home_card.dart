import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeCard {
  const HomeCard({
    required this.id,
    required this.order,
    required this.builder,
    this.spaced = true,
  });

  final String id;

  final int order;

  final WidgetBuilder builder;

  /// False when the card adds its own bottom gap, so a card that is often
  /// hidden leaves no empty space behind.
  final bool spaced;
}

final Provider<List<HomeCard>> homeCardsProvider = Provider<List<HomeCard>>(
  (Ref ref) => const <HomeCard>[],
);
