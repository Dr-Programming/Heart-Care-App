import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/domain/entities/health_goals.dart';
import 'package:libu_care/features/profile/presentation/onboarding/onboarding_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  OnboardingController controller() =>
      container.read(onboardingControllerProvider.notifier);

  OnboardingState state() => container.read(onboardingControllerProvider);

  test('starts empty, defaulting to English', () {
    expect(state().birthYear, isNull);
    expect(state().preferredLanguage, 'en');
    expect(state().comorbidities, isEmpty);
  });

  test('answers survive a step change', () {
    controller().updatePersonalDetails(
      birthYear: 1965,
      heightCm: 172,
      preferredLanguage: 'am',
    );
    controller().updateMedicalProfile(
      chdStage: 'Stable angina',
      comorbidities: ['diabetes'],
      diseaseHistory: 'Diagnosed 2019',
      managementPlan: 'Aspirin, statin',
    );

    // Step 1's answers must still be there after step 2 writes its own.
    expect(state().birthYear, 1965);
    expect(state().heightCm, 172);
    expect(state().preferredLanguage, 'am');
    expect(state().chdStage, 'Stable angina');
    expect(state().comorbidities, ['diabetes']);
    expect(state().managementPlan, 'Aspirin, statin');
  });

  test('skipping step 2 (empty comorbidities) still produces a valid profile', () {
    controller().updatePersonalDetails(birthYear: 1965);
    controller().updateMedicalProfile(comorbidities: const []);

    final profile = state().toPatientProfile();

    expect(profile.birthYear, 1965);
    expect(profile.comorbidities, isEmpty);
  });

  test('toPatientProfile carries every field the wizard collected', () {
    controller().updatePersonalDetails(
      birthYear: 1970,
      heightCm: 165,
      preferredLanguage: 'en',
    );
    controller().updateMedicalProfile(
      chdStage: 'CAD',
      comorbidities: ['hypertension'],
      diseaseHistory: 'One stent',
      managementPlan: 'Beta-blocker',
    );
    controller().updateGoals(const HealthGoals(bpSystolic: 130, stepsPerDay: 6000));

    final profile = state().toPatientProfile();

    expect(profile.birthYear, 1970);
    expect(profile.heightCm, 165);
    expect(profile.preferredLanguage, 'en');
    expect(profile.chdStage, 'CAD');
    expect(profile.comorbidities, ['hypertension']);
    expect(profile.diseaseHistory, 'One stent');
    expect(profile.managementPlan, 'Beta-blocker');
    expect(profile.goals?.bpSystolic, 130);
    expect(profile.goals?.stepsPerDay, 6000);
  });
}
