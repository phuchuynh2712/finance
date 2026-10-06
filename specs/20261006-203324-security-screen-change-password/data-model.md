# Data Model: Security Screen, Change Password, and Platform Config Normalization

**Feature**: `20261006-203324-security-screen-change-password` | **Date**: 2026-10-06

No database table, no remote schema and no persisted field is added or changed.
The biometric preference is the only stored value this feature touches, and it
already exists. Everything below is in-memory state, pure rules and a few
contracts between layers.

## 1. PasswordPolicy (pure Dart, `features/account/domain/`)

| Member | Rule |
|--------|------|
| `minLength` | `8` (single source of truth; sign-up, reset and change use it) |
| `meetsMinimum(String)` | `password.runes.length >= minLength` — characters counted as Unicode code points (an accented Vietnamese letter or an emoji is one), exactly as typed, **no trimming**, no composition rules |
| `differs(String current, String candidate)` | `current != candidate` |
| `matches(String a, String b)` | `a == b` |

Sign-in never calls the policy. `SignUpValidation.isPasswordValid` delegates to
`meetsMinimum`; `isConfirmPasswordValid` delegates to `matches`.

## 2. ChangePasswordForm (UI state, `autoDispose`, never persisted)

| Field | Notes |
|-------|-------|
| `currentPassword`, `newPassword`, `confirmPassword` | text exactly as typed; held only in the screen's `TextEditingController`s, cleared on success and on leaving |
| `showCurrent`, `showNew`, `showConfirm` | visibility toggles, default hidden |
| `fieldErrors` | per-field error kind or null (a validation rule or a failed result), resolved to localized text only at display time |
| `status` | `idle` · `submitting` · `failed(ChangePasswordResult)` — success is not a state: the screen pops with the outcome (`changed` / `changedOthersNotEnded`) |
| `error` | the raw `Object?` carried by a failed result; localized only at display time (`mapErrorToMessage`), never stored as text |

**Validation order** (first failure wins per field, all shown together where
independent):

1. `currentPassword` empty → "Nhập mật khẩu hiện tại."
2. `newPassword` fails `meetsMinimum` → `passwordTooShortError`
3. `newPassword` equals `currentPassword` → `changePasswordSameAsCurrentError`
4. `confirmPassword` ≠ `newPassword` → `resetPasswordMismatchError` (existing key reused)

No request is made unless 1–4 all pass. `status == submitting` blocks a second
submit (single-flight).

### State transitions

```text
idle ──submit(valid)──▶ submitting ──┬─▶ pop(changed)                     (all steps ok)
  ▲                                  ├─▶ pop(changedOthersNotEnded)       (password set, others not ended)
  │                                  └─▶ failed(result)  ──edit──▶ idle   (values kept)
  └────────── invalid input: fieldErrors set, status stays idle
failed(sessionExpired): banner "session ended"; the app's auth-state handling
  (gotrue emits signedOut when a refresh token is invalid) takes the person to
  sign in; typed values are discarded when the screen is left
```

## 3. ChangePasswordResult and ChangePasswordOutcome (result of `ChangePasswordService`)

```dart
class ChangePasswordResult {
  final ChangePasswordOutcome outcome;
  final Object? error; // the raw exception for failure outcomes; null on success
}
```

The service classifies **where** a failure belongs; the **text** always comes
from the shared `mapErrorToMessage` (one mapping table for message copy), except
the one case whose shared copy would mislead (`wrongCurrentPassword`).

| Outcome | Meaning | UI (placement · message source) |
|---------|---------|----|
| `changed` | session check ✓, verify ✓, set ✓, temp session closed, other sessions ended | pop to Security screen; transient `securityPasswordChangedNotice` |
| `changedOthersNotEnded` | password set but `endOtherSessions` failed | pop to Security screen; persistent notice with a **Thử lại** action (§3b) |
| `wrongCurrentPassword` | `invalid_credentials` at verify | field error on the current-password field · `changePasswordWrongCurrentError` |
| `sameAsCurrent` | `same_password` at set | field error on the new-password field · mapper (`changePasswordSameAsCurrentError`) |
| `weakPassword` | `weak_password` at set (server minimum/rules) | field error on the new-password field · mapper (`errorMapperWeakPassword`) |
| `rateLimited` | `over_request_rate_limit` at the verify or update step (never at the session check, see the contract) | banner, values kept · mapper (`errorMapperRateLimited`) |
| `sessionExpired` | this device's session invalid at the start (any `AuthException` from the session check other than a network/5xx `AuthRetryableFetchException` — a 429 included, because gotrue has already signed this device out — or session codes anywhere) | banner · mapper (`errorMapperSessionExpired`); nothing was changed; auth-state handling goes to sign-in |
| `offline` | `SocketException` / `TimeoutException` / `AuthRetryableFetchException` | banner, values kept · mapper (`errorMapperNetworkFailure`) |
| `failed` | anything else | generic banner, values kept · mapper (`errorMapperGeneric`) |

## 3b. OtherDevicesNotice (Security screen, in-memory, `autoDispose`)

| State | Meaning | UI |
|-------|---------|----|
| `hidden` | default; also after a `changed` outcome | nothing |
| `notEnded` | the change-password screen popped with `changedOthersNotEnded` | inline notice (`securityPasswordChangedOthersNotEnded`) with a **Thử lại** button |
| `retrying` | the retry is in flight (single-flight) | the button shows a spinner and is disabled |

`retry()` calls `ChangePasswordService.signOutOtherDevices()` (session check, then
end other sessions) and returns its `ChangePasswordResult`. `changed` ⇒ `hidden` +
transient `securityOthersSignedOutNotice`; a failure result ⇒ back to `notEnded`
**and** a transient SnackBar with the mapped error text (`mapErrorToMessage`:
offline → `errorMapperNetworkFailure`, anything else → `errorMapperGeneric`), so a
failed retry is never silent. The notice lives as long as the Security screen;
leaving it drops the retry (changing the password again still ends the other
sessions).

## 4. BiometricAvailability and SecuritySettings

```dart
enum BiometricAvailability { available, webUnsupported, noHardware, notEnrolled }

class SecuritySettings {
  final BiometricAvailability availability;
  final bool preferenceEnabled; // stored per account per device (exists today)
  bool get switchOn  => preferenceEnabled && availability == BiometricAvailability.available;
  bool get switchEnabled => availability == BiometricAvailability.available;
}
```

| Stored preference | Availability | Switch shows | Interaction |
|-------------------|--------------|--------------|-------------|
| off | available | off, enabled | turning on → `authenticate()`; success ⇒ stored on |
| on | available | on, enabled | turning off ⇒ stored off, no extra check |
| any | `webUnsupported` / `noHardware` / `notEnrolled` | off, **disabled** + localized reason | none; stored value untouched |

State transitions of the switch: `off ──tap──▶ authenticating ──ok──▶ on`;
`authenticating ──cancel/fail──▶ off`; `on ──tap──▶ off`. Availability is
re-read on screen open and on app resume.

**Stored value** (unchanged): secure-storage key `BIOMETRIC_ENABLED_<userId>`
present ⇒ enabled, absent ⇒ disabled (`AuthRepository.setBiometricLoginEnabled`).
Local sign-out still clears it; changing the password does not (FR-009).

## 5. Sessions (conceptual, owned by the service)

| Session | Created | Ended |
|---------|---------|-------|
| This device | at sign-in | validated at the start of a change (a token refresh) and otherwise not touched; stays signed in |
| Temporary session | step 1 of the change (plain REST sign-in; never a second client) | handed to the app as this device's new session (`continueOnThisDevice`) after the password was updated; revoked by `close()` only if the hand-over did not happen |
| This device's previous session | at sign-in | revoked by the server when the password is updated (it keeps only the updating session) — replaced by the temporary session, so this device stays signed in |
| Other devices' sessions | earlier sign-ins | revoked by the server when the password is updated; `endOtherSessions()` (`SignOutScope.others`) is a safety net. They can no longer refresh, so they are signed out when they next use the service, and at the latest when their access token expires |

## 6. Platform configuration files (US4)

Not data: the six tracked files and the canonical content the toolchain wants
are specified in [contracts/platform-config.md](./contracts/platform-config.md).

## 7. Runtime keys (US4)

`AppEnvironment.keys = ['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY',
'WEB_PASSWORD_RESET_REDIRECT_URL']` — must equal the key set of
`tool/env.example.json` and each key must appear in the README table
(enforced by a unit test).
