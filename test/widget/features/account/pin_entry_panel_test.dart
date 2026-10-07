import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/pin_entry_panel.dart';
import 'package:finance/features/account/presentation/widgets/pin_keypad.dart';

import '../../../support/expense_screen_harness.dart' show useView;
import '../../../support/load_app_fonts.dart';
import '../../../support/lock_harness.dart';

/// `contracts/pin-ui.md` §2: the PIN panel of the lock screen.
void main() {
  late AppLocalizations l10n;
  late LockTestPins pins;
  var unlocked = 0;
  var invalidated = 0;
  var usedPassword = 0;
  var forgot = 0;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Future<void> pump(
    WidgetTester tester, {
    double width = 410,
    double height = 864,
    ThemeData? theme,
    double textScale = 1,
    PinLockRepository? repository,
  }) async {
    unlocked = invalidated = usedPassword = forgot = 0;
    useView(tester, width, height);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinLockRepositoryProvider.overrideWithValue(
            repository ?? pins.repository,
          ),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: app!,
          ),
          home: Scaffold(
            body: Center(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: PinEntryPanel(
                    onUnlocked: () => unlocked++,
                    onInvalidated: () => invalidated++,
                    onUsePassword: () => usedPassword++,
                    onForgot: () => forgot++,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump();
    }
  }

  setUp(() async {
    pins = LockTestPins();
    await pins.repository.set('483920');
  });

  testWidgets('shows the title, the dots, the keypad and both links', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(l10n.pinEnterTitle), findsOne);
    expect(find.bySemanticsLabel('Đã nhập 0 trên 6 chữ số'), findsOne);
    expect(find.byType(PinKeypad), findsOne);
    expect(find.text(l10n.pinUsePasswordAction), findsOne);
    expect(find.text(l10n.pinForgotAction), findsOne);
  });

  testWidgets('the dots follow the digits and Backspace removes one', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, '48');
    expect(find.bySemanticsLabel('Đã nhập 2 trên 6 chữ số'), findsOne);
    await tester.tap(find.byKey(const ValueKey('pin-key-backspace')));
    await tester.pump();
    expect(find.bySemanticsLabel('Đã nhập 1 trên 6 chữ số'), findsOne);
  });

  testWidgets('the sixth digit verifies at once, and the right PIN unlocks', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, '48392');
    expect(unlocked, 0, reason: 'five digits are not enough');
    await tester.tap(find.byKey(const ValueKey('pin-key-0')));
    await tester.pump();
    await tester.pump();
    expect(unlocked, 1);
    expect(invalidated, 0);
  });

  testWidgets('keys are disabled while the check runs', (tester) async {
    final slow = _SlowPins(pins.repository);
    await pump(tester, repository: slow);
    await type(tester, '483920');
    final keypad = tester.widget<PinKeypad>(find.byType(PinKeypad));
    expect(keypad.enabled, isFalse);
    // A tap during the check is ignored.
    await tester.tap(find.byKey(const ValueKey('pin-key-1')));
    await tester.pump();
    slow.finish();
    await tester.pump();
    await tester.pump();
    expect(unlocked, 1);
    expect(slow.verifyCalls, 1);
    expect(tester.widget<PinKeypad>(find.byType(PinKeypad)).enabled, isTrue);
  });

  testWidgets('a wrong PIN clears the entry and says how many tries are left', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, '000001');
    await tester.pump();
    expect(find.text(l10n.pinWrongTries(4)), findsOne);
    expect(find.bySemanticsLabel('Đã nhập 0 trên 6 chữ số'), findsOne);
    expect(unlocked, 0);

    await type(tester, '000002');
    await tester.pump();
    expect(find.text(l10n.pinWrongTries(3)), findsOne);
  });

  testWidgets('the wrong-tries message is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await type(tester, '000001');
    await tester.pump();
    final node = tester.getSemantics(find.text(l10n.pinWrongTries(4)));
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('no semantic label or value ever contains the typed digits', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await type(tester, '4839');
    final labels = <String>[];
    void walk(SemanticsNode node) {
      labels
        ..add(node.label)
        ..add(node.value)
        ..add(node.hint);
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(
      tester
          .binding
          .renderViews
          .first
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    final text = labels.join('\n');
    expect(text.contains('4839'), isFalse);
    expect(text.contains('483'), isFalse);
    expect(text, contains('Đã nhập 4 trên 6 chữ số'));
    handle.dispose();
  });

  testWidgets('typing again removes the message', (tester) async {
    await pump(tester);
    await type(tester, '000001');
    await tester.pump();
    expect(find.text(l10n.pinWrongTries(4)), findsOne);
    await type(tester, '1');
    expect(find.text(l10n.pinWrongTries(4)), findsNothing);
  });

  testWidgets(
    'the fifth wrong PIN reports invalidated and the record is gone',
    (tester) async {
      await pump(tester);
      for (var i = 1; i <= 5; i++) {
        await type(tester, '00000$i');
        await tester.pump();
      }
      expect(invalidated, 1);
      expect(unlocked, 0);
      expect(await pins.repository.status(), PinStatus.none);
    },
  );

  testWidgets('the links call back', (tester) async {
    await pump(tester);
    await tester.tap(find.text(l10n.pinUsePasswordAction));
    await tester.tap(find.text(l10n.pinForgotAction));
    expect(usedPassword, 1);
    expect(forgot, 1);
  });

  testWidgets('a storage failure never unlocks and shows a message', (
    tester,
  ) async {
    await pump(tester, repository: _ThrowingPins());
    await type(tester, '483920');
    await tester.pump();
    expect(unlocked, 0);
    expect(find.byKey(const ValueKey('pin-message')), findsOne);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('pin-message')))
          .data!
          .trim(),
      isNotEmpty,
    );
  });

  for (final width in [320.0, 410.0, 900.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'no overflow at ${width.toInt()} dp, ${dark ? 'dark' : 'light'}, '
        '130 % text',
        (tester) async {
          await pump(
            tester,
            width: width,
            height: 500,
            textScale: 1.3,
            theme: dark ? AppTheme.dark : AppTheme.light,
          );
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(PinKeypad)).width,
            lessThanOrEqualTo(450),
          );
        },
      );
    }
  }
}

/// Holds `verify` open until [finish] so the in-progress state can be seen.
class _SlowPins implements PinLockRepository {
  _SlowPins(this._inner);

  final PinLockRepository _inner;
  var verifyCalls = 0;
  final _gate = Completer<void>();

  void finish() => _gate.complete();

  @override
  Future<PinCheckResult> verify(String pin) async {
    verifyCalls++;
    await _gate.future;
    return _inner.verify(pin);
  }

  @override
  Future<PinStatus> status() => _inner.status();

  @override
  Future<int> triesLeft() => _inner.triesLeft();

  @override
  Future<void> set(String pin) => _inner.set(pin);

  @override
  Future<void> clear() => _inner.clear();

  @override
  Future<bool> shouldOfferPin() => _inner.shouldOfferPin();

  @override
  Future<void> markOfferShown() => _inner.markOfferShown();
}

class _ThrowingPins implements PinLockRepository {
  @override
  Future<PinCheckResult> verify(String pin) async =>
      throw StateError('storage unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
