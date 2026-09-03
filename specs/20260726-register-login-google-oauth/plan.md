# Implementation Plan: Registration & Google Sign-In

**Branch**: `20260726-register-login-google-oauth` | **Date**: 2026-08-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260726-register-login-google-oauth/spec.md`

## Summary

Adds a registration screen (email/password/confirm-password, plus optional display name and phone number, immediate sign-in with no confirmation step) reachable from the existing sign-in screen — closing the gap where `AuthRepository.signUp()` exists but is never called from any UI — plus native Google Sign-In (Android account chooser / iOS equivalent) on both the sign-in and registration screens. Google sign-in with an email matching an existing email/password account automatically links to it rather than erroring (spec.md Clarifications sessions 2–3): research into Supabase's GoTrue server source confirmed this is safe as-is, because GoTrue unconditionally evicts every prior identity (including a password) from an account whenever a new OAuth identity attaches to a still-unconfirmed row — an attacker who pre-registers someone else's email can never get that row confirmed themselves, so their account is always in the state this eviction targets (research.md §6). A signed-in user can additionally link a Google account under a *different* email explicitly from the Profile/Account screen. Technical approach: `supabase.auth.signInWithIdToken()` and `.linkIdentityWithIdToken()` (native, no browser/webview) fed by the `google_sign_in` v7 package, extending the existing `AuthRepository`/`AccountAuthActions` interfaces rather than introducing new abstractions — no new database schema, since `auth.users`/`auth.identities` already model everything this feature needs; the optional display name/phone number are stored via `signUp()`'s existing `data:` metadata parameter (`raw_user_meta_data`), the same mechanism `AuthRepository.updateAvatar()` already uses for `avatar_url`, so no new Supabase table or column is needed for those either.

**2026-08-04 addendum (part 1)**: Following live device testing (T030 walkthrough) and direct user feedback, three fields were added to the registration form: a required "Confirm Password" field (client-side match validation only, no new backend call) and optional "Display Name" / "Phone Number" fields (stored via the `data:` metadata parameter above, consistent with the no-new-schema approach already used for `signInWithGoogle`/`linkGoogleAccount`). See spec.md Clarifications, Session 2026-08-04.

**2026-08-04 addendum (part 2)**: FR-015 reversed — email/password registration now requires email confirmation before sign-in, instead of signing the user in immediately. This surfaced from live testing: the app was calling `signUp()` and treating any successful response as "signed in," but Supabase's `AuthResponse.session` is `null` when email confirmation is required, so the app was silently doing nothing useful with an unconfirmed account — which the user correctly read as "nothing happens when I tap Đăng ký." Rather than just fixing that bug to match the original "sign in immediately" design, the user asked to switch to requiring confirmation (the more common pattern), so this is a product decision on top of the bug fix. Technical approach: detect `AuthResponse.session == null` after `signUp()` to know confirmation is pending (no new API call — `session` is already part of the existing response type); detect Supabase's `email_not_confirmed` error code (a normal `AuthApiException.code` string, same mechanism already used for `email_exists`) when `signInWithPassword()` is attempted on an unconfirmed account; use Supabase's existing `resend(email:, type: OtpType.signup)` API to resend the confirmation email — no new dependency, this ships in `supabase_flutter`'s `gotrue` package already in use. **External dependency**: this only takes effect once the Supabase Dashboard's "Enable email confirmations" setting is turned on (Authentication → Settings) — a new `[EXT]` task, since the client-side code change alone doesn't force server-side confirmation if the Dashboard setting is off.

## Technical Context

**Language/Version**: Dart (SDK `^3.11.0`), Flutter stable

**Primary Dependencies**: `supabase_flutter: ^2.8.0` (already present; resolved `gotrue 2.26.0` already supports `linkIdentityWithIdToken`, no version bump needed — research.md §3), `google_sign_in: ^7.2.0` (NEW), `flutter_riverpod` (existing DI pattern, plain `Provider`/`StateNotifierProvider.autoDispose`, no codegen — matches existing `AccountController`/`SignInScreen` conventions, not the unused `riverpod_generator` dependency). 2026-08-04 addendum (part 2): no new dependency — `resend()` and `AuthResponse.session` are already part of the `gotrue` client the project depends on.

**Storage**: No new schema. Extends the existing Supabase-managed `auth.users`/`auth.identities` tables via Auth API calls only (see data-model.md) — no new Drift tables, no new Supabase migration

**Testing**: `flutter_test` for unit + widget tests, using hand-written fakes (matching the existing `_FakeAccountAuthActions` pattern in `test/widget/features/account/account_screen_test.dart` — no mocking library is introduced); unit tests cover registration validation (email format, password length) and the error-mapping table in `contracts/auth_repository_interface.md`; widget tests for the new registration screen and the Profile Google-linking control; no new integration test is added (the existing `allocate_spend_cover_flow_test.dart` already exercises sign-in as a precondition — this feature doesn't need its own end-to-end DB-backed test since it introduces no persisted schema); Supabase's server-side automatic-linking-plus-eviction behavior (FR-008, research.md §6) cannot be exercised by a unit test against a live Supabase project and is instead covered by the manual `quickstart.md` walkthrough, consistent with how the prior feature's offline-sync reconciliation was also manually verified where a live backend was required

**Target Platform**: Android + iOS (matches existing app scope)

**Project Type**: Mobile app (Flutter, single codebase, feature-first Clean Architecture per constitution)

**Performance Goals**: SC-001 (registration <60s end-to-end, immediate sign-in), SC-002/SC-006 (Google sign-in and link-then-sign-in <15s, excluding OS account-chooser time) — both are interaction-time targets, not raw device performance; no new lists/animations are introduced so constitution Principle IV's 60fps/list-virtualization rules aren't newly triggered by this feature

**Constraints**: Google sign-in and linking calls are network-bound (Supabase Auth API + Google's native SDK) and MUST NOT block the UI thread — both are already `Future`-based Supabase/Google SDK calls, run naturally off the UI isolate by the Dart async runtime; no explicit isolate offload is needed (unlike CPU-bound work, this is I/O-bound)

**Scale/Scope**: 1 new screen (registration), 1 new control on the existing Account screen (Google linking), extensions to 2 existing classes (`AuthRepository`, `AccountAuthActions`) — no new feature module needed; lives entirely inside the existing `features/account/` and `core/auth/`. The 2026-08-04 addendum adds 3 fields (confirm-password, display name, phone number) to the same registration screen and 1 new client-side validator function — no new screens, no new classes, no schema change

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / Section | Applies? | How this feature satisfies it |
|---|---|---|
| I. Code Quality | Yes | Google-SDK interaction (`google_sign_in` calls) is isolated inside `AuthRepository` (`data/`-equivalent role within `core/auth/`); `domain/`-facing surface is just the two method signatures in `contracts/auth_repository_interface.md` — no widget directly touches the Google SDK; registration form validation logic (email/password rules) lives in a plain Dart validator, not inline in `build()` |
| II. Testing Standards | Yes | Registration validation (email format, password length, confirm-password match) and the Supabase-error → user-message mapping table (`contracts/auth_repository_interface.md`) are pure Dart, unit-tested via hand-written fakes; widget tests for the registration screen (including the new confirm-password/name/phone fields) and Profile's Google-linking control; this feature has no financial calculation logic, so the 80% domain-coverage gate applies narrowly (validation + error-mapping) rather than broadly |
| III. UX Consistency | Yes | Registration screen reuses the existing `SignInScreen`'s layout/theme conventions (`FilledButton`, shared `TextField` styling, `_isSubmitting`-style disable-while-in-flight pattern per FR-010); all new strings ship in both `app_vi.arb` (with `@key` metadata blocks, matching existing convention) and `app_en.arb` in the same PR, explicitly including the Profile Google-linking control and its errors (FR-013). 2026-08-04 addendum (part 2): the "check your email" state (FR-021) reuses `SignUpScreen`'s existing error-message `Text` widget pattern rather than introducing a new screen/route — swapping the form for a confirmation message in place, consistent with how `SignInScreen`'s error message already renders inline without navigation |
| IV. Performance | Yes | No new lists/animations; Google sign-in/linking are I/O-bound `Future` calls that don't block the UI thread by construction — no isolate offload needed |
| Recommended Architecture | Yes | Extends existing `core/auth/auth_repository.dart` and `features/account/presentation/` rather than creating a new feature module (this is infrastructure-adjacent auth capability, not a new business domain); the new registration screen lives in `features/account/presentation/`, matching where `sign_in_screen.dart` already lives |
| Offline-First Data & Sync | N/A | This feature has no offline-writable data of its own — registration/sign-in/linking inherently require connectivity (there is no "queue a sign-up for later sync" concept in Supabase Auth); the existing outbox pattern is unaffected |
| Security | Yes | RLS is unaffected (no new tables); no financial data or tokens are logged by this feature's new code. Display name and phone number (2026-08-04 addendum) are non-financial profile metadata stored via Supabase's standard `raw_user_meta_data` mechanism (same as the existing `avatar_url` field) — no new sensitive-data-handling concern beyond the existing convention of not logging user-supplied form values. Automatic Google-identity-linking-by-email-match (FR-008) is safe as-is — verified via primary-source research into Supabase's GoTrue server code, specifically the `RemoveUnconfirmedIdentities` eviction path that fires unconditionally whenever the pre-existing account being linked into is not yet confirmed (research.md §6). This is the feature's one genuine account-takeover risk, and it is closed by a mechanism already built into the platform, not by any code this feature adds — confirmed by directly reading GoTrue's source (two research passes were needed; the first pass misattributed which party's "verified" flag mattered — see research.md §6's process note). **Fixed inline** (was a pre-existing gap, not introduced by this feature, but resolved here since this branch already touches auth code): `Supabase.initialize()` in `lib/core/network/supabase_client_provider.dart` now passes `authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage())` — a new `lib/core/storage/secure_local_storage.dart` backed by `flutter_secure_storage` (Keychain/Keystore) — replacing the default `SharedPreferences` session storage. Android additionally gets `android:allowBackup="false"` in `AndroidManifest.xml` to prevent a Keystore-key/auto-backup mismatch on restore. **Caveat**: any user currently signed in (via the old `SharedPreferences` storage) will be signed out on first launch after this change, since the new secure storage starts empty — acceptable for this pre-release app, but worth calling out explicitly rather than discovering it as a surprise. iOS may additionally need a Keychain Sharing entitlement added via Xcode on first iOS build (no `.entitlements` files exist in this project yet; not addressed here since it requires a macOS/Xcode environment to do safely) |
| Development Workflow | Yes | Feature branch already created (`20260726-register-login-google-oauth`); tests ship in the same PR as the logic they cover |

**Result**: PASS — no violations requiring Complexity Tracking justification. One pre-existing gap (session storage) is explicitly noted above rather than silently inherited; it does not block this plan since this feature doesn't create or worsen it.

**Post-Phase-1 re-check**: Confirmed against the completed `research.md`, `data-model.md`, and `contracts/auth_repository_interface.md` — the "no new schema" claim holds (data-model.md maps entirely onto existing `auth.users`/`auth.identities`), the error-mapping contract concretely enumerates every Supabase error condition the spec's FRs require distinguishing (not just asserted), and the Security gap note above is unchanged by design details discovered during Phase 1. Still PASS, no new violations surfaced.

**2026-08-04 addendum re-check (part 1)**: The 3 new fields require no new research (no new Supabase API, no new package) and no schema change (display name/phone number ride the same `data:` metadata parameter `updateAvatar()` already established as the pattern for profile fields) — updated `data-model.md`'s Account entity and `contracts/auth_repository_interface.md`'s `signUp()` signature accordingly. Still PASS.

**2026-08-04 addendum re-check (part 2)**: Reversing FR-015 does not change the Security row's conclusion — `RemoveUnconfirmedIdentities` (research.md §6) is unconditional and was never the reason "sign in immediately" was safe; this reversal is a UX decision layered on top of an already-safe design, not a fix to something unsafe. Explicitly re-confirmed here so a future reader doesn't mistake the reversal for "the original design had a security hole." Still PASS — no new violations.

## Project Structure

### Documentation (this feature)

```text
specs/20260726-register-login-google-oauth/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md         # Phase 1 output
├── quickstart.md         # Phase 1 output
├── contracts/
│   └── auth_repository_interface.md   # Phase 1 output — Dart interface contract, no schema
└── tasks.md              # Phase 2 output (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── auth/                                  # existing — extended, no new files
│   │   ├── auth_repository.dart               # DONE — signInWithGoogle, linkGoogleAccount, linkedGoogleEmail; 2026-08-04 (1): signUp() gains optional displayName/phoneNumber params, passed via signUp()'s existing `data:` metadata parameter; 2026-08-04 (2): signUp() returns whether the account needs confirmation (AuthResponse.session == null), + new resendConfirmationEmail(email) using gotrue's resend(type: OtpType.signup)
│   │   └── auth_state_provider.dart           # unchanged
│   ├── network/
│   │   └── supabase_client_provider.dart      # DONE (Security gate, ahead of tasks.md) — authOptions now uses SecureLocalStorage
│   ├── storage/
│   │   └── secure_local_storage.dart          # DONE (Security gate, ahead of tasks.md) — NEW, flutter_secure_storage-backed LocalStorage
│   └── router/
│       └── app_router.dart                    # DONE (T012) — /sign-up route registration
├── features/
│   └── account/
│       ├── domain/
│       │   └── account_use_cases.dart         # existing — unchanged (AccountAuthActions lives in core/auth per current code, not here)
│       └── presentation/
│           ├── sign_in_screen.dart            # DONE — "Create account" link + "Sign in with Google" button + SingleChildScrollView (overflow fix); 2026-08-04 (2): detect email_not_confirmed error code, show a distinct message + "resend" action (FR-022)
│           ├── sign_up_screen.dart            # DONE (T010) — registration form; 2026-08-04 (1): + confirm-password/name/phone fields, SingleChildScrollView (overflow fix); 2026-08-04 (2): on signUp() success, show "check your email" message (FR-021) instead of relying on the router auth guard to navigate in
│           ├── sign_up_validation.dart        # DONE (T009) — email/password rules; 2026-08-04: + confirm-password match rule
│           ├── account_screen.dart            # DONE — "Link Google account" control + linked-email display
│           └── account_controller.dart        # DONE — extended with linkGoogleAccount/linkedGoogleEmail passthrough
├── core/l10n/
│   ├── app_vi.arb                             # existing — new keys (sign-up screen, Google buttons/errors, Profile linking), @key metadata blocks per existing convention; 2026-08-04 (2): + check-your-email message, email_not_confirmed error, resend action/confirmation keys
│   └── app_en.arb                             # existing — same new keys, no @key metadata (matches existing convention)
└── main.dart                                  # + GoogleSignIn.instance.initialize() call alongside initSupabase() (T006) — no new provider scope wiring needed otherwise

android/app/
├── build.gradle.kts                           # unchanged (no OAuth config needed for native flow beyond the app's own signing setup, which already exists)
└── src/main/AndroidManifest.xml               # DONE (Security gate, ahead of tasks.md) — added android:allowBackup="false"

ios/Runner/
└── Info.plist                                 # + CFBundleURLTypes entry (reversed iOS OAuth client ID) — research.md §4

test/
├── unit/
│   └── features/account/presentation/
│       └── sign_up_validation_test.dart       # DONE (T007) — email/password rules; 2026-08-04 (1): + confirm-password match rule
└── widget/
    └── features/account/
        ├── sign_up_screen_test.dart           # DONE (T008) — 2026-08-04 (1): + confirm-password/name/phone field coverage; 2026-08-04 (2): + "check your email" message assertion, no-navigation assertion
        ├── sign_in_screen_test.dart           # DONE (T015) — Google button states; 2026-08-04 (2): + email_not_confirmed message + resend action coverage
        └── account_screen_test.dart           # DONE — extended for the Google-linking control
```

**Structure Decision**: No new feature module. This is an extension of the existing `core/auth/` capability and the existing `features/account/` module (which already owns `sign_in_screen.dart` and `account_screen.dart`), not a new business domain — introducing a `features/registration/` or `features/google_auth/` module would fragment a single cohesive auth capability across artificial feature boundaries the constitution's feature-first rule doesn't require here (feature-first applies to *business domains* like envelopes/expenses; auth is core infrastructure shared by the whole app, matching how `core/auth/` is already organized). External-only changes: one new `Info.plist` entry (iOS) and Google Cloud Console / Supabase Dashboard configuration (quickstart.md) — no Android manifest change needed *for OAuth specifically* (the native, non-browser flow requires no new intent-filter); the one Android manifest change in this branch (`allowBackup="false"`) is unrelated to Google sign-in and instead supports the secure-storage fix described in the Security row above. 2026-08-04 addendum (part 2): one additional external, no-code change — Supabase Dashboard → Authentication → Settings → "Enable email confirmations" must be turned on for FR-015's reversal to take effect server-side; the client-side handling (FR-021/FR-022/FR-023) is built and tested regardless, but is only exercised end-to-end once that setting is on.

## Complexity Tracking

*No violations — table intentionally empty. The Security gate's noted pre-existing gap is informational (see Constitution Check table), not a violation this plan introduces, so it does not require a Complexity Tracking justification row.*
