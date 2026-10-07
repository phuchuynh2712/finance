import 'package:finance/features/expenses/presentation/expense_key_mapping.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _digit(int d) =>
    isA<ExpenseDigitAction>().having((a) => a.digit, 'digit', d);

void main() {
  group('expenseKeyActionFor (contracts/expense-entry-ui.md K1–K7)', () {
    test('main-row digits map to digit actions', () {
      final keys = {
        '0': LogicalKeyboardKey.digit0,
        '1': LogicalKeyboardKey.digit1,
        '5': LogicalKeyboardKey.digit5,
        '9': LogicalKeyboardKey.digit9,
      };
      keys.forEach((character, key) {
        expect(
          expenseKeyActionFor(character: character, key: key),
          _digit(int.parse(character)),
        );
      });
    });

    test('numpad digits map to digit actions', () {
      expect(
        expenseKeyActionFor(character: '5', key: LogicalKeyboardKey.numpad5),
        _digit(5),
      );
      expect(
        expenseKeyActionFor(character: '0', key: LogicalKeyboardKey.numpad0),
        _digit(0),
      );
    });

    test('numpad digits without a character still map to digits', () {
      expect(expenseKeyActionFor(key: LogicalKeyboardKey.numpad9), _digit(9));
      expect(expenseKeyActionFor(key: LogicalKeyboardKey.numpad0), _digit(0));
    });

    test('Backspace maps to backspace', () {
      expect(
        expenseKeyActionFor(key: LogicalKeyboardKey.backspace),
        isA<ExpenseBackspaceAction>(),
      );
    });

    test('. and , map to the decimal no-op action', () {
      expect(
        expenseKeyActionFor(character: '.', key: LogicalKeyboardKey.period),
        isA<ExpenseDecimalAction>(),
      );
      expect(
        expenseKeyActionFor(character: ',', key: LogicalKeyboardKey.comma),
        isA<ExpenseDecimalAction>(),
      );
      expect(
        expenseKeyActionFor(key: LogicalKeyboardKey.numpadDecimal),
        isA<ExpenseDecimalAction>(),
      );
    });

    test('Enter and NumpadEnter map to save', () {
      expect(
        expenseKeyActionFor(key: LogicalKeyboardKey.enter),
        isA<ExpenseSaveAction>(),
      );
      expect(
        expenseKeyActionFor(key: LogicalKeyboardKey.numpadEnter),
        isA<ExpenseSaveAction>(),
      );
    });

    test(
      'Ctrl, Meta or Alt held makes every key unmapped (Ctrl+0 zoom reset)',
      () {
        for (final modifier in ['ctrl', 'meta', 'alt']) {
          expect(
            expenseKeyActionFor(
              character: '0',
              key: LogicalKeyboardKey.digit0,
              ctrl: modifier == 'ctrl',
              meta: modifier == 'meta',
              alt: modifier == 'alt',
            ),
            isNull,
            reason: modifier,
          );
          expect(
            expenseKeyActionFor(
              key: LogicalKeyboardKey.enter,
              ctrl: modifier == 'ctrl',
              meta: modifier == 'meta',
              alt: modifier == 'alt',
            ),
            isNull,
            reason: '$modifier+Enter',
          );
        }
      },
    );

    test('letters, symbols, arrows, Tab and Escape are unmapped', () {
      expect(
        expenseKeyActionFor(character: 'a', key: LogicalKeyboardKey.keyA),
        isNull,
      );
      expect(
        expenseKeyActionFor(character: '!', key: LogicalKeyboardKey.digit1),
        isNull,
      );
      expect(expenseKeyActionFor(key: LogicalKeyboardKey.arrowLeft), isNull);
      expect(expenseKeyActionFor(key: LogicalKeyboardKey.tab), isNull);
      expect(expenseKeyActionFor(key: LogicalKeyboardKey.escape), isNull);
      expect(expenseKeyActionFor(key: LogicalKeyboardKey.space), isNull);
    });

    test('a multi-character or empty character is not a digit', () {
      expect(
        expenseKeyActionFor(character: '12', key: LogicalKeyboardKey.digit1),
        isNull,
      );
      expect(
        expenseKeyActionFor(character: '', key: LogicalKeyboardKey.digit1),
        isNull,
      );
    });
  });
}
