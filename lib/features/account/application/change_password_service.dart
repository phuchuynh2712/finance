import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/password_change_gateway.dart';
import 'package:finance/core/error/error_mapper.dart';

/// What happened when the person tried to change their password. The service
/// only classifies *where* a failure belongs (a field, a banner, a redirect);
/// the text always comes from the shared `mapErrorToMessage`.
enum ChangePasswordOutcome {
  /// Password changed and every other session ended.
  changed,

  /// Password changed, but ending the other sessions failed. The change
  /// stands; the Security screen offers a one-tap retry.
  changedOthersNotEnded,

  /// The current password was rejected. Nothing changed.
  wrongCurrentPassword,

  /// The new password equals the current one. Nothing changed.
  sameAsCurrent,

  /// The service rejected the new password as too weak. Nothing changed.
  weakPassword,

  /// Too many attempts. Nothing changed.
  rateLimited,

  /// This device's own session has ended (revoked or expired). Nothing changed.
  sessionExpired,

  /// No connection (or a server error wrapped as one). Nothing changed.
  offline,

  /// Anything else. Nothing changed.
  failed,
}

/// The [outcome] plus the raw [error] behind a failure (null on success). The
/// error is the original exception object, never wrapped or re-messaged, so no
/// password can end up in it.
class ChangePasswordResult {
  const ChangePasswordResult(this.outcome, [this.error]);

  final ChangePasswordOutcome outcome;
  final Object? error;
}

/// The change-password sequence (contracts/password-change-gateway.md):
///
/// 0. confirm this device's own session is still valid;
/// 1. verify the current password on a temporary session;
/// 2. set the new password on that fresh session — the server then revokes
///    every OTHER session of the account, this device's included;
/// 3. hand the temporary session to the app so this device stays signed in,
///    then always close it;
/// 4. end any other session still left (a no-op on today's server).
class ChangePasswordService {
  ChangePasswordService(this._gateway);

  final PasswordChangeGateway _gateway;

  Future<ChangePasswordResult> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _gateway.ensureSessionActive();
    } catch (error) {
      return ChangePasswordResult(_classifySessionCheck(error), error);
    }

    final VerifiedPasswordSession session;
    try {
      session = await _gateway.verifyCurrentPassword(currentPassword);
    } catch (error) {
      return ChangePasswordResult(_classify(error, atVerify: true), error);
    }

    try {
      await session.setNewPassword(newPassword);
    } catch (error) {
      await session.close();
      return ChangePasswordResult(_classify(error), error);
    }

    // The password is changed. Keep THIS device signed in: the temporary
    // session is the only one that survived, so the app takes it over. If that
    // fails the change still stands; report it like a failed last step.
    try {
      await session.continueOnThisDevice();
    } catch (error) {
      await session.close();
      return ChangePasswordResult(
        ChangePasswordOutcome.changedOthersNotEnded,
        error,
      );
    }
    await session.close();

    try {
      await _gateway.endOtherSessions();
    } catch (error) {
      return ChangePasswordResult(
        ChangePasswordOutcome.changedOthersNotEnded,
        error,
      );
    }
    return const ChangePasswordResult(ChangePasswordOutcome.changed);
  }

  /// Retries only the last step of [change] after
  /// [ChangePasswordOutcome.changedOthersNotEnded]: confirm this device's
  /// session, then end the other sessions. `changed` on success; otherwise
  /// `changedOthersNotEnded` carrying the original error.
  Future<ChangePasswordResult> signOutOtherDevices() async {
    try {
      await _gateway.ensureSessionActive();
      await _gateway.endOtherSessions();
    } catch (error) {
      return ChangePasswordResult(
        ChangePasswordOutcome.changedOthersNotEnded,
        error,
      );
    }
    return const ChangePasswordResult(ChangePasswordOutcome.changed);
  }

  /// Step 0 is a token refresh. gotrue removes the local session and emits
  /// `signedOut` for every refresh failure except a connectivity one (a 429
  /// included), so by the time we see it the device has already been signed
  /// out: anything that is not connectivity means "session ended".
  static ChangePasswordOutcome _classifySessionCheck(Object error) {
    if (isConnectivityError(error)) return ChangePasswordOutcome.offline;
    if (error is AuthException) return ChangePasswordOutcome.sessionExpired;
    return ChangePasswordOutcome.failed;
  }

  static ChangePasswordOutcome _classify(
    Object error, {
    bool atVerify = false,
  }) {
    if (error is AuthWeakPasswordException) {
      return ChangePasswordOutcome.weakPassword;
    }
    if (error is AuthApiException) {
      if (atVerify && error.code == 'invalid_credentials') {
        return ChangePasswordOutcome.wrongCurrentPassword;
      }
      if (error.code == ErrorCode.samePassword.code) {
        return ChangePasswordOutcome.sameAsCurrent;
      }
      if (error.code == ErrorCode.weakPassword.code) {
        return ChangePasswordOutcome.weakPassword;
      }
      if (error.code == ErrorCode.overRequestRateLimit.code) {
        return ChangePasswordOutcome.rateLimited;
      }
    }
    if (isSessionEndedError(error)) return ChangePasswordOutcome.sessionExpired;
    if (isConnectivityError(error)) return ChangePasswordOutcome.offline;
    return ChangePasswordOutcome.failed;
  }
}
