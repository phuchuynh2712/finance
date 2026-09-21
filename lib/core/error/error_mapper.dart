import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';

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
    if (error.code == ErrorCode.overEmailSendRateLimit.code) {
      return l10n.errorMapperRateLimited;
    }
  }

  if (error is SocketException ||
      error is TimeoutException ||
      error is AuthRetryableFetchException) {
    return l10n.errorMapperNetworkFailure;
  }

  return l10n.errorMapperGeneric;
}
