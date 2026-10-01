import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/data/datasources/pending_pin_change_store.dart';
import 'package:libu_care/features/auth/domain/security_question.dart';

import '../../../../helpers/auth_fakes.dart';

const List<SecurityAnswer> _answers = <SecurityAnswer>[
  SecurityAnswer(SecurityQuestion.firstSchool, 'Bole Primary'),
  SecurityAnswer(SecurityQuestion.childhoodFriend, 'Dawit'),
  SecurityAnswer(SecurityQuestion.favoriteTeacher, 'Ato Kebede'),
];

void main() {
  late MemoryPendingPinChangeStore store;

  setUp(() => store = MemoryPendingPinChangeStore());

  test('is empty to start with', () async {
    expect(await store.read(), isNull);
  });

  test('records a change with the old PIN as its proof', () async {
    await store.recordChange(phone: '+251911234567', currentPin: '1234', newPin: '5678');

    final PendingPinChange? pending = await store.read();
    expect(pending!.kind, PendingPinChangeKind.change);
    expect(pending.phone, '+251911234567');
    expect(pending.currentPin, '1234');
    expect(pending.newPin, '5678');
    expect(pending.changeId, isNotEmpty);
  });

  test('records a reset with the answers as its proof', () async {
    await store.recordReset(phone: '+251911234567', answers: _answers, newPin: '5678');

    final PendingPinChange? pending = await store.read();
    expect(pending!.kind, PendingPinChangeKind.reset);
    expect(pending.answers, _answers);
    expect(pending.currentPin, isNull);
  });

  test('a second change keeps the first proof, takes the newest PIN and a new changeId', () async {
    // The server still has 1234, so 1234 is what will prove the change when it syncs.
    await store.recordChange(phone: '+251911234567', currentPin: '1234', newPin: '5678');
    final String firstId = (await store.read())!.changeId;

    await store.recordChange(phone: '+251911234567', currentPin: '5678', newPin: '9999');

    final PendingPinChange pending = (await store.read())!;
    expect(pending.kind, PendingPinChangeKind.change);
    expect(pending.currentPin, '1234');
    expect(pending.newPin, '9999');
    expect(pending.changeId, isNot(firstId));
  });

  test('a reset on top of a pending change keeps the old-PIN proof', () async {
    await store.recordChange(phone: '+251911234567', currentPin: '1234', newPin: '5678');

    await store.recordReset(phone: '+251911234567', answers: _answers, newPin: '2468');

    final PendingPinChange pending = (await store.read())!;
    expect(pending.kind, PendingPinChangeKind.change);
    expect(pending.currentPin, '1234');
    expect(pending.newPin, '2468');
  });

  test('a change for a different phone replaces the pending one', () async {
    await store.recordChange(phone: '+251911234567', currentPin: '1234', newPin: '5678');

    await store.recordChange(phone: '+251922222222', currentPin: '1111', newPin: '2222');

    final PendingPinChange pending = (await store.read())!;
    expect(pending.phone, '+251922222222');
    expect(pending.currentPin, '1111');
  });

  test('clear removes it', () async {
    await store.recordChange(phone: '+251911234567', currentPin: '1234', newPin: '5678');
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('a corrupt record reads as nothing pending', () async {
    store.values['pending_pin_change'] = 'not json';
    expect(await store.read(), isNull);
  });
}
