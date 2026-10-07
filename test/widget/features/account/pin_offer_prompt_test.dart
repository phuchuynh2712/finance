import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/pin_offer_prompt.dart';

import '../../../support/expense_screen_harness.dart' show useView;
import '../../../support/lock_harness.dart';

/// `contracts/pin-ui.md` §5: the dialog that offers a PIN.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Future<void> open(
    WidgetTester tester, {
    double width = 410,
    double height = 864,
  }) async {
    useView(tester, width, height);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => offerPinSetUp(
                      Navigator.of(context, rootNavigator: true),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
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
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title, the message and both buttons', (tester) async {
    await open(tester);
    expect(find.byType(AlertDialog), findsOne);
    expect(find.text(l10n.pinOfferTitle), findsOne);
    expect(find.text(l10n.pinOfferMessage), findsOne);
    expect(find.text(l10n.pinOfferAcceptAction), findsOne);
    expect(find.text(l10n.pinOfferDeclineAction), findsOne);
  });

  testWidgets('the accept button has the initial focus; Enter accepts and '
      'pushes the set-up flow', (tester) async {
    await open(tester, width: 1440, height: 900);
    final accept = find.widgetWithText(FilledButton, l10n.pinOfferAcceptAction);
    final focus = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(of: accept, matching: find.byWidget(focus.widget)),
      findsOne,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('pin-flow-setUp'), findsOne);
  });

  testWidgets('tapping the accept button pushes the set-up flow', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text(l10n.pinOfferAcceptAction));
    await tester.pumpAndSettle();
    expect(find.text('pin-flow-setUp'), findsOne);
  });

  testWidgets('the decline button closes it and nothing is pushed', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text(l10n.pinOfferDeclineAction));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('pin-flow-setUp'), findsNothing);
    expect(find.text('Open'), findsOne, reason: 'the app is reachable');
  });

  testWidgets('Escape is declining', (tester) async {
    await open(tester, width: 1440, height: 900);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('pin-flow-setUp'), findsNothing);
  });

  testWidgets('a tap outside the dialog is declining', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('pin-flow-setUp'), findsNothing);
  });

  testWidgets('fully visible at 320 dp wide', (tester) async {
    await open(tester, width: 320, height: 500);
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byType(AlertDialog));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
  });

  group('maybeShowPinOfferPrompt (the one-time offer)', () {
    late LockTestPins pins;

    Future<void> openPrompt(
      WidgetTester tester, {
      BiometricAvailability availability = BiometricAvailability.noHardware,
      LockTestPins? withPins,
    }) async {
      pins = withPins ?? LockTestPins();
      useView(tester, 410, 864);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricLoginRepositoryProvider.overrideWithValue(
              FakeLockBiometric(availability),
            ),
            pinLockRepositoryProvider.overrideWithValue(pins.repository),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            locale: const Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () => maybeShowPinOfferPrompt(
                          Navigator.of(context, rootNavigator: true),
                          ProviderScope.containerOf(context),
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
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
    }

    Future<void> press(WidgetTester tester) async {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a phone with no usable biometrics, no PIN, never offered: '
        'the offer shows, and the marker is written before it', (tester) async {
      await openPrompt(tester);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOne);
      expect(
        await pins.raw('PIN_OFFER_SHOWN'),
        'true',
        reason: 'written while the dialog is still open',
      );
    });

    testWidgets('biometrics not enrolled count as unusable too', (
      tester,
    ) async {
      await openPrompt(tester, availability: BiometricAvailability.notEnrolled);
      await press(tester);
      expect(find.byType(AlertDialog), findsOne);
    });

    testWidgets('biometrics available: no offer, and the marker stays free', (
      tester,
    ) async {
      await openPrompt(tester, availability: BiometricAvailability.available);
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await pins.raw('PIN_OFFER_SHOWN'), isNull);
    });

    testWidgets('the web (no biometric API): no offer', (tester) async {
      await openPrompt(
        tester,
        availability: BiometricAvailability.webUnsupported,
      );
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a PIN already in use: no offer', (tester) async {
      final existing = LockTestPins();
      await existing.repository.set('483920');
      await openPrompt(tester, withPins: existing);
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('an expired PIN is still "in use": no offer', (tester) async {
      final existing = LockTestPins();
      await existing.repository.set('483920');
      existing.now = existing.now.add(const Duration(days: 400));
      await openPrompt(tester, withPins: existing);
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the marker already exists: no offer', (tester) async {
      final existing = LockTestPins();
      await existing.repository.markOfferShown();
      await openPrompt(tester, withPins: existing);
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('declining means it never shows again for that account on '
        'that device', (tester) async {
      await openPrompt(tester);
      await press(tester);
      await tester.tap(find.text(l10n.pinOfferDeclineAction));
      await tester.pumpAndSettle();
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('closing it with Escape counts as declining', (tester) async {
      await openPrompt(tester);
      await press(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('accepting pushes the set-up flow', (tester) async {
      await openPrompt(tester);
      await press(tester);
      await tester.tap(find.text(l10n.pinOfferAcceptAction));
      await tester.pumpAndSettle();
      expect(find.text('pin-flow-setUp'), findsOne);
    });

    testWidgets('a different account gets its own offer', (tester) async {
      await openPrompt(tester);
      await press(tester);
      await tester.tap(find.text(l10n.pinOfferDeclineAction));
      await tester.pumpAndSettle();

      pins.userId = 'user-b';
      await press(tester);
      expect(find.byType(AlertDialog), findsOne);
      await tester.tap(find.text(l10n.pinOfferDeclineAction));
      await tester.pumpAndSettle();

      pins.userId = 'user-a';
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a sign-out (clearing the PIN) keeps the marker, so it is '
        'not offered again', (tester) async {
      await openPrompt(tester);
      await press(tester);
      await tester.tap(find.text(l10n.pinOfferDeclineAction));
      await tester.pumpAndSettle();
      await pins.repository.clear();
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a storage failure while deciding shows nothing and throws '
        'nothing', (tester) async {
      pins = LockTestPins();
      useView(tester, 410, 864);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricLoginRepositoryProvider.overrideWithValue(
              FakeLockBiometric(BiometricAvailability.noHardware),
            ),
            pinLockRepositoryProvider.overrideWithValue(_ThrowingPins()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => maybeShowPinOfferPrompt(
                    Navigator.of(context, rootNavigator: true),
                    ProviderScope.containerOf(context),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await press(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ThrowingPins implements PinLockRepository {
  @override
  Future<PinStatus> status() async => throw StateError('storage unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
