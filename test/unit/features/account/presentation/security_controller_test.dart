import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/features/account/presentation/security_controller.dart';

class _FakeBiometric extends Fake implements BiometricLoginRepository {
  BiometricAvailability availabilityResult = BiometricAvailability.available;
  bool authenticateResult = true;
  Object? authenticateError;
  Object? availabilityError;
  Completer<bool>? authenticateGate;
  final authenticateReasons = <String>[];
  int availabilityCalls = 0;

  @override
  Future<BiometricAvailability> availability() async {
    availabilityCalls++;
    if (availabilityError != null) throw availabilityError!;
    return availabilityResult;
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateReasons.add(localizedReason);
    if (authenticateError != null) throw authenticateError!;
    if (authenticateGate != null) return authenticateGate!.future;
    return authenticateResult;
  }
}

class _FakeAccount extends Fake implements AccountAuthActions {
  bool stored = false;
  Object? readError;
  final writes = <bool>[];

  @override
  Future<bool> isBiometricLoginEnabled() async {
    if (readError != null) throw readError!;
    return stored;
  }

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    writes.add(enabled);
    stored = enabled;
  }
}

const _reason = 'Confirm to turn on';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeBiometric biometric;
  late _FakeAccount account;
  late SecurityController controller;

  setUp(() {
    biometric = _FakeBiometric();
    account = _FakeAccount();
  });

  tearDown(() => controller.dispose());

  Future<void> create({
    BiometricAvailability availability = BiometricAvailability.available,
    bool stored = false,
  }) async {
    biometric.availabilityResult = availability;
    account.stored = stored;
    controller = SecurityController(biometric: biometric, account: account);
    await _settle();
  }

  group('loading', () {
    test('settings are unknown until availability and the stored preference '
        'are read (no flash of a wrong state)', () async {
      biometric.availabilityResult = BiometricAvailability.available;
      controller = SecurityController(biometric: biometric, account: account);

      expect(controller.state.settings, isNull);
      expect(controller.state.isLoaded, isFalse);

      await _settle();

      expect(controller.state.isLoaded, isTrue);
    });
  });

  group('what the switch shows (data-model.md §4)', () {
    test('available and not stored: off but enabled', () async {
      await create();

      expect(controller.state.settings!.switchOn, isFalse);
      expect(controller.state.settings!.switchEnabled, isTrue);
    });

    test('available and stored: on and enabled', () async {
      await create(stored: true);

      expect(controller.state.settings!.switchOn, isTrue);
      expect(controller.state.settings!.switchEnabled, isTrue);
    });

    for (final availability in [
      BiometricAvailability.webUnsupported,
      BiometricAvailability.noHardware,
      BiometricAvailability.notEnrolled,
    ]) {
      test('$availability: off and disabled, even when a preference is stored '
          '(the stored value is left alone)', () async {
        await create(availability: availability, stored: true);

        final settings = controller.state.settings!;
        expect(settings.switchOn, isFalse);
        expect(settings.switchEnabled, isFalse);
        expect(settings.availability, availability);
        expect(account.writes, isEmpty);
        expect(account.stored, isTrue);
      });
    }
  });

  group('turning it on', () {
    test('asks for one biometric check with the localized reason, then stores '
        'the preference', () async {
      await create();

      await controller.setEnabled(true, localizedReason: _reason);

      expect(biometric.authenticateReasons, [_reason]);
      expect(account.writes, [true]);
      expect(controller.state.settings!.switchOn, isTrue);
      expect(controller.state.notice, isNull);
      expect(controller.state.isChanging, isFalse);
    });

    test(
      'a cancelled check leaves it off and raises the failure notice',
      () async {
        await create();
        biometric.authenticateResult = false;

        await controller.setEnabled(true, localizedReason: _reason);

        expect(account.writes, isEmpty);
        expect(controller.state.settings!.switchOn, isFalse);
        expect(controller.state.notice, SecurityNotice.enableFailed);
      },
    );

    test(
      'a LocalAuthException leaves it off and raises the failure notice',
      () async {
        await create();
        biometric.authenticateError = const LocalAuthException(
          code: LocalAuthExceptionCode.userCanceled,
        );

        await controller.setEnabled(true, localizedReason: _reason);

        expect(account.writes, isEmpty);
        expect(controller.state.settings!.switchOn, isFalse);
        expect(controller.state.notice, SecurityNotice.enableFailed);
        expect(controller.state.isChanging, isFalse);
      },
    );

    test('is ignored while biometrics are unavailable', () async {
      await create(availability: BiometricAvailability.notEnrolled);

      await controller.setEnabled(true, localizedReason: _reason);

      expect(biometric.authenticateReasons, isEmpty);
      expect(account.writes, isEmpty);
    });

    test('is single-flight', () async {
      await create();
      biometric.authenticateGate = Completer<bool>();

      final first = controller.setEnabled(true, localizedReason: _reason);
      await _settle();
      expect(controller.state.isChanging, isTrue);

      await controller.setEnabled(true, localizedReason: _reason);
      expect(biometric.authenticateReasons, hasLength(1));

      biometric.authenticateGate!.complete(true);
      await first;
      expect(account.writes, [true]);
    });
  });

  group('turning it off', () {
    test('takes effect immediately with no biometric check', () async {
      await create(stored: true);

      await controller.setEnabled(false, localizedReason: _reason);

      expect(biometric.authenticateReasons, isEmpty);
      expect(account.writes, [false]);
      expect(controller.state.settings!.switchOn, isFalse);
    });
  });

  group('platform failures never leave the switch loading forever', () {
    test('an unreadable device is shown as unsupported, switch off', () async {
      biometric.availabilityError = StateError('plugin missing');
      controller = SecurityController(biometric: biometric, account: account);
      await _settle();

      expect(controller.state.isLoaded, isTrue);
      expect(
        controller.state.settings!.availability,
        BiometricAvailability.noHardware,
      );
      expect(controller.state.settings!.switchOn, isFalse);
      expect(controller.state.settings!.switchEnabled, isFalse);
    });

    test('an unreadable stored preference is treated as not enabled', () async {
      account.readError = StateError('keychain');
      controller = SecurityController(biometric: biometric, account: account);
      await _settle();

      expect(controller.state.isLoaded, isTrue);
      expect(controller.state.settings!.preferenceEnabled, isFalse);
      expect(controller.state.settings!.switchEnabled, isTrue);
    });
  });

  group('refresh and notice', () {
    test('refresh re-reads availability (e.g. after returning from system '
        'settings)', () async {
      await create(availability: BiometricAvailability.notEnrolled);
      expect(controller.state.settings!.switchEnabled, isFalse);

      biometric.availabilityResult = BiometricAvailability.available;
      await controller.refresh();

      expect(controller.state.settings!.switchEnabled, isTrue);
      expect(biometric.availabilityCalls, 2);
    });

    test('a refresh keeps the shown notice and the loaded settings', () async {
      await create();
      biometric.authenticateResult = false;
      await controller.setEnabled(true, localizedReason: _reason);

      await controller.refresh();

      expect(controller.state.notice, SecurityNotice.enableFailed);
      expect(controller.state.isLoaded, isTrue);
    });

    test('clearNotice drops the one-shot notice', () async {
      await create();
      biometric.authenticateResult = false;
      await controller.setEnabled(true, localizedReason: _reason);

      controller.clearNotice();

      expect(controller.state.notice, isNull);
    });
  });
}
