import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:libu_care/features/profile/data/models/patient_profile_model.dart';
import 'package:libu_care/features/profile/presentation/profile/profile_screen.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  late AppDatabase db;
  const userId = 'u-1';

  setUp(() async {
    db = testDatabase();
    await db.cachedUserDao.save(
      const CachedUsersCompanion(
        id: Value(userId),
        name: Value('Abebe Bekele'),
        phone: Value('+251911234567'),
        preferredLanguage: Value('en'),
        role: Value('PATIENT'),
      ),
    );
  });

  tearDown(() => db.close());

  List<Override> overrides() {
    final fakeDio = FakeDio();
    fakeDio.stubAll(FakeResponse.offline());
    return <Override>[
      appDatabaseProvider.overrideWithValue(db),
      dioProvider.overrideWithValue(fakeDio.dio),
      connectivityStreamProvider.overrideWithValue(const Stream<bool>.empty()),
    ];
  }

  testWidgets('shows an inviting empty state when nothing has been saved', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const ProfileScreen(), overrides: overrides());

    expect(find.text('Not set'), findsWidgets);
    expect(find.text('None recorded'), findsOneWidget);
  });

  testWidgets('shows everything the patient entered, including the '
      'management plan', (WidgetTester tester) async {
    await ProfileLocalDatasource(db).saveProfile(
      userId,
      const PatientProfileModel(
        birthYear: 1965,
        heightCm: 172,
        chdStage: 'Stable angina',
        managementPlan: 'Aspirin, statin',
        comorbidities: ['diabetes', 'stroke'],
        goals: HealthGoalsModel(bpSystolic: 130, bpDiastolic: 80),
      ),
    );

    await pumpApp(tester, const ProfileScreen(), overrides: overrides());

    expect(find.text('1965'), findsOneWidget);
    expect(find.text('Stable angina'), findsOneWidget);
    expect(find.text('Aspirin, statin'), findsOneWidget);
    expect(find.text('Diabetes, Stroke'), findsOneWidget);
    expect(find.text('130/80'), findsOneWidget);
  });

  testWidgets('renders correctly in Amharic', (WidgetTester tester) async {
    await ProfileLocalDatasource(db).saveProfile(
      userId,
      const PatientProfileModel(managementPlan: 'Aspirin, statin'),
    );

    await pumpApp(
      tester,
      const ProfileScreen(),
      overrides: overrides(),
      language: AppLanguage.am,
    );

    expect(find.text('የእኔ መገለጫ'), findsOneWidget);
    expect(find.text('የአሁኑ የሕክምና ዕቅድ'), findsOneWidget);
  });
}
