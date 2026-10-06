# Contract: Password-Change Gateway and Service

**Feature**: `20261006-203324-security-screen-change-password` | **Date**: 2026-10-06

## Interfaces (`lib/core/auth/password_change_gateway.dart`)

```dart
abstract interface class PasswordChangeGateway {
  /// Refreshes THIS device's own session against the service. Throws when the
  /// session has been revoked or has expired (nothing is changed after that),
  /// and leaves this device with a fresh access token for `endOtherSessions`.
  /// Backed by the existing `AuthRepository.verifySessionAlive()`.
  Future<void> ensureSessionActive();

  /// Signs a temporary session in (plain REST) with the current password.
  /// Throws AuthApiException(code: 'invalid_credentials') if it is wrong.
  Future<VerifiedPasswordSession> verifyCurrentPassword(String currentPassword);

  /// Ends every session of the account except this device's
  /// (SignOutScope.others on the app's own client). Never silently a no-op:
  /// throws AuthSessionMissingException when this device has no live access
  /// token (see "Why the guard" below).
  Future<void> endOtherSessions();
}

abstract interface class VerifiedPasswordSession {
  /// PUT /user {password} on the temporary, fresh session. The server revokes
  /// every OTHER session of the account when this succeeds.
  Future<void> setNewPassword(String newPassword);

  /// Hands the temporary session to the app's own client
  /// (`GoTrueClient.setSession(refreshToken)`) so THIS device keeps a valid
  /// session after the server revoked its old one. Throws if the app cannot
  /// take it over.
  Future<void> continueOnThisDevice();

  /// Revokes the temporary session (POST /logout?scope=local) unless it was
  /// handed over, and frees its resources. Idempotent; never throws.
  Future<void> close();
}
```

`AuthRepository implements PasswordChangeGateway`. The temporary session is a
`TemporaryPasswordSession` over `SupabaseAuthRest`: three plain HTTP calls with
the `http` package (`POST /auth/v1/token?grant_type=password`,
`PUT /auth/v1/user`, `POST /auth/v1/logout?scope=local`), the project URL and
the publishable key (`apikey` header). **It is deliberately not a second
`SupabaseClient`/`GoTrueClient`**: on web every gotrue client of a project
shares one `BroadcastChannel`, and a client that receives a broadcast saves or
drops the session it carries, so a throwaway client would sign the app's own
client in as the temporary session and out again. Plain HTTP has no channel,
storage or events. Errors use gotrue's own types so the existing mapping
applies: a 4xx becomes `AuthApiException(message, statusCode, code)` with the
server's `error_code`; a network failure, a timeout or a 5xx becomes
`AuthRetryableFetchException`. The email comes from the app's current user; no
password is stored, logged or returned. `http.Client` and the URL/key are
constructor parameters of `AuthRepository`, so tests use `MockClient`.

Provider: `passwordChangeGatewayProvider` (overridable in tests).

### Why the guard in `endOtherSessions`

`GoTrueClient.signOut(scope: others)` reads `currentSession?.accessToken` and
calls the admin sign-out endpoint, and **ignores 401/403/404 responses**
(gotrue 2.26.0 `gotrue_client.dart:1000-1009`: "an invalid or expired JWT
should sign out the current session"). With `scope: others` that means a stale
access token makes the call return normally while no other session was ended.
So the repository (1) relies on `ensureSessionActive()` having just refreshed
the token and (2) throws `AuthSessionMissingException` itself when
`currentSession` is null or `isExpired`, so the service reports
`changedOthersNotEnded` instead of a false `changed`.

## Service (`features/account/application/change_password_service.dart`)

```dart
enum ChangePasswordOutcome {
  changed, changedOthersNotEnded, wrongCurrentPassword, sameAsCurrent,
  weakPassword, rateLimited, sessionExpired, offline, failed,
}

class ChangePasswordResult {
  const ChangePasswordResult(this.outcome, [this.error]);
  final ChangePasswordOutcome outcome;
  final Object? error; // raw exception for failure outcomes; never a password
}

class ChangePasswordService {
  ChangePasswordService(this._gateway);
  Future<ChangePasswordResult> change({
    required String currentPassword,
    required String newPassword,
  });

  /// Retry for `changedOthersNotEnded`: ensureSessionActive → endOtherSessions.
  /// Returns `ChangePasswordResult(changed)` when both succeed; on any failure
  /// returns `ChangePasswordResult(changedOthersNotEnded, error)` carrying the
  /// original exception, so the UI can show its mapped text.
  Future<ChangePasswordResult> signOutOtherDevices();
}
```

### Sequence (the contract the unit tests pin)

```text
0  await gateway.ensureSessionActive()                          // may throw — nothing changed yet
1  session = await gateway.verifyCurrentPassword(current)       // may throw
2  try { await session.setNewPassword(new) }                    // may throw → close, classify
3  try { await session.continueOnThisDevice() }                 // this device keeps a valid session
   catch → close(); return changedOthersNotEnded(error)
   await session.close()                                        // revokes nothing once handed over
4  try { await gateway.endOtherSessions() }                     // safety net; only if 2 and 3 succeeded
   catch → return changedOthersNotEnded(error)
5  return changed
```

| Step failure | Outcome |
|--------------|---------|
| 0 throws network (`SocketException`, `TimeoutException`, `AuthRetryableFetchException` — gotrue also wraps HTTP 5xx in it) | `offline` (no step 1–4) |
| 0 throws any other `AuthException` — revoked/expired/invalid refresh token, `AuthSessionMissingException`, and also `over_request_rate_limit` (429) | `sessionExpired` (no step 1–4) |
| 1 throws `invalid_credentials` | `wrongCurrentPassword` (no step 2–4) |
| 1 throws session/network/rate-limit | mapped per the table below (no step 2–4) |
| 2 throws `same_password` | `sameAsCurrent` (`close` runs; 3 and 4 not run) |
| 2 throws `weak_password` / `AuthWeakPasswordException` | `weakPassword` |
| 2 throws other | mapped per the table below |
| 3 throws | `changedOthersNotEnded` (the password is changed; `close` revokes the temporary session; the app's old session is already revoked by the server, so the person is taken to sign in when the app next refreshes) |
| 4 throws | `changedOthersNotEnded` |

**Why step 0 has no `rateLimited` branch**: step 0 is `refreshSession()`, and
gotrue's `_doRefresh` removes the local session and emits `signedOut` for every
refresh failure except `AuthRetryableFetchException` — a 429 included. By the
time the service sees the error the app has already been signed out, so
"too many attempts, try again, your values are kept" would be false; the honest
outcome is `sessionExpired`. `rateLimited` therefore only comes from steps 1–2.

### Error mapping table (classification: which outcome and where it is shown)

| Exception | Outcome |
|-----------|---------|
| `AuthApiException` `invalid_credentials` (step 1 only) | `wrongCurrentPassword` |
| `AuthApiException` `same_password` | `sameAsCurrent` |
| `AuthWeakPasswordException`, `weak_password` | `weakPassword` |
| `AuthApiException` `over_request_rate_limit` (steps 1–2 only; at step 0 see above) | `rateLimited` |
| `AuthApiException` `session_expired` / `session_not_found` / `reauthentication_needed` / `bad_jwt` / `refresh_token_not_found` / `refresh_token_already_used`, `AuthSessionMissingException` | `sessionExpired` |
| `SocketException`, `TimeoutException`, `AuthRetryableFetchException` | `offline` |
| anything else | `failed` |

`refresh_token_not_found` and `refresh_token_already_used` have no constant in
`gotrue 2.26.0`'s `ErrorCode` (like `invalid_credentials`), so the wire strings
are compared literally.

**Message text** is never chosen by the service: the controller resolves it with
the shared `mapErrorToMessage(result.error, l10n)` (which the foundational
phase extends with the same codes), except `wrongCurrentPassword`, whose shared
copy (`errorMapperInvalidCredentials`, "email or password…") would mislead and
which uses `changePasswordWrongCurrentError`.

The service never includes a password in an exception message, a log line, a
`ChangePasswordResult` or its `toString()`.

## Controller (`features/account/presentation/change_password_controller.dart`)

Holds the `ChangePasswordForm` state of `data-model.md` §2, runs the
validation order, calls the service once (single-flight), and exposes the
result as state; it contains no widget code. Localized text is resolved at
display time with `AppLocalizations` (the project's "Pattern B" for notifiers
without a `BuildContext`).

## Other-devices notice (`features/account/presentation/other_devices_notice_controller.dart`)

`StateNotifier<OtherDevicesNotice>` (`autoDispose`) of `data-model.md` §3b:
`show()` after the change-password screen pops with `changedOthersNotEnded`;
`retry()` is single-flight, calls `ChangePasswordService.signOutOtherDevices()`
and returns its `ChangePasswordResult`; on a failure result (or an unexpected
throw, wrapped as `changedOthersNotEnded` with the error) the state goes back
to `notEnded` and the screen shows the mapped error text.

## Preserved behavior

`AccountAuthActions`, `AuthRepository.signOut`, the lock screen, sign-in,
sign-up and the email reset keep their contracts; only the reset screen gains a
client-side length check and sign-up's rule becomes 8 characters. The token
refresh in step 0 is the same operation the biometric unlock already performs
(`verifySessionAlive`) and also happens hourly in normal use, so the app's
providers already tolerate its `tokenRefreshed` event.
