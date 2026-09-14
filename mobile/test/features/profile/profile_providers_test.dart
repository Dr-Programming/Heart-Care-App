import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/profile_providers.dart';

import '../../helpers/fake_dio.dart';
import '../../helpers/test_database.dart';

void main() {
  test('profileRepositoryProvider builds a real, usable ProfileRepository', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final fake = FakeDio();
    final container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(fake.dio),
        isOnlineProvider.overrideWithValue(() async => true),
      ],
    );
    addTearDown(container.dispose);

    final repo = container.read(profileRepositoryProvider);
    final profile = await repo.getProfile('u1');

    expect(profile.userId, 'u1');
    expect(profile.birthYear, isNull);
  });
}
