# Contract: Extended Auth Repository Interface

This feature has no new backend endpoint or database schema (see `data-model.md`) — its only real "contract" is the Dart-level interface boundary between `presentation/` and `domain/`/`data/`, per the constitution's Clean Architecture rule (`domain/` depends on nothing Flutter-specific; `presentation/` depends only on the interface, never the concrete Supabase-backed implementation).

## `AuthRepository` additions (`lib/core/auth/auth_repository.dart`)

Extends the existing class (not a new file) — `signUp` already exists (FR-001/FR-004 reuse it as-is, per spec Assumptions). New methods:

```dart
/// Registers a new email/password account (FR-001/FR-004). The account is
/// created in an unconfirmed state — the returned bool is `true` if the
/// caller must show a "check your email" message (FR-021) because
/// Supabase's `AuthResponse.session` came back null (2026-08-04, FR-015
/// reversed: confirmation is required before sign-in). [displayName] and
/// [phoneNumber] are optional (FR-019) and, if provided, are stored via
/// Supabase's `data:` metadata parameter to `signUp()`
/// (`raw_user_meta_data.display_name` / `raw_user_meta_data.phone_number`)
/// — the same mechanism already used for `avatar_url` by [updateAvatar].
/// [phoneNumber] is plain profile text with no OTP/SMS verification
/// (FR-020) and is unrelated to Supabase's separate phone-auth column.
/// Throws on duplicate email (FR-003) or Google-only existing account
/// (FR-012) — see error mapping below.
Future<bool> signUp({
  required String email,
  required String password,
  String? displayName,
  String? phoneNumber,
}); // EXISTING — now called from UI; displayName/phoneNumber added 2026-08-04 (1); return type changed String→bool 2026-08-04 (2)

/// Resends the confirmation email for an unconfirmed account (FR-023,
/// 2026-08-04 addendum part 2), using `gotrue`'s existing
/// `resend(type: OtpType.signup)` — no new dependency. Throws the same
/// error types as any other Supabase Auth call; caller maps to a
/// retryable error per FR-011's pattern.
Future<void> resendConfirmationEmail(String email);

/// Signs in via native Google ID token (FR-005, FR-006, FR-007, FR-008).
/// If the Google account's email matches an existing password-based
/// account, Supabase's server automatically links and signs into that
/// account (FR-008) — this method does not branch on that case itself;
/// whatever account signInWithIdToken resolves to is correct and safe by
/// construction, since Supabase evicts any unconfirmed prior identity on
/// that account as part of the same server-side operation (research.md
/// §6).
Future<void> signInWithGoogle();

/// Links a Google account to the CURRENTLY signed-in user (FR-016) — used
/// for a Google account whose email differs from the signed-in account's
/// email (automatic linking per FR-008 already covers the matching-email
/// case). Throws `identity_already_exists` if the Google identity belongs
/// to a different account (FR-017) — caller maps this to a user-facing
/// error.
Future<void> linkGoogleAccount();

/// Returns the linked Google account's email, or null if none linked
/// (FR-018).
String? get linkedGoogleEmail;
```

`signInWithGoogle()` and `linkGoogleAccount()` both internally perform the same two-step native flow (research.md §2): `google_sign_in`'s `authenticate()` + `authorizationClient.authorizationForScopes()` to obtain an `idToken`/`accessToken`, then call `Supabase.instance.client.auth.signInWithIdToken(...)` or `.linkIdentityWithIdToken(...)` respectively (research.md §1, §3). This Google-SDK interaction is entirely inside `data/` — `domain/` only sees the method signatures above, so it stays framework-agnostic and unit-testable per the constitution's Testing Standards.

## `AccountAuthActions` interface additions (`lib/core/auth/auth_repository.dart`)

The existing narrow interface consumed by `AccountController` (`lib/features/account/presentation/account_controller.dart`) gains the Profile-facing subset needed for User Story 4:

```dart
abstract interface class AccountAuthActions {
  Future<void> updateAvatar(String avatarUrl);   // existing
  Future<void> changePassword(String newPassword); // existing
  Future<void> signOut();                          // existing
  Future<void> linkGoogleAccount();                // NEW (FR-016)
  String? get linkedGoogleEmail;                   // NEW (FR-018)
}
```

`signUp()` and `signInWithGoogle()` are **not** added to `AccountAuthActions` — they're only ever called from the sign-in/registration screens (pre-authentication), which read `authRepositoryProvider` directly (matching the existing `SignInScreen` pattern, not the narrowed interface used post-authentication).

## Error mapping contract (Dart exception → user-facing message)

| Supabase error condition | Spec requirement | UI behavior |
|---|---|---|
| Duplicate email on `signUp` (`email_exists`/`user_already_exists`) — covers both a duplicate password account (FR-003) and an existing Google-only account (FR-012), since Supabase's error code doesn't distinguish them | FR-003, FR-012 | Inline error, no account created, directing the user to sign in with either password or Google |
| `signUp` succeeds, `AuthResponse.session != null` | FR-004 | Sign in immediately (only reachable if the Dashboard's "Enable email confirmations" is off — not the expected configuration as of 2026-08-04, but the code handles it gracefully rather than assuming) |
| `signUp` succeeds, `AuthResponse.session == null` | FR-004, FR-015, FR-021 | **Not an error** — account created but unconfirmed; show "check your email to confirm your account", do not navigate into the app |
| `signInWithPassword` → `email_not_confirmed` | FR-022 | Distinct inline message from a generic wrong-password error, explaining the email must be confirmed first; show a "resend confirmation email" action |
| `resendConfirmationEmail` succeeds | FR-023 | Brief confirmation that the email was sent |
| `resendConfirmationEmail` fails (network/server) | FR-023 | Retryable error message, same pattern as FR-011 |
| `signInWithIdToken` for an email matching an existing password account | FR-008 | **Not an error** — Supabase auto-links (and, if that account was unconfirmed, evicts its prior identities per research.md §6) and signs in; UI treats this identically to any other successful Google sign-in (no special-case branch needed) |
| `linkIdentityWithIdToken` → `identity_already_exists` | FR-017 | Error on Profile screen; existing linkage (either side) unchanged |
| `linkIdentityWithIdToken` → `manual_linking_disabled` | (project prerequisite, research.md §3) | Not user-facing in normal operation — indicates a project misconfiguration; surfaced as a generic error, logged for developer attention (never silently swallowed) |
| Network/timeout during any of the above | FR-011 (registration), edge case (Google flows) | Retryable error message, no partial state, per User Story 5's pattern |
| User cancels Google account chooser | FR-009 | Silent return to prior screen, no error, no state change |

**Note on a row that does not exist**: there is no row for "`signInWithIdToken` for an email with an existing *unlinked* password account → error, direct to email/password sign-in." Implementing that as a client-observable error would require a custom email-lookup endpoint, which is itself a user-enumeration security risk (research.md §6) — and it turned out to be unnecessary, since Supabase's own eviction mechanism already makes the matching-email case safe. This is indistinguishable, from the client's perspective, from a normal successful Google sign-in.
