import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/features/education/domain/entities/content_block.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';

void main() {
  test('chd-basics BP chart severities match the shipped content (en)', () {
    final List<dynamic> json = jsonDecode(
      File('assets/content/topics_en.json').readAsStringSync(),
    ) as List<dynamic>;
    final Topic topic = Topic.fromJson(
      (json.first as Map<Object?, Object?>).cast(),
    );

    final TopicSection vitalsSection = topic.sections.singleWhere(
      (TopicSection s) => s.title == 'What your Vitals check flags',
    );
    final CategoryRangesChartBlock chart = vitalsSection.blocks
        .whereType<CategoryRangesChartBlock>()
        .single;

    expect(chart.ranges.map((CategoryRange r) => r.severity).toList(), <
      Severity
    >[Severity.urgent, Severity.none, Severity.urgent]);
  });
}
