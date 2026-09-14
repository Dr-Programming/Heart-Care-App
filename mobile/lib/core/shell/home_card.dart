import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeCard {
  const HomeCard({
    required this.id,
    required this.order,
    required this.builder,
  });

  final String id;

  final int order;

  final WidgetBuilder builder;
}

final Provider<List<HomeCard>> homeCardsProvider = Provider<List<HomeCard>>(
  (Ref ref) => const <HomeCard>[],
);
