# Implementation Plan: Biometric Login & Sign-Up Refactor

**Branch**: `20260904-111850-biometric-login` | **Date**: 2026-09-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260904-111850-biometric-login/spec.md`

## Summary

Rebuilds the Login and Sign Up screens to match the new "Khai Tâm" design handoff (`reference/login-signup-spec.md`), removes Google Sign-In entirely (it was already flag-gated `false` and never live for real users — research.md §7), and adds device biometric (fingerprint/Face ID) quick login via `local_auth`. The core insight that shapes the whole design: biometric login only has real everyday value if the app actually re-shows the Login screen on a normal reopen — today's app silently auto-resumes a persisted session forever, so this feature adds a re-entry "lock" gate (cold start, and background-resume past a 5-minute threshold, satisfying the constitution's Security section's "app-level lock ... after launch or resume from background" requirement) with biometric as the fast unlock path and password as the always-available fallback. Biometric is strictly a **local convenience layer** on top of the already-persisted Supabase session — it never survives a genuinely dead session (no password or other durable secret is stored on-device for that purpose), and is scoped per-device-per-account so it can't leak across accounts on a shared device. Also adds a real Forgot Password flow (Supabase's built-in email-link recovery, via a new mobile deep link this app doesn't have yet) with automatic, non-optional multi-device session revocation on password reset (global) and password change (other devices only) — closing the gap where the client can't reliably tell *why* a session died by instead making cross-device sign-out something the system triggers on purpose. Technical approach favors extending existing infrastructure over new abstractions: `AuthRepository`/`AccountAuthActions` (existing) gain the reset/scope-aware sign-out methods, a new small `BiometricLoginRepository` wraps `local_auth` the same way `AuthRepository` wraps Supabase, and the existing `computeAuthRedirect` pure function in `app_router.dart` gains two new boolean inputs rather than a parallel gating mechanism. No new Supabase schema (research.md §9: name/phone capture already exists from the prior feature) — only two new on-device `flutter_secure_storage` keys and one new deep-link registration.

## Technical Context

**Language/Version**: Dart (SDK `^3.11.0`), Flutter stable

**Primary Dependencies**: `local_auth: ^3.0.2` (NEW — biometric prompt, research.md §1); `flutter_secure_storage: ^9.2.2` (existing, reused for 2 new keys — research.md §5); `supabase_flutter: ^2.8.0` (existing — `SignOutScope`, `resetPasswordForEmail`, `AuthChangeEvent.passwordRecovery`, all already-available APIs, research.md §2–§3); `go_router: ^14.6.2` (existing, `computeAuthRedirect` extended); `flutter_riverpod: ^2.6.1` (existing DI/state pattern, unchanged); `lucide_icons: ^0.257.0` (existing — new screens use it exclusively, no new icon library). **Removed**: `google_sign_in: ^7.2.0` (research.md §7). **New font assets** (not a package): Lexend TTF files bundled under `assets/fonts/`, declared in `pubspec.yaml`'s `fonts:` block (research.md §8) — chosen over the `google_fonts` package specifically to avoid a runtime font-fetch dependency on an offline-first app.

**Storage**: No new Supabase schema (data-model.md — name/phone/email already modeled by the prior feature's `auth.users` metadata approach). Two new **device-local** `flutter_secure_storage` keys: `BIOMETRIC_ENABLED_<userId>` (per-account biometric preference) and `APP_LAST_BACKGROUNDED_AT` (device-global, background-resume threshold). No new Drift tables — this is non-relational, non-financial device/UI-preference state, explicitly out of the constitution's relational-data mandate.

**Testing**: `flutter_test` for unit + widget tests, continuing the existing hand-written-fake pattern (no mocking library introduced, matching `test/widget/features/account/account_screen_test.dart`'s `_FakeAccountAuthActions` precedent). `BiometricLoginRepository` is faked via its own narrow interface (contracts/auth_repository_interface.md §3) since `local_auth` has no official test double. `computeAuthRedirect`'s new branches are added to the existing `test/unit/core/router/app_router_test.dart` pure-function test file. The `passwordRecovery` deep-link flow and the live fingerprint/Face ID hardware prompt cannot be exercised by `flutter_test` and are covered by `quickstart.md`'s manual walkthrough instead (same precedent as the prior feature's Google-linking flow).

**Target Platform**: Android + iOS (matches existing app scope)

**Project Type**: Mobile app (Flutter, single codebase, feature-first Clean Architecture per constitution)

**Performance Goals**: SC-001 (biometric unlock, cold-open-to-signed-in, <3s) — an interaction-time target, not raw device performance; no new lists/animations, so Principle IV's 60fps/list-virtualization rules aren't newly triggered

**Constraints**: The background-resume timer (research.md §4) must not run on the UI isolate in a way that blocks interaction — `WidgetsBindingObserver` lifecycle callbacks and a single `DateTime` comparison are trivially cheap, no isolate offload needed. The deep-link/password-recovery flow is network-bound and must not block the UI thread — already `Future`-based Supabase SDK calls, same as the prior feature's Google flows. Biometric prompt itself is a native OS UI (not a Flutter-rendered widget), so it cannot jank the Flutter frame budget by construction.

**Scale/Scope**: 2 screens rebuilt (Login, Sign Up), 1 new screen (Set New Password), 1 new small repository (`BiometricLoginRepository`), extensions to 3 existing classes (`AuthRepository`, `AccountAuthActions`/`AccountController`, `computeAuthRedirect`), 1 new Riverpod state provider (`appLockProvider`) plus 1 derived provider (`isPasswordRecoveryProvider`), Google Sign-In fully removed (1 file deleted, ~6 call sites cleaned up per research.md §7), 2 native platform changes (Android `FlutterFragmentActivity` + biometric permission + deep-link intent-filter; iOS `NSFaceIDUsageDescription` + `CFBundleURLTypes`), font asset bundling. No new feature module — everything lives inside the existing `core/auth/`, `core/router/`, and `features/account/`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / Section | Applies? | How this feature satisfies it |
|---|---|---|
| I. Code Quality | Yes | `local_auth` interaction is isolated inside `BiometricLoginRepository` (contracts §3) — no widget touches `package:local_auth` directly, mirroring how `AuthRepository` isolates the Supabase SDK. The background-resume timer logic (a pure `DateTime` comparison) and `computeAuthRedirect`'s new branches are plain functions, not embedded in `build()`. Dead code from the Google removal (research.md §7) and the now-impossible `email_not_confirmed` path (contracts note) is deleted outright, not commented out |
| II. Testing Standards | Yes | `computeAuthRedirect`'s new branches (isLocked, isPasswordRecovery) are pure-function unit tests, extending the existing test file. `BiometricLoginRepository` is faked at its interface boundary for `appLockProvider`/Login-screen widget tests, matching the existing `_FakeAccountAuthActions` convention. Two flows are inherently untestable by `flutter_test` (live biometric hardware prompt; the `passwordRecovery` deep-link cold-start reliability caveat, research.md §3) and are covered by `quickstart.md`'s manual walkthrough instead — consistent with how the prior feature's Google OAuth flow and this project's earlier offline-sync reconciliation were both handled the same way. This feature has no financial-calculation logic, so the 80% domain-coverage gate applies narrowly (redirect logic, biometric-repository fakes, form validation) |
| III. UX Consistency | Yes | Both rebuilt screens consume the app's existing `ColorScheme`/`AppSemanticColors` tokens exclusively (no hardcoded hex — FR-018) and the existing `lucide_icons` library exclusively (FR-017) — no new design-system fork. The re-entry "lock" gate deliberately **reuses** the existing Login screen/route rather than inventing a second near-identical screen (research.md §6), directly following Principle III's "a new screen MUST NOT invent a bespoke pattern where an existing one applies." All new strings (new screens, biometric prompts/toggle, forgot/reset password, Google-string removal) ship in both `app_vi.arb` and `app_en.arb` in the same PR, following the existing `camelCase` + `@key`-metadata-block convention (confirmed via direct file inspection, not assumed) |
| IV. Performance | Yes | No new lists/animations. Background-resume detection and the redirect-gate check are O(1) local comparisons; biometric/password/reset calls are all I/O-bound `Future`s that don't block the UI thread by construction, same pattern as the prior feature's auth calls |
| Recommended Architecture | Yes | `BiometricLoginRepository` and the extended `AuthRepository` live in `core/auth/` (not a new `features/biometric/` module) — auth, including its device-lock gate, is core infrastructure shared by the whole app's routing, not a business domain, matching the prior feature's own stated rationale for the same directory choice. The new "Set New Password" screen lives in `features/account/presentation/`, alongside the existing `sign_in_screen.dart`/`sign_up_screen.dart` it's a sibling of |
| Offline-First Data & Sync | N/A | This feature has no offline-writable financial data of its own; sign-in/sign-up/biometric-unlock/password-reset inherently require connectivity (biometric unlock is the one local-only operation, and it deliberately does NOT attempt any offline "queue this for later" semantics — it either unlocks an already-valid session or falls back to password, per spec). The Lexend font asset decision (research.md §8) is explicitly an offline-first choice (bundled, not fetched) |
| Security | Yes | **This feature directly implements a previously-unmet constitution requirement**: "the app MUST support an app-level lock (biometric/PIN) gating access to financial data after launch or resume from background" — today's app has no such gate at all; FR-020/FR-021 (cold start + 5-minute background threshold, biometric-or-password unlock) closes this gap. `flutter_secure_storage` (already the constitution-mandated choice) is reused for the 2 new device-local keys — no plaintext prefs introduced. **Explicit non-negotiable**: no password or other durable secret is ever written to device storage to make biometric survive a dead session (research.md §5) — the on-device secret-storage surface is unchanged from before this feature (still just the one Supabase session token `SecureLocalStorage` already stores). Logging discipline: biometric prompt reasons/results and password field values must never be logged — no new logging is introduced by this feature's design, and existing screens already avoid logging form values. RLS is unaffected (no new tables). Dependency hygiene: `local_auth` is the official `flutter.dev`-published federated package (research.md §1), actively maintained, reviewed as part of this plan — not a third-party unknown |
| Development Workflow | Yes | Feature branch already created (`20260904-111850-biometric-login`); all new logic ships with tests in the same PR per Principle II above |

**Result**: PASS — no violations requiring Complexity Tracking justification. The one item worth calling out explicitly (not a violation, a scope note): the constitution's app-lock requirement says "biometric/PIN" — this feature implements biometric + password fallback, not a separate numeric PIN entry mode. Password fallback is judged to satisfy the same underlying intent (a short, memorized, always-available credential gating re-entry) at least as strongly as a PIN would, and introducing a third credential type (PIN) alongside password and biometric was not requested by the spec and would add a config surface (PIN set/reset/forgot-PIN flows) with no clear incremental security benefit over the password the app already requires — not pursued here.

**Post-Phase-1 re-check**: Confirmed against the completed `research.md`, `data-model.md`, and `contracts/auth_repository_interface.md`. One design detail surfaced only during Phase 1 and is captured in the Security/UX rows above and the contract itself: the password-recovery deep link creates a real (if recovery-scoped) Supabase session client-side, which would otherwise cause the ordinary signed-in redirect to bypass the "Set New Password" screen — `computeAuthRedirect` gained a third, highest-priority `isPasswordRecovery` branch to close this, not a separate ad hoc screen-level check (keeping the single pure-function redirect source of truth the constitution's Code Quality principle favors). Still PASS, no new violations.

## Project Structure

### Documentation (this feature)

```text
specs/20260904-111850-biometric-login/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md         # Phase 1 output
├── contracts/
│   └── auth_repository_interface.md   # Phase 1 output — Dart interface + router-contract changes, no schema
├── reference/            # Design handoff assets (copied earlier, not generated by /speckit-plan)
└── tasks.md              # Phase 2 output (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── auth/
│   │   ├── auth_repository.dart               # CHANGED — remove signInWithGoogle/linkGoogleAccount/linkedGoogleEmail/_authenticateWithGoogle (research.md §7); signUp() reverts to Future<void> (FR-019, no confirmation branch); signOut() gains {scope} param; changePassword() internally signs out `others`; ADD resetPasswordForEmail(), confirmPasswordReset(), onPasswordRecoveryEvent; REMOVE resendConfirmationEmail (dead, FR-019)
│   │   ├── biometric_login_repository.dart    # NEW — wraps local_auth (contracts §3): isDeviceCapable(), authenticate()
│   │   └── auth_state_provider.dart           # CHANGED — ADD appLockProvider (isLocked, StateNotifier), isPasswordRecoveryProvider (derived from onPasswordRecoveryEvent), biometricLoginRepositoryProvider
│   ├── router/
│   │   └── app_router.dart                    # CHANGED — computeAuthRedirect gains isLocked + isPasswordRecovery params and 2 new branches (contracts §4); new /reset-password route; redirect wiring reads appLockProvider/isPasswordRecoveryProvider alongside existing isSignedInProvider
│   ├── storage/
│   │   └── secure_local_storage.dart          # UNCHANGED — the 2 new keys (data-model.md §1, §3) are separate direct FlutterSecureStorage reads/writes from BiometricLoginRepository / a small new lifecycle-observer helper, not routed through this Supabase-session-specific class
│   └── l10n/
│       ├── app_vi.arb                         # CHANGED — new screens' strings + biometric/reset-password strings ADDED; Google-related keys REMOVED
│       └── app_en.arb                         # CHANGED — same, mirrored
├── features/
│   └── account/
│       └── presentation/
│           ├── sign_in_screen.dart            # CHANGED — full visual rebuild per reference/login-signup-spec.md §1; remove Google button + email_not_confirmed handling; add fingerprint button (per appLockProvider/biometric availability) + "Forgot password?" link; reused as-is for the lock-gate case (no separate screen)
│           ├── sign_up_screen.dart            # CHANGED — full visual rebuild per reference/login-signup-spec.md §2; remove Google button + "check your email" branch (FR-019); email now required (FR-006); reword duplicate-email error text (no more Google fallback mention)
│           ├── sign_up_validation.dart        # CHANGED — email now always required (drop any optional-email branch if one existed for this screen's rules)
│           ├── reset_password_screen.dart     # NEW — "Set New Password" screen, reached only via the router's isPasswordRecovery branch
│           ├── account_controller.dart        # CHANGED — remove isLinkingGoogle/linkGoogleErrorMessage/linkGoogleAccount()/linkedGoogleEmail; ADD isBiometricEnabled state + setBiometricEnabled(bool)
│           ├── account_screen.dart            # CHANGED — remove the entire Google-linking block; ADD a biometric on/off toggle control (FR-010)
│           └── google_sign_in_feature_flag.dart  # DELETE
├── core/theme/                                 # UNCHANGED (prior feature's palette/AppSemanticColors already provide everything these screens need)
└── main.dart                                   # CHANGED — remove _initGoogleSignIn() + call site; add WidgetsBindingObserver registration (or a small dedicated lifecycle-observer class) for the background-resume timer

assets/
└── fonts/                                      # NEW — Lexend-Regular.ttf, -SemiBold.ttf, -Bold.ttf, -ExtraBold.ttf (research.md §8)

android/app/
├── src/main/kotlin/com/finance/finance/MainActivity.kt  # CHANGED — FlutterActivity → FlutterFragmentActivity (research.md §1)
└── src/main/AndroidManifest.xml               # CHANGED — add USE_BIOMETRIC permission + a new intent-filter (custom scheme) for the password-reset deep link (research.md §1, §3)

ios/Runner/
└── Info.plist                                  # CHANGED — add NSFaceIDUsageDescription + CFBundleURLTypes entry (research.md §1, §3)

pubspec.yaml                                    # CHANGED — add local_auth; remove google_sign_in; add fonts: block for Lexend

test/
├── unit/
│   ├── core/router/
│   │   └── app_router_test.dart                # CHANGED — new cases for isLocked/isPasswordRecovery branches
│   └── features/account/presentation/
│       └── sign_up_validation_test.dart        # CHANGED — email-required case, remove any now-invalid optional-email case
└── widget/
    └── features/account/
        ├── sign_in_screen_test.dart            # CHANGED — remove Google/email_not_confirmed cases; add fingerprint-button visibility + tap cases (via a faked BiometricLoginRepository)
        ├── sign_up_screen_test.dart            # CHANGED — remove Google/"check your email" cases; email-required case
        ├── account_screen_test.dart            # CHANGED — remove Google-linking cases; add biometric toggle cases
        └── reset_password_screen_test.dart     # NEW
```

**Structure Decision**: No new feature module — this extends the existing `core/auth/` capability (adding one small sibling repository, `biometric_login_repository.dart`, alongside `auth_repository.dart`) and the existing `features/account/presentation/` module (which already owns every screen this feature touches or adds). Matches the prior auth feature's own precedent for the same reasoning: auth — including its new device-lock gate, which by nature must be reachable from the app-wide router, not scoped to one feature — is core infrastructure, not a business domain. External-only changes (no app code): the Supabase Dashboard's Redirect URLs allow-list entry for the password-reset deep link (already noted as `[EXT]` in research.md §3), alongside the "Enable email confirmations" toggle already flipped off earlier in this session.

## Complexity Tracking

*No violations — table intentionally empty.*
