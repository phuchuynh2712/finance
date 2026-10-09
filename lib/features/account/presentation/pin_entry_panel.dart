import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/auth/pin_rules.dart';
import 'package:finance/core/error/error_mapper.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/features/account/presentation/widgets/pin_dots.dart';
import 'package:finance/features/account/presentation/widgets/pin_keypad.dart';

/// The PIN half of the lock screen (`contracts/pin-ui.md` §2): a title, the
/// dots, one live message line, the number pad and the two ways out ("Dùng mật
/// khẩu", "Quên mã PIN"). The sixth digit verifies at once, with no confirm
/// key, and the keys are off while the check runs.
///
/// It decides nothing about the app: it reports back, and the lock screen
/// unlocks, shows the password form or explains. The PIN lives only in this
/// state, is never logged, and is cleared after every check.
class PinEntryPanel extends ConsumerStatefulWidget {
  const PinEntryPanel({
    super.key,
    required this.onUnlocked,
    required this.onInvalidated,
    required this.onUsePassword,
    required this.onForgot,
  });

  /// The PIN was right.
  final VoidCallback onUnlocked;

  /// The fifth wrong try: the PIN is gone, only the password unlocks.
  final VoidCallback onInvalidated;

  /// "Dùng mật khẩu": the password form, the PIN stays.
  final VoidCallback onUsePassword;

  /// "Quên mã PIN": the password form, and a new PIN is offered after it.
  final VoidCallback onForgot;

  @override
  ConsumerState<PinEntryPanel> createState() => _PinEntryPanelState();
}

class _PinEntryPanelState extends ConsumerState<PinEntryPanel> {
  String _entered = '';
  bool _checking = false;
  String? _message;

  void _onDigit(String digit) {
    if (_checking || _entered.length >= pinLength) return;
    setState(() {
      _entered += digit;
      _message = null;
    });
    if (_entered.length == pinLength) _check();
  }

  void _onBackspace() {
    if (_checking || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(pinLockRepositoryProvider);
    final pin = _entered;
    setState(() => _checking = true);
    try {
      final result = await repository.verify(pin);
      if (!mounted) return;
      switch (result) {
        case PinCheckSuccess():
          setState(() => _entered = '');
          widget.onUnlocked();
        case PinCheckWrong(:final triesLeft):
          setState(() {
            _entered = '';
            _message = l10n.pinWrongTries(triesLeft);
          });
        case PinCheckInvalidated():
          setState(() => _entered = '');
          ref.invalidate(pinStatusProvider);
          widget.onInvalidated();
        case PinCheckUnavailable():
          // Expired or removed meanwhile: the lock screen re-reads the status
          // and shows the password form with the right explanation.
          setState(() => _entered = '');
          ref.invalidate(pinStatusProvider);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _entered = '';
        _message = mapErrorToMessage(e, l10n);
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Column(
      key: const ValueKey('pin-entry-panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.pinEnterTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        PinDots(entered: _entered.length),
        const SizedBox(height: 12),
        // One line is always reserved, so a message appearing does not move
        // the keypad under a finger.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _message ?? '',
              key: const ValueKey('pin-message'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        PinKeypad(
          autofocus: true,
          enabled: !_checking,
          onDigit: _onDigit,
          onBackspace: _onBackspace,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton(
              onPressed: _checking ? null : widget.onUsePassword,
              child: Text(
                l10n.pinUsePasswordAction,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _checking ? null : widget.onForgot,
              child: Text(
                l10n.pinForgotAction,
                style: TextStyle(fontSize: 13, color: semantic.fg3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
