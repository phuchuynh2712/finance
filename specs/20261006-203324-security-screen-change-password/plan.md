# Implementation Plan: Security Screen, Change Password, and Platform Config Normalization

**Branch**: `20261006-203324-security-screen-change-password` | **Date**: 2026-10-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from
`specs/20261006-203324-security-screen-change-password/spec.md`

## Summary

Four independent slices, one feature:

1. **US1 (P1, MVP)** — the Bảo mật row opens a real Security screen
   (`/account/security`) with a **change-password** sub-screen
   (`/account/security/change-password`). First this device's own session is
   confirmed by a refresh (a revoked session stops the change before anything
   happens); the current password is verified on a *temporary session over plain
   REST* (no second client, so no effect on the app's session, router, lock or
   sync, and nothing leaks over the web `BroadcastChannel`); the new password is
   set on that fresh session (which also satisfies Supabase's "secure password
   change" recency rule), and the server then revokes every other session of the
   account; the temporary session is handed to the app so this device stays
   signed in. If a later step fails the Security screen shows a notice with a
   one-tap retry (research Decisions 1–3, 6).
2. **US2 (P2)** — a **biometric switch** on the Security screen showing the real
   stored preference with an explicit availability model (web / no hardware /
   not enrolled), a confirming biometric check when turning on, an immediate
   off, and re-evaluation on resume (Decision 8).
3. **US3 (P2)** — **minimum 8 characters** everywhere a password is set via one
   pure `PasswordPolicy`; sign-up changes, the email reset gains the missing
   client check, sign-in is untouched; the server-side minimum is an external
   owner action verified by a request (Decisions 4–5).
4. **US4 (P3)** — **one documented, stable configuration**: the six tracked
   iOS/Android files committed in the toolchain's canonical form (including
   the iOS deployment target 13.0 → 15.0 the toolchain forces), web verified
   clean, a rewritten README setup, a complete example env file and a unit test
   tying `AppEnvironment.keys`, the example file and the README together
   (Decisions 10–11).

No new package in the dependency graph (`http`, already pulled in by
`supabase`/`gotrue`, becomes a direct dependency at the same locked version), no
schema change, no stored-data change.

## Technical Context

**Language/Version**: Dart 3.13.4 / Flutter 3.47.5 stable (verified baseline);
SDK floor `^3.11.0` (Flutter ≥ 3.41); a `flutter: ">=3.41.0"` floor is added to
`pubspec.yaml` so the documented minimum is enforced.

**Primary Dependencies**: existing only — `supabase_flutter 2.16.0` (`gotrue
2.26.0`, `supabase 2.14.0`), `http 1.6.0` (already transitive; now direct, used
for the temporary password-change session), `local_auth` (via `BiometricLoginRepository`),
`flutter_secure_storage` (existing biometric preference), `flutter_riverpod
2.6.1`, `go_router 14.8.1`, `lucide_flutter` through `app_icons.dart`.

**Storage**: none new. The per-account per-device biometric preference
(`BIOMETRIC_ENABLED_<userId>` in secure storage) is read and written exactly as
today. Passwords are never stored.

**Testing**: `flutter test` — unit (policy, service sequence with fakes,
availability mapping, env-keys consistency), widget (Security and
change-password screens at compact and expanded widths, sign-up/reset
updates), routing; plus the existing suite, analyzer, format check, and the
manual cross-device/cross-platform scenarios in `quickstart.md`.

**Target Platform**: Android, iOS, Web — all three verified (web in Chrome,
Android emulator, iOS Simulator), light and dark, compact and wide. Biometrics
are unavailable on web by design (switch disabled with a reason).

**Project Type**: Flutter mobile + web app (single project, feature-first
layout under `lib/features/account/`).

**Performance Goals**: no new budget: about five short requests per change (this
device's session refresh, the temporary sign-in, the update, the hand-over
refresh, ending any other session); measured end to end at 1–2 s on web and iOS, all off the UI isolate by
the SDK; the screens are static forms. SC-001 (under 60 s for the person) is
interaction time, not latency.

**Constraints**: the only navigation change is the two new routes (existing
sign-in, lock and redirect behavior untouched); passwords are never logged or
retained (FR-011); all text vi + en; no hand-drawn icons;
sign-in behavior unchanged; the iOS deployment target change is the one
deliberate platform-level change (accepted by the owner on 2026-10-06).

**Scale/Scope**: 2 new screens, 2 routes, 1 pure domain class, 1 service,
2 small gateway interfaces (+ `AuthRepository` implementation), 1 controller
per screen plus a small other-devices notice controller, generalized shared menu
widgets, ≈ 27 new l10n keys, README rewrite,
6 platform files, 1 `pubspec.yaml` line, and test updates for 8-character
rules.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

- **I. Code Quality — PASS.** Business logic (policy, sequence, outcome mapping,
  availability) lives in pure/testable classes (`PasswordPolicy`,
  `ChangePasswordService`, controllers); widgets only render. The private menu
  widgets are extracted and reused instead of duplicated. No dead code; the now
  unused `AccountPlaceholderFeature.security` is removed.
- **II. Testing Standards — PASS.** Unit tests for all logic, widget tests for
  both screens **at compact (<600 dp) and expanded (≥840 dp)**, light and dark,
  as the constitution requires for breakpoint-dependent layouts, route tests,
  updated sign-up/reset tests, and an executable env-keys consistency test
  (SC-008). The new `AuthRepository` gateway code (temporary REST session and its hand-over, session
  check, the swallowed-401 guard) is unit-tested with `MockClient` and fakes — `AuthRepository` had no unit tests before, so this also
  starts covering it — instead of being left to manual checks.
- **III. UX Consistency & Adaptive Design — PASS.** Existing tokens, `AdaptiveBody`,
  shared menu card/row, light/dark, ≥48 dp targets, keyboard/hover/tooltips,
  semantics, both languages; icons from the maintained package only. No
  mockup exists, so the screen follows the Hồ sơ patterns (recorded in spec
  Assumptions).
- **IV. Performance — PASS.** Three short requests per change; static screens; no
  lists, no polling.
- **Recommended Architecture — PASS.** Feature-first: `domain/` pure Dart (policy),
  `application/` (service), `presentation/` (screens, controllers); the Supabase
  SDK and the temporary REST session sit behind `PasswordChangeGateway` in
  `core/auth/` (third-party wrapper behind an abstraction), injected through
  Riverpod; no feature imports another feature's internals.
- **Offline-First Data & Sync — PASS (explicitly N/A for writes).** Changing a
  password is an online-only account operation, not a Drift write: no outbox
  row, no local balance; the spec states the offline behavior (clear message,
  nothing changed). No synced data changes.
- **Multi-Platform Support — PASS, with one inherited gap.** Verified on web,
  Android and iOS; biometric capability is detected at runtime and disabled
  with a reason on web. The constitution's *PIN fallback for the app-level
  lock where biometrics are unavailable* is a **pre-existing gap**, not
  introduced or worsened here (spec Assumptions/Out of Scope).
- **Security — PASS.** Current-password verification before any change; other
  sessions ended; passwords never logged, stored or retained; no new
  dependency (hygiene unaffected); the server-side minimum is raised as defense
  in depth; error messages never echo secrets; RLS untouched.
- **Development Workflow — PASS (procedural).** Feature branch; analyze, format and
  the full suite run; PR call-outs required for shared `core/` changes:
  `AuthRepository` gains `PasswordChangeGateway`, `BiometricLoginRepository`
  gains `availability()`, `SignUpValidation` delegates to `PasswordPolicy`,
  shared error mapper extended, sign-up/reset behavior changes (8 characters),
  **iOS deployment target 13.0 → 15.0**, new `AppEnvironment.keys`, pubspec
  `flutter` floor, and the external Supabase dashboard setting.

**Post-design re-check**: PASS. Phase 1 added no package, entity or stored
field; the only cross-cutting items are the call-outs above. The Development
Workflow rule on shared-code bugs is addressed in Complexity Tracking (the
known cold-start lock race).

## Project Structure

### Documentation (this feature)

```text
specs/20261006-203324-security-screen-change-password/
├── plan.md                              # This file
├── research.md                          # Phase 0: 13 decisions with measured evidence
├── data-model.md                        # Phase 1: policy, form state machine, outcomes, availability
├── quickstart.md                        # Phase 1: 7 verification scenarios
├── contracts/
│   ├── security-screens-ui.md           # routes, elements, states, a11y, test keys
│   ├── password-change-gateway.md       # interfaces, service sequence, error mapping
│   ├── l10n-keys.md                     # new/changed vi + en strings
│   └── platform-config.md               # canonical platform files, idempotence check, README contract
├── checklists/requirements.md           # Spec quality checklist
└── tasks.md                             # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
lib/core/auth/
├── password_change_gateway.dart              # NEW: PasswordChangeGateway (3 methods) + VerifiedPasswordSession (set / hand over / close)
├── temporary_password_session.dart           # NEW: SupabaseAuthRest (3 plain HTTP calls) + TemporaryPasswordSession
├── auth_repository.dart                      # MODIFIED: implements the gateway (timed session check, REST temporary session, guarded endOtherSessions)
└── biometric_login_repository.dart           # MODIFIED: BiometricAvailability + availability()

lib/core/config/app_environment.dart          # MODIFIED: + `keys` list
lib/core/error/error_mapper.dart              # MODIFIED: same_password, over_request_rate_limit, session errors
lib/core/l10n/app_vi.arb, app_en.arb          # MODIFIED: changed + ~25 new keys (see contracts/l10n-keys.md)

lib/features/account/
├── domain/password_policy.dart               # NEW: pure Dart, minLength = 8
├── application/change_password_service.dart  # NEW: sequence, ChangePasswordResult, signOutOtherDevices() retry (returns a result)
├── account_routes.dart                       # MODIFIED: security routes; enum loses `security`
├── presentation/
│   ├── security_screen.dart                  # NEW
│   ├── security_controller.dart              # NEW: availability + preference + toggle
│   ├── change_password_screen.dart           # NEW
│   ├── change_password_controller.dart       # NEW: form state, validation order, single-flight
│   ├── other_devices_notice_controller.dart  # NEW: notice state + one-tap retry on the Security screen
│   ├── widgets/account_menu.dart             # NEW: AccountMenuCard(children) / AccountMenuRow(trailing, caption) generalized from account_screen.dart's private _MenuCard/_MenuRow
│   ├── account_screen.dart                   # MODIFIED: Bảo mật row → /account/security; uses extracted widgets
│   ├── sign_up_validation.dart               # MODIFIED: delegates to PasswordPolicy
│   ├── sign_up_screen.dart                   # MODIFIED: 8 characters + hint
│   └── reset_password_screen.dart            # MODIFIED: adds the length check + hint

lib/core/router/app_router.dart               # MODIFIED: nested /security and /security/change-password under /account

README.md                                     # MODIFIED: one documented setup (Decision 11)
tool/env.example.json                         # CHECKED: keys already match; no change expected
.env.example                                  # MODIFIED: the dotenv copy was missing WEB_PASSWORD_RESET_REDIRECT_URL (found in the README dry run); completed and covered by the keys test
pubspec.yaml                                  # MODIFIED: + `flutter: ">=3.41.0"` in environment

ios/Flutter/Debug.xcconfig, Release.xcconfig                      # MODIFIED: canonical (Pods include)
ios/Runner.xcodeproj/project.pbxproj                              # MODIFIED: canonical (Pods/SwiftPM, deployment target 15.0)
ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme       # MODIFIED: canonical (pre-action)
ios/Runner.xcworkspace/contents.xcworkspacedata                   # MODIFIED: canonical (Pods project ref)
android/gradle.properties                                         # MODIFIED: canonical (two migrator flags)

test/unit/features/account/domain/password_policy_test.dart           # NEW
test/unit/features/account/application/change_password_service_test.dart   # NEW
test/unit/features/account/presentation/change_password_controller_test.dart  # NEW
test/unit/features/account/presentation/other_devices_notice_controller_test.dart  # NEW
test/unit/core/auth/auth_repository_password_change_test.dart         # NEW (fake SupabaseClient/GoTrueClient via the injectable factory)
test/unit/features/account/presentation/security_controller_test.dart # NEW (availability + preference + toggle, fakes)
test/unit/core/auth/biometric_availability_test.dart                  # NEW (fake LocalAuthentication)
test/unit/core/config/app_environment_keys_test.dart                  # NEW: example file == keys == README table
test/unit/core/l10n/l10n_key_parity_test.dart                         # NEW (if none exists): vi keys == en keys
test/unit/features/account/presentation/sign_up_validation_test.dart  # MODIFIED: 8-character cases
test/widget/features/account/security_screen_test.dart                # NEW: states, compact + expanded
test/widget/features/account/change_password_screen_test.dart         # NEW: validation, single-flight, outcomes, compact + expanded
test/widget/features/account/account_screen_test.dart                 # MODIFIED: Bảo mật no longer a placeholder
test/widget/features/account/sign_up_screen_test.dart, reset_password_screen_test.dart  # MODIFIED: 8 characters
```

**Structure Decision**: no new feature directory; the work extends
`features/account` with the layers the constitution prescribes and one thin
shared seam in `core/auth`. The platform configuration files are changed in
place (US4) and can be delivered as their own pull request, independent of the
product slices.

## Phase 0: Research Summary

See [research.md](./research.md) — 13 decisions: the temporary-session
sequence and why, incl. what the real service does (1); partial-failure semantics (2); a separate
`PasswordChangeGateway` that leaves four existing test fakes untouched (3); one
`PasswordPolicy` and where today's rules actually live (4); the external Supabase
minimum and how to verify it (5); error mapping (6); routes (7); biometric
availability and honest switch state (8); screen design without a mockup (9);
the measured canonical platform files, including the forced iOS deployment target
(10); documentation and the executable env-keys test (11); test strategy (12);
verification scope (13).

## Phase 1: Design Summary

- [data-model.md](./data-model.md): `PasswordPolicy`, the change-password form
  state machine and validation order, the outcome table, `BiometricAvailability`
  and the switch truth table, session lifecycle.
- [contracts/](./contracts/): UI and routes, the gateway/service sequence with
  its error table, localization keys, and the platform-config contract with an
  idempotence check.
- [quickstart.md](./quickstart.md): seven scenarios from unit tests to a
  two-device session check, a biometric matrix, and a clean-clone config check.

## Suggested Implementation Order (input for `/speckit-tasks`)

1. **Foundational**: `PasswordPolicy` + l10n keys; extend the shared error
   mapper; `PasswordChangeGateway` interfaces and the `AuthRepository`
   implementation with its unit test; generalize `account_menu.dart`. (Routes and
   the removal of the `security` placeholder come with US1.)
2. **US1 (MVP)**: `ChangePasswordService` (tests first), controller, the two
   screens, wiring from Hồ sơ.
3. **US3**: apply the 8-character rule to sign-up and reset (+ hint, tests).
   `[EXT]` owner raises the Supabase minimum; verify with the request.
4. **US2**: `BiometricAvailability`, `SecurityController`, the switch,
   resume handling.
5. **US4** (can be its own PR, even first, since it removes build churn):
   commit canonical platform files, README rewrite, pubspec floor, env-keys
   test, clean-clone idempotence run.
6. **Final pass**: full suite, analyzer, format, quickstart Scenarios 1–7 on web,
   Android and iOS.

## Complexity Tracking

No constitution violations. Items a reviewer should look at:

- **The temporary REST session and its hand-over** (Decision 1) — more moving
  parts than a plain `updateUser`, justified by two facts measured on the real
  service: the server revokes every other session when a password is updated
  (so the updating session must become this device's session), and a second
  gotrue client is not isolated on web. It is unit-tested with `MockClient` and
  was verified end to end on web, Android and iOS.
- **The iOS deployment-target change** (Decision 10) — forced by the toolchain and
  accepted by the owner on 2026-10-06.
- **Inherited PIN-fallback gap** — the constitution requires a PIN where
  biometrics are unavailable; the app has none on web today. Pre-existing, not
  introduced or worsened here; documented rather than hidden.
- **Known shared-code bug left unfixed: the cold-start lock race** (Development
  Workflow: a real bug in shared code is fixed at its root unless that is
  infeasible in the current feature, in which case the root cause, why it is
  deferred and a pointer MUST be recorded). *Root cause*: `AppLockNotifier`
  (`lib/core/auth/auth_state_provider.dart`) only locks when
  `authStateChangesProvider` already holds data at the moment the notifier is
  first built; its `fireImmediately` callback sets `_initialCheckDone` even while
  the stream is still loading, so a cold start with a stored session sometimes
  skips the lock. *Why deferred*: it was recorded as unconfirmed (one observed
  relaunch, no reproduction yet); the fix changes the cold-start gate shared by
  every sign-in path, the router redirect and the lock screen, so it needs its
  own reproduction, tests and verification on all three platforms; this feature
  neither changes the lock nor relies on its cold-start behavior (the biometric
  switch only edits the stored preference the lock screen reads, verified with
  background/resume locking). *Pointer*: `specs/20261005-211030-fix-lucide-icons-compat/research.md`
  Observations ("Cold-start lock looks racy"). Keeping this PR small is not the
  reason. Recommended next step: a dedicated spec.
