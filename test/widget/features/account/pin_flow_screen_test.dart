import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/password_change_gateway.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/pin_flow_controller.dart';
import 'package:finance/features/account/presentation/pin_flow_screen.dart';
import 'package:finance/features/account/presentation/widgets/pin_keypad.dart';

import '../../../support/expense_screen_harness.dart' show useView;
import '../../../support/load_app_fonts.dart';

class _FakeSession implements VerifiedPasswordSession {
  var closeCalls = 0;

  @override
  Future<void> close() async => closeCalls++;

  @override
  Future<void> continueOnThisDevice() async {}

  @override
  Future<void> setNewPassword(String newPassword) async {}
}

class _FakeGateway implements PasswordChangeGateway {
  final sessions = <_FakeSession>[];
  final checked = <String>[];
  Object? error;

  @override
  Future<VerifiedPasswordSession> verifyCurrentPassword(
    String currentPassword,
  ) async {
    checked.add(currentPassword);
    if (error != null) throw error!;
    final session = _FakeSession();
    sessions.add(session);
    return session;
  }

  @override
  Future<void> ensureSessionActive() async {}

  @override
  Future<void> endOtherSessions() async {}
}

/// `contracts/pin-ui.md` §3, mode `setUp`.
void main() {
  late AppLocalizations l10n;
  late _FakeGateway gateway;
  late PinLockRepository pins;
  Object? popResult;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    gateway = _FakeGateway();
    pins = SecurePinLockRepository(
      storage: const FlutterSecureStorage(),
      userId: () => 'user-a',
      now: () => DateTime.utc(2026, 3, 1, 9),
    );
    popResult = null;
  });

  /// A home page with one button that pushes the flow, so a pop is visible.
  Future<void> open(
    WidgetTester tester, {
    double width = 410,
    double height = 864,
    double textScale = 1,
    bool dark = false,
    TargetPlatform platform = TargetPlatform.android,
    PinFlowMode mode = PinFlowMode.setUp,
  }) async {
    useView(tester, width, height);
    final base = dark ? AppTheme.dark : AppTheme.light;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          passwordChangeGatewayProvider.overrideWithValue(gateway),
          pinLockRepositoryProvider.overrideWithValue(pins),
        ],
        child: MaterialApp(
          theme: base.copyWith(platform: platform),
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popResult = await Navigator.of(context).push<Object?>(
                      MaterialPageRoute(
                        builder: (_) => PinFlowScreen(mode: mode),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> passwordStep(
    WidgetTester tester, [
    String pw = 'Secret-123',
  ]) async {
    await tester.enterText(find.byKey(const ValueKey('pin-flow-password')), pw);
    await tester.tap(find.byKey(const ValueKey('pin-flow-continue')));
    await tester.pumpAndSettle();
  }

  /// Digits from a hardware keyboard.
  Future<void> keys(WidgetTester tester, String digits) async {
    const digitKeys = {
      '0': LogicalKeyboardKey.digit0,
      '1': LogicalKeyboardKey.digit1,
      '2': LogicalKeyboardKey.digit2,
      '3': LogicalKeyboardKey.digit3,
      '4': LogicalKeyboardKey.digit4,
      '5': LogicalKeyboardKey.digit5,
      '6': LogicalKeyboardKey.digit6,
      '7': LogicalKeyboardKey.digit7,
      '8': LogicalKeyboardKey.digit8,
      '9': LogicalKeyboardKey.digit9,
    };
    for (final d in digits.split('')) {
      await tester.sendKeyEvent(digitKeys[d]!, character: d);
    }
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('the three steps, then the PIN is saved and the screen closes '
      'with true', (tester) async {
    await open(tester);

    // 1. password
    expect(find.text(l10n.pinSetupConfirmPasswordTitle), findsOne);
    expect(find.byType(PinKeypad), findsNothing);
    await passwordStep(tester);
    expect(gateway.checked, ['Secret-123']);
    expect(
      gateway.sessions.single.closeCalls,
      1,
      reason: 'the temporary session is closed',
    );

    // 2. new PIN
    expect(find.text(l10n.pinSetupNewTitle), findsOne);
    expect(find.bySemanticsLabel('Đã nhập 0 trên 6 chữ số'), findsOne);
    await type(tester, '483920');

    // 3. repeat
    expect(find.text(l10n.pinSetupRepeatTitle), findsOne);
    expect(await pins.status(), PinStatus.none, reason: 'nothing saved yet');
    await type(tester, '483920');

    expect(find.byType(PinFlowScreen), findsNothing);
    expect(popResult, true);
    expect(await pins.status(), PinStatus.active);
    expect(await pins.verify('483920'), const PinCheckSuccess());
    expect(find.text(l10n.pinSetDone), findsOne);
  });

  testWidgets('a wrong password stays on the step with the sign-in message', (
    tester,
  ) async {
    gateway.error = const AuthApiException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );
    await open(tester);
    await passwordStep(tester, 'wrong-one');
    expect(find.text(l10n.pinSetupConfirmPasswordTitle), findsOne);
    expect(find.byType(PinKeypad), findsNothing);
    expect(gateway.sessions, isEmpty);
    expect(await pins.status(), PinStatus.none);
    final message = find.byKey(const ValueKey('pin-flow-message'));
    expect(tester.widget<Text>(message).data, isNotEmpty);
  });

  testWidgets(
    'an easy PIN and a mismatch show their messages in live regions',
    (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      await passwordStep(tester);

      await type(tester, '123456');
      expect(find.text(l10n.pinTooEasy), findsOne);
      expect(
        tester
            .getSemantics(find.text(l10n.pinTooEasy))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      expect(find.text(l10n.pinSetupNewTitle), findsOne);

      await type(tester, '483920');
      await type(tester, '483921');
      expect(find.text(l10n.pinMismatch), findsOne);
      expect(
        tester
            .getSemantics(find.text(l10n.pinMismatch))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      expect(
        find.text(l10n.pinSetupRepeatTitle),
        findsOne,
        reason: 'only the repeat step restarts',
      );
      expect(await pins.status(), PinStatus.none);

      await type(tester, '483920');
      expect(popResult, true);
      handle.dispose();
    },
  );

  testWidgets('the password step shows and hides the password', (tester) async {
    await open(tester);
    TextField field() => tester.widget<TextField>(
      find.byKey(const ValueKey('pin-flow-password')),
    );
    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip(l10n.signInShowPasswordSemantic));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('Escape leaves with nothing saved', (tester) async {
    await open(tester);
    await passwordStep(tester);
    await type(tester, '483920');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PinFlowScreen), findsNothing);
    expect(popResult, isNull);
    expect(await pins.status(), PinStatus.none);
  });

  testWidgets('the back button leaves with nothing saved', (tester) async {
    await open(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(PinFlowScreen), findsNothing);
    expect(popResult, isNull);
    expect(await pins.status(), PinStatus.none);
  });

  testWidgets('on a desktop the password field has the focus at first, then '
      'the keypad on the PIN steps', (tester) async {
    await open(tester, platform: TargetPlatform.macOS);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('pin-flow-password')),
    );
    expect(field.focusNode!.hasFocus, isTrue);

    await passwordStep(tester);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(
        of: find.byType(PinKeypad),
        matching: find.byWidget(focused.widget),
      ),
      findsOne,
    );
  });

  testWidgets('on a phone the keyboard is not raised by itself', (
    tester,
  ) async {
    await open(tester);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('pin-flow-password')),
    );
    expect(field.focusNode!.hasFocus, isFalse);
  });

  testWidgets('the whole set-up works from a hardware keyboard alone', (
    tester,
  ) async {
    await open(tester, platform: TargetPlatform.macOS);

    // Type the password, Enter confirms the step.
    await tester.enterText(
      find.byKey(const ValueKey('pin-flow-password')),
      'Secret-123',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text(l10n.pinSetupNewTitle), findsOne);

    // Digits and Backspace.
    await keys(tester, '483');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await keys(tester, '3');
    await tester.pump();
    expect(find.bySemanticsLabel('Đã nhập 3 trên 6 chữ số'), findsOne);
    await keys(tester, '920');
    await tester.pumpAndSettle();
    expect(find.text(l10n.pinSetupRepeatTitle), findsOne);
    await keys(tester, '483920');
    await tester.pumpAndSettle();
    expect(popResult, true);
    expect(await pins.verify('483920'), const PinCheckSuccess());
  });

  testWidgets('Tab reaches the Continue button from the password field', (
    tester,
  ) async {
    await open(tester, platform: TargetPlatform.macOS);
    await tester.enterText(
      find.byKey(const ValueKey('pin-flow-password')),
      'Secret-123',
    );
    var reached = false;
    for (var i = 0; i < 4 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = FocusManager.instance.primaryFocus?.context;
      reached =
          focus != null &&
          find
              .descendant(
                of: find.byKey(const ValueKey('pin-flow-continue')),
                matching: find.byWidget(focus.widget),
              )
              .evaluate()
              .isNotEmpty;
    }
    expect(reached, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text(l10n.pinSetupNewTitle), findsOne);
  });

  for (final width in [320.0, 412.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'no overflow at ${width.toInt()} dp, ${dark ? 'dark' : 'light'}, '
        '130 % text, every step',
        (tester) async {
          await open(
            tester,
            width: width,
            height: 500,
            textScale: 1.3,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          await passwordStep(tester);
          expect(tester.takeException(), isNull);
          await type(tester, '123456');
          expect(tester.takeException(), isNull);
          await type(tester, '483920');
          expect(tester.takeException(), isNull);
          await type(tester, '483921');
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(PinKeypad)).width,
            lessThanOrEqualTo(450),
          );
        },
      );
    }
  }

  group('change', () {
    setUp(() async {
      await pins.set('483920');
    });

    testWidgets('current PIN, new PIN, repeat: the PIN is replaced', (
      tester,
    ) async {
      await open(tester, mode: PinFlowMode.change);
      expect(find.text(l10n.pinChangeCurrentTitle), findsOne);
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'no password in a change',
      );
      await type(tester, '483920');
      expect(find.text(l10n.pinSetupNewTitle), findsOne);
      await type(tester, '594031');
      expect(find.text(l10n.pinSetupRepeatTitle), findsOne);
      await type(tester, '594031');

      expect(find.byType(PinFlowScreen), findsNothing);
      expect(popResult, true);
      expect(await pins.verify('594031'), const PinCheckSuccess());
      expect(find.text(l10n.pinSetDone), findsOne);
      expect(gateway.checked, isEmpty);
    });

    testWidgets('a wrong current PIN says how many tries are left', (
      tester,
    ) async {
      await open(tester, mode: PinFlowMode.change);
      await type(tester, '000001');
      expect(find.text(l10n.pinWrongTries(4)), findsOne);
      expect(find.text(l10n.pinChangeCurrentTitle), findsOne);
    });

    testWidgets('the fifth wrong PIN closes the flow with the invalidation '
        'message', (tester) async {
      await open(tester, mode: PinFlowMode.change);
      for (var i = 1; i <= 5; i++) {
        await type(tester, '00000$i');
      }
      expect(find.byType(PinFlowScreen), findsNothing);
      expect(popResult, false);
      expect(find.text(l10n.pinInvalidated), findsOne);
      expect(await pins.status(), PinStatus.none);
    });

    testWidgets('Escape leaves and the PIN stays', (tester) async {
      await open(tester, mode: PinFlowMode.change);
      await type(tester, '483920');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(popResult, isNull);
      expect(await pins.verify('483920'), const PinCheckSuccess());
    });
  });

  group('turnOff', () {
    setUp(() async {
      await pins.set('483920');
    });

    testWidgets('the right PIN turns it off, with no confirmation banner', (
      tester,
    ) async {
      await open(tester, mode: PinFlowMode.turnOff);
      expect(find.text(l10n.pinTurnOffTitle), findsOne);
      await type(tester, '483920');
      expect(find.byType(PinFlowScreen), findsNothing);
      expect(popResult, true);
      expect(await pins.status(), PinStatus.none);
      expect(find.text(l10n.pinSetDone), findsNothing);
    });

    testWidgets('a wrong PIN keeps it on', (tester) async {
      await open(tester, mode: PinFlowMode.turnOff);
      await type(tester, '000001');
      expect(find.text(l10n.pinWrongTries(4)), findsOne);
      expect(await pins.status(), PinStatus.active);
    });
  });

  for (final mode in [PinFlowMode.change, PinFlowMode.turnOff]) {
    for (final width in [320.0, 1440.0]) {
      for (final dark in [false, true]) {
        testWidgets('${mode.name}: no overflow at ${width.toInt()} dp, '
            '${dark ? 'dark' : 'light'}, 130 % text', (tester) async {
          await pins.set('483920');
          await open(
            tester,
            mode: mode,
            width: width,
            height: 500,
            textScale: 1.3,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          await type(tester, '000001');
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(PinKeypad)).width,
            lessThanOrEqualTo(450),
          );
        });
      }
    }
  }
}
