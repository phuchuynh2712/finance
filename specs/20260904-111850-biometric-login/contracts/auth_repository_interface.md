# Contract: Auth Repository & Biometric Interface Changes

This feature has no new backend endpoint or database schema (see `data-model.md`) — its contracts are (a) the Dart-level `presentation/` ↔ `domain/`/`data/` interface boundary, per the constitution's Clean Architecture rule, and (b) the local biometric-capability boundary between `presentation/` and the new `core/auth/biometric_login_repository.dart`.

## 1. `AuthRepository` changes (`lib/core/auth/auth_repository.dart`)

### Removed (Google Sign-In deletion — research.md §7)

```dart
Future<void> signInWithGoogle();          // REMOVED
Future<void> linkGoogleAccount();         // REMOVED (also removed from AccountAuthActions)
String? get linkedGoogleEmail;            // REMOVED (also removed from AccountAuthActions)
Future<({String idToken, String accessToken})> _authenticateWithGoogle(); // REMOVED (private)
```

### Changed

```dart
/// FR-019: no longer conditionally returns "needs confirmation" — this
/// feature requires Supabase's "Enable email confirmations" Dashboard
/// setting to be off (already done, per spec Assumptions), so a
/// successful call always returns an active session. Return type reverts
/// from the prior feature's `Future<bool>` (confirmation-pending flag)
/// back to `Future<void>` — there is no pending state left to report.
/// [displayName]/[phoneNumber] behavior is UNCHANGED from the prior
/// feature (data-model.md §2) — this feature does not touch how they're
/// stored, only that [email] is now enforced required by the caller
/// (FR-006, client-side validation in SignUpValidation, not a new
/// server-side rule).
Future<void> signUp({
  required String email,
  required String password,
  String? displayName,
  String? phoneNumber,
});

/// FR-014a/FR-016a/FR-016b: gains a scope parameter (research.md §2).
/// Default unchanged (local-only, current behavior) so every existing
/// call site that doesn't pass [scope] keeps working as-is.
@override
Future<void> signOut({SignOutScope scope = SignOutScope.local});

/// FR-016b: after a successful password change, the repository itself
/// (not the caller) issues the `SignOutScope.others` call as part of the
/// same operation — callers don't need to remember to do it separately,
/// and can't accidentally skip it.
@override
Future<void> changePassword(String newPassword); // internally: updateUser() then signOut(scope: SignOutScope.others)
```

### Removed (dead code, per research.md §7)

```dart
Future<void> resendConfirmationEmail(String email); // REMOVED — no confirmation flow exists anymore (FR-019)
```

### Added

```dart
/// FR-015: requests a password-reset email. [redirectTo] is fixed to this
/// app's registered deep link (research.md §3) — not caller-configurable,
/// since there is exactly one correct value for a given build (Android
/// package / iOS bundle scheme).
Future<void> resetPasswordForEmail(String email);

/// FR-016: completes a password reset from a recovery-session context
/// (i.e., only valid to call after `AuthChangeEvent.passwordRecovery` has
/// fired — see contracts note below). Internally: updateUser() with the
/// new password, then signOut(scope: SignOutScope.global) (FR-016a) —
/// same "repository owns the scope, caller can't forget it" pattern as
/// changePassword above.
Future<void> confirmPasswordReset(String newPassword);

/// FR-020/FR-021 support: exposes the passwordRecovery auth event so the
/// presentation layer can navigate to the "Set New Password" screen
/// without depending on supabase_flutter types directly outside data/.
Stream<bool> get onPasswordRecoveryEvent; // true emitted once per PASSWORD_RECOVERY event
```

## 2. `AccountAuthActions` interface (`lib/core/auth/auth_repository.dart`)

```dart
abstract interface class AccountAuthActions {
  Future<void> updateAvatar(String avatarUrl);              // unchanged
  Future<void> changePassword(String newPassword);          // unchanged signature, new internal side effect (see above)
  Future<void> signOut({SignOutScope scope = SignOutScope.local}); // CHANGED: gains scope param
  // linkGoogleAccount() / linkedGoogleEmail — REMOVED
  Future<bool> isBiometricLoginEnabled();                   // NEW (FR-008/FR-010) — reads BIOMETRIC_ENABLED_<userId>
  Future<void> setBiometricLoginEnabled(bool enabled);       // NEW (FR-010) — writes/deletes the same key; also deletes BIOMETRIC_PROMPT_SHOWN_<userId> when disabling is NOT correct — see hasShownBiometricPrompt below for which key clears when
}
```

Two more methods live on `AuthRepository` directly (not `AccountAuthActions`, since they're only ever called right after Sign Up/Sign In — pre-`AccountController` context, same reasoning as `signUp()`/`signInWithGoogle()` not being on the narrow interface):

```dart
/// FR-009: true only the first time this returns for a given signed-in
/// user on this device — reads BIOMETRIC_PROMPT_SHOWN_<userId>. Callers
/// MUST call markBiometricPromptShown() immediately after showing the
/// prompt (regardless of the user's answer) so this never returns true
/// twice for the same account/device pair without an intervening sign-out
/// (data-model.md §1).
Future<bool> shouldShowBiometricEnablePrompt();

/// Marks the one-time prompt as shown (data-model.md §1). Does not itself
/// enable biometric — call setBiometricLoginEnabled(true) separately if
/// the user accepts.
Future<void> markBiometricPromptShown();
```

`AccountController` (`lib/features/account/presentation/account_controller.dart`) is extended with a biometric toggle passthrough (`isBiometricEnabled` state field + `setBiometricEnabled(bool)` method) mirroring the existing `updateAvatar`/`changePassword` pattern — no new state-management approach introduced.

## 3. New: `BiometricLoginRepository` (`lib/core/auth/biometric_login_repository.dart`)

A small new class, separate from `AuthRepository`, because it wraps a different SDK (`local_auth`, not Supabase) — keeps `data/`-equivalent boundaries clean per the constitution's layering rule (one repository per external dependency it wraps).

```dart
class BiometricLoginRepository {
  BiometricLoginRepository(this._localAuth); // LocalAuthentication, injected for testability

  /// FR-008: device capability check (hardware + at least one enrolled
  /// fingerprint/face). Combines canCheckBiometrics + isDeviceSupported()
  /// per research.md §1 — both must be true.
  Future<bool> isDeviceCapable();

  /// FR-011: triggers the native prompt. Returns true on success, false
  /// on user cancel; rethrows LocalAuthException for the caller to map
  /// per research.md §1's error table (FR-012/FR-014).
  Future<bool> authenticate({required String localizedReason});
}
```

`presentation/` code (the reused Login screen, and the new `appLockProvider`) depends only on this class's two methods — never imports `package:local_auth` directly, matching the same boundary discipline as `AuthRepository` for Supabase.

## 4. `computeAuthRedirect` (`lib/core/router/app_router.dart`)

```dart
/// CHANGED: gains `isLocked` and `isPasswordRecovery`. Existing 2-bool
/// signature/behavior is a strict subset (isLocked: false,
/// isPasswordRecovery: false reproduces today's exact behavior), so no
/// existing test case's expected output changes — only new cases are
/// added to test/unit/core/router/app_router_test.dart.
String? computeAuthRedirect({
  required bool isSignedIn,
  required bool isLocked, // NEW (FR-020/FR-021)
  required bool isPasswordRecovery, // NEW (FR-016) — see note below
  required String matchedLocation,
}) {
  // Checked FIRST, before the ordinary signed-in branches: Supabase's
  // passwordRecovery event establishes a real (recovery-scoped) session,
  // which would otherwise make isSignedIn true and redirect straight to
  // /overview — bypassing the "Set New Password" screen entirely. This
  // branch takes priority regardless of isSignedIn/isLocked.
  if (isPasswordRecovery && matchedLocation != '/reset-password') {
    return '/reset-password';
  }
  final isSigningIn = matchedLocation == '/sign-in' || matchedLocation == '/sign-up';
  if (!isSignedIn && !isSigningIn) return '/sign-in';
  if (isSignedIn && isLocked && !isSigningIn) return '/sign-in'; // NEW branch
  if (isSignedIn && !isLocked && isSigningIn) return '/overview'; // guards against showing sign-up while merely locked
  return null;
}
```

**Why `isPasswordRecovery` must be a router-level input, not handled ad hoc in a screen**: Supabase's recovery deep link establishes an actual session client-side (so `AuthRepository.currentSession`/`isSignedInProvider` become non-null/true as a side effect of the link being opened) — without this explicit, highest-priority redirect branch, the existing signed-in redirect would send the user straight to `/overview` instead of the "Set New Password" screen the moment the recovery link opens the app. `isPasswordRecovery` is sourced from a new `isPasswordRecoveryProvider` (`core/auth/auth_state_provider.dart`) derived from `AuthRepository.onPasswordRecoveryEvent` (§1), and is reset to `false` once `confirmPasswordReset()` completes (which also fully signs the session out via `SignOutScope.global`, naturally clearing `isSignedIn` too).

## Error mapping contract (new/changed rows only — Google-related rows from the prior feature's contract are deleted, not reproduced here)

| Condition | Spec requirement | UI behavior |
|---|---|---|
| `BiometricLoginRepository.authenticate()` throws `noBiometricHardware`/`noBiometricsEnrolled`/`noCredentialsSet` | FR-008, FR-014 | Hide/never-show the fingerprint button; if previously enabled, clear `BIOMETRIC_ENABLED_<userId>` |
| `BiometricLoginRepository.authenticate()` throws `temporaryLockout`/`biometricLockout`/`userCanceled`/`userRequestedFallback`/`timeout`/`deviceError`/`unknownError` | FR-012 | Stay on Login screen, password fields available, no form data lost |
| `BiometricLoginRepository.authenticate()` returns `true` but the underlying session is dead (next API call 401s) | Session-death Clarification | Fall back to password form (no false "signed in" state); clear `BIOMETRIC_ENABLED_<userId>` once the user re-authenticates with password, consistent with FR-014a |
| `resetPasswordForEmail` for a registered email | FR-015 | Generic "check your email" confirmation |
| `resetPasswordForEmail` for an unregistered email | FR-015 | **Same** generic confirmation (no enumeration leak) |
| `AuthChangeEvent.passwordRecovery` fires (app already running) | FR-016 | Navigate to "Set New Password" screen |
| `AuthChangeEvent.passwordRecovery` fires (app cold-started by the link) | FR-016 | Same navigation; requires the explicit manual test noted in research.md §3 |
| `confirmPasswordReset` succeeds | FR-016, FR-016a | New password active; `SignOutScope.global` already issued internally; navigate to Login screen (now fully signed out everywhere) |
| `changePassword` succeeds | FR-016b | Success message on Account screen; no navigation (current device stays signed in, per research.md §2's `SignOutScope.others` caveat — no auth-state event fires for the current session) |
| `signUp` succeeds | FR-019 | Always an active session now (no confirmation-pending branch) — navigate straight into the app, then FR-009's biometric-enable prompt |

**Note on a row that no longer exists**: there is no `email_not_confirmed` row — that error condition cannot occur anymore once FR-019 takes effect (Dashboard setting already off, per spec Assumptions), so the prior feature's `email_not_confirmed`-handling code in `SignInScreen` (the `_showResendConfirmation` state and `resend confirmation` action) is dead code to delete, not behavior to preserve.
