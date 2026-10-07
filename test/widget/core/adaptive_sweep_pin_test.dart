import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/auth/password_change_gateway.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/account/presentation/pin_entry_panel.dart';
import 'package:finance/features/account/presentation/pin_flow_controller.dart';
import 'package:finance/features/account/presentation/pin_flow_screen.dart';
import 'package:finance/features/account/presentation/pin_offer_prompt.dart';
import 'package:finance/features/account/presentation/security_screen.dart';
import 'package:finance/features/account/presentation/sign_in_screen.dart';
import 'package:finance/features/account/presentation/widgets/pin_keypad.dart';

import '../../support/adaptive_sweep.dart';
import '../../support/load_app_fonts.dart';
import '../../support/lock_harness.dart';

/// A locked app: signed in, locked from the start.
class _AlwaysLocked extends AppLockNotifier {
  _AlwaysLocked(super.ref) {
    lock();
  }
}

class _FakeAccount extends Fake implements AccountAuthActions {
  @override
  Future<bool> isBiometricLoginEnabled() async => false;
}

class _FakeSession implements VerifiedPasswordSession {
  @override
  Future<void> close() async {}

  @override
  Future<void> continueOnThisDevice() async {}

  @override
  Future<void> setNewPassword(String newPassword) async {}
}

class _FakeGateway implements PasswordChangeGateway {
  @override
  Future<VerifiedPasswordSession> verifyCurrentPassword(String p) async =>
      _FakeSession();

  @override
  Future<void> ensureSessionActive() async {}

  @override
  Future<void> endOtherSessions() async {}
}

/// The PIN screens across the final sweep's matrix (the sweep helper is
/// `test/support/adaptive_sweep.dart`): the lock screen in PIN mode, each step
/// of the flow, the Security row and the one-time offer. Every case fails on
/// any framework exception, and the keypad is never wider than 450 dp.
void main() {
  late LockTestPins pins;

  setUpAll(loadAppFonts);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    pins = LockTestPins();
    await pins.repository.set('483920');
  });

  Future<void> sweep(
    WidgetTester tester,
    SweepCase c,
    Widget screen, {
    List<Override> overrides = const [],
  }) {
    return pumpSweepCase(
      tester,
      c,
      (theme) => screen,
      rail: false,
      wrap: (app) => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeLockAuthRepository()),
          pinLockRepositoryProvider.overrideWithValue(pins.repository),
          biometricLoginRepositoryProvider.overrideWithValue(
            FakeLockBiometric(BiometricAvailability.noHardware),
          ),
          passwordChangeGatewayProvider.overrideWithValue(_FakeGateway()),
          accountAuthActionsProvider.overrideWithValue(_FakeAccount()),
          ...overrides,
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

  void expectKeypadBounded(WidgetTester tester) {
    for (final element in find.byType(PinKeypad).evaluate()) {
      expect(
        (element.renderObject! as RenderBox).size.width,
        lessThanOrEqualTo(450.01),
      );
    }
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  group('lock screen in PIN mode', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(
          tester,
          c,
          const SignInScreen(),
          overrides: [
            isSignedInProvider.overrideWithValue(true),
            appLockProvider.overrideWith(_AlwaysLocked.new),
          ],
        );
        expect(find.byType(PinEntryPanel), findsOne);
        expectKeypadBounded(tester);
        // A wrong PIN adds a message line: still no overflow.
        await type(tester, '000001');
        expect(tester.takeException(), isNull);
        expectKeypadBounded(tester);
      });
    }
  });

  group('set-up flow, every step', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        await sweep(tester, c, const PinFlowScreen(mode: PinFlowMode.setUp));
        await tester.enterText(
          find.byKey(const ValueKey('pin-flow-password')),
          'Secret-123',
        );
        await tester.tap(find.byKey(const ValueKey('pin-flow-continue')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectKeypadBounded(tester);

        await type(tester, '123456'); // refused: message line
        expect(tester.takeException(), isNull);
        await type(tester, '594031'); // repeat step
        expect(tester.takeException(), isNull);
        await type(tester, '594032'); // mismatch: message line
        expect(tester.takeException(), isNull);
        expectKeypadBounded(tester);
      });
    }
  });

  group('change flow', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const PinFlowScreen(mode: PinFlowMode.change));
        expectKeypadBounded(tester);
        await type(tester, '000001');
        expect(tester.takeException(), isNull);
        await type(tester, '483920');
        expect(tester.takeException(), isNull);
        expectKeypadBounded(tester);
      });
    }
  });

  group('Bảo mật with an active PIN', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(tester, c, const SecurityScreen());
        expect(find.byKey(const ValueKey('security-pin-row')), findsOne);
        expect(find.byKey(const ValueKey('security-pin-change-row')), findsOne);
      });
    }
  });

  group('Bảo mật with no PIN yet', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        await sweep(tester, c, const SecurityScreen());
        expect(find.byKey(const ValueKey('security-pin-row')), findsOne);
        expect(
          find.byKey(const ValueKey('security-pin-change-row')),
          findsNothing,
        );
      });
    }
  });

  group('the one-time offer', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await sweep(
          tester,
          c,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPinOfferDialog(
                    Navigator.of(context, rootNavigator: true),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOne);
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byType(AlertDialog));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(c.width + 0.01));
      });
    }
  });
}
