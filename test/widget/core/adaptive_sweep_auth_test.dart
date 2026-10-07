import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/account/presentation/forgot_password_screen.dart';
import 'package:finance/features/account/presentation/reset_password_screen.dart';
import 'package:finance/features/account/presentation/sign_in_screen.dart';
import 'package:finance/features/account/presentation/sign_up_screen.dart';

import '../../support/adaptive_sweep.dart';
import '../../support/load_app_fonts.dart';

class _FakeAuth extends Fake implements AuthRepository {
  _FakeAuth({this.biometricEnabled = false});

  final bool biometricEnabled;

  @override
  Future<bool> isBiometricLoginEnabled() async => biometricEnabled;
}

class _FakeBiometric extends Fake implements BiometricLoginRepository {
  @override
  Future<bool> isDeviceCapable() async => true;
}

/// Final sweep, layer 1: the four sign-in screens (and the sign-in screen in
/// its lock mode, with the biometric button) across the width × theme × height
/// × text-size matrix. They are not part of the shell: no rail.
void main() {
  setUpAll(loadAppFonts);

  Future<void> sweep(
    WidgetTester tester,
    SweepCase c,
    Widget screen, {
    bool biometric = false,
  }) {
    return pumpSweepCase(
      tester,
      c,
      (theme) => screen,
      rail: false,
      wrap: (app) => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuth(biometricEnabled: biometric),
          ),
          biometricLoginRepositoryProvider.overrideWithValue(_FakeBiometric()),
        ],
        child: MaterialApp(
          theme: c.theme,
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(c.textScale)),
            child: child!,
          ),
          home: app,
        ),
      ),
    );
  }

  void expectFormBounded(WidgetTester tester, SweepCase c) {
    if (c.width < 600) return;
    final field = tester.getRect(find.byType(TextField).first);
    expect(field.width, lessThanOrEqualTo(450.01));
    expect(field.center.dx, closeTo(c.width / 2, 1));
  }

  group('Đăng nhập', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const SignInScreen());
        expectFormBounded(tester, c);
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Đăng nhập (khoá, có nút vân tay)', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const SignInScreen(), biometric: true);
        expectFormBounded(tester, c);
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Đăng ký', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const SignUpScreen());
        expectFormBounded(tester, c);
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Quên mật khẩu', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const ForgotPasswordScreen());
        expectFormBounded(tester, c);
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });

  group('Đặt lại mật khẩu', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const ResetPasswordScreen());
        expectFormBounded(tester, c);
        await expectNoDeadZoneFor(tester, c);
      });
    }
  });
}
