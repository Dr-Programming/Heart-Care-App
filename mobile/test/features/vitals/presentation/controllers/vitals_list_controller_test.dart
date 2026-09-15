import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/presentation/controllers/vitals_list_controller.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('the Home card shows null (mapped to "—" by the widget) for a type with no readings', () async {
    final AppDatabase db = testDatabase();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() {
      container.dispose();
      db.close();
    });

    container.listen(vitalsListControllerProvider, (_, _) {});
    final Map<VitalType, dynamic> latest = await container.read(
      vitalsListControllerProvider.future,
    );

    expect(latest[VitalType.bloodPressure], isNull);
  });
}
