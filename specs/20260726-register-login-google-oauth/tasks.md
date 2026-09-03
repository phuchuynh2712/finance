# Tasks: Registration & Google Sign-In

**Input**: Design documents from `specs/20260726-register-login-google-oauth/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/auth_repository_interface.md, quickstart.md

**Tests**: Included per the constitution's Testing Standards (Principle II) — validation/error-mapping logic and new screens/controls get unit + widget tests in the same PR.

**Organization**: Tasks are grouped by user story (US1, US2, US4, US5 — spec.md has no US3; the numbering there is intentional, preserved here for traceability).

## Already done in this branch (not tasks — do not redo)

- `lib/core/storage/secure_local_storage.dart` — `flutter_secure_storage`-backed `LocalStorage`
- `lib/core/network/supabase_client_provider.dart` — wired to use it via `authOptions`
- `android/app/src/main/AndroidManifest.xml` — added `android:allowBackup="false"`

These were completed during planning (constitution Security gate) and verified with `flutter analyze` (no issues). Listed here only so no one repeats the work.

---

## Phase 1: Setup

**Purpose**: Dependency and external-service prerequisites shared by every user story.

- [X] T001 Add `google_sign_in: ^7.2.0` to `pubspec.yaml` and run `flutter pub get`
- [ ] T002 [EXT] External: create a Web OAuth client ID, an Android OAuth client ID (with debug + release keystore SHA-1 fingerprints), and an iOS OAuth client ID in Google Cloud Console (research.md §4)
- [ ] T003 [EXT] External: enable the Google provider in Supabase Dashboard → Authentication → Providers → Google, using the Web client ID + secret from T002
- [ ] T004 [EXT] External: enable "Manual Linking" in Supabase Dashboard → Authentication → Settings (required for `linkIdentityWithIdToken`, US4 — without it every explicit link attempt fails with `manual_linking_disabled`, research.md §3)
- [ ] T005 [P] Add `CFBundleURLTypes` entry (reversed iOS OAuth client ID) to `ios/Runner/Info.plist` (research.md §4)

**Checkpoint**: Dependency resolved, external OAuth config in place. No app code changes yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The one shared piece of Google-SDK plumbing every Google-related story (US2, US4) needs. US1 (email/password registration) has no foundational dependency beyond Phase 1 and can start immediately after Setup.

**⚠️ CRITICAL**: US2 and US4 cannot start until this phase is complete. US1 is unaffected.

- [X] T006 Initialize `GoogleSignIn.instance` with `serverClientId` (Web client ID) and `clientId` (iOS client ID) once at app startup in `lib/main.dart`, alongside the existing `initSupabase()` call (research.md §2)

**Checkpoint**: `GoogleSignIn.instance` ready to call `attemptLightweightAuthentication()`/`authenticate()` from anywhere in the app.

---

## Phase 3: User Story 1 - Create an account with email and password (Priority: P1) 🎯 MVP

**Goal**: A new user can register with email/password from a new registration screen and is immediately signed in — closing the gap where `AuthRepository.signUp()` exists but no UI calls it.

**Independent Test**: Open the app with no existing account, complete the registration form with a valid email/password, and confirm the user lands in an authenticated state — no other user story required.

### Tests for User Story 1

- [X] T007 [P] [US1] Unit test email-format and password-length (≥6 chars) validation rules in `test/unit/features/account/presentation/sign_up_validation_test.dart`
- [X] T008 [P] [US1] Widget test for `SignUpScreen` covering: successful registration, duplicate-email error, weak-password inline error, invalid-email inline error, submit-button disabled while in flight, in `test/widget/features/account/sign_up_screen_test.dart` (fakes `AuthRepository`, matching the `_FakeAccountAuthActions` pattern already used in `test/widget/features/account/account_screen_test.dart`)

### Implementation for User Story 1

- [X] T009 [US1] Add a plain-Dart registration validator (email format, ≥6-char password) — colocate with the new screen's controller logic, no framework dependency, per constitution Principle I (FR-002)
- [X] T010 [US1] Create `SignUpScreen` in `lib/features/account/presentation/sign_up_screen.dart` — email + password fields, submit button disabled while in flight (FR-010), calls `authRepositoryProvider.signUp()` directly (matches `SignInScreen`'s existing pattern of reading the repository directly rather than through a controller) (FR-001, FR-004)
- [X] T011 [US1] Add a "Create account" link/button to `lib/features/account/presentation/sign_in_screen.dart` navigating to the new registration route
- [X] T012 [US1] Register the `/sign-up` route in `lib/core/router/app_router.dart`
- [X] T013 [US1] Map duplicate-email and Google-only-account errors from `signUp()` to user-facing messages per the error-mapping table in `contracts/auth_repository_interface.md`, preserving the entered email (not password) on failure (FR-011, FR-003, FR-012 — this is the edge case in spec.md: "email exists but was created via Google sign-in only")
- [X] T014 [P] [US1] Add new l10n keys for the registration screen to `lib/core/l10n/app_vi.arb` (with `@key` metadata blocks, matching existing convention) and `lib/core/l10n/app_en.arb` (FR-013)

### Registration form additions (2026-08-04 — Confirm Password, Display Name, Phone Number)

- [X] T032 [P] [US1] Unit test the confirm-password match rule in `test/unit/features/account/presentation/sign_up_validation_test.dart` (FR-002)
- [X] T033 [US1] Add `isConfirmPasswordValid` (or equivalent) to `lib/features/account/presentation/sign_up_validation.dart` — exact-match check against the password (FR-002)
- [X] T034 [US1] Add Confirm Password (required), Display Name (optional), and Phone Number (optional) fields to `lib/features/account/presentation/sign_up_screen.dart`; block submission with an inline error when Confirm Password doesn't match Password (FR-001, FR-002, FR-019)
- [X] T035 [US1] Extend `AuthRepository.signUp()` in `lib/core/auth/auth_repository.dart` with optional `displayName`/`phoneNumber` parameters, passed through Supabase's `data:` metadata parameter (same mechanism as `updateAvatar`'s `avatar_url`) — no schema change (FR-001, FR-019, FR-020, contracts/auth_repository_interface.md)
- [X] T036 [P] [US1] Update `test/widget/features/account/sign_up_screen_test.dart` to cover: Confirm Password mismatch shows an inline error and does not submit; Display Name/Phone Number left blank still succeeds; Display Name/Phone Number filled in are passed to `signUp()` (FR-001, FR-002, FR-019)
- [X] T037 [P] [US1] Add l10n keys for the three new fields and the confirm-password-mismatch error to `lib/core/l10n/app_vi.arb`/`app_en.arb` (FR-013)

**Checkpoint**: User Story 1 fully functional and independently testable — this alone is a shippable MVP increment.

### Email confirmation requirement (2026-08-04 part 2 — FR-015 reversed)

- [ ] T038 [EXT] External: confirm "Enable email confirmations" is ON in Supabase Dashboard → Authentication → Settings (Supabase's default for new projects — likely already satisfied; only action needed if a prior session turned it off) (FR-015, quickstart.md item 4)
- [ ] T038b [EXT] External (optional but recommended): set Supabase Dashboard → Authentication → URL Configuration → Site URL to a real value (or a `Confirmed!` landing page) — the default confirmation email template redirects here after verifying, and an unset/`localhost` Site URL means the user's phone browser lands on a broken/dev page after clicking the link even though the account is now confirmed server-side and sign-in works. Out of scope to build a dedicated landing page in this feature; if skipped, quickstart.md documents this as a known cosmetic gap (FR-015 note)
- [X] T039 [P] [US1] Change `AuthRepository.signUp()`'s return type from `Future<void>` to `Future<bool>` in `lib/core/auth/auth_repository.dart` — `true` when `AuthResponse.session == null` (unconfirmed, caller must show "check your email"), `false` when a session came back immediately (contracts/auth_repository_interface.md, FR-004, FR-015, FR-021)
- [X] T040 [P] [US1] Add `AuthRepository.resendConfirmationEmail(String email)` in `lib/core/auth/auth_repository.dart` using `_client.auth.resend(email: email, type: OtpType.signup)` (contracts/auth_repository_interface.md, FR-023)
- [X] T041 [US1] Update `SignUpScreen._submit()` in `lib/features/account/presentation/sign_up_screen.dart` to branch on `signUp()`'s new bool: on `true`, show a "check your email to confirm your account" message and stay on the sign-in/registration flow (no navigation into the app); on `false`, keep the existing sign-in-immediately behavior (FR-004, FR-015, FR-021)
- [X] T042 [US1] Update `SignInScreen._submit()` in `lib/features/account/presentation/sign_in_screen.dart` to detect the `email_not_confirmed` error code from `signInWithPassword()` and show a distinct message (not the generic wrong-password error) with a "resend confirmation email" action wired to `resendConfirmationEmail()` (contracts/auth_repository_interface.md, FR-022, FR-023)
- [X] T043 [P] [US1] Add l10n keys for the "check your email" message, the `email_not_confirmed` error message, the "resend confirmation email" action label, and resend success/failure messages to `lib/core/l10n/app_vi.arb`/`app_en.arb` (FR-013, FR-021, FR-022, FR-023)
- [X] T044 [P] [US1] Update `test/widget/features/account/sign_up_screen_test.dart`: successful registration now asserts the "check your email" message instead of a signed-in state (fake `signUp()` returns `true`); add a case for `signUp()` returning `false` (immediate sign-in still works)
- [X] T045 [P] [US1] Add widget test cases to `test/widget/features/account/sign_in_screen_test.dart`: `email_not_confirmed` shows the distinct message with a resend action; tapping resend calls `resendConfirmationEmail()` and shows success/retryable-error feedback (FR-022, FR-023)

**Checkpoint**: User Story 1's registration flow now requires email confirmation before sign-in, matching the reversed FR-015. US2 (Google) and US4 (linking) are unaffected — Google-authenticated accounts are always pre-confirmed (data-model.md).

---

## Phase 4: User Story 2 - Sign in and register with a Google account (Priority: P2)

**Goal**: A "Sign in with Google" button on both sign-in and registration screens creates a new account on first use, or automatically joins an existing email/password account sharing the same email (safe per research.md §6's `RemoveUnconfirmedIdentities` mechanism — no client-side branching needed).

**Independent Test**: Tap "Sign in with Google" on a device with a Google account configured, complete the account chooser, and confirm an authenticated state is reached — no prior password-based registration required.

### Tests for User Story 2

- [X] T015 [P] [US2] Widget test for the "Sign in with Google" button's states (idle, cancelled chooser → no error/no state change, network failure → retryable error) in `test/widget/features/account/sign_in_screen_test.dart` and the registration screen's equivalent

### Implementation for User Story 2

- [X] T016 [US2] Implement `AuthRepository.signInWithGoogle()` in `lib/core/auth/auth_repository.dart`: `GoogleSignIn.instance.authenticate()` → `authorizationClient.authorizationForScopes()` (fallback to `authorizeScopes()`) → `Supabase.instance.client.auth.signInWithIdToken(provider: OAuthProvider.google, ...)` (research.md §1, §2; contracts/auth_repository_interface.md) — a single call correctly produces all three outcomes: new-account creation (FR-006), returning-user sign-in (FR-007), and automatic linking to a matching-email account (FR-008)
- [X] T017 [US2] Add a "Sign in with Google" button to `lib/features/account/presentation/sign_in_screen.dart`, calling `signInWithGoogle()` directly (matches T010's direct-repository-call pattern)
- [X] T018 [US2] Add the same "Sign in with Google" button to `lib/features/account/presentation/sign_up_screen.dart` (FR-005)
- [X] T019 [US2] Handle Google-chooser cancellation as a silent no-op (no error, no navigation) distinct from a network/server failure, which shows a retryable error (FR-009, edge case in spec.md)
- [X] T020 [P] [US2] Add new l10n keys for the Google sign-in button and its errors to `app_vi.arb`/`app_en.arb` (FR-013)

**Checkpoint**: User Stories 1 and 2 both work independently. Google sign-in is usable standalone or alongside email/password.

---

## Phase 5: User Story 4 - Link a Google account from Profile for one-tap future sign-in (Priority: P2)

**Goal**: A signed-in user can explicitly link a Google account whose email differs from their app account's email (the one case automatic linking in US2 cannot cover) from the Profile/Account screen.

**Independent Test**: Sign in with email/password, link a Google account under a different email from Profile, sign out, sign in with that Google account, and confirm it lands in the original account.

### Tests for User Story 4

- [X] T021 [P] [US4] Extend `test/widget/features/account/account_screen_test.dart`'s `_FakeAccountAuthActions` with `linkGoogleAccount`/`linkedGoogleEmail`, and add test cases: successful link shows linked email, `identity_already_exists` shows a clear error with no state change (FR-017)

### Implementation for User Story 4

- [X] T022 [US4] Implement `AuthRepository.linkGoogleAccount()` and `linkedGoogleEmail` getter in `lib/core/auth/auth_repository.dart`, using `linkIdentityWithIdToken()` (research.md §3; contracts/auth_repository_interface.md)
- [X] T023 [US4] Add `linkGoogleAccount()`/`linkedGoogleEmail` to the `AccountAuthActions` interface in `lib/core/auth/auth_repository.dart` (FR-016, FR-018)
- [X] T024 [US4] Add `linkGoogleAccount()` passthrough and `identity_already_exists` error handling to `AccountController` in `lib/features/account/presentation/account_controller.dart`
- [X] T025 [US4] Add a "Link Google account" control and linked-account display to `lib/features/account/presentation/account_screen.dart` (FR-016, FR-018)
- [X] T026 [P] [US4] Add new l10n keys for the Profile Google-linking control and its errors to `app_vi.arb`/`app_en.arb` (FR-013)

**Checkpoint**: All of US1, US2, US4 work independently and together — a user who registered with email/password can now also use Google, either automatically (matching email) or explicitly (different email).

---

## Phase 6: User Story 5 - Recover from a failed or interrupted sign-up (Priority: P3)

**Goal**: Registration failures (network/server errors) are retryable, not dead ends.

**Independent Test**: Start registration, simulate a network failure on submit, confirm a retryable error is shown with the email preserved, then retry successfully with the same email.

**Note**: This phase is intentionally verification-only, not new-code — US5's requirements (FR-011) were already implemented as part of T013 in Phase 3. This phase's single task confirms that implementation actually satisfies US5's acceptance scenarios end to end; it is not a placeholder or an omitted phase.

### Implementation for User Story 5

*No new tests — this hardens behavior already covered by T008/T013's error-preservation assertions; this phase only needs to confirm the existing implementation already satisfies it.*

- [X] T027 [US5] Verify `SignUpScreen` (from T010/T013) preserves the entered email (not password) and shows a retryable error on network/server failure, and that resubmitting with the same email succeeds once connectivity returns (FR-011) — no code change expected if T013 was implemented per the error-mapping contract; add the missing handling if a gap is found

**Checkpoint**: Registration is robust to interruption. All user stories complete.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T028 Run `flutter analyze` — zero errors/warnings (constitution Principle I gate)
- [X] T029 Run `flutter test` — confirm all new unit/widget tests pass and existing tests (e.g. `test/widget/features/account/account_screen_test.dart`) are unaffected
- [X] T030 Walk through `quickstart.md` end to end on a real device/emulator with the external setup (T002–T005) in place, including the pre-registration-takeover verification step (US2's quickstart step 4: confirm the original attacker-set password stops working after the real owner's Google sign-in evicts it)
- [ ] T031 [EXT] External (macOS/Xcode required, not doable from this Windows environment): add the Keychain Sharing entitlement for `flutter_secure_storage` if iOS builds show session-persistence issues (research.md §5)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately. T002–T005 are external/manual and can proceed in parallel with T001.
- **Foundational (Phase 2)**: Depends on T001 (dependency) and T002 (Web/iOS client IDs exist) — BLOCKS US2 and US4 only. Does **not** block US1.
- **User Story 1 (Phase 3)**: Depends only on Setup (Phase 1) — can start immediately, in parallel with Phase 2.
- **User Story 2 (Phase 4)**: Depends on Foundational (Phase 2). Independent of US1's completion, though it adds a button to the same two screens US1 creates/modifies (T017/T018 touch files T010/T011 create — sequence after US1 if one person is doing both).
- **User Story 4 (Phase 5)**: Depends on Foundational (Phase 2). Independent of US2's completion (different files: `account_screen.dart`/`account_controller.dart` vs `sign_in_screen.dart`/`sign_up_screen.dart`), but shares the same `AuthRepository` class US2 also extends — coordinate if working in parallel to avoid merge conflicts in one file.
- **User Story 5 (Phase 6)**: Depends on US1 (Phase 3) being implemented; it verifies/hardens US1's behavior rather than adding new surface area.
- **Email confirmation requirement (2026-08-04 part 2, within Phase 3)**: Depends on the original US1 tasks (T009–T014, T032–T037) being complete — it changes `signUp()`'s return type and the screens that call it, not net-new surface area. T038 (Dashboard check) has no code dependency and can happen anytime.
- **Polish (Phase 7)**: Depends on all desired user stories being complete.

### Parallel Opportunities

- T002, T003, T004, T005 (all external/config, no shared files) can proceed in parallel with each other and with T001.
- T007 and T008 (US1 tests, different files) can run in parallel.
- T014 (US1 l10n) can run in parallel with T009–T013 (different files).
- Phase 3 (US1) and Phase 2 (Foundational) can proceed in parallel — US1 doesn't need Google plumbing.
- Once Foundational (Phase 2) completes, US2 (Phase 4) and US4 (Phase 5) can proceed in parallel by different people, provided both coordinate around shared edits to `lib/core/auth/auth_repository.dart` (T016 and T022 both touch it).
- T032 and T036 (2026-08-04 additions, different test files) can run in parallel; T037 (l10n) can run in parallel with T033–T035 (different files). T033 must precede T034 (screen needs the validator); T034/T035 both touch different concerns of the same PR but no shared file conflict (screen vs. repository).
- T039, T040, T043 (2026-08-04 part 2: repository return-type change, new resend method, l10n — different files/concerns) can run in parallel; T041 depends on T039 (screen needs the new bool signature), T042 depends on T040 (screen needs `resendConfirmationEmail`). T044/T045 (test files) can run in parallel with each other and with T043, but should follow T041/T042 respectively so the tests assert real behavior. T038 (Dashboard check) has no code dependency and can run anytime.

---

## Parallel Example: Setup + User Story 1 running together

```bash
# One person handles external config while another starts US1 code:
Task: "External: create OAuth client IDs in Google Cloud Console (T002)"
Task: "Create SignUpScreen in lib/features/account/presentation/sign_up_screen.dart (T010)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1's non-Google-specific parts (T001 only needed if also doing US2/US4 in the same pass — US1 alone doesn't even need `google_sign_in`).
2. Complete Phase 3: User Story 1.
3. **STOP and VALIDATE**: registration works end to end, `flutter analyze`/`flutter test` pass.
4. This is a legitimate, shippable MVP — email/password registration alone closes the biggest gap (no registration UI existed at all).

### Incremental Delivery

1. Setup (T001–T005, Google-specific parts can be deferred if shipping US1 alone first) → Foundational (T006) → US1 (Phase 3) → **MVP**, ship/demo.
2. Add US2 (Phase 4) → Google sign-in works alongside email/password → ship/demo.
3. Add US4 (Phase 5) → Profile Google-linking for non-matching emails → ship/demo.
4. Add US5 (Phase 6) → hardening pass, verify-only in most cases.
5. Polish (Phase 7).

---

## Notes

- [P] tasks touch different files with no dependency on incomplete tasks in the same phase.
- [EXT] tasks are external configuration (Google Cloud Console, Supabase Dashboard, or requiring a macOS/Xcode environment) — not `lib/` code changes, but still required before the corresponding story's acceptance scenarios can pass.
- No mocking library is introduced — tests use hand-written fakes (`_FakeAccountAuthActions` pattern), consistent with the existing test suite.
- Commit after each task or logical group, per repository convention.
