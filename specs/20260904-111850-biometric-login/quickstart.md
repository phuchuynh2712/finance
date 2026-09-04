# Quickstart: Biometric Login & Sign-Up Refactor

How to verify this feature once implemented, mapped to the spec's acceptance scenarios. Windows dev environment caveat (same as the prior theme/icon feature): iOS builds/simulators are unavailable here — iOS-specific steps below are BLOCKED without a macOS machine; Android steps are runnable via emulator/device.

## Prerequisites

- `local_auth` added to `pubspec.yaml`; `MainActivity.kt` changed to extend `FlutterFragmentActivity`; `USE_BIOMETRIC` permission + `NSFaceIDUsageDescription` added (research.md §1)
- Lexend font files bundled under `assets/fonts/` and declared in `pubspec.yaml` (research.md §8)
- Login/Sign Up screens rebuilt per `reference/login-signup-spec.md`; `google_sign_in` removed (research.md §7)
- Deep-link intent-filter (Android) / `CFBundleURLTypes` (iOS) registered for the password-reset redirect URL; the same URL added to the Supabase Dashboard's Redirect URLs allow-list (research.md §3, `[EXT]`)
- Supabase Dashboard "Enable email confirmations" already OFF (done earlier in this session, per spec Assumptions)

```bash
flutter pub get
flutter analyze
flutter test
```

## Verify: Quick Sign-In With Fingerprint/Face ID (User Story 1)

Android emulator with a fingerprint enrolled (Extended Controls → Fingerprint → enroll one):

1. Sign up or sign in with a password → accept the FR-009 prompt to enable biometric login.
2. Fully close the app (swipe away from recent apps, not just background) → reopen → confirm the Login screen appears with a "Log in with fingerprint" button visible (FR-020, FR-008).
3. Tap it → trigger the emulator's fingerprint simulation (`adb -e emu finger touch 1`) → confirm the app signs in directly to the main screen with no password entry (FR-011).
4. Tap it again → simulate a failed/cancelled fingerprint → confirm the app stays on the Login screen with password fields still usable (FR-012).
5. Remove the emulator's enrolled fingerprint (Settings → Security → Fingerprint → delete) → relaunch the app → confirm the fingerprint button no longer appears and password sign-in is required (FR-014).
6. Sign in as a second account on the same device (without enabling biometric for it) → confirm the first account's fingerprint enrollment does not grant access to the second account (FR-013).

## Verify: Rebranded Screens, No Google Sign-In (User Story 2)

1. Open the Login screen and the Sign Up screen in both light and dark mode (`flutter run` + OS theme toggle) → visually compare against `reference/login-signup-spec.md` (logo block, field order/labels, button styles, divider, footer links).
2. Repository-wide search for `google` (case-insensitive) under `lib/` → zero remaining references outside of comments explaining the removal, if any (research.md §7).
3. Open the Account screen → confirm no "linked Google account" section exists.
4. On Sign Up, leave the Terms of Service checkbox unchecked → confirm the primary "Sign Up" button is disabled/blocked (FR-007).
5. Complete Sign Up with valid data → confirm it signs in immediately with no "check your email"/confirmation step of any kind (FR-019).

## Verify: Cold-Start / Background Re-Entry Gate (User Story 1, FR-020/FR-021)

1. Sign in, fully close the app, reopen → Login screen (gate) appears even though the session is still valid (not a real sign-out) — confirms FR-020's cold-start branch.
2. Sign in, background the app (Home button, don't swipe away), wait under 5 minutes, resume → confirm the app returns straight to where it was, no gate (FR-020's threshold, negative case).
3. Repeat, but wait over 5 minutes backgrounded (or temporarily lower the threshold constant for testing) before resuming → confirm the gate appears (FR-020's threshold, positive case).

## Verify: Turn Biometric Login On/Off (User Story 3)

1. Fresh device/emulator, sign up for the first time → confirm the one-time enable-biometric prompt appears immediately (FR-009, fires on Sign Up per Clarifications).
2. Decline it → sign out and back in with password → confirm the prompt does NOT reappear automatically, but the Account screen's toggle can still turn it on manually (FR-010).
3. With biometric enabled, sign out from the Account screen → confirm the fingerprint button no longer appears on next Login screen visit, and the toggle reads "off" after signing back in (FR-014a).

## Verify: Forgot Password + Session Revocation (User Story 4, FR-016a/FR-016b)

Requires two things running: (a) the app, (b) access to the test account's inbox (or Supabase Dashboard → Authentication → Logs, to read the recovery link directly if email delivery isn't set up in the dev project).

1. Tap "Forgot password?" → submit a registered email → confirm a generic on-screen confirmation appears (FR-015), same wording as step 2 below.
2. Repeat with an unregistered email → confirm the identical on-screen confirmation (no enumeration difference).
3. Open the recovery link (a) with the app already running in the background, (b) with the app fully closed (cold start via the link) — test BOTH, per research.md §3's flagged reliability caveat — confirm both land on a "Set New Password" screen.
4. Set a new password → confirm sign-in with the OLD password now fails, and the account is fully signed out everywhere (FR-016, FR-016a) — if a second device/session was signed in, confirm it's also forced back to the Login screen.
5. Separately, from the Account screen's existing "change password" field (already signed in, current device), change the password → confirm THIS device stays signed in (no forced re-entry gate beyond what FR-020 would already trigger normally), while a second signed-in device/session is signed out (FR-016b) — note per research.md §2 this does not fire a `signedOut` auth-state event on the current device, so verify via the second device/session, not by watching the first device's own state.

## Manual accessibility / consistency spot-check

- Every icon on the new Login/Sign Up screens is a `LucideIcons.*` constant (`eye`/`eyeOff`, `fingerprint`, `chevronLeft`, `userPlus`, `check`) per `reference/icons.json` — no `Icons.*` (Material) on either screen.
- All colors come from `Theme.of(context).colorScheme`/`AppSemanticColors` — no hardcoded hex in the new screens.
- Run `flutter test test/unit/core/theme/app_theme_test.dart` (unchanged by this feature) → still passes, confirming this feature didn't regress the existing WCAG AA contrast tests.
- Lexend renders correctly on both a cold-started (offline) launch and a normal launch — no fallback-font flash, confirming the local asset bundling (research.md §8) works without a network fetch.
