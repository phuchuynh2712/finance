import 'package:flutter/services.dart';

/// What a physical key press means on the "Chi tiêu" pad. Each action maps
/// 1:1 to the controller call the matching on-screen key already makes, so
/// keyboard and pad share one code path (SC-002).
sealed class ExpenseKeyAction {
  const ExpenseKeyAction();
}

/// A digit `0`–`9`: `controller.appendDigit`.
final class ExpenseDigitAction extends ExpenseKeyAction {
  const ExpenseDigitAction(this.digit);

  final int digit;
}

/// Backspace: `controller.backspace`.
final class ExpenseBackspaceAction extends ExpenseKeyAction {
  const ExpenseBackspaceAction();
}

/// The decimal separator: the same no-op as the on-screen `.` key (amounts are
/// whole VND).
final class ExpenseDecimalAction extends ExpenseKeyAction {
  const ExpenseDecimalAction();
}

/// Enter: `controller.save` (under the focus rules of the screen).
final class ExpenseSaveAction extends ExpenseKeyAction {
  const ExpenseSaveAction();
}

/// Numpad digit keys, for platforms that report them as `numpad0`…`numpad9`
/// without a character (the browser reports a numpad digit as the digit key).
final _numpadDigits = <LogicalKeyboardKey, int>{
  LogicalKeyboardKey.numpad0: 0,
  LogicalKeyboardKey.numpad1: 1,
  LogicalKeyboardKey.numpad2: 2,
  LogicalKeyboardKey.numpad3: 3,
  LogicalKeyboardKey.numpad4: 4,
  LogicalKeyboardKey.numpad5: 5,
  LogicalKeyboardKey.numpad6: 6,
  LogicalKeyboardKey.numpad7: 7,
  LogicalKeyboardKey.numpad8: 8,
  LogicalKeyboardKey.numpad9: 9,
};

/// Maps a key press to an [ExpenseKeyAction], or `null` when the key means
/// nothing on this screen. Pure — no widget, no focus — so it is unit-tested
/// as a table (contracts/expense-entry-ui.md K1–K7).
///
/// [character] is the key event's `character` (so a numpad, a layout that
/// needs Shift for digits, or a Vietnamese Telex layout all behave: only the
/// characters `'0'`–`'9'` count as digits). Any held `Ctrl`, `Meta` or `Alt`
/// makes the key unmapped, so browser shortcuts such as `Ctrl+0` (zoom reset)
/// keep working.
ExpenseKeyAction? expenseKeyActionFor({
  String? character,
  required LogicalKeyboardKey key,
  bool ctrl = false,
  bool meta = false,
  bool alt = false,
}) {
  if (ctrl || meta || alt) return null;
  if (character != null && character.length == 1) {
    final code = character.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) {
      return ExpenseDigitAction(code - 0x30);
    }
    if (character == '.' || character == ',') {
      return const ExpenseDecimalAction();
    }
  }
  final numpadDigit = _numpadDigits[key];
  if (numpadDigit != null) return ExpenseDigitAction(numpadDigit);
  if (key == LogicalKeyboardKey.backspace) {
    return const ExpenseBackspaceAction();
  }
  if (key == LogicalKeyboardKey.numpadDecimal) {
    return const ExpenseDecimalAction();
  }
  if (key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter) {
    return const ExpenseSaveAction();
  }
  return null;
}
