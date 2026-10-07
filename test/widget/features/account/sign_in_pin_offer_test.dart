import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/sign_up_screen.dart';

import '../../../support/expense_screen_harness.dart' show useView;
import '../../../support/load_app_fonts.dart';
import '../../../support/lock_harness.dart';

class _SignUpAuth extends FakeLockAuthRepository {
  var signUps = 0;

  @override
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    signUps++;
    await Future<void>.delayed(Duration.zero);
  }
}

/// `contracts/pin-ui.md` §5: the one-time PIN offer follows the biometric
/// offer after a successful sign-in or sign-up, and blocks neither.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  group('sign-in', () {
    Future<void> signIn(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'qa@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'Secret-123');
      await tester.tap(find.text(l10n.signInSubmit));
      await tester.pumpAndSettle();
    }

    testWidgets('the biometric offer comes first, then the PIN offer', (
      tester,
    ) async {
      final auth = FakeLockAuthRepository()..showBiometricPrompt = true;
      await pumpLockGate(
        tester,
        auth: auth,
        signedIn: false,
        deviceCapable: true,
      );
      await tester.pumpAndSettle();
      await signIn(tester);

      expect(find.text(l10n.biometricEnablePromptTitle), findsOne);
      expect(
        find.text(l10n.pinOfferTitle),
        findsNothing,
        reason: 'one dialog at a time',
      );
      await tester.tap(find.text(l10n.biometricEnablePromptDeclineAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.pinOfferTitle), findsOne);
      await tester.tap(find.text(l10n.pinOfferDeclineAction));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no biometric offer, the PIN offer shows straight away', (
      tester,
    ) async {
      await pumpLockGate(tester, signedIn: false);
      await tester.pumpAndSettle();
      await signIn(tester);
      expect(find.text(l10n.pinOfferTitle), findsOne);
    });

    testWidgets('a device with usable biometrics gets no PIN offer', (
      tester,
    ) async {
      await pumpLockGate(
        tester,
        signedIn: false,
        availability: BiometricAvailability.available,
      );
      await tester.pumpAndSettle();
      await signIn(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a failed sign-in offers nothing', (tester) async {
      final auth = FakeLockAuthRepository()
        ..throwOnSignInWithPassword = Exception('boom');
      await pumpLockGate(tester, auth: auth, signedIn: false);
      await tester.pumpAndSettle();
      await signIn(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the offer is made once: a second sign-in does not repeat it', (
      tester,
    ) async {
      final pins = LockTestPins();
      await pumpLockGate(tester, pins: pins, signedIn: false);
      await tester.pumpAndSettle();
      await signIn(tester);
      await tester.tap(find.text(l10n.pinOfferDeclineAction));
      await tester.pumpAndSettle();
      await signIn(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('sign-up', () {
    Future<_SignUpAuth> openSignUp(
      WidgetTester tester, {
      bool biometricOffer = false,
    }) async {
      useView(tester, 410, 864);
      final auth = _SignUpAuth()..showBiometricPrompt = biometricOffer;
      final pins = LockTestPins();
      final biometric = FakeLockBiometric(BiometricAvailability.noHardware)
        ..deviceCapable = biometricOffer ? true : null;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            biometricLoginRepositoryProvider.overrideWithValue(biometric),
            pinLockRepositoryProvider.overrideWithValue(pins.repository),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            locale: const Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: GoRouter(
              initialLocation: '/sign-up',
              routes: [
                GoRoute(
                  path: '/sign-up',
                  builder: (context, state) => const SignUpScreen(),
                ),
                GoRoute(
                  path: '/sign-in',
                  builder: (context, state) => const Scaffold(),
                ),
                GoRoute(
                  path: '/account/security/pin/:mode',
                  builder: (context, state) => Scaffold(
                    body: Text('pin-flow-${state.pathParameters['mode']}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(2), 'user@example.com');
      await tester.enterText(find.byType(TextField).at(3), 'password123');
      await tester.enterText(find.byType(TextField).at(4), 'password123');
      await tester.ensureVisible(find.textContaining('Tôi đồng ý với'));
      await tester.tap(find.textContaining('Tôi đồng ý với'));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();
    }

    testWidgets('a successful sign-up offers a PIN', (tester) async {
      final auth = await openSignUp(tester);
      await submit(tester);
      expect(auth.signUps, 1);
      expect(find.text(l10n.pinOfferTitle), findsOne);
      await tester.tap(find.text(l10n.pinOfferAcceptAction));
      await tester.pumpAndSettle();
      expect(find.text('pin-flow-setUp'), findsOne);
    });

    testWidgets('the biometric offer comes first, then the PIN offer', (
      tester,
    ) async {
      await openSignUp(tester, biometricOffer: true);
      await submit(tester);
      expect(find.text(l10n.biometricEnablePromptTitle), findsOne);
      await tester.tap(find.text(l10n.biometricEnablePromptDeclineAction));
      await tester.pumpAndSettle();
      expect(find.text(l10n.pinOfferTitle), findsOne);
    });
  });
}
