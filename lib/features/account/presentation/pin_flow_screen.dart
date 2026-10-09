import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_layout.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/adaptive_body.dart';
import 'package:finance/features/account/presentation/pin_flow_controller.dart';
import 'package:finance/features/account/presentation/widgets/password_field.dart';
import 'package:finance/features/account/presentation/widgets/pin_dots.dart';
import 'package:finance/features/account/presentation/widgets/pin_keypad.dart';

/// Sets up, changes or turns off the PIN (`contracts/pin-ui.md` §3): the account
/// password (set-up) or the current PIN (change, turn off), then the new PIN
/// twice. Pushed from Bảo mật (and from the one-time offer); pops with `true`
/// once the PIN is saved or removed, with `false` when the PIN ended meanwhile
/// (used up or expired), and with nothing if the person leaves first.
///
/// The typed password lives only in this screen's text controller and is
/// cleared when the screen is left; nothing is written until the last step.
class PinFlowScreen extends ConsumerStatefulWidget {
  const PinFlowScreen({super.key, required this.mode});

  final PinFlowMode mode;

  @override
  ConsumerState<PinFlowScreen> createState() => _PinFlowScreenState();
}

class _PinFlowScreenState extends ConsumerState<PinFlowScreen> {
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;
  bool _finished = false;

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  PinFlowController get _controller =>
      ref.read(pinFlowControllerProvider(widget.mode).notifier);

  void _submitPassword() {
    final state = ref.read(pinFlowControllerProvider(widget.mode));
    if (state.isBusy) return;
    _controller.submitPassword(_passwordController.text);
  }

  void _leave() => Navigator.of(context).maybePop();

  /// The PIN is saved or removed: re-read the status everywhere, close, and
  /// confirm a new or changed PIN (turning it off shows in the row itself).
  void _finish() {
    if (_finished) return;
    _finished = true;
    _passwordController.clear();
    ref.invalidate(pinStatusProvider);
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).pinSetDone;
    Navigator.of(context).pop(true);
    if (widget.mode != PinFlowMode.turnOff) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// The PIN was used up or expired while the flow was open: nothing changed,
  /// close and say why on the screen underneath.
  void _end(PinFlowIssue? issue) {
    if (_finished) return;
    _finished = true;
    ref.invalidate(pinStatusProvider);
    final messenger = ScaffoldMessenger.of(context);
    final message = issue?.message(AppLocalizations.of(context));
    Navigator.of(context).pop(false);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Only where there is a hardware keyboard may the password field take the
  /// focus by itself (a phone must not raise its on-screen keyboard).
  bool get _hasHardwareKeyboard => switch (Theme.of(context).platform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final state = ref.watch(pinFlowControllerProvider(widget.mode));
    ref.listen<PinFlowState>(pinFlowControllerProvider(widget.mode), (
      previous,
      next,
    ) {
      if (next.step == PinFlowStep.done) _finish();
      if (next.step == PinFlowStep.ended) _end(next.issue);
    });

    final title = switch (state.step) {
      PinFlowStep.confirmPassword => l10n.pinSetupConfirmPasswordTitle,
      PinFlowStep.currentPin =>
        widget.mode == PinFlowMode.turnOff
            ? l10n.pinTurnOffTitle
            : l10n.pinChangeCurrentTitle,
      PinFlowStep.newPin => l10n.pinSetupNewTitle,
      PinFlowStep.repeatPin => l10n.pinSetupRepeatTitle,
      PinFlowStep.done || PinFlowStep.ended => l10n.pinSetDone,
    };
    final message = state.issue?.message(l10n);

    final messageLine = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message ?? '',
          key: const ValueKey('pin-flow-message'),
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
        ),
      ),
    );

    final body = state.step == PinFlowStep.confirmPassword
        ? FocusTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepTitle(title),
                const SizedBox(height: 20),
                PasswordField(
                  fieldKey: const ValueKey('pin-flow-password'),
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  autofocus: _hasHardwareKeyboard,
                  label: l10n.signInPasswordLabel,
                  autofillHint: AutofillHints.password,
                  obscure: !_showPassword,
                  onToggle: () =>
                      setState(() => _showPassword = !_showPassword),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {},
                  onSubmitted: (_) => _submitPassword(),
                ),
                const SizedBox(height: 8),
                messageLine,
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('pin-flow-continue'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: state.isBusy ? null : _submitPassword,
                    child: state.isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.pinSetupContinueAction),
                  ),
                ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StepTitle(title),
              const SizedBox(height: 20),
              PinDots(entered: state.entered.length),
              const SizedBox(height: 12),
              messageLine,
              const SizedBox(height: 8),
              PinKeypad(
                autofocus: true,
                enabled: !state.isBusy,
                onDigit: _controller.addDigit,
                onBackspace: _controller.backspace,
              ),
            ],
          );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _leave},
      child: Scaffold(
        backgroundColor: semantic.bgApp,
        appBar: AppBar(
          backgroundColor: semantic.bgApp,
          title: Text(l10n.pinLockRow),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AdaptiveBody(
                activatesAt: WindowSizeClass.medium,
                maxWidth: AppLayoutTokens.authContentMaxWidth,
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
