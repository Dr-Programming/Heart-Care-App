import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/auth/presentation/widgets/auth_failure_text.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  Future<void> ready(WidgetTester tester) =>
      pumpApp(tester, const SizedBox.shrink());

  testWidgets('locked with minutes remaining shows the parsed count', (
    tester,
  ) async {
    await ready(tester);
    const AccountLockedFailure failure = AccountLockedFailure(
      'Too many failed attempts. Try again in 12 minutes.',
      minutesRemaining: 12,
    );

    expect(authFailureText(failure), 'Too many attempts. Try again in 12 min.');
  });

  testWidgets('locked with no parsed minutes shows the no-time copy', (
    tester,
  ) async {
    await ready(tester);
    const AccountLockedFailure failure = AccountLockedFailure(
      'Too many failed attempts.',
    );

    expect(
      authFailureText(failure),
      'Too many attempts. Please wait and try again.',
    );
  });

  testWidgets('invalid credentials never distinguishes unknown phone', (
    tester,
  ) async {
    await ready(tester);
    const InvalidCredentialsFailure failure = InvalidCredentialsFailure(
      'Invalid phone or PIN',
    );

    expect(authFailureText(failure), 'Invalid phone or PIN');
  });

  testWidgets('phone already registered maps to the phone-taken copy', (
    tester,
  ) async {
    await ready(tester);
    const PhoneAlreadyRegisteredFailure failure = PhoneAlreadyRegisteredFailure(
      'Phone already registered',
    );

    expect(authFailureText(failure), 'That phone number is already registered');
  });

  testWidgets('offline translation key resolves to its sentence', (
    tester,
  ) async {
    await ready(tester);
    const NetworkFailure failure = NetworkFailure('errors.offline');

    expect(
      authFailureText(failure),
      'You need a connection to sign in the first time',
    );
  });

  testWidgets('a raw network message is shown verbatim', (tester) async {
    await ready(tester);
    const NetworkFailure failure = NetworkFailure(
      'No connection. Check your network and try again.',
    );

    expect(
      authFailureText(failure),
      'No connection. Check your network and try again.',
    );
  });

  testWidgets('a server validation message is shown verbatim', (tester) async {
    await ready(tester);
    const ValidationFailure failure = ValidationFailure(
      'phone: phone must be a valid Ethiopian number',
    );

    expect(
      authFailureText(failure),
      'phone: phone must be a valid Ethiopian number',
    );
  });

  testWidgets('a server or unknown failure falls back to the generic copy', (
    tester,
  ) async {
    await ready(tester);
    const ServerFailure server = ServerFailure('boom');
    const UnknownFailure unknown = UnknownFailure('boom');

    expect(authFailureText(server), 'Something went wrong. Please try again.');
    expect(authFailureText(unknown), 'Something went wrong. Please try again.');
  });
}
