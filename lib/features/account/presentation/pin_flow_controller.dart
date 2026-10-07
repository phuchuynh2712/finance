import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/auth/pin_rules.dart';
import 'package:finance/core/error/error_mapper.dart';
import 'package:finance/core/l10n/app_localizations.dart';

/// What the PIN screen is doing (`contracts/pin-ui.md` §3).
enum PinFlowMode {
  /// Account password, then a new PIN twice.
  setUp,

  /// The current PIN, then a new PIN twice.
  change,

  /// The current PIN, then the PIN is removed.
  turnOff,
}

/// One screenful of the flow.
enum PinFlowStep {
  /// Type the account password.
  confirmPassword,

  /// Type the current PIN.
  currentPin,

  /// Type a new PIN.
  newPin,

  /// Type the new PIN again.
  repeatPin,

  /// Finished: the PIN is saved (or removed).
  done,

  /// Ended without a change: the PIN was used up or expired meanwhile.
  ended,
}

/// Why the flow is showing a message.
enum PinFlowIssueKind {
  /// The new PIN is all one digit or a straight run.
  tooEasy,

  /// The repeated PIN differs from the first.
  mismatch,

  /// The current PIN was wrong; [PinFlowIssue.triesLeft] more tries remain.
  wrongPin,

  /// The fifth wrong PIN: it is gone and only the password unlocks.
  invalidated,

  /// The PIN expired while the flow was open.
  expired,

  /// A failure reported by the service or the device; its text comes from the
  /// shared error mapper.
  service,
}

/// A message on the current step. It stores a *kind* (and, for a failure, the
/// raw error), never localized text, so a locale switch is immediate and no
/// password or PIN can end up in it.
class PinFlowIssue {
  const PinFlowIssue(this.kind, {this.error, this.triesLeft});

  final PinFlowIssueKind kind;
  final Object? error;

  /// Only for [PinFlowIssueKind.wrongPin].
  final int? triesLeft;

  String message(AppLocalizations l10n) => switch (kind) {
    PinFlowIssueKind.tooEasy => l10n.pinTooEasy,
    PinFlowIssueKind.mismatch => l10n.pinMismatch,
    PinFlowIssueKind.wrongPin => l10n.pinWrongTries(triesLeft ?? 0),
    PinFlowIssueKind.invalidated => l10n.pinInvalidated,
    PinFlowIssueKind.expired => l10n.pinExpired,
    PinFlowIssueKind.service =>
      error == null ? l10n.errorMapperGeneric : mapErrorToMessage(error!, l10n),
  };
}

/// The flow's state. [entered] is the digits typed on the current PIN step; the
/// password lives only in the screen's text field and is never kept here.
class PinFlowState {
  const PinFlowState({
    required this.mode,
    required this.step,
    this.entered = '',
    this.issue,
    this.isBusy = false,
  });

  final PinFlowMode mode;
  final PinFlowStep step;
  final String entered;
  final PinFlowIssue? issue;
  final bool isBusy;

  PinFlowState copyWith({
    PinFlowStep? step,
    String? entered,
    PinFlowIssue? issue,
    bool clearIssue = false,
    bool? isBusy,
  }) => PinFlowState(
    mode: mode,
    step: step ?? this.step,
    entered: entered ?? this.entered,
    issue: clearIssue ? null : (issue ?? this.issue),
    isBusy: isBusy ?? this.isBusy,
  );

  /// Never prints the digits typed so far.
  @override
  String toString() =>
      'PinFlowState($mode, $step, ${entered.length} digits, busy: $isBusy)';
}

/// The set-up flow as a state machine: no widget, no storage of its own. The
/// password check and the PIN repository come in as arguments, so every row of
/// §3 is a plain unit test. Nothing is written before the last step succeeds;
/// leaving the screen (disposing this) discards everything typed.
class PinFlowController extends StateNotifier<PinFlowState> {
  PinFlowController({
    required PinFlowMode mode,
    required Future<void> Function(String password) verifyPassword,
    required PinLockRepository pins,
  }) : _verifyPassword = verifyPassword,
       _pins = pins,
       super(
         PinFlowState(
           mode: mode,
           step: switch (mode) {
             PinFlowMode.setUp => PinFlowStep.confirmPassword,
             PinFlowMode.change ||
             PinFlowMode.turnOff => PinFlowStep.currentPin,
           },
         ),
       );

  final Future<void> Function(String password) _verifyPassword;
  final PinLockRepository _pins;

  /// The first PIN, kept in memory until the repeat step matches it.
  String? _firstPin;

  /// Checks the account password (the caller closes the temporary session it
  /// opens). A failure keeps the step and records the error for the mapper.
  Future<void> submitPassword(String password) async {
    if (state.step != PinFlowStep.confirmPassword || state.isBusy) return;
    state = state.copyWith(isBusy: true, clearIssue: true);
    try {
      await _verifyPassword(password);
      if (!mounted) return;
      state = state.copyWith(step: PinFlowStep.newPin, isBusy: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        issue: PinFlowIssue(PinFlowIssueKind.service, error: e),
        isBusy: false,
      );
    }
  }

  bool get _takesDigits =>
      state.step == PinFlowStep.currentPin ||
      state.step == PinFlowStep.newPin ||
      state.step == PinFlowStep.repeatPin;

  /// One digit `'0'`…`'9'`; the sixth completes the step at once.
  void addDigit(String digit) {
    if (state.isBusy || !_takesDigits || state.entered.length >= pinLength) {
      return;
    }
    state = state.copyWith(entered: state.entered + digit, clearIssue: true);
    if (state.entered.length == pinLength) unawaited(_completeStep());
  }

  void backspace() {
    if (state.isBusy || !_takesDigits || state.entered.isEmpty) return;
    state = state.copyWith(
      entered: state.entered.substring(0, state.entered.length - 1),
    );
  }

  Future<void> _completeStep() async {
    final pin = state.entered;
    switch (state.step) {
      case PinFlowStep.currentPin:
        await _checkCurrentPin(pin);
      case PinFlowStep.newPin:
        if (validate(pin) != null) {
          state = state.copyWith(
            entered: '',
            issue: const PinFlowIssue(PinFlowIssueKind.tooEasy),
          );
          return;
        }
        _firstPin = pin;
        state = state.copyWith(step: PinFlowStep.repeatPin, entered: '');
      case PinFlowStep.repeatPin:
        if (pin != _firstPin) {
          // Only this step restarts; the first PIN stays.
          state = state.copyWith(
            entered: '',
            issue: const PinFlowIssue(PinFlowIssueKind.mismatch),
          );
          return;
        }
        state = state.copyWith(isBusy: true);
        try {
          await _pins.set(pin);
          if (!mounted) return;
          _firstPin = null;
          state = state.copyWith(
            step: PinFlowStep.done,
            entered: '',
            isBusy: false,
          );
        } catch (e) {
          if (!mounted) return;
          state = state.copyWith(
            entered: '',
            issue: PinFlowIssue(PinFlowIssueKind.service, error: e),
            isBusy: false,
          );
        }
      case PinFlowStep.confirmPassword:
      case PinFlowStep.done:
      case PinFlowStep.ended:
        break;
    }
  }

  /// The only place the current PIN is compared is [PinLockRepository.verify],
  /// so a wrong try here counts toward the same five as on the lock screen.
  Future<void> _checkCurrentPin(String pin) async {
    state = state.copyWith(isBusy: true);
    try {
      final result = await _pins.verify(pin);
      if (!mounted) return;
      switch (result) {
        case PinCheckSuccess():
          if (state.mode == PinFlowMode.turnOff) {
            await _pins.clear();
            if (!mounted) return;
            state = state.copyWith(
              step: PinFlowStep.done,
              entered: '',
              isBusy: false,
            );
          } else {
            state = state.copyWith(
              step: PinFlowStep.newPin,
              entered: '',
              isBusy: false,
            );
          }
        case PinCheckWrong(:final triesLeft):
          state = state.copyWith(
            entered: '',
            issue: PinFlowIssue(
              PinFlowIssueKind.wrongPin,
              triesLeft: triesLeft,
            ),
            isBusy: false,
          );
        case PinCheckInvalidated():
          state = state.copyWith(
            step: PinFlowStep.ended,
            entered: '',
            issue: const PinFlowIssue(PinFlowIssueKind.invalidated),
            isBusy: false,
          );
        case PinCheckUnavailable():
          state = state.copyWith(
            step: PinFlowStep.ended,
            entered: '',
            issue: const PinFlowIssue(PinFlowIssueKind.expired),
            isBusy: false,
          );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        entered: '',
        issue: PinFlowIssue(PinFlowIssueKind.service, error: e),
        isBusy: false,
      );
    }
  }

  @override
  void dispose() {
    _firstPin = null;
    super.dispose();
  }
}

/// One controller per screen visit: leaving the screen discards it, and with it
/// everything typed.
final pinFlowControllerProvider = StateNotifierProvider.autoDispose
    .family<PinFlowController, PinFlowState, PinFlowMode>((ref, mode) {
      return PinFlowController(
        mode: mode,
        // The same temporary-session check as changing the password: sign in
        // with the typed password on a throwaway session, then close it, so
        // the app's own session, router and lock never see a second sign-in.
        verifyPassword: (password) async {
          final session = await ref
              .read(passwordChangeGatewayProvider)
              .verifyCurrentPassword(password);
          await session.close();
        },
        pins: ref.read(pinLockRepositoryProvider),
      );
    });
