# Implementation Plan: Profile Screen with Theme and Language Settings

**Branch**: `20260921-130340-profile-settings` | **Date**: 2026-09-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20260921-130340-profile-settings/spec.md`

## Summary

Redesign the existing, sparse Profile screen (`lib/features/account/presentation/account_screen.dart`) to match the reference mockup: an Appearance (Light/Dark) toggle and a Language (Tiếng Việt/English) selector, both applied instantly app-wide and persisted across restarts via a new device-level key-value store; plus account identity display (name/email/avatar), three menu rows to placeholder destinations, and sign-out. The current avatar-URL entry, password-change flow, and biometric toggle are removed entirely (spec.md Clarifications). Technical approach: two Riverpod `StateNotifier`s (`ThemeModeNotifier`, `LocaleNotifier`) backed by a new `AppPreferencesStorage` interface wrapping `shared_preferences`, loaded before `runApp()` to avoid a launch-time appearance/language flash, and wired into `FinanceApp`'s existing `MaterialApp.router` call.

## Technical Context

**Language/Version**: Dart (SDK `^3.11.0`), Flutter (stable channel, per existing project)

**Primary Dependencies**: `flutter_riverpod` (state management, existing), `shared_preferences` (new — device-level key-value preference storage), `lucide_icons` (existing, icon set), `supabase_flutter` (existing, auth identity read)

**Storage**: `shared_preferences` for the two new device-level preferences (Appearance, Language) — explicitly NOT Drift/SQLite (not relational, not financial data, not synced — Constitution's Offline-First section permits a key-value store for exactly this case)

**Testing**: `flutter_test` (unit + widget), matching existing project convention (`test/unit/`, `test/widget/`)

**Target Platform**: Android + iOS (existing app targets; this feature adds no new platform surface)

**Project Type**: Mobile app (Flutter, single codebase, existing feature-first + Clean Architecture layering per Constitution)

**Performance Goals**: Appearance/Language switch reflected across the whole app in <1s with zero extra navigation (spec.md SC-001/SC-002) — in practice this is a single Riverpod state update propagating through `ref.watch` in `main.dart`, well under budget; no new list rendering or animation surfaces are introduced by this feature.

**Constraints**: No launch-time visual flash of default appearance/language before the persisted value is applied (research.md Decision 2); preferences MUST survive app restart (spec.md SC-003) and MUST NOT be tied to a signed-in account (FR-013).

**Scale/Scope**: One redesigned screen, two new provider/notifier pairs, one new storage wrapper, two new `AuthRepository` getters, deletion of three now-unused `AccountController`/`AccountAuthActions` members. No new route is added (`/account` already exists and is reused).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design below.*

- **I. Code Quality**: PASS. Business logic (preference read/write, fallback-to-default) lives in `AppPreferencesStorage`/`ThemeModeNotifier`/`LocaleNotifier` — plain, framework-independent-where-possible Dart classes — not inside `build()`. The screen widget only renders state and dispatches actions. Old ad hoc fields are deleted outright, not commented out or left as dead code (research.md Decision 7 explicitly maps the deletion's blast radius before implementation).
- **II. Testing Standards**: PASS (planned). Unit tests for both notifiers (initial-from-storage, write-through, fallback-on-error) and the storage wrapper's fake; widget tests for the redesigned screen covering every FR; one integration test for cross-restart persistence (research.md Decision 8, quickstart.md). No financial calculation logic is touched by this feature, so the 80% domain-coverage bar applies to a small, fully-covered surface.
- **III. User Experience Consistency**: PASS. Reuses the existing design-token system (`AppColors`/`AppSemanticColors`), the existing dialog pattern (`showDialog`/`SimpleDialog` — research.md Decision 5) rather than inventing a bottom sheet, and the existing `NotAvailablePlaceholderScreen` for the three unimplemented menu destinations rather than three new placeholder widgets. Localization: this feature is what finally lets `en` be reached at runtime (previously present in ARB files but unreachable — spec.md context); Vietnamese remains the default per FR-008, satisfying "Vietnamese MUST be the default locale." "A locale switch MUST be reflected immediately across the whole app without requiring a restart" is satisfied by FR-006/the notifier design; the launch-time flash risk this same sentence implies is explicitly addressed in research.md Decision 2. Touch targets and contrast follow the existing token system's already-verified values (no new colors introduced).
- **IV. Performance Requirements**: PASS. No lists, no heavy computation; the only new I/O is two small `shared_preferences` reads at startup (off the synchronous build path — awaited in `main()` before `runApp()`, not blocking any UI thread frame) and writes on user action (fire against local sandboxed storage, not network). Cold-start budget impact is negligible (a `shared_preferences` read is typically sub-millisecond to a few ms).
- **Offline-First Data & Sync**: PASS. Appearance/Language preferences are explicitly NOT financial data and are explicitly NOT synced (spec.md Assumptions, FR-013) — they fall under the Constitution's named exception for a key-value store rather than Drift/outbox/Supabase Realtime. No `sync_outbox` entry, no server-authoritative reconciliation applies here.
- **Security**: PASS. No new secrets, tokens, or financial data are introduced or logged. `shared_preferences` storing a theme/language choice is correctly NOT treated as sensitive data requiring secure storage (research.md Decision 1's explicit rejection of `flutter_secure_storage` for this use case). No new Supabase table is added, so no new RLS surface.

No violations requiring Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/20260921-130340-profile-settings/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── profile_ui_state.md
├── reference/            # Preserved design handoff (README.md, ho-so-spec.md,
│                          # icons.json, theme-tokens.json, screen-light.png,
│                          # screen-dark.png) — copied from
│                          # E:\Study\design\ho-so-package per the original request
└── tasks.md              # Phase 2 output (/speckit-tasks — not created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── storage/
│   │   └── app_preferences_storage.dart   # NEW — interface + SharedPreferences impl
│   ├── theme/
│   │   ├── app_theme.dart                 # unchanged
│   │   └── theme_mode_notifier.dart       # NEW — ThemeModeNotifier + themeModeProvider
│   ├── l10n/
│   │   ├── app_localizations.dart         # unchanged (generated)
│   │   └── locale_notifier.dart           # NEW — LocaleNotifier + localeProvider
│   └── auth/
│       └── auth_repository.dart           # MODIFIED — add currentDisplayName/currentEmail
│                                           #   getters; remove updateAvatar/changePassword
│                                           #   from AccountAuthActions interface
├── features/
│   └── account/
│       └── presentation/
│           ├── account_screen.dart        # REWRITTEN — matches reference mockup
│           └── account_controller.dart    # MODIFIED — drop avatar/password/biometric
│                                           #   fields+methods, keep signOut
└── main.dart                               # MODIFIED — load prefs before runApp(),
                                             #   wire themeModeProvider/localeProvider
                                             #   into MaterialApp.router

test/
├── unit/
│   └── core/
│       ├── storage/
│       │   └── app_preferences_storage_test.dart   # NEW (fake-backed)
│       ├── theme/
│       │   └── theme_mode_notifier_test.dart        # NEW
│       └── l10n/
│           └── locale_notifier_test.dart             # NEW
├── widget/
│   ├── features/account/
│   │   └── account_screen_test.dart        # REWRITTEN — tests new UI, not old
│   └── core/router/
│       ├── app_shell_nav_bar_test.dart              # MODIFIED — trim removed-from-
│       ├── app_shell_discard_prompt_test.dart        #   interface fake stubs
│       └── overview_placeholder_test.dart            #   (research.md Decision 7)
└── integration/
    └── profile_preferences_persistence_test.dart     # NEW
```

**Structure Decision**: Single Flutter project, existing feature-first + Clean Architecture layering (Constitution's Recommended Architecture). No new feature directory is created — Profile already exists as `features/account/`; this plan modifies it in place plus adds cross-cutting infrastructure to `core/storage/`, `core/theme/`, and `core/l10n/` since the new preferences are consumed app-wide (`main.dart`), not just by the Account feature, per the Constitution's "`core/` only if used by two or more features" rule (every screen is a consumer via the app-wide `MaterialApp`).

## Complexity Tracking

*No Constitution Check violations — table intentionally empty.*
