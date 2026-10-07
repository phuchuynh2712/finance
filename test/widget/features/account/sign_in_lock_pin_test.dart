import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/account/presentation/pin_entry_panel.dart';

import '../../../support/load_app_fonts.dart';
import '../../../support/lock_harness.dart';

/// `contracts/pin-ui.md` §2: the lock screen in PIN mode (US2). The expired,
/// invalidated and forgotten paths are US4 and live further down.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Future<void> type(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump();
    }
  }

  Future<LockGate> openWithPin(
    WidgetTester tester, {
    BiometricAvailability availability = BiometricAvailability.noHardware,
    bool biometricOn = false,
  }) async {
    final pins = LockTestPins();
    await pins.repository.set('483920');
    final auth = FakeLockAuthRepository()..biometricEnabled = biometricOn;
    final gate = await pumpLockGate(
      tester,
      pins: pins,
      auth: auth,
      availability: availability,
    );
    await tester.pumpAndSettle();
    return gate;
  }

  testWidgets('locked with an active PIN: the PIN panel comes first', (
    tester,
  ) async {
    final gate = await openWithPin(tester);
    expect(gate.isLocked, isTrue);
    expect(find.byType(PinEntryPanel), findsOne);
    expect(find.text(l10n.pinEnterTitle), findsOne);
    expect(find.text(l10n.signInPasswordLabel), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('"Dùng mật khẩu" reveals the unchanged password form, the PIN '
      'stays', (tester) async {
    final gate = await openWithPin(tester);
    await tester.tap(find.text(l10n.pinUsePasswordAction));
    await tester.pumpAndSettle();
    expect(find.byType(PinEntryPanel), findsNothing);
    expect(find.text(l10n.signInPasswordLabel), findsOne);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text(l10n.signInSubmit), findsOne);
    expect(await gate.pins.repository.status(), PinStatus.active);
  });

  testWidgets('a correct PIN unlocks with no network call and lands on home', (
    tester,
  ) async {
    final gate = await openWithPin(tester);
    await type(tester, '483920');
    await tester.pumpAndSettle();
    expect(gate.isLocked, isFalse);
    expect(find.text('home'), findsOne);
    expect(gate.auth.networkCalls, isEmpty);
  });

  testWidgets('a wrong PIN keeps the app locked and shows the tries left', (
    tester,
  ) async {
    final gate = await openWithPin(tester);
    await type(tester, '000001');
    await tester.pumpAndSettle();
    expect(gate.isLocked, isTrue);
    expect(find.text(l10n.pinWrongTries(4)), findsOne);
  });

  testWidgets('no PIN set: the screen is exactly today\'s password form', (
    tester,
  ) async {
    final gate = await pumpLockGate(tester);
    await tester.pumpAndSettle();
    expect(gate.isLocked, isTrue);
    expect(find.byType(PinEntryPanel), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text(l10n.pinUsePasswordAction), findsNothing);
  });

  testWidgets('a device with biometrics and no PIN: today\'s screen', (
    tester,
  ) async {
    await pumpLockGate(tester, availability: BiometricAvailability.available);
    await tester.pumpAndSettle();
    expect(find.byType(PinEntryPanel), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('a PIN set earlier on a device that has since gained biometrics '
      'still shows the PIN panel', (tester) async {
    final gate = await openWithPin(
      tester,
      availability: BiometricAvailability.available,
    );
    expect(await gate.container.read(pinAvailableProvider.future), isFalse);
    expect(gate.container.read(pinInUseProvider), isTrue);
    expect(find.byType(PinEntryPanel), findsOne);
  });

  testWidgets('while the status is read only the logo and a progress '
      'indicator show, never the password form', (tester) async {
    final pins = LockTestPins();
    await pins.repository.set('483920');
    final never = Completer<PinStatus>();
    await pumpLockGate(
      tester,
      pins: pins,
      overrides: [pinStatusProvider.overrideWith((ref) => never.future)],
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOne);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(PinEntryPanel), findsNothing);
    expect(find.text(l10n.signInAppName), findsOne);
    never.complete(PinStatus.active);
    await tester.pumpAndSettle();
    expect(find.byType(PinEntryPanel), findsOne);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('biometric sign-in on and a PIN: the fingerprint button shows '
      'beside the panel', (tester) async {
    await openWithPin(
      tester,
      availability: BiometricAvailability.available,
      biometricOn: true,
    );
    expect(find.byType(PinEntryPanel), findsOne);
    expect(find.text(l10n.signInWithBiometricAction), findsOne);
  });

  testWidgets('the ordinary signed-out sign-in screen never shows a PIN', (
    tester,
  ) async {
    final pins = LockTestPins();
    await pins.repository.set('483920');
    await pumpLockGate(tester, pins: pins, signedIn: false);
    await tester.pumpAndSettle();
    expect(find.byType(PinEntryPanel), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  // ---------------------------------------------------------------- US4

  Future<void> signInWithPassword(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'qa@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'Secret-123');
    await tester.tap(find.text(l10n.signInSubmit));
    await tester.pumpAndSettle();
  }

  Future<void> wrongPins(WidgetTester tester, int count) async {
    for (var i = 1; i <= count; i++) {
      await type(tester, '00000$i');
      await tester.pumpAndSettle();
    }
  }

  group('wrong tries (FR-013)', () {
    testWidgets('four wrong PINs show 4, 3, 2, 1 tries left', (tester) async {
      await openWithPin(tester);
      for (final left in [4, 3, 2, 1]) {
        await type(tester, '000009');
        await tester.pumpAndSettle();
        expect(find.text(l10n.pinWrongTries(left)), findsOne);
      }
    });

    testWidgets('the fifth wrong PIN shows the invalidation message and the '
        'password form, and the PIN is gone', (tester) async {
      final gate = await openWithPin(tester);
      await wrongPins(tester, 5);
      expect(find.text(l10n.pinInvalidated), findsOne);
      expect(find.byType(PinEntryPanel), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(await gate.pins.raw('PIN_RECORD'), isNull);
      expect(await gate.pins.raw('PIN_FAILS'), isNull);
      expect(gate.isLocked, isTrue);
    });

    testWidgets('the count continues after the widget tree is recreated', (
      tester,
    ) async {
      final pins = LockTestPins();
      await pins.repository.set('483920');
      await pumpLockGate(tester, pins: pins);
      await tester.pumpAndSettle();
      await wrongPins(tester, 2);
      expect(find.text(l10n.pinWrongTries(3)), findsOne);

      await tester.pumpWidget(const SizedBox());
      await pumpLockGate(tester, pins: pins);
      await tester.pumpAndSettle();
      await type(tester, '000009');
      await tester.pumpAndSettle();
      expect(find.text(l10n.pinWrongTries(2)), findsOne);
    });

    testWidgets('a correct PIN after two wrong ones resets the count', (
      tester,
    ) async {
      final gate = await openWithPin(tester);
      await wrongPins(tester, 2);
      await type(tester, '483920');
      await tester.pumpAndSettle();
      expect(gate.isLocked, isFalse);
      expect(await gate.pins.raw('PIN_FAILS'), isNull);
      expect(await gate.pins.repository.triesLeft(), 5);
    });
  });

  group('forgot, expired, invalidated (FR-014, FR-016, FR-017)', () {
    testWidgets('"Quên mã PIN" then a password sign-in clears the PIN and '
        'offers a new one, as the only PIN dialog', (tester) async {
      final gate = await openWithPin(tester);
      await tester.tap(find.text(l10n.pinForgotAction));
      await tester.pumpAndSettle();
      expect(find.byType(PinEntryPanel), findsNothing);

      await signInWithPassword(tester);
      expect(gate.auth.networkCalls, ['signInWithPassword']);
      expect(gate.isLocked, isFalse);
      expect(await gate.pins.repository.status(), PinStatus.none);
      expect(find.byType(AlertDialog), findsOne);
      expect(find.text(l10n.pinOfferTitle), findsOne);
      expect(await gate.pins.raw('PIN_OFFER_SHOWN'), 'true');

      await tester.tap(find.text(l10n.pinOfferDeclineAction));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('home'), findsOne);
    });

    testWidgets('accepting the new-PIN offer opens the set-up flow', (
      tester,
    ) async {
      await openWithPin(tester);
      await tester.tap(find.text(l10n.pinForgotAction));
      await tester.pumpAndSettle();
      await signInWithPassword(tester);
      await tester.tap(find.text(l10n.pinOfferAcceptAction));
      await tester.pumpAndSettle();
      expect(find.text('pin-flow-setUp'), findsOne);
    });

    testWidgets('"Dùng mật khẩu" then a password sign-in keeps the PIN and '
        'offers nothing', (tester) async {
      final gate = await openWithPin(tester);
      await tester.tap(find.text(l10n.pinUsePasswordAction));
      await tester.pumpAndSettle();
      await signInWithPassword(tester);
      expect(gate.isLocked, isFalse);
      expect(await gate.pins.repository.status(), PinStatus.active);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('an expired PIN opens the password form with the expiry '
        'message, and a sign-in clears it and offers a new one', (
      tester,
    ) async {
      final pins = LockTestPins();
      await pins.repository.set('483920');
      pins.now = pins.now.add(const Duration(days: 366));
      final gate = await pumpLockGate(tester, pins: pins);
      await tester.pumpAndSettle();
      expect(find.byType(PinEntryPanel), findsNothing);
      expect(find.text(l10n.pinExpired), findsOne);
      expect(find.byType(TextField), findsNWidgets(2));

      await signInWithPassword(tester);
      expect(gate.isLocked, isFalse);
      expect(await pins.repository.status(), PinStatus.none);
      expect(find.text(l10n.pinOfferTitle), findsOne);
      expect(await pins.raw('PIN_OFFER_SHOWN'), 'true');
    });

    testWidgets('after the fifth wrong PIN, a password sign-in offers a new '
        'PIN once', (tester) async {
      final gate = await openWithPin(tester);
      await wrongPins(tester, 5);
      await signInWithPassword(tester);
      expect(find.byType(AlertDialog), findsOne);
      expect(find.text(l10n.pinOfferTitle), findsOne);
      expect(await gate.pins.raw('PIN_OFFER_SHOWN'), 'true');
      await tester.tap(find.text(l10n.pinOfferDeclineAction));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a PIN left over from an earlier session is removed by a '
        'password sign-in on the ordinary sign-in screen', (tester) async {
      final pins = LockTestPins();
      await pins.repository.set('483920');
      final gate = await pumpLockGate(tester, pins: pins, signedIn: false);
      await tester.pumpAndSettle();
      expect(await pins.repository.status(), PinStatus.active);

      await signInWithPassword(tester);
      expect(gate.auth.networkCalls, ['signInWithPassword']);
      expect(await pins.repository.status(), PinStatus.none);
      // Not the "forgot PIN" path: the only dialog is the ordinary one-time
      // offer, made once because no PIN is left and none was offered before.
      expect(find.byType(AlertDialog), findsOne);
      expect(find.text(l10n.pinOfferTitle), findsOne);
    });
  });
}
