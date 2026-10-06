import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/error/error_mapper.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/account/application/change_password_service.dart';
import 'package:finance/features/account/domain/password_policy.dart';

/// Why a field (or the whole form) is showing an error.
enum ChangePasswordIssueKind {
  /// The current-password field is empty.
  currentRequired,

  /// The new password is shorter than [PasswordPolicy.minLength].
  tooShort,

  /// The new password equals the current one.
  sameAsCurrent,

  /// The confirmation differs from the new password.
  mismatch,

  /// The service rejected the current password.
  wrongCurrent,

  /// A failure reported by the service; its text comes from the shared
  /// error mapper.
  service,
}

/// An error shown on a field or in the banner. It stores a *kind* (and, for
/// service failures, the raw error), never localized text: the text is
/// resolved with [message] at display time, so a locale switch is immediate
/// and no password can leak into it.
class ChangePasswordIssue {
  const ChangePasswordIssue(this.kind, [this.error]);

  final ChangePasswordIssueKind kind;
  final Object? error;

  String message(AppLocalizations l10n) => switch (kind) {
    ChangePasswordIssueKind.currentRequired =>
      l10n.changePasswordCurrentRequiredError,
    ChangePasswordIssueKind.tooShort => l10n.passwordTooShortError,
    ChangePasswordIssueKind.sameAsCurrent =>
      l10n.changePasswordSameAsCurrentError,
    ChangePasswordIssueKind.mismatch => l10n.resetPasswordMismatchError,
    ChangePasswordIssueKind.wrongCurrent =>
      l10n.changePasswordWrongCurrentError,
    ChangePasswordIssueKind.service =>
      error == null ? l10n.errorMapperGeneric : mapErrorToMessage(error!, l10n),
  };
}

/// The form's non-secret state. The typed passwords live only in the screen's
/// `TextEditingController`s; nothing here can hold one.
class ChangePasswordFormState {
  const ChangePasswordFormState({
    this.isSubmitting = false,
    this.currentIssue,
    this.newIssue,
    this.confirmIssue,
    this.bannerIssue,
  });

  final bool isSubmitting;
  final ChangePasswordIssue? currentIssue;
  final ChangePasswordIssue? newIssue;
  final ChangePasswordIssue? confirmIssue;

  /// Failures that belong to no single field (offline, throttled, session
  /// ended, unexpected).
  final ChangePasswordIssue? bannerIssue;

  bool get hasIssues =>
      currentIssue != null ||
      newIssue != null ||
      confirmIssue != null ||
      bannerIssue != null;
}

class ChangePasswordController extends StateNotifier<ChangePasswordFormState> {
  ChangePasswordController(this._service)
    : super(const ChangePasswordFormState());

  final ChangePasswordService _service;

  /// Validates, then asks the service to change the password (single-flight).
  ///
  /// Returns the outcome — [ChangePasswordOutcome.changed] or
  /// [ChangePasswordOutcome.changedOthersNotEnded] — when the password was
  /// changed, so the screen can pop with it; otherwise `null`, with the
  /// reason in [state].
  Future<ChangePasswordOutcome?> submit({
    required String current,
    required String newPassword,
    required String confirm,
  }) async {
    if (state.isSubmitting) return null;

    final currentIssue = current.isEmpty
        ? const ChangePasswordIssue(ChangePasswordIssueKind.currentRequired)
        : null;
    final newIssue = !PasswordPolicy.meetsMinimum(newPassword)
        ? const ChangePasswordIssue(ChangePasswordIssueKind.tooShort)
        : !PasswordPolicy.differs(current, newPassword)
        ? const ChangePasswordIssue(ChangePasswordIssueKind.sameAsCurrent)
        : null;
    final confirmIssue = !PasswordPolicy.matches(newPassword, confirm)
        ? const ChangePasswordIssue(ChangePasswordIssueKind.mismatch)
        : null;

    if (currentIssue != null || newIssue != null || confirmIssue != null) {
      state = ChangePasswordFormState(
        currentIssue: currentIssue,
        newIssue: newIssue,
        confirmIssue: confirmIssue,
      );
      return null;
    }

    state = const ChangePasswordFormState(isSubmitting: true);
    final result = await _service.change(
      currentPassword: current,
      newPassword: newPassword,
    );
    if (!mounted) return null;

    switch (result.outcome) {
      case ChangePasswordOutcome.changed:
      case ChangePasswordOutcome.changedOthersNotEnded:
        state = const ChangePasswordFormState();
        return result.outcome;
      case ChangePasswordOutcome.wrongCurrentPassword:
        state = const ChangePasswordFormState(
          currentIssue: ChangePasswordIssue(
            ChangePasswordIssueKind.wrongCurrent,
          ),
        );
      case ChangePasswordOutcome.sameAsCurrent:
        state = const ChangePasswordFormState(
          newIssue: ChangePasswordIssue(ChangePasswordIssueKind.sameAsCurrent),
        );
      case ChangePasswordOutcome.weakPassword:
        state = ChangePasswordFormState(
          newIssue: ChangePasswordIssue(
            ChangePasswordIssueKind.service,
            result.error,
          ),
        );
      case ChangePasswordOutcome.rateLimited:
      case ChangePasswordOutcome.sessionExpired:
      case ChangePasswordOutcome.offline:
      case ChangePasswordOutcome.failed:
        state = ChangePasswordFormState(
          bannerIssue: ChangePasswordIssue(
            ChangePasswordIssueKind.service,
            result.error,
          ),
        );
    }
    return null;
  }

  /// Drops the shown errors once the person edits a field, so a stale message
  /// never sits next to corrected input. Ignored while a request is running.
  void clearIssues() {
    if (state.isSubmitting || !state.hasIssues) return;
    state = const ChangePasswordFormState();
  }
}

final changePasswordServiceProvider = Provider<ChangePasswordService>((ref) {
  return ChangePasswordService(ref.watch(passwordChangeGatewayProvider));
});

final changePasswordControllerProvider =
    StateNotifierProvider.autoDispose<
      ChangePasswordController,
      ChangePasswordFormState
    >((ref) {
      return ChangePasswordController(ref.watch(changePasswordServiceProvider));
    });
