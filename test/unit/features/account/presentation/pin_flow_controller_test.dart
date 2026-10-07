import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/features/account/presentation/pin_flow_controller.dart';

/// Counts what the flow writes, over the real repository on in-memory storage.
class _CountingPins implements PinLockRepository {
  _CountingPins(this.inner);

  final PinLockRepository inner;
  final setCalls = <String>[];
  Object? throwOnSet;

  @override
  Future<void> set(String pin) async {
    setCalls.add(pin);
    if (throwOnSet != null) throw throwOnSet!;
    return inner.set(pin);
  }

  @override
  Future<PinStatus> status() => inner.status();

  @override
  Future<int> triesLeft() => inner.triesLeft();

  @override
  Future<PinCheckResult> verify(String pin) => inner.verify(pin);

  @override
  Future<void> clear() => inner.clear();

  @override
  Future<bool> shouldOfferPin() => inner.shouldOfferPin();

  @override
  Future<void> markOfferShown() => inner.markOfferShown();
}

/// `contracts/pin-ui.md` §3, mode `setUp`.
void main() {
  late _CountingPins pins;
  late List<String> passwordsChecked;
  Object? passwordError;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    pins = _CountingPins(
      SecurePinLockRepository(
        storage: const FlutterSecureStorage(),
        userId: () => 'user-a',
        now: () => DateTime.utc(2026, 3, 1, 9),
      ),
    );
    passwordsChecked = [];
    passwordError = null;
  });

  PinFlowController create() => PinFlowController(
    mode: PinFlowMode.setUp,
    verifyPassword: (password) async {
      passwordsChecked.add(password);
      if (passwordError != null) throw passwordError!;
    },
    pins: pins,
  );

  Future<void> type(PinFlowController c, String digits) async {
    for (final d in digits.split('')) {
      c.addDigit(d);
      // The last digit of a step triggers async work.
      await pumpEventQueue();
    }
  }

  test('starts on the password step with nothing entered', () {
    final c = create();
    expect(c.state.step, PinFlowStep.confirmPassword);
    expect(c.state.entered, isEmpty);
    expect(c.state.issue, isNull);
    expect(c.state.isBusy, isFalse);
  });

  test('the right password moves to the new-PIN step', () async {
    final c = create();
    await c.submitPassword('Secret-123');
    expect(passwordsChecked, ['Secret-123']);
    expect(c.state.step, PinFlowStep.newPin);
    expect(c.state.issue, isNull);
  });

  test('a wrong password stays on the step and saves nothing', () async {
    passwordError = const AuthApiException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );
    final c = create();
    await c.submitPassword('wrong-one');
    expect(c.state.step, PinFlowStep.confirmPassword);
    expect(c.state.issue?.kind, PinFlowIssueKind.service);
    expect(c.state.issue?.error, passwordError);
    expect(c.state.isBusy, isFalse);
    expect(pins.setCalls, isEmpty);
    expect(await pins.status(), PinStatus.none);
  });

  test('no connection keeps the flow on the first step', () async {
    passwordError = const SocketException('offline');
    final c = create();
    await c.submitPassword('Secret-123');
    expect(c.state.step, PinFlowStep.confirmPassword);
    expect(c.state.issue?.kind, PinFlowIssueKind.service);
    expect(c.state.issue?.error, isA<SocketException>());
  });

  test('a later correct password clears the earlier error', () async {
    passwordError = const SocketException('offline');
    final c = create();
    await c.submitPassword('Secret-123');
    passwordError = null;
    await c.submitPassword('Secret-123');
    expect(c.state.step, PinFlowStep.newPin);
    expect(c.state.issue, isNull);
  });

  test(
    'digits and Backspace edit the entry; a seventh digit is ignored',
    () async {
      final c = create();
      await c.submitPassword('Secret-123');
      c.addDigit('4');
      c.addDigit('8');
      expect(c.state.entered, '48');
      c.backspace();
      expect(c.state.entered, '4');
      c.backspace();
      c.backspace();
      expect(c.state.entered, isEmpty);
    },
  );

  test('digits are ignored on the password step', () {
    final c = create();
    c.addDigit('4');
    expect(c.state.entered, isEmpty);
  });

  test('an easy PIN is refused and the entry clears', () async {
    final c = create();
    await c.submitPassword('Secret-123');
    await type(c, '123456');
    expect(c.state.step, PinFlowStep.newPin);
    expect(c.state.issue?.kind, PinFlowIssueKind.tooEasy);
    expect(c.state.entered, isEmpty);
    await type(c, '111111');
    expect(c.state.issue?.kind, PinFlowIssueKind.tooEasy);
    expect(pins.setCalls, isEmpty);
  });

  test(
    'a good PIN moves to the repeat step; typing removes the message',
    () async {
      final c = create();
      await c.submitPassword('Secret-123');
      await type(c, '123456');
      expect(c.state.issue?.kind, PinFlowIssueKind.tooEasy);
      c.addDigit('4');
      expect(c.state.issue, isNull, reason: 'typing clears the old message');
      c.backspace();
      await type(c, '483920');
      expect(c.state.step, PinFlowStep.repeatPin);
      expect(c.state.entered, isEmpty);
      expect(pins.setCalls, isEmpty, reason: 'nothing is written yet');
    },
  );

  test(
    'a mismatch restarts only the repeat step and keeps the first PIN',
    () async {
      final c = create();
      await c.submitPassword('Secret-123');
      await type(c, '483920');
      await type(c, '483921');
      expect(c.state.step, PinFlowStep.repeatPin);
      expect(c.state.issue?.kind, PinFlowIssueKind.mismatch);
      expect(c.state.entered, isEmpty);
      expect(pins.setCalls, isEmpty);

      // The first PIN is still the one to match.
      await type(c, '483920');
      expect(c.state.step, PinFlowStep.done);
      expect(pins.setCalls, ['483920']);
    },
  );

  test(
    'a match calls PinLockRepository.set exactly once and finishes',
    () async {
      final c = create();
      await c.submitPassword('Secret-123');
      await type(c, '483920');
      await type(c, '483920');
      expect(c.state.step, PinFlowStep.done);
      expect(c.state.entered, isEmpty);
      expect(pins.setCalls, ['483920']);
      expect(await pins.status(), PinStatus.active);
      expect(await pins.verify('483920'), const PinCheckSuccess());
    },
  );

  test('input after the end is ignored and does not set twice', () async {
    final c = create();
    await c.submitPassword('Secret-123');
    await type(c, '483920');
    await type(c, '483920');
    c.addDigit('1');
    await pumpEventQueue();
    expect(pins.setCalls, hasLength(1));
    expect(c.state.step, PinFlowStep.done);
  });

  test(
    'a storage failure on the last step is reported, not finished',
    () async {
      pins.throwOnSet = StateError('storage unavailable');
      final c = create();
      await c.submitPassword('Secret-123');
      await type(c, '483920');
      await type(c, '483920');
      expect(c.state.step, PinFlowStep.repeatPin);
      expect(c.state.issue?.kind, PinFlowIssueKind.service);
      expect(c.state.isBusy, isFalse);
      expect(await pins.status(), PinStatus.none);
    },
  );

  test('leaving (disposing) mid-flow writes nothing', () async {
    final c = create();
    await c.submitPassword('Secret-123');
    await type(c, '483920');
    c.dispose();
    expect(pins.setCalls, isEmpty);
    expect(await pins.status(), PinStatus.none);
  });

  test('the state never holds the password', () async {
    final c = create();
    await c.submitPassword('Secret-123');
    expect(c.state.toString().contains('Secret-123'), isFalse);
  });

  group('change', () {
    PinFlowController createChange() => PinFlowController(
      mode: PinFlowMode.change,
      verifyPassword: (_) async => fail('change never asks for the password'),
      pins: pins,
    );

    setUp(() async {
      await pins.inner.set('483920');
    });

    test('starts on the current-PIN step', () {
      final c = createChange();
      expect(c.state.step, PinFlowStep.currentPin);
    });

    test('the right current PIN moves on to the new PIN', () async {
      final c = createChange();
      await type(c, '483920');
      expect(c.state.step, PinFlowStep.newPin);
      expect(c.state.issue, isNull);
      expect(c.state.entered, isEmpty);
    });

    test('a wrong current PIN counts toward the same five tries', () async {
      final c = createChange();
      await type(c, '000001');
      expect(c.state.step, PinFlowStep.currentPin);
      expect(c.state.issue?.kind, PinFlowIssueKind.wrongPin);
      expect(c.state.issue?.triesLeft, 4);
      expect(c.state.entered, isEmpty);
      expect(await pins.triesLeft(), 4);
    });

    test('the fifth wrong PIN ends the flow with the invalidation', () async {
      final c = createChange();
      for (var i = 1; i <= 5; i++) {
        await type(c, '00000$i');
      }
      expect(c.state.step, PinFlowStep.ended);
      expect(c.state.issue?.kind, PinFlowIssueKind.invalidated);
      expect(await pins.status(), PinStatus.none);
    });

    test('a successful change writes a new record: new salt, new date, '
        'count 0', () async {
      final before = await const FlutterSecureStorage().read(
        key: 'PIN_RECORD_user-a',
      );
      final c = createChange();
      await type(c, '000001'); // one wrong try first
      await type(c, '483920');
      await type(c, '594031');
      await type(c, '594031');
      expect(c.state.step, PinFlowStep.done);
      expect(pins.setCalls, ['594031']);
      final after = await const FlutterSecureStorage().read(
        key: 'PIN_RECORD_user-a',
      );
      expect(after, isNot(before));
      expect(await pins.triesLeft(), 5);
      expect(await pins.verify('594031'), const PinCheckSuccess());
      expect(await pins.verify('483920'), isA<PinCheckWrong>());
    });

    test('the new PIN may not be easy, and a mismatch restarts only the '
        'repeat step', () async {
      final c = createChange();
      await type(c, '483920');
      await type(c, '654321');
      expect(c.state.issue?.kind, PinFlowIssueKind.tooEasy);
      await type(c, '594031');
      await type(c, '594032');
      expect(c.state.issue?.kind, PinFlowIssueKind.mismatch);
      expect(c.state.step, PinFlowStep.repeatPin);
      expect(pins.setCalls, isEmpty);
    });

    test('an expired PIN ends the flow', () async {
      final c = PinFlowController(
        mode: PinFlowMode.change,
        verifyPassword: (_) async {},
        pins: _CountingPins(_ExpiredPins()),
      );
      await type(c, '483920');
      expect(c.state.step, PinFlowStep.ended);
      expect(c.state.issue?.kind, PinFlowIssueKind.expired);
    });

    test(
      'a storage failure while checking is reported and never advances',
      () async {
        final c = PinFlowController(
          mode: PinFlowMode.change,
          verifyPassword: (_) async {},
          pins: _CountingPins(_VerifyThrowsPins()),
        );
        await type(c, '483920');
        expect(c.state.step, PinFlowStep.currentPin);
        expect(c.state.issue?.kind, PinFlowIssueKind.service);
        expect(c.state.isBusy, isFalse);
      },
    );
  });

  group('turnOff', () {
    PinFlowController createOff() => PinFlowController(
      mode: PinFlowMode.turnOff,
      verifyPassword: (_) async =>
          fail('turning off never asks for the password'),
      pins: pins,
    );

    setUp(() async {
      await pins.inner.set('483920');
    });

    test('starts on the current-PIN step', () {
      expect(createOff().state.step, PinFlowStep.currentPin);
    });

    test('the right PIN clears the record and the count', () async {
      await pins.verify('000001'); // leave a count behind
      final c = createOff();
      await type(c, '483920');
      expect(c.state.step, PinFlowStep.done);
      expect(await pins.status(), PinStatus.none);
      expect(
        await const FlutterSecureStorage().read(key: 'PIN_FAILS_user-a'),
        isNull,
      );
      expect(pins.setCalls, isEmpty);
    });

    test('a wrong PIN keeps it on and counts', () async {
      final c = createOff();
      await type(c, '000001');
      expect(c.state.step, PinFlowStep.currentPin);
      expect(c.state.issue?.triesLeft, 4);
      expect(await pins.status(), PinStatus.active);
    });

    test('the fifth wrong PIN ends the flow; the PIN is gone anyway', () async {
      final c = createOff();
      for (var i = 1; i <= 5; i++) {
        await type(c, '00000$i');
      }
      expect(c.state.step, PinFlowStep.ended);
      expect(c.state.issue?.kind, PinFlowIssueKind.invalidated);
      expect(await pins.status(), PinStatus.none);
    });
  });
}

class _ExpiredPins extends _Delegating {
  @override
  Future<PinCheckResult> verify(String pin) async =>
      const PinCheckUnavailable();
}

class _VerifyThrowsPins extends _Delegating {
  @override
  Future<PinCheckResult> verify(String pin) async =>
      throw StateError('storage unavailable');
}

/// A repository with no behavior of its own, for a subclass to override one
/// method of.
class _Delegating implements PinLockRepository {
  @override
  Future<PinStatus> status() async => PinStatus.active;

  @override
  Future<int> triesLeft() async => 5;

  @override
  Future<void> set(String pin) async {}

  @override
  Future<PinCheckResult> verify(String pin) async => const PinCheckSuccess();

  @override
  Future<void> clear() async {}

  @override
  Future<bool> shouldOfferPin() async => true;

  @override
  Future<void> markOfferShown() async {}
}
