import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/expenses/presentation/expense_screen.dart';

import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Future<void> _typeDigits(WidgetTester tester, String digits) async {
  const keys = {
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
  for (final digit in digits.split('')) {
    await _press(tester, keys[digit]!);
  }
}

/// Presses Tab until the focus sits inside [target], at most [max] times.
Future<void> _tabTo(WidgetTester tester, Finder target, {int max = 30}) async {
  for (var i = 0; i < max; i++) {
    if (focusIsWithin(tester, target)) return;
    await _press(tester, LogicalKeyboardKey.tab);
  }
  fail('Tab never reached $target');
}

Finder _modeTab(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

Finder _backButton() =>
    find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton));

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  group('digits, Backspace and the decimal key (K1–K3)', () {
    testWidgets('typing 1 0 0 0 0 0 reads 100.000 ₫', (tester) async {
      await pumpExpenseScreen(tester, width: 1440, height: 900);
      await _typeDigits(tester, '100000');
      expect(amountText(tester), contains('100.000'));
    });

    testWidgets('Backspace removes the last digit', (tester) async {
      await pumpExpenseScreen(tester, width: 1440, height: 900);
      await _typeDigits(tester, '1250');
      await _press(tester, LogicalKeyboardKey.backspace);
      expect(amountText(tester), contains('125'));
      expect(amountText(tester), isNot(contains('1.250')));
    });

    testWidgets('the numpad works like the main row', (tester) async {
      await pumpExpenseScreen(tester, width: 1440, height: 900);
      await _press(tester, LogicalKeyboardKey.numpad7);
      await _press(tester, LogicalKeyboardKey.numpad0);
      expect(amountText(tester), contains('70'));
    });

    testWidgets('. and , change nothing (whole-VND amounts)', (tester) async {
      await pumpExpenseScreen(tester, width: 1440, height: 900);
      await _typeDigits(tester, '12');
      final before = amountText(tester);
      await _press(tester, LogicalKeyboardKey.period);
      await _press(tester, LogicalKeyboardKey.comma);
      expect(amountText(tester), before);
    });

    testWidgets('letters do nothing', (tester) async {
      await pumpExpenseScreen(tester, width: 1440, height: 900);
      await _press(tester, LogicalKeyboardKey.keyA);
      expect(amountText(tester), contains('0'));
      expect(amountText(tester), isNot(contains('1')));
    });
  });

  group('Enter saves (K4)', () {
    testWidgets('after clicking digits and an account, Enter saves once', (
      tester,
    ) async {
      final repository = await pumpExpenseScreenPushed(
        tester,
        width: 1440,
        height: 900,
        items: accounts(3),
      );
      await tapDigits(tester, '50000');
      await tester.tap(chip('a2'));
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repository.recordExpenseCallCount, 1);
      expect(repository.lastItemId, 'a2');
      expect(repository.lastAmount, 50000);
      // Saved: the screen popped back to the home.
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('with no account chosen Enter saves nothing and explains', (
      tester,
    ) async {
      final repository = await pumpExpenseScreen(
        tester,
        width: 1440,
        height: 900,
        items: accounts(3),
      );
      await _typeDigits(tester, '500');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(repository.recordExpenseCallCount, 0);
      expect(find.text(l10n.expenseErrorMissingItem), findsOneWidget);
    });

    testWidgets('with no amount Enter saves nothing and explains', (
      tester,
    ) async {
      final repository = await pumpExpenseScreen(
        tester,
        width: 1440,
        height: 900,
        items: accounts(3),
      );
      await tester.tap(chip('a1'));
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.enter);
      expect(repository.recordExpenseCallCount, 0);
      expect(find.text(l10n.expenseErrorInvalidAmount), findsOneWidget);
    });
  });

  group('keyboard-only flow and focus rules (K5, K5b)', () {
    testWidgets(
      'digits, Tab to an account, Enter picks it (no save), Enter saves once',
      (tester) async {
        final repository = await pumpExpenseScreenPushed(
          tester,
          width: 1440,
          height: 900,
          items: accounts(3),
        );
        await _typeDigits(tester, '100000');
        await _tabTo(tester, chip('a2'));

        await _press(tester, LogicalKeyboardKey.enter);
        // Picked, but not saved: the preview banner shows, nothing recorded.
        expect(previewBanner(), findsOneWidget);
        expect(repository.recordExpenseCallCount, 0);

        // Focus is still on the (now chosen) chip: Enter saves.
        await _press(tester, LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(repository.recordExpenseCallCount, 1);
        expect(repository.lastItemId, 'a2');
        expect(repository.lastAmount, 100000);
      },
    );

    testWidgets('Enter on an unchosen account only picks it', (tester) async {
      final repository = await pumpExpenseScreen(
        tester,
        width: 1440,
        height: 900,
        items: accounts(3),
      );
      await _typeDigits(tester, '700');
      await tester.tap(chip('a1'));
      await tester.pump();
      await _tabTo(tester, chip('a3'));
      await _press(tester, LogicalKeyboardKey.enter);
      expect(repository.recordExpenseCallCount, 0);
      // a3 is now the chosen account: pressing Enter again saves it.
      await _press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repository.lastItemId, 'a3');
    });

    testWidgets('Enter on a mode tab activates the tab, not Save', (
      tester,
    ) async {
      final repository = await pumpExpenseScreen(
        tester,
        width: 1440,
        height: 900,
        items: accounts(3),
      );
      await _typeDigits(tester, '500');
      await tester.tap(chip('a1'));
      await tester.pump();
      await _tabTo(tester, _modeTab(l10n.expenseTabScan));
      await _press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(keypadKey('1'), findsNothing); // the scan tab is showing
      expect(repository.recordExpenseCallCount, 0);
    });

    testWidgets(
      'a pointer press returns focus to the panel, so Enter saves (K5b)',
      (tester) async {
        final repository = await pumpExpenseScreenPushed(
          tester,
          width: 1440,
          height: 900,
          items: accounts(3),
        );
        await tapDigits(tester, '500');
        await tester.tap(chip('a1'));
        await tester.pump();
        // Keyboard focus lands on another, unchosen account...
        await _tabTo(tester, chip('a2'));
        // ...then the person goes back to the mouse and presses a pad key.
        await tester.tap(keypadKey('5'));
        await tester.pump();
        await _press(tester, LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(repository.recordExpenseCallCount, 1);
        expect(repository.lastItemId, 'a1'); // not the stale a2
        expect(repository.lastAmount, 5005);
      },
    );
  });

  group('a held or repeated Enter saves once (K6)', () {
    testWidgets('key repeat after the first Enter does not save again', (
      tester,
    ) async {
      final repository = await pumpExpenseScreen(
        tester,
        width: 1440,
        height: 900,
        items: accounts(3),
      );
      repository.recordExpenseGate = Completer<void>();
      await tapDigits(tester, '500');
      await tester.tap(chip('a1'));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(repository.recordExpenseCallCount, 1);
      repository.recordExpenseGate!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('keys the screen must not swallow (K7, K8)', () {
    final observer = FocusNode(debugLabel: 'observer');
    tearDownAll(observer.dispose);

    Future<List<LogicalKeyboardKey>> pumpWithObserver(
      WidgetTester tester,
    ) async {
      useView(tester, 1440, 900);
      final seen = <LogicalKeyboardKey>[];
      await tester.pumpWidget(
        wrapForTest(
          Focus(
            focusNode: observer,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) seen.add(event.logicalKey);
              return KeyEventResult.ignored;
            },
            child: const ExpenseScreen(),
          ),
          repository: FakeExpenseControlRepository(accounts(3)),
        ),
      );
      await tester.pumpAndSettle();
      return seen;
    }

    testWidgets('Ctrl+0 is not consumed; a plain 0 is', (tester) async {
      final seen = await pumpWithObserver(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(seen, contains(LogicalKeyboardKey.digit0));

      seen.clear();
      await _press(tester, LogicalKeyboardKey.digit5);
      expect(seen, isNot(contains(LogicalKeyboardKey.digit5)));
    });

    testWidgets('unmapped keys are not consumed', (tester) async {
      final seen = await pumpWithObserver(tester);
      await _press(tester, LogicalKeyboardKey.keyA);
      expect(seen, contains(LogicalKeyboardKey.keyA));
    });

    testWidgets('the scan tab has no digit handler', (tester) async {
      final seen = await pumpWithObserver(tester);
      await tester.tap(find.text(l10n.expenseTabScan));
      await tester.pumpAndSettle();
      // The manual tab's panel is gone; the rest of the screen sees the key.
      observer.requestFocus();
      await tester.pump();
      seen.clear();
      await _press(tester, LogicalKeyboardKey.digit7);
      expect(seen, contains(LogicalKeyboardKey.digit7));
      await tester.tap(find.text(l10n.expenseTabManual));
      await tester.pumpAndSettle();
      expect(amountText(tester), isNot(contains('7')));
    });

    testWidgets('digits do nothing while a dialog is open', (tester) async {
      await pumpExpenseScreen(
        tester,
        width: 1440,
        height: 900,
        items: accounts(3),
      );
      final context = tester.element(find.byType(ExpenseScreen));
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('dialog body')),
      );
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.digit7);
      Navigator.of(context, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      expect(amountText(tester), isNot(contains('7')));
    });
  });

  group('Tab order (K9, K10)', () {
    testWidgets('pad keys are skipped; order is Back, tabs, chips, Save', (
      tester,
    ) async {
      await pumpExpenseScreen(
        tester,
        width: 1440,
        height: 900,
        items: accounts(3),
      );
      final stops = <String, Finder>{
        'back': _backButton(),
        'manual': _modeTab(l10n.expenseTabManual),
        'scan': _modeTab(l10n.expenseTabScan),
        'a1': chip('a1'),
        'a2': chip('a2'),
        'a3': chip('a3'),
        'save': saveButton(),
      };
      final visited = <String>[];
      for (var i = 0; i < 20; i++) {
        await _press(tester, LogicalKeyboardKey.tab);
        for (final key in const ['1', '5', '0', '⌫', '.']) {
          expect(
            focusIsWithin(tester, keypadKey(key)),
            isFalse,
            reason: 'pad key $key must not take focus',
          );
        }
        for (final entry in stops.entries) {
          if (focusIsWithin(tester, entry.value) &&
              (visited.isEmpty || visited.last != entry.key)) {
            visited.add(entry.key);
          }
        }
      }
      const expected = ['back', 'manual', 'scan', 'a1', 'a2', 'a3', 'save'];
      final start = expected.indexOf(visited.first);
      final rotated = [
        ...expected.sublist(start),
        ...expected.sublist(0, start),
      ];
      expect(visited.take(expected.length).toList(), rotated);
      expect(visited.toSet(), containsAll(expected));
    });
  });
}
