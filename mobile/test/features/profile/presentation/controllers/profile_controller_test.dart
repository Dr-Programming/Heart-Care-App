import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/presentation/controllers/profile_controller.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/test_database.dart';

void main() {
  test('build loads the local profile for the cached user', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(FakeDio().dio),
        isOnlineProvider.overrideWithValue(() async => false),
      ],
    );
    addTearDown(container.dispose);

    container.listen(profileControllerProvider, (_, _) {});
    final profile = await container.read(profileControllerProvider.future);

    expect(profile.birthYear, isNull);
  });
}
