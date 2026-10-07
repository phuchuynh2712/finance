import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/widgets/pin_dots.dart';
import 'package:finance/features/account/presentation/widgets/pin_keypad.dart';

import '../../../support/expense_screen_harness.dart' show useView;
import '../../../support/load_app_fonts.dart';

/// `contracts/pin-ui.md` §1: the two widgets the lock screen and the set-up
/// flow share.
void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 410,
    double height = 700,
    double textScale = 1,
    Locale locale = const Locale('vi'),
    ThemeData? theme,
  }) async {
    useView(tester, width, height);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pump();
  }

  group('PinKeypad', () {
    testWidgets('every on-screen digit key reports its digit', (tester) async {
      final digits = <String>[];
      await pump(tester, PinKeypad(onDigit: digits.add, onBackspace: () {}));
      for (var d = 0; d <= 9; d++) {
        await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      }
      expect(digits, ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']);
    });

    testWidgets('the delete key calls onBackspace', (tester) async {
      var backspaces = 0;
      await pump(
        tester,
        PinKeypad(onDigit: (_) {}, onBackspace: () => backspaces++),
      );
      await tester.tap(find.byKey(const ValueKey('pin-key-backspace')));
      expect(backspaces, 1);
    });

    testWidgets('digits and Backspace from a hardware keyboard work', (
      tester,
    ) async {
      final digits = <String>[];
      var backspaces = 0;
      await pump(
        tester,
        PinKeypad(
          autofocus: true,
          onDigit: digits.add,
          onBackspace: () => backspaces++,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4, character: '4');
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad7);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(digits, ['4', '7']);
      expect(backspaces, 1);
    });

    testWidgets('letters and shortcuts such as Ctrl+0 are left alone', (
      tester,
    ) async {
      final digits = <String>[];
      await pump(
        tester,
        PinKeypad(autofocus: true, onDigit: digits.add, onBackspace: () {}),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0, character: '0');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(digits, isEmpty);
    });

    testWidgets('holding a digit key does not type it again', (tester) async {
      final digits = <String>[];
      await pump(
        tester,
        PinKeypad(autofocus: true, onDigit: digits.add, onBackspace: () {}),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit5, character: '5');
      await tester.sendKeyRepeatEvent(
        LogicalKeyboardKey.digit5,
        character: '5',
      );
      await tester.sendKeyRepeatEvent(
        LogicalKeyboardKey.digit5,
        character: '5',
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit5);
      expect(digits, ['5']);
    });

    testWidgets('enabled: false ignores taps and keys', (tester) async {
      final digits = <String>[];
      var backspaces = 0;
      await pump(
        tester,
        PinKeypad(
          autofocus: true,
          enabled: false,
          onDigit: digits.add,
          onBackspace: () => backspaces++,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pin-key-1')));
      await tester.tap(find.byKey(const ValueKey('pin-key-backspace')));
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(digits, isEmpty);
      expect(backspaces, 0);
    });

    testWidgets('keys are at least 48 dp and the pad is at most 450 dp wide', (
      tester,
    ) async {
      await pump(
        tester,
        PinKeypad(onDigit: (_) {}, onBackspace: () {}),
        width: 1200,
      );
      for (final key in [
        for (var d = 0; d <= 9; d++) 'pin-key-$d',
        'pin-key-backspace',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
      }
      expect(
        tester.getSize(find.byType(PinKeypad)).width,
        lessThanOrEqualTo(450),
      );
    });

    testWidgets('the delete key has a label and a tooltip', (tester) async {
      await pump(tester, PinKeypad(onDigit: (_) {}, onBackspace: () {}));
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.bySemanticsLabel(l10n.pinKeypadDeleteSemantic), findsOne);
      expect(find.byTooltip(l10n.pinKeypadDeleteSemantic), findsOne);
    });

    testWidgets('digit keys are announced as their digit', (tester) async {
      await pump(tester, PinKeypad(onDigit: (_) {}, onBackspace: () {}));
      for (final d in ['1', '5', '0']) {
        expect(find.bySemanticsLabel(d), findsWidgets, reason: d);
      }
    });

    testWidgets('no overflow at 320 dp wide and 130 % text, light and dark', (
      tester,
    ) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await pump(
          tester,
          PinKeypad(onDigit: (_) {}, onBackspace: () {}),
          width: 320,
          height: 500,
          textScale: 1.3,
          theme: theme,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('PinDots', () {
    testWidgets('one label, never the digits', (tester) async {
      await pump(tester, const PinDots(entered: 3));
      expect(find.bySemanticsLabel('Đã nhập 3 trên 6 chữ số'), findsOne);
    });

    testWidgets('the English label', (tester) async {
      await pump(tester, const PinDots(entered: 0), locale: const Locale('en'));
      expect(find.bySemanticsLabel('0 of 6 digits entered'), findsOne);
    });

    testWidgets('six dots, as many filled as digits entered', (tester) async {
      await pump(tester, const PinDots(entered: 2));
      final filled = [
        for (var i = 0; i < 6; i++)
          (tester
                          .widget<Container>(find.byKey(ValueKey('pin-dot-$i')))
                          .decoration!
                      as BoxDecoration)
                  .color !=
              null,
      ];
      expect(filled, [true, true, false, false, false, false]);
    });

    testWidgets('no text at all is drawn, so a digit can never show', (
      tester,
    ) async {
      await pump(tester, const PinDots(entered: 6));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('no overflow at 320 dp wide and 130 % text', (tester) async {
      await pump(
        tester,
        const PinDots(entered: 4),
        width: 320,
        height: 500,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
