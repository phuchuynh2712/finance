import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:finance/core/auth/biometric_login_repository.dart';

class _FakeLocalAuth extends Fake implements LocalAuthentication {
  bool canCheck = true;
  bool supported = true;
  List<BiometricType> enrolled = [BiometricType.fingerprint];
  final calls = <String>[];

  @override
  Future<bool> get canCheckBiometrics async {
    calls.add('canCheckBiometrics');
    return canCheck;
  }

  @override
  Future<bool> isDeviceSupported() async {
    calls.add('isDeviceSupported');
    return supported;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    calls.add('getAvailableBiometrics');
    return enrolled;
  }
}

void main() {
  late _FakeLocalAuth localAuth;

  setUp(() => localAuth = _FakeLocalAuth());

  BiometricLoginRepository repository({bool isWeb = false}) =>
      BiometricLoginRepository(localAuth, isWeb: isWeb);

  group('availability()', () {
    test('web is webUnsupported and never asks the device', () async {
      expect(
        await repository(isWeb: true).availability(),
        BiometricAvailability.webUnsupported,
      );
      expect(localAuth.calls, isEmpty);
    });

    test(
      'a device that cannot check biometrics at all is noHardware',
      () async {
        localAuth
          ..supported = false
          ..enrolled = [];

        expect(
          await repository().availability(),
          BiometricAvailability.noHardware,
        );
      },
    );

    test('supported but with nothing enrolled is notEnrolled', () async {
      localAuth.enrolled = [];

      expect(
        await repository().availability(),
        BiometricAvailability.notEnrolled,
      );
    });

    test('supported with an enrolled fingerprint is available', () async {
      expect(
        await repository().availability(),
        BiometricAvailability.available,
      );
    });

    test('supported with an enrolled face is available', () async {
      localAuth.enrolled = [BiometricType.face];

      expect(
        await repository().availability(),
        BiometricAvailability.available,
      );
    });
  });

  group('isDeviceCapable() keeps its existing behavior', () {
    test(
      'true only when it can check biometrics and the device is supported',
      () async {
        expect(await repository().isDeviceCapable(), isTrue);

        localAuth.canCheck = false;
        expect(await repository().isDeviceCapable(), isFalse);

        localAuth
          ..canCheck = true
          ..supported = false;
        expect(await repository().isDeviceCapable(), isFalse);
      },
    );
  });
}
