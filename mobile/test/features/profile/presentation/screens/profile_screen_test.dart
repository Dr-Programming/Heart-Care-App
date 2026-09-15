import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/presentation/screens/profile_screen.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  testWidgets('shows the empty state when nothing has been saved', (tester) async {
    await pumpApp(
      tester,
      const ProfileScreen(),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(testDatabase()),
        dioProvider.overrideWithValue(FakeDio().dio),
        isOnlineProvider.overrideWithValue(() async => false),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('profile.empty.title'.tr()), findsOneWidget);
  });
}
