import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/domain/entities/health_goals.dart';
import 'package:libu_care/features/profile/domain/entities/patient_profile.dart';
import 'package:libu_care/features/profile/presentation/controllers/profile_controller.dart';
import 'package:libu_care/features/profile/presentation/home/profile_home_card.dart';

import '../../../../helpers/pump_app.dart';

class _LoadingProfileController extends ProfileController {
  @override
  Future<PatientProfile> build() => Completer<PatientProfile>().future;
}

class _ErrorProfileController extends ProfileController {
  @override
  Future<PatientProfile> build() {
    Future<void>.microtask(
      () => state = AsyncValue<PatientProfile>.error(
        Exception('boom'),
        StackTrace.current,
      ),
    );
    return Completer<PatientProfile>().future;
  }
}

class _DataProfileController extends ProfileController {
  _DataProfileController(this.profile);

  final PatientProfile profile;

  @override
  Future<PatientProfile> build() async => profile;
}

void main() {
  setUpWidgetTests();

  test('has order 300 (base spec §6, progress-and-encouragement band)', () {
    expect(profileHomeCard.order, 300);
  });

  test('has a real, kebab-case, feature-prefixed id', () {
    expect(profileHomeCard.id, matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')));
    expect(profileHomeCard.id, startsWith('profile-'));
  });

  testWidgets(
    'renders a placeholder without throwing while the profile is loading',
    (tester) async {
      await pumpApp(
        tester,
        Builder(builder: profileHomeCard.builder),
        overrides: <Override>[
          profileControllerProvider.overrideWith(_LoadingProfileController.new),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('profile.home.title'.tr()), findsOneWidget);
      expect(find.text('profile.home.emptyMessage'.tr()), findsOneWidget);
    },
  );

  testWidgets(
    'renders a placeholder without throwing when the profile fails to load',
    (tester) async {
      await pumpApp(
        tester,
        Builder(builder: profileHomeCard.builder),
        overrides: <Override>[
          profileControllerProvider.overrideWith(_ErrorProfileController.new),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('profile.home.title'.tr()), findsOneWidget);
      expect(find.text('profile.home.emptyMessage'.tr()), findsOneWidget);
    },
  );

  testWidgets(
    'renders the empty prompt without throwing for an unset profile',
    (tester) async {
      await pumpApp(
        tester,
        Builder(builder: profileHomeCard.builder),
        overrides: <Override>[
          profileControllerProvider.overrideWith(
            () => _DataProfileController(PatientProfile.empty('user-1')),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.text('profile.home.emptyMessage'.tr()), findsOneWidget);
    },
  );

  testWidgets('renders a summary without throwing for a populated profile', (
    tester,
  ) async {
    final profile = PatientProfile.empty('user-1').copyWith(
      birthYear: 1970,
      heightCm: 170,
      chdStage: 'STEMI',
      goals: const HealthGoals(stepsPerDay: 6000),
    );

    await pumpApp(
      tester,
      Builder(builder: profileHomeCard.builder),
      overrides: <Override>[
        profileControllerProvider.overrideWith(
          () => _DataProfileController(profile),
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('profile.home.title'.tr()), findsOneWidget);
    expect(find.text('STEMI'), findsOneWidget);
    expect(
      find.text(
        'profile.home.goalSteps'.tr(
          namedArgs: <String, String>{'value': '6000'},
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('profile.home.emptyMessage'.tr()), findsNothing);
  });
}
