import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/education/presentation/screens/learn_screen.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('renders the real bundled topics without throwing', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const LearnScreen());
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(find.text('Understanding coronary heart disease'), findsOneWidget);
  });

  testWidgets('renders correctly in Amharic', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const LearnScreen(),
      language: AppLanguage.am,
    );
    await tester.pumpAndSettle();
    expect(find.text('የልብ ደም ስር በሽታን መረዳት'), findsOneWidget);
  });
}
