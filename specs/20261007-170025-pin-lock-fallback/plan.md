# Implementation Plan: App Lock to the Banking Security Standard (Inactivity Lock and PIN Fallback)

**Branch**: `20261007-170025-pin-lock-fallback` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20261007-170025-pin-lock-fallback/spec.md`

## Summary

Two separable changes to how the app locks, both aligned to the reference banking standard (Circular 50/2024/TT-NHNN)
and to constitution v1.8.0:

1. **Inactivity lock (US1, every platform, the web included).** One `AppLockPolicy` (5 minutes, one named constant)
   decides when to lock from the time of the last interaction, replacing the old "5 minutes in the background" rule,
   which never fires in a browser (the observer waits for `paused`, a state only iOS and Android reach). An
   `ActivityTracker` records interactions through the framework's global pointer router and hardware-keyboard handler,
   checks every 10 seconds and on every `resumed`, and, on the web, shares activity, lock and unlock between browser
   tabs over a `BroadcastChannel` behind a `core/` abstraction.
2. **PIN (US2–US6, phones and tablets without usable biometrics).** The existing sign-in screen, which already is the
   lock screen, shows a six-digit PIN entry first; a `PinLockRepository` keeps a salted, iterated hash, a wrong-tries
   count (five, then the PIN is invalidated) and a 365-day expiry in the platform's secure storage; the first PIN is set
   from Bảo mật after confirming the account password; "forgot PIN" is the password sign-in; a one-time offer follows a
   sign-in or sign-up; a PIN that exists keeps working if biometrics are enrolled later. No PIN on the web, no e-mail code, no server involved.

No database, sync, calculation or navigation change. Two new direct dependencies, `crypto` and `web` (both the Dart
team's own and already in `pubspec.lock`), and new strings in `vi` and `en`.

## Technical Context

**Language/Version**: Dart 3.13.4 / Flutter 3.47.5 (`flutter: ">=3.41.0"` in `pubspec.yaml`).

**Primary Dependencies**: existing `flutter_riverpod` 2.6.1, `go_router` 14.8.1, `flutter_secure_storage` 9.x,
`local_auth` 3.x, `supabase_flutter`; **new direct**: `crypto` (PBKDF2's HMAC-SHA256) and `web` (`BroadcastChannel`, web
build only). Reviewed under the constitution's dependency-hygiene rule (research Decisions 4 and 6).

**Storage**: the platform's secure storage (`flutter_secure_storage`: Keychain / Keystore) for three per-account keys
(`PIN_RECORD_`, `PIN_FAILS_`, `PIN_OFFER_SHOWN_` + user id); nothing in Drift, nothing on the server. See `data-model.md`.

**Testing**: `flutter_test` with `fakeAsync` and an injected clock for the tracker; in-memory fakes for secure storage
and the channel; widget tests at a pinned compact (412 × 915) and expanded (1440 × 900) viewport; an adaptive sweep
case for the new screens; real checks on the Android emulator and iOS simulator (PIN path, `notEnrolled`) and in Chrome
with two pages in one context (shared timer), using a profile build with `INACTIVITY_LOCK_SECONDS`. See `quickstart.md`.

**Target Platform**: Android, iOS (PIN and inactivity), Web (inactivity only). Native desktop out of scope.

**Project Type**: Flutter mobile + web app (single codebase; `lib/core`, `lib/features/*`).

**Performance Goals**: unchanged budgets (60 fps, cold start < 2 s). The pointer route and keyboard handler do one
timestamp write per event; the periodic check is one comparison per 10 s; hash + verify is expected under 100 ms
(asserted under 250 ms in a test, real figure recorded from the emulator).

**Constraints**: unlock by PIN under 5 s and offline (SC-002); no PIN, digit or prefix in any log, request or semantic
label (SC-006); the lock must not stop sync (FR-005); a release build can never use a period other than 5 minutes; the
sign-in tests and the rest of the existing suite pass unmodified except the rewritten lifecycle-observer test.

**Scale/Scope**: 6 stories; about 8 new files in `core/auth`, 6 new and 3 changed files in
`features/account/presentation` (the two keypad widgets included), 1 changed file at the app root, 1 pair of ARB files.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 design (below).* Constitution **v1.8.0** (amended 2026-10-07 for
this feature).

| Principle / section | Status | How |
|---------------------|--------|-----|
| I. Code Quality | ✅ | pure `AppLockPolicy`, `pin_rules`, `pin_hasher`; one responsibility per file; doc comments on public API; zero analyzer issues beyond the 2 existing infos; no duplicated lock rule (the old observer rule is replaced, not kept beside the new one) |
| II. Testing Standards | ✅ | unit tests for every pure rule and the verify sequence, `fakeAsync` tests for time, widget tests at compact and expanded viewports for each new screen; the rewritten lifecycle test is called out; no financial calculation is touched |
| III. UX Consistency & Adaptive Design | ✅ | new screens reuse tokens, `AdaptiveBody`, the shared column and `AppTheme`; targets ≥ 48 dp; keyboard support on pointer platforms; light and dark; 130 % text; adaptive sweep cases added |
| IV. Performance | ✅ | O(1) per event, no per-frame work, hash cost measured; no new eager list |
| Recommended Architecture | ✅ | `core/auth` holds the lock policy, tracker and channel (app-wide) and the PIN repository (the core `AuthRepository` must clear it on sign-out; justified in Complexity Tracking); every PIN screen and widget, keypad included, stays in `features/account/presentation`; no business rule in widgets; platform code behind a conditional import |
| Offline-First Data & Sync | ✅ | PIN unlock needs no network; the channel and tracker never touch the network; locking leaves the sync worker running (FR-005) |
| Multi-Platform Support | ✅ | PIN offered by runtime capability (`BiometricAvailability`), not by platform name; web gets the inactivity lock; web-only code behind `core/auth` abstraction; verified on web, Android, iOS |
| Security (v1.8.0) | ✅ | implements (a) inactivity lock everywhere, (b) PIN ≥ 6 digits, never shown, device-only and unreadable, ≤ 10 tries (5), expiry ≤ 12 months, password as the way back, (c) no PIN on web, (d) no platform without a lock; PIN and digits never logged; secure storage for the record |
| Development Workflow | ✅ | the PR description lists the `core/` changes; the observer's web bug is fixed at its root (Decision 2), not patched at a call site |
| Dependency hygiene | ✅ | two direct additions, both Dart-team packages already in the lock file, reviewed (maintenance, license, no permissions) |

**Post-design re-check**: no violation found; nothing added to Complexity Tracking beyond the two reviewed dependencies.

## Project Structure

### Documentation (this feature)

```text
specs/20261007-170025-pin-lock-fallback/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── inactivity-lock.md
│   ├── pin-lock-repository.md
│   └── pin-ui.md
├── checklists/requirements.md
├── spec.md
└── tasks.md                 # /speckit-tasks, not created here
```

### Source Code (repository root)

```text
pubspec.yaml                                           # + crypto, web
lib/
├── main.dart                                          # US1: FinanceApp also watches activityTrackerProvider
├── core/
│   ├── auth/
│   │   ├── app_lock_policy.dart                       # US1 NEW: inactivityPeriod + shouldLock (pure)
│   │   ├── activity_tracker.dart                      # US1 NEW: pointer + key hooks, timer, resume check, provider
│   │   ├── lock_channel.dart                          # US1 NEW: interface + conditional export
│   │   ├── lock_channel_web.dart                      # US1 NEW: BroadcastChannel (package:web)
│   │   ├── lock_channel_stub.dart                     # US1 NEW: no-op for every other platform
│   │   ├── app_lifecycle_observer.dart                # US1 CHANGED: only `resumed` matters; it asks the tracker to check at once
│   │   ├── pin_rules.dart                             # US2 NEW: format, easy PINs, expiry (pure)
│   │   ├── pin_hasher.dart                            # US2 NEW: PBKDF2-HMAC-SHA256 over package:crypto
│   │   ├── pin_lock_repository.dart                   # US2 NEW: secure-storage store + verify sequence
│   │   ├── auth_state_provider.dart                   # CHANGED: providers (tracker, channel, PIN repo, pinAvailable, pinInUse, pinStatus); AppLockNotifier waits for the first real auth event
│   │   └── auth_repository.dart                       # US5 CHANGED: sign-out also clears the PIN record and count
│   └── l10n/app_vi.arb, app_en.arb                    # + pin* strings (+ regenerated app_localizations*.dart)
└── features/account/presentation/
    ├── sign_in_screen.dart                            # US2/US4/US6 CHANGED: PIN mode of the lock screen, forgot-PIN handling, one-time offer call
    ├── widgets/pin_keypad.dart, widgets/pin_dots.dart # US2 NEW (used by the lock screen and the flow, both account-feature screens)
    ├── widgets/password_field.dart                    # US3 EXTRACTED from change_password_screen.dart (shared by it and the PIN flow)
    ├── account_routes.dart (../)                      # US3 CHANGED: `pinFlowRoute`; app_router.dart (core/router) registers `/account/security/pin/:mode`
    ├── pin_entry_panel.dart                           # US2 NEW
    ├── pin_flow_controller.dart                       # US3/US5 NEW: pure state machine (setUp / change / turnOff)
    ├── pin_flow_screen.dart                           # US3/US5 NEW
    ├── pin_offer_prompt.dart                          # US4/US6 NEW: the dialog (US4), the one-time rule (US6)
    ├── security_controller.dart, security_screen.dart # US3/US5 CHANGED: PIN row
    └── (sign_up_screen.dart)                          # US6 CHANGED: also calls maybeShowPinOfferPrompt after sign-up

test/
├── unit/core/auth/{app_lock_policy,activity_tracker,lock_channel_message,pin_rules,pin_hasher,pin_lock_repository,auth_repository_pin_clear,pin_never_logged}_test.dart
├── unit/core/auth/app_lifecycle_observer_test.dart    # REWRITTEN (replaces the shouldRelockOnResume tests)
├── unit/core/auth/app_lock_notifier_test.dart         # NEW: pins the cold-start lock rule (FR-003)
├── unit/features/account/presentation/pin_flow_controller_test.dart
├── widget/features/account/pin_keypad_test.dart
├── widget/features/account/{pin_entry_panel,pin_flow_screen,sign_in_lock_pin,security_pin_row,pin_offer_prompt,sign_in_pin_offer}_test.dart
├── widget/core/adaptive_sweep_pin_test.dart
└── support/{lock_harness,fake_lock_channel}.dart
```

**Structure Decision**: keep the layered-by-feature layout. The inactivity policy, tracker and channel gate the whole app
(the app root, the lifecycle observer and the router's lock), so they live in `core/auth`. The PIN rules, hasher and
repository live there too, next to the biometric repository, only because the core `AuthRepository.signOut` must clear the
PIN and `core/` may not import a feature's internals (see Complexity Tracking). Every screen and widget only the account
feature shows, the keypad included, stays in `features/account/presentation`. No new folder, layer or architectural
pattern.

### Delivery slices

| PR | Stories | Contents | Depends on |
|----|---------|----------|------------|
| 1 | US1 | policy, tracker, channel, observer fix, `main.dart`, the `web` dependency; tests; verification | — |
| 2 | US2–US6 | PIN rules, hasher, repository, widgets, lock-screen PIN mode, flow, Security row, offer, strings, the `crypto` dependency | — (independent of PR 1: it only reads `appLockProvider`, which exists today) |

Two independent pull requests from `origin/master`, each passing format, analyze and the full suite alone (the owner's
squash-merge workflow makes stacks expensive). The inactivity lock is the part of the standard that is missing on every
platform today, so it ships first; the PIN can ship in either order.

## Complexity Tracking

| Item | Why needed | Simpler alternative rejected because |
|------|------------|--------------------------------------|
| Two new direct dependencies (`crypto`, `web`) | PBKDF2's HMAC and the browser's `BroadcastChannel` | writing HMAC by hand is worse than a maintained Dart-team package; a `localStorage` hack for tabs writes on every interaction and cannot carry `lock` / `unlock` |
| A web-only abstraction (`LockChannel`) with a conditional import | shared timer and lock across tabs (owner's choice) | per-tab timers would lock a hidden tab while the person works in another (rejected in Clarifications) |
| Replacing `shouldRelockOnResume` instead of keeping it | one rule measuring one thing | two overlapping rules would need two sets of tests and disagree at the edges |
| `pin_rules`, `pin_hasher`, `pin_lock_repository` in `core/auth/` although only the account feature's screens show PIN UI | the core `AuthRepository.signOut` must clear the PIN, as it clears the biometric preference, and `core/` may not import a feature's internals | placing them in `features/account` would force `core/auth/auth_repository.dart` to import feature code, which the constitution forbids |
