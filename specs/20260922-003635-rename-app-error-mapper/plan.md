# Implementation Plan: App Rename to "Kiểm Soát" and Centralized Error Messages

**Branch**: `20260922-003635-rename-app-error-mapper` | **Date**: 2026-09-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260922-003635-rename-app-error-mapper/spec.md`

## Summary

Two small, related, user-facing polish fixes bundled into one feature: (1) rename the app's displayed name from "Khai Tâm" to "Kiểm Soát" (vi) / "Budget Control" (en) everywhere it appears — the sign-in screen, one non-user-facing doc-comment, and 13 historical `specs/` documents — without touching the shared icon/logo or platform bundle identifiers; (2) introduce a shared `core/error/error_mapper.dart` pure function that turns a caught exception into a localized, friendly message, and route all 7 existing raw-exception-to-user call sites (plus one previously-silent gap in the expense-control form) through it.

## Technical Context

**Language/Version**: Dart (Flutter SDK, per existing `pubspec.yaml`)

**Primary Dependencies**: `flutter_riverpod` (state management, existing), `supabase_flutter: ^2.8.0` (resolved `gotrue: 2.26.0`, `postgrest: 2.8.0` — exception types this feature classifies), `flutter_localizations` + generated `AppLocalizations` (ARB-based l10n, existing)

**Storage**: N/A — no persisted data introduced by this feature (Error Mapping Result is computed on demand, never stored, per spec.md Key Entities)

**Testing**: `flutter_test` (widget tests, existing fake-repository pattern per `sign_in_screen_test.dart`/`expense_screen_test.dart`), plain Dart unit tests for the mapper function itself

**Target Platform**: Android + iOS (existing Flutter app; this feature makes no platform-specific changes — Android/iOS manifests and bundle identifiers are explicitly untouched per FR-003)

**Project Type**: Mobile app (existing feature-first Flutter project, Clean Architecture layering per Constitution)

**Performance Goals**: N/A — string mapping is a synchronous, in-memory, no-I/O operation; no measurable performance target beyond "does not introduce jank," which a pure switch/type-check function cannot violate

**Constraints**: Must not change the Android `applicationId`/iOS bundle identifier (FR-003); must not change icon/logo artwork or its embedded metadata (FR-002); must not regress the existing correct "email already registered" message (FR-013); must not rename `specs/` file/folder names, only prose content (FR-004)

**Scale/Scope**: 6 source/generated files + 13 historical `specs/` documents for the rename; 1 new file (`core/error/error_mapper.dart`) + up to 2 new ARB-adjacent files (no barrel/index per this project's `core/` convention) + edits to 7 existing call-site files for the error mapper

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (Code Quality)**: PASS. `mapErrorToMessage` is a single-responsibility pure function (one file, one job: exception → message). No business logic moves into a `build()` method — it's called from existing `catch` blocks (already outside `build()`) and existing `ref.listen`/inline-catch sites.
- **Principle II (Testing Standards)**: PASS, with plan — the mapper is pure Dart domain-adjacent logic (no Flutter dependency beyond generated `AppLocalizations`), so it gets direct unit tests (one per FR-007/FR-008/FR-009 category). The 7 call sites already have widget-test coverage patterns (fake repositories throwing specific exception types) that this feature extends, not invents.
- **Principle III (User Experience Consistency, incl. Localization)**: PASS — this feature's entire purpose is strengthening this principle's "error states... MUST follow the same reusable patterns" and localization requirements, which were previously violated by 7 independent, inconsistent, unlocalized-content patterns. New ARB keys ship in both `vi` (primary) and `en` (secondary) in the same PR per the Localization sub-principle.
- **Principle IV (Performance)**: PASS trivially — no list rendering, no async work, no UI-isolate-blocking operation introduced.
- **Recommended Architecture / `core/` placement**: PASS — `core/error/` is explicitly pre-named in the Constitution's own `core/` contents list and Suggested top-level layout (lines 172, 200) as the intended home for "shared `Failure`/`Exception` types, error mapper." This feature is the first to populate an already-scaffolded-but-empty directory, not a deviation requiring justification. The mapper is consumed by 3+ features (account, expenses, expense_control), satisfying the "used by two or more features" bar for `core/` placement.
- **Security**: PASS/N/A — no new secrets, tokens, network calls, or logging introduced. Existing logging-discipline rule (no raw financial data/tokens in logs) is unaffected; the mapper only ever produces a display string, never logs anything.
- **Offline-First Data & Sync**: N/A — this feature does not change sync behavior, the outbox pattern, or conflict resolution; it only changes how an already-occurring failure (including a sync/write failure) is *displayed*.

No violations requiring Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/20260922-003635-rename-app-error-mapper/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── error/
│   │   └── error_mapper.dart          # NEW — mapErrorToMessage(Object, AppLocalizations)
│   ├── l10n/
│   │   ├── app_vi.arb                 # MODIFIED — signInAppName value + new errorMapper* keys
│   │   ├── app_en.arb                 # MODIFIED — signInAppName value + new errorMapper* keys
│   │   ├── app_localizations.dart     # REGENERATED via flutter gen-l10n
│   │   ├── app_localizations_vi.dart  # REGENERATED
│   │   └── app_localizations_en.dart  # REGENERATED
│   └── theme/
│       └── app_theme.dart             # MODIFIED — doc-comment only, no runtime effect
├── features/
│   ├── account/presentation/
│   │   ├── sign_in_screen.dart              # MODIFIED — catch block calls mapErrorToMessage
│   │   ├── sign_up_screen.dart              # MODIFIED — _mapSignUpError fallback branch only
│   │   └── reset_password_screen.dart       # MODIFIED — catch block calls mapErrorToMessage
│   ├── expenses/presentation/
│   │   ├── income_providers.dart            # MODIFIED — IncomeFormController.save() catch
│   │   ├── income_screen.dart               # MODIFIED — ref.listen SnackBar call site
│   │   ├── expense_providers.dart           # MODIFIED — ExpenseFormController + ScanFormController catch
│   │   └── expense_screen.dart              # MODIFIED — 2x ref.listen SnackBar call sites
│   └── expense_control/presentation/
│       ├── expense_control_form_controller.dart  # MODIFIED — catch block calls mapErrorToMessage
│       └── expense_control_screen.dart           # MODIFIED — NEW ref.listen + display (closes FR-012 gap)

test/
├── unit/core/error/
│   └── error_mapper_test.dart          # NEW — one test per recognized category + fallback
├── widget/features/account/
│   ├── sign_in_screen_test.dart        # MODIFIED — existing raw-prefix assertion updated to new friendly text
│   ├── sign_up_screen_test.dart        # MODIFIED — fallback-path assertion updated; duplicate-email assertion unchanged (FR-013)
│   └── reset_password_screen_test.dart # MODIFIED — existing raw-prefix assertion updated
├── widget/features/expenses/
│   ├── income_screen_test.dart         # MODIFIED/EXTENDED — writeFailed path gets a new assertion
│   └── expense_screen_test.dart        # MODIFIED/EXTENDED — writeFailed path (both controllers) gets new assertions
└── unit/features/expense_control/
    └── expense_control_form_controller_test.dart  # EXTENDED — error-path coverage (previously zero)

specs/ (13 historical files — prose-only edits, no renames of filenames/paths)
├── 20260904-030816-theme-icon-splash/{spec.md, plan.md, reference/README.md}
└── 20260904-111850-biometric-login/{spec.md, plan.md, tasks.md, reference/login-signup-spec.md}
```

**Structure Decision**: Follows the existing feature-first + `core/` layering exactly as already established — `core/error/` was already scaffolded (empty) per the Constitution's own suggested layout, this feature is the first to populate it. No new top-level directory, no new package dependency. The mapper is a single flat file (no barrel/index), matching every existing sibling under `core/` (`formatting/`, `network/`, `storage/`, etc., all flat multi-file-or-single-file directories with direct relative imports, never an index re-export).

## Complexity Tracking

*No violations — table omitted.*
