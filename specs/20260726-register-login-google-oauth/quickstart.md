# Quickstart: Registration & Google Sign-In

How to verify this feature once implemented, mapped to the spec's acceptance scenarios.

## External setup prerequisites (one-time, outside the codebase)

These are required before any Google sign-in acceptance scenario can pass — without them, failures look like app bugs but are actually missing configuration (research.md §3, §4):

1. **Google Cloud Console**: create a Web OAuth client ID (used as `serverClientId`), an Android OAuth client ID (with the debug/release keystore SHA-1 fingerprints registered), and an iOS OAuth client ID (with the app's Bundle ID).
2. **Supabase Dashboard → Authentication → Providers → Google**: enable the provider, paste in the Web client ID + secret from step 1.
3. **Supabase Dashboard → Authentication → Settings**: enable **"Manual Linking"** — required for `linkIdentityWithIdToken` (User Story 4); without it every explicit link attempt fails with `manual_linking_disabled`.
4. **Supabase Dashboard → Authentication → Settings**: confirm **"Enable email confirmations"** is ON (2026-08-04 addendum) — required for FR-015/FR-021/FR-022's "confirm before sign-in" behavior to take effect. This is Supabase's **default value for new projects**, so if the Dashboard has never been visited, no action is needed here; only change it if a prior session explicitly turned it off. Without it, `signUp()` returns a usable session immediately and User Story 1's Scenarios 2–4 (as revised below) won't reproduce, even though the client-side code handles both cases.
5. **`ios/Runner/Info.plist`**: add a `CFBundleURLTypes` entry with the reversed iOS client ID as the URL scheme.
6. A test Google account (or two, to test the "already linked to a different account" rejection in User Story 4).
7. Access to the test email inbox used for registration, to click the confirmation link (2026-08-04 addendum).

**Known cosmetic gap (2026-08-04 addendum)**: Supabase's default confirmation email template redirects to the project's Site URL after verifying, which defaults to `http://localhost:3000` on a fresh project. Clicking the confirmation link on a phone will still confirm the account server-side (so sign-in afterward works correctly) but may land the browser on a broken/dev page first. This is a known, low-priority polish item (optionally addressed by setting Site URL in Supabase Dashboard → Authentication → URL Configuration) — it does not affect whether the auth flow itself works, so it does not block verifying the scenarios below.

## Prerequisites (code)

- `AuthRepository` extended per `contracts/auth_repository_interface.md` (`signInWithGoogle`, `linkGoogleAccount`, `linkedGoogleEmail`)
- A registration screen exists and is reachable from `SignInScreen`
- `AccountScreen` shows the Google-linking control
- `google_sign_in: ^7.2.0` added and initialized with the Web client ID as `serverClientId` (research.md §2)
- A test user account (email/password) already exists, for User Story 4's "link from an existing account" scenarios

## Verify: Create an account with email and password (User Story 1)

1. From the sign-in screen, tap "Create account" → confirm the registration screen appears with Email, Password, Confirm Password, Display Name, and Phone Number fields.
2. Register with a new, valid email, a 6+ character password, a matching confirm-password, leaving Display Name and Phone Number blank → confirm the account is created (not signed in) and the screen shows a "check your email to confirm your account" message (FR-015, FR-021).
3. Attempt to sign in with that same email/password before confirming → confirm a distinct message explaining the email must be confirmed first, with a "resend confirmation email" option (FR-022).
4. Tap "resend confirmation email" → confirm a brief success message (or a retryable error if offline) (FR-023).
5. Open the confirmation email and click the link → confirm the account becomes confirmed; return to the app and sign in with the same email/password → confirm the user is now signed in successfully (FR-015 Scenario 3).
6. Register with a new, valid email/password/confirm-password and a Display Name and Phone Number filled in → confirm the account is created and (via Supabase Dashboard or a follow-up Profile view, after confirming) the display name and phone number are saved.
7. Attempt to register again with the same (already-registered) email → confirm a clear "already registered" error and no duplicate account.
8. Attempt to register with a 5-character password → confirm an inline validation error before any network call.
9. Attempt to register with `not-an-email` → confirm an inline validation error before any network call.
10. Attempt to register with a Confirm Password that doesn't match Password → confirm an inline validation error before any network call.
11. Turn off connectivity, attempt to register → confirm a retryable error is shown and the email (not password) remains filled in (FR-011); re-enable connectivity and retry successfully with the same email.

## Verify: Sign in and register with a Google account (User Story 2)

1. From the sign-in screen, tap "Sign in with Google" and pick a Google account never used with this app before → confirm a new account is created using that account's email and the user lands signed in.
2. Sign out, tap "Sign in with Google" again with the same account → confirm it signs into the same account (no duplicate).
3. Start Google sign-in, cancel the account chooser → confirm a silent return to the sign-in screen (no error, no state change) (FR-009).
4. Register a new account via email/password using `test@example.com` (do **not** confirm it), then attempt "Sign in with Google" using a Google account whose email is also `test@example.com` → confirm it signs directly into that same account (FR-008 — automatic linking, not an error), and confirm the original password no longer works for that account afterward (Supabase's eviction behavior, research.md §6) — this is the intended protection against someone else having pre-registered that email. Note this scenario specifically requires the email/password account to still be *unconfirmed* at the moment of the Google sign-in — confirming it first (Scenario 5 above) would make it a legitimate account, not a demonstration of the takeover protection.

## Verify: Link a Google account from Profile (User Story 4)

1. Sign in with an email/password account under a different email than any test Google account (so automatic linking, Story 2, does not apply). Go to Profile/Account → tap "Link Google account" → complete the chooser with a Google account under a *different* email → confirm it's recorded as linked and displayed on the Profile screen (FR-016, FR-018).
2. Sign out, sign in with that same Google account → confirm it now signs directly into the original email/password account (no duplicate) (User Story 4 Scenario 2).
3. On a second test account, attempt to link a Google account that's already linked to the first account → confirm the link attempt is rejected and neither account's linkage changes (FR-017).

## Verify: Recover from a failed or interrupted sign-up (User Story 5)

1. Fill in the registration form, disable connectivity, submit → confirm a retryable error and the email field stays populated (FR-011).
2. Re-enable connectivity, submit again with the same email → confirm registration completes successfully (shows the "check your email" message).
3. Close and reopen the app immediately after a successful (but not yet confirmed) registration → confirm the user lands back on the sign-in screen, not signed in, since confirmation is still pending (FR-015, 2026-08-04) — they can resume by confirming the email or using the resend action (FR-022/FR-023).

## Localization checkpoint

- Switch the device/app locale between `vi` and `en` → confirm every string on the registration screen, the Google sign-in button/errors, and the Profile Google-linking control (including all error messages from the table in `contracts/auth_repository_interface.md`) render in the selected locale with no missing keys (FR-013, SC-005).

## Automated test coverage checkpoint

Run `flutter test` → confirm:
- Unit tests cover the registration validation rules (email format, password length) and the error-mapping logic in `contracts/auth_repository_interface.md`'s table, using hand-written fakes for `AuthRepository`/`AccountAuthActions` (matching the existing `_FakeAccountAuthActions` pattern in `test/widget/features/account/account_screen_test.dart` — no new mocking library introduced).
- Widget tests pass for the new registration screen and the Profile Google-linking control.
