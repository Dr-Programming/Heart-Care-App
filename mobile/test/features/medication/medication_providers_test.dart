import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/data/caregiver_notify_store.dart';
import 'package:libu_care/features/medication/medication_providers.dart';

void main() {
  test('caregiverNotifyStoreProvider provides a CaregiverNotifyStore', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(caregiverNotifyStoreProvider), isA<CaregiverNotifyStore>());
  });
}
