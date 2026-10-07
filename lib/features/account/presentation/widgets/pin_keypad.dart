import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';

/// The 3 × 4 number pad of the PIN screens: `1…9`, an empty cell, `0`, and a
/// delete key. Taps and a hardware keyboard (digits, the number pad's digits,
/// Backspace) do the same thing; any held Ctrl, Meta or Alt leaves the key
/// alone so browser shortcuts such as Ctrl+0 keep working.
///
/// The keys are not Tab stops (twelve of them would make keyboard navigation
/// worse): typing is the keyboard path, like the Chi tiêu pad.
class PinKeypad extends StatefulWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    this.autofocus = false,
  });

  /// Called with the digit as a one-character string, `'0'`…`'9'`.
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// While `false` (a check is running) nothing is reported.
  final bool enabled;

  /// Asks for the keyboard focus so a hardware keyboard works at once.
  final bool autofocus;

  /// The widest the pad grows on a wide window.
  static const double maxWidth = 360;

  static const double keyHeight = 56;
  static const double keyGap = 8;

  @override
  State<PinKeypad> createState() => _PinKeypadState();
}

class _PinKeypadState extends State<PinKeypad> {
  static final _numpadDigits = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (widget.enabled) widget.onBackspace();
      return KeyEventResult.handled;
    }
    // A held digit key is one digit, not a run of them.
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final digit = _digitOf(event);
    if (digit == null) return KeyEventResult.ignored;
    if (widget.enabled) widget.onDigit(digit);
    return KeyEventResult.handled;
  }

  /// Only the characters `0`–`9` count (a layout that needs Shift for digits or
  /// a Telex layout behave); the number pad reports its own keys.
  String? _digitOf(KeyEvent event) {
    final character = event.character;
    if (character != null && character.length == 1) {
      final code = character.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) return character;
    }
    return _numpadDigits[event.logicalKey];
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PinKeypad.maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', '⌫'],
            ]) ...[
              if (row.first != '1') const SizedBox(height: PinKeypad.keyGap),
              Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: PinKeypad.keyGap),
                    Expanded(child: _keyFor(context, row[i])),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _keyFor(BuildContext context, String key) {
    if (key.isEmpty) return const SizedBox(height: PinKeypad.keyHeight);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final isDelete = key == '⌫';
    final face = isDelete
        ? Semantics(
            button: true,
            label: l10n.pinKeypadDeleteSemantic,
            excludeSemantics: true,
            child: Icon(LucideIcons.delete, size: 20, color: semantic.fg2),
          )
        : Text(
            key,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          );
    final button = Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        key: ValueKey(isDelete ? 'pin-key-backspace' : 'pin-key-$key'),
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(4),
        onTap: widget.enabled
            ? () => isDelete ? widget.onBackspace() : widget.onDigit(key)
            : null,
        child: Container(
          height: PinKeypad.keyHeight,
          decoration: BoxDecoration(
            border: Border.all(color: semantic.border1),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: face,
        ),
      ),
    );
    if (!isDelete) return button;
    // Icon-only key: a tooltip for the mouse (the screen-reader label is the
    // [Semantics] above, so the tooltip does not announce it twice).
    return Tooltip(
      message: l10n.pinKeypadDeleteSemantic,
      excludeFromSemantics: true,
      child: button,
    );
  }
}
