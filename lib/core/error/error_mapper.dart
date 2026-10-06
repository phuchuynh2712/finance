import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/l10n/app_localizations.dart';

/// Turns a caught exception into a localized, human-friendly message —
/// the single shared mechanism every write-failure call site in the app
/// MUST route through (FR-006/FR-011), replacing raw `e.toString()`
/// interpolation. Pure Dart, no `BuildContext` dependency: callers with a
/// `BuildContext` at their catch site pass `AppLocalizations.of(context)`
/// directly; `StateNotifier`s with no context available store the raw
/// [error] in their state and let the widget-side `ref.listen` call this
/// with its own `l10n` at display time (contracts/error_mapper.md Pattern
/// B, research.md Decision 1).
String mapErrorToMessage(Object error, AppLocalizations l10n) {
  // AuthWeakPasswordException extends AuthException directly, NOT
  // AuthApiException — it needs its own independent `is` check, checked
  // before/alongside the AuthApiException branch below, or a real
  // instance of this type would silently fall through to the generic
  // fallback (research.md Decision 2's documented subtype pitfall).
  if (error is AuthWeakPasswordException) {
    return l10n.errorMapperWeakPassword;
  }

  if (error is AuthApiException) {
    // No `ErrorCode.invalidCredentials` constant exists in the installed
    // gotrue package — compare the literal wire string directly
    // (research.md Decision 2).
    if (error.code == 'invalid_credentials') {
      return l10n.errorMapperInvalidCredentials;
    }
    if (error.code == ErrorCode.emailExists.code ||
        error.code == ErrorCode.userAlreadyExists.code) {
      return l10n.errorMapperEmailExists;
    }
    if (error.code == ErrorCode.weakPassword.code) {
      return l10n.errorMapperWeakPassword;
    }
    // `over_request_rate_limit` is what sign-in throttling returns (HTTP 429);
    // `over_email_send_rate_limit` is the email-sending limit.
    if (error.code == ErrorCode.overEmailSendRateLimit.code ||
        error.code == ErrorCode.overRequestRateLimit.code) {
      return l10n.errorMapperRateLimited;
    }
    if (error.code == ErrorCode.samePassword.code) {
      return l10n.changePasswordSameAsCurrentError;
    }
  }

  if (isSessionEndedError(error)) {
    return l10n.errorMapperSessionExpired;
  }

  if (isConnectivityError(error)) {
    return l10n.errorMapperNetworkFailure;
  }

  return l10n.errorMapperGeneric;
}

/// Whether [error] means this device's session is no longer usable: there is
/// no session at all (`AuthSessionMissingException`, which extends
/// `AuthException` directly, not `AuthApiException`) or the service reported
/// one of the [_endedSessionCodes]. Shared with callers that classify errors
/// by what to do next (e.g. the change-password service).
bool isSessionEndedError(Object error) {
  if (error is AuthSessionMissingException) return true;
  return error is AuthApiException && _endedSessionCodes.contains(error.code);
}

/// Whether [error] is a connectivity problem: no network, a timeout, or
/// gotrue's `AuthRetryableFetchException` (which also wraps HTTP 5xx).
bool isConnectivityError(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is AuthRetryableFetchException;

/// Codes meaning this device's session is no longer usable. The two
/// refresh-token codes have no constant in gotrue's `ErrorCode` (like
/// `invalid_credentials`), so their wire strings are spelled out.
final _endedSessionCodes = <String?>{
  ErrorCode.sessionExpired.code,
  ErrorCode.sessionNotFound.code,
  ErrorCode.reauthenticationNeeded.code,
  ErrorCode.badJwt.code,
  'refresh_token_not_found',
  'refresh_token_already_used',
};
