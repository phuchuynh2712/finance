import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/auth/password_change_gateway.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/account/presentation/pin_flow_controller.dart';
import 'package:finance/features/account/presentation/pin_flow_screen.dart';
import 'package:finance/features/account/presentation/security_screen.dart';

import '../../../support/expense_screen_harness.dart' show useView;
import '../../../support/load_app_fonts.dart';

class _FakeBiometric extends Fake implements BiometricLoginRepository {
  _FakeBiometric(this.availabilityResult);

  BiometricAvailability availabilityResult;

  @override
  Future<BiometricAvailability> availability() async => availabilityResult;
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
  Future<VerifiedPasswordSession> verifyCurrentPassword(
    String currentPassword,
  ) async => _FakeSession();

  @override
  Future<void> ensureSessionActive() async {}

  @override
  Future<void> endOtherSessions() async {}
}

const _row = ValueKey('security-pin-row');
const _switchKey = ValueKey('security-pin-switch');
const _caption = ValueKey('security-pin-caption');

/// `contracts/pin-ui.md` §4: the Bảo mật row, off and on states.
void main() {
  late AppLocalizations l10n;
  late DateTime now;
  late PinLockRepository pins;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    now = DateTime.utc(2026, 3, 1, 9);
    pins = SecurePinLockRepository(
      storage: const FlutterSecureStorage(),
      userId: () => 'user-a',
      now: () => now,
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    BiometricAvailability availability = BiometricAvailability.noHardware,
    double width = 410,
    double height = 864,
    double textScale = 1,
    bool dark = false,
  }) async {
    useView(tester, width, height);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          biometricLoginRepositoryProvider.overrideWithValue(
            _FakeBiometric(availability),
          ),
          accountAuthActionsProvider.overrideWithValue(_FakeAccount()),
          pinLockRepositoryProvider.overrideWithValue(pins),
          passwordChangeGatewayProvider.overrideWithValue(_FakeGateway()),
        ],
        child: MaterialApp.router(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
          routerConfig: GoRouter(
            initialLocation: '/account/security',
            routes: [
              GoRoute(
                path: '/account/security',
                builder: (context, state) => const SecurityScreen(),
                routes: [
                  GoRoute(
                    path: 'pin/:mode',
                    builder: (context, state) => PinFlowScreen(
                      mode: PinFlowMode.values.byName(
                        state.pathParameters['mode']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Switch switchWidget(WidgetTester tester) =>
      tester.widget<Switch>(find.byKey(_switchKey));

  group('visibility', () {
    testWidgets('no usable biometrics and no PIN: the row is there, off', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(_row), findsOne);
      expect(find.text(l10n.pinLockRow), findsOne);
      expect(
        tester.widget<Text>(find.byKey(_caption)).data,
        l10n.pinLockRowCaptionOff,
      );
      expect(switchWidget(tester).value, isFalse);
      expect(switchWidget(tester).onChanged, isNotNull);
    });

    testWidgets('biometrics not enrolled count as unusable too', (
      tester,
    ) async {
      await pump(tester, availability: BiometricAvailability.notEnrolled);
      expect(find.byKey(_row), findsOne);
    });

    testWidgets('biometrics available and no PIN: no PIN row, the biometric '
        'row is untouched', (tester) async {
      await pump(tester, availability: BiometricAvailability.available);
      expect(find.byKey(_row), findsNothing);
      expect(find.byKey(const ValueKey('security-biometric-row')), findsOne);
    });

    testWidgets('the web (no biometric API): no PIN row', (tester) async {
      await pump(tester, availability: BiometricAvailability.webUnsupported);
      expect(find.byKey(_row), findsNothing);
      expect(find.byKey(const ValueKey('security-biometric-row')), findsOne);
    });

    testWidgets('a PIN exists although biometrics are available: the row is '
        'there, on', (tester) async {
      await pins.set('483920');
      await pump(tester, availability: BiometricAvailability.available);
      expect(find.byKey(_row), findsOne);
      expect(switchWidget(tester).value, isTrue);
      expect(
        tester.widget<Text>(find.byKey(_caption)).data,
        l10n.pinLockRowCaptionOn,
      );
    });

    testWidgets('an expired PIN: switch off, caption says so, tapping sets a '
        'new one', (tester) async {
      await pins.set('483920');
      now = now.add(const Duration(days: 366));
      await pump(tester);
      expect(switchWidget(tester).value, isFalse);
      expect(
        tester.widget<Text>(find.byKey(_caption)).data,
        l10n.pinLockRowCaptionExpired,
      );
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();
      expect(find.byType(PinFlowScreen), findsOne);
    });
  });

  group('turning it on', () {
    testWidgets('the switch while off pushes the set-up flow', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();
      expect(find.byType(PinFlowScreen), findsOne);
      expect(find.text(l10n.pinSetupConfirmPasswordTitle), findsOne);
    });

    testWidgets('tapping the row does the same', (tester) async {
      await pump(tester);
      await tester.tap(find.text(l10n.pinLockRow));
      await tester.pumpAndSettle();
      expect(find.byType(PinFlowScreen), findsOne);
    });

    testWidgets('after a successful set-up the row shows as on', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('pin-flow-password')),
        'Secret-123',
      );
      await tester.tap(find.byKey(const ValueKey('pin-flow-continue')));
      await tester.pumpAndSettle();
      for (var round = 0; round < 2; round++) {
        for (final d in '483920'.split('')) {
          await tester.tap(find.byKey(ValueKey('pin-key-$d')));
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      expect(find.byType(PinFlowScreen), findsNothing);
      expect(switchWidget(tester).value, isTrue);
      expect(
        tester.widget<Text>(find.byKey(_caption)).data,
        l10n.pinLockRowCaptionOn,
      );
      expect(find.text(l10n.pinSetDone), findsOne);
    });

    testWidgets('leaving the flow keeps the row off', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(switchWidget(tester).value, isFalse);
      expect(await pins.status(), PinStatus.none);
    });
  });

  group('layout', () {
    for (final width in [320.0, 412.0, 1200.0]) {
      for (final dark in [false, true]) {
        testWidgets('no overflow at ${width.toInt()} dp, '
            '${dark ? 'dark' : 'light'}, 130 % text', (tester) async {
          await pump(
            tester,
            width: width,
            height: 600,
            textScale: 1.3,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(_row), findsOne);
        });
      }
    }
  });

  group('the actions of an active PIN', () {
    setUp(() async {
      await pins.set('483920');
    });

    testWidgets('a change row sits below the PIN row; it opens the change '
        'flow', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('security-pin-change-row')), findsOne);
      expect(find.text(l10n.pinChangeAction), findsOne);
      await tester.tap(find.byKey(const ValueKey('security-pin-change-row')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pinChangeCurrentTitle), findsOne);
    });

    testWidgets('switching it off asks for the current PIN, then the row is '
        'off', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pinTurnOffTitle), findsOne);
      for (final d in '483920'.split('')) {
        await tester.tap(find.byKey(ValueKey('pin-key-$d')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(PinFlowScreen), findsNothing);
      expect(switchWidget(tester).value, isFalse);
      expect(
        tester.widget<Text>(find.byKey(_caption)).data,
        l10n.pinLockRowCaptionOff,
      );
      expect(
        find.byKey(const ValueKey('security-pin-change-row')),
        findsNothing,
      );
      expect(await pins.status(), PinStatus.none);
    });

    testWidgets('after the fifth wrong PIN in the flow the row is gone '
        '(biometrics available) and the message shows', (tester) async {
      await pump(tester, availability: BiometricAvailability.available);
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();
      for (var i = 1; i <= 5; i++) {
        for (final d in '00000$i'.split('')) {
          await tester.tap(find.byKey(ValueKey('pin-key-$d')));
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }
      expect(find.byType(PinFlowScreen), findsNothing);
      expect(find.text(l10n.pinInvalidated), findsOne);
      expect(find.byKey(_row), findsNothing);
    });

    testWidgets('the row stays after the device gains biometrics and can '
        'still be turned off', (tester) async {
      await pump(tester, availability: BiometricAvailability.available);
      expect(find.byKey(_row), findsOne);
      expect(switchWidget(tester).value, isTrue);
      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pinTurnOffTitle), findsOne);
    });

    testWidgets('no overflow at 320 dp, 130 % text, with the change row', (
      tester,
    ) async {
      await pump(tester, width: 320, height: 600, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });
}
