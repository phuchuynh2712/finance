# Implementation Plan: Align Expense Control Screen with Design (Formula Editing, Group Summary, Bottom Nav)

**Branch**: `20260727-lock-formula-dialog-edit` | **Date**: 2026-09-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/20260918-100444-lock-formula-dialog-edit/spec.md`

## Summary

Bring the "Kiểm soát chi tiêu" (Expense Control) screen fully into line with its design mockups. The centerpiece change (User Stories 1-3): the inline formula value/mode display in the item list becomes a non-interactive static label — editing a leaf item's formula moves entirely into its existing edit dialog (which gains formula fields alongside its current name/icon/description fields), staged there as an in-memory pending edit exactly like today's inline-typing mechanism, and only committed to the database by the existing "Lưu công thức" button or a new save option in a tab-switch confirmation prompt that now guards against silently discarding unsaved staged edits. Two smaller, independently-testable visual-parity fixes ride along because they touch the same widgets or were found during the same design review (User Stories 4-5): a group header's allocation-summary line is now shown only while collapsed and never truncated, and three visual mismatches in the shared bottom navigation bar (indicator color, one label wrapping, missing top border) are corrected app-wide.

## Technical Context

**Language/Version**: Dart (SDK `^3.11.0`), Flutter (stable channel matching that SDK constraint)

**Primary Dependencies**: `flutter_riverpod ^2.6.1` (state management — `StateNotifierProvider`/`Provider` already used throughout `expense_control/`), `drift ^2.22.1` (local persistence — `ExpenseControlRepository`'s existing implementation), `lucide_icons` (icon set, already standardized app-wide per the project's icon-consistency work), `go_router` (the app's router, owner of the bottom-navigation `NavigationBar` this feature also touches)

**Storage**: Drift (SQLite) via the existing `ExpenseControlRepositoryImpl` — this feature adds no new tables/columns; it only changes *when* `saveFormulas()` is invoked (still solely from "Lưu công thức" and the new tab-switch "Lưu" choice), never introducing a new write path

**Testing**: `flutter test` — unit tests for controller/provider logic (`test/unit/features/expense_control/`), widget tests for the screen/dialog/row/card widgets (`test/widget/features/expense_control/`), matching this codebase's existing per-feature test layout; a new widget test area is needed for the shared `NavigationBar`'s wiring (`test/widget/core/router/`, following the existing `app_shell_test.dart`)

**Target Platform**: Android + iOS (Flutter mobile app; no web/desktop target per the project's existing scope)

**Project Type**: Mobile app (single Flutter project, feature-first `lib/features/expense_control/` plus a shared `lib/core/router/` change for User Story 5)

**Performance Goals**: No new goal beyond the constitution's standing 60fps/16ms frame budget — this feature only swaps widget types (TextField → Text, DropdownButton → the existing pill-toggle widget) and adds one confirmation dialog; no new lists, no new heavy computation

**Constraints**: Offline-first (unaffected — this feature is purely local UI/state until the existing `saveFormulas()` write path fires, which already goes through the app's established Drift + outbox sync); no new backend/Supabase schema changes

**Scale/Scope**: One screen (`ExpenseControlScreen` and its widget tree: `ExpenseGroupCard`, `ExpenseItemRow`, the shared item-edit dialog) plus one shared widget (`AppShell`'s `NavigationBar` in `lib/core/router/app_router.dart`) — no new screens, no new routes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (Code Quality)**: PASS. No new widget mixes data-fetching/logic/presentation — the dialog's formula fields reuse the existing `ExpenseControlFormController` (already the single place formula validation logic lives, per the codebase's existing separation). `flutter analyze` must stay at zero warnings, matching the project's established baseline.
- **Principle II (Testing Standards)**: PASS, with an explicit obligation. Moving formula editing from inline `onChanged` to the dialog's staged-edit flow changes controller/provider behavior covered by existing unit tests (`expense_control_form_controller_test.dart`) and widget tests (`expense_item_row_test.dart`, `expense_control_screen_test.dart`) — these MUST be updated in the same PR, not left to "add tests later," per this principle. The domain-layer coverage bar (≥80%) applies to `ExpenseControlFormController`'s validation logic, which this feature extends (dialog now runs FR-006's over-budget check) rather than replaces.
- **Principle III (User Experience Consistency, incl. Localization)**: PASS — this is the principle the whole feature exists to satisfy. FR-016/FR-017/FR-018 directly correct violations of "single centralized design system" (wrong indicator color) and touch-target/reachability concerns are unaffected (the static label removal is explicitly a *reduction* in interactive surface, not an addition needing new Semantics). The three new confirmation-prompt button labels ("Lưu"/"Không lưu"/"Hủy," FR-009) MUST ship with both `vi` and `en` ARB entries in the same PR per the Localization subsection — `vi` MUST NOT lag `en`.
- **Principle IV (Performance)**: PASS. No new `ListView`/heavy list — the existing `ReorderableListView.builder` is untouched; the dialog gains two more form fields (bounded, small); one new `AlertDialog`-style confirmation adds negligible cost. No off-UI-isolate work is introduced.
- **Offline-First Data & Sync**: PASS, N/A beyond existing behavior — this feature does not add a new write path to Supabase; it only changes when the *existing* `saveFormulas()` call fires (from "Lưu công thức" or the new tab-switch "Lưu" choice), which already goes through the established outbox/sync pipeline untouched by this feature.
- **Security**: N/A — no new table, no new secret/token handling, no new logging of financial values.

No violations requiring justification — Complexity Tracking table is empty.

## Project Structure

### Documentation (this feature)

```text
specs/20260918-100444-lock-formula-dialog-edit/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command) — UI-contract notes, no network API
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   ├── l10n/
│   │   ├── app_vi.arb                          # + 3 new confirmation-prompt strings (Lưu/Không lưu/Hủy)
│   │   └── app_en.arb                          # + matching English strings, same PR
│   └── router/
│       └── app_router.dart                     # NavigationBar: indicatorColor, top border, label overflow fix (US5)
└── features/
    └── expense_control/
        └── presentation/
            ├── expense_control_screen.dart      # dialog gains formula fields; navigation-confirmation prompt wiring
            ├── expense_control_form_controller.dart  # dialog "Lưu" now stages instead of (or in addition to) committing for leaves
            ├── expense_control_providers.dart   # pendingFormulaEditsProvider: no shape change, new consumer only
            └── widgets/
                ├── expense_group_card.dart       # group-summary collapsed-only visibility + no-truncate wrapping (US4)
                └── expense_item_row.dart         # value/mode become a static label; pill-toggle reused in dialog (US1, FR-013)

test/
├── unit/
│   └── features/expense_control/
│       └── expense_control_form_controller_test.dart   # update: dialog-staging behavior, over-budget block-on-Lưu
├── widget/
│   ├── core/router/
│   │   └── app_shell_test.dart                  # + NavigationBar indicator color / label single-line / top border assertions
│   └── features/expense_control/
│       ├── expense_control_screen_test.dart      # + navigation-confirmation prompt scenarios
│       ├── expense_group_card_test.dart          # + collapsed/expanded summary visibility
│       └── expense_item_row_test.dart            # update: static label (no TextField) assertions
```

**Structure Decision**: Single Flutter mobile app, feature-first layout per the constitution's Recommended Architecture — no new feature directory is created; all changes land inside the existing `features/expense_control/presentation/` and one shared `core/router/` file, matching the constitution's "something belongs in `core/` only if used by two or more features" rule (the `NavigationBar` already qualifies, being shared by every screen).

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

*No violations — table intentionally empty.*
