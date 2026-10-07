# Implementation Plan: Adaptive Web Layout for the Remaining Screens

**Branch**: `20261007-100751-adaptive-web-remaining-screens` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20261007-100751-adaptive-web-remaining-screens/spec.md`

## Summary

Make every screen that still lays out as a stretched phone screen adaptive on wide windows, one page at a time, in the
clarified order: **Chi tiêu → Thu nhập → Thu chi → Kế hoạch → Hồ sơ → placeholders → final sweep**. Every page becomes one
bounded, centered column (no grids, no list-detail), with label-beside-value rows, and below 600 dp it stays exactly as
it is.

The technical approach, from [research.md](research.md):

1. **One shared bounding primitive** (`adaptiveGutterFor` + `AdaptiveGutters`) that gives scroll views a horizontal
   inset instead of wrapping them, so the scroll view spans the window (the mouse wheel works over the margins — it does
   not on today's finished screens), the widget tree keeps one shape across breakpoints (no remount, state survives a
   resize), and compact is identical by construction (the inset equals today's 18 dp padding).
2. **Chi tiêu** (the real defect: pad keys 435 × 198 px, bottom row and account chooser below the fold, amount scrolls out
   of sight): a 520 dp panel from 600 dp, key height `clamp(48 + (h − 640) / 8, 48, 64)`, amount and Save pinned, a
   wrapping chooser bounded to two rows, with a written vertical budget that fits 640 dp; a physical-keyboard layer
   (digits, Backspace, Enter-to-save) that calls the same controller methods as the pad.
3. **Thu nhập, Thu chi, Kế hoạch, Hồ sơ**: gutters (520 dp for Thu nhập, shared 960 dp for the others, matching Bảo mật);
   Kế hoạch moves each item's allocation box next to its name with a bounded width; one shared dialog constraint
   (≤ 560 dp) for every pop-up; destructive pop-ups default to Cancel.
4. **Placeholders**: `AdaptiveBody` around the existing empty state.
5. **Final sweep**: an automated width × appearance matrix test over every screen (plus 500 dp-high and 130 %-text cases), a recorded browser pass, and a
   compact regression on Android and iOS; every defect found is fixed in this feature, starting with the wheel dead zone
   on the finished screens that wrap their scroll view in `AdaptiveBody`.

No data, schema, calculation or navigation change, and exactly one new string (the number pad's delete key label and tooltip, in `vi` and `en`).

## Technical Context

**Language/Version**: Dart 3.13.4 / Flutter 3.47.5 (`flutter: ">=3.41.0"` in `pubspec.yaml`)

**Primary Dependencies**: existing only — `flutter_riverpod` 2.6.1, `go_router` 14.8.1, `lucide_flutter` (through
`core/theme/app_icons.dart`), `intl`. **No new package** (constitution Principle III forbids responsive-layout
packages without a maintenance review, and none is needed).

**Storage**: N/A — nothing is stored or migrated. Existing form state stays in its Riverpod notifiers and widget `State`
(see `data-model.md` §2).

**Testing**: `flutter_test` widget tests at a pinned compact (412 × 915) and expanded (1440 × 900) viewport per changed
screen plus the extra sizes in the contracts; pure-Dart unit tests for `adaptiveGutterFor`, `ExpenseEntryLayout` and the
key mapping; an automated sweep matrix; real-browser verification with throwaway Playwright scripts (Chrome, light and
dark); Android emulator (Pixel_10) and iOS simulator (iPhone 17) for compact regression. The existing tests of every
changed screen must pass **unmodified**; the exceptions, both listed in tasks.md ("Compact-unchanged rule"), are a
viewport-only change to `expense_screen_test.dart`'s 800 × 1400 surface helper if (and only if) the wide layout makes it
fail, and, in the final sweep, four assertions that encode `AdaptiveBody`'s old structure (the width tests of Tổng quan and Báo cáo, the
empty and the error state of Lịch sử giao dịch) and are re-pointed with the same intent in the same pull request.

**Target Platform**: Web (the subject of this feature), with Android and iOS verified unchanged at compact. Native
desktop stays out of scope.

**Project Type**: Flutter mobile + web app (single codebase; `lib/core`, `lib/features/*`).

**Performance Goals**: unchanged budgets (60 fps, cold start < 2 s). The keyboard handler is O(1) per key; no list
becomes eager; Kế hoạch keeps its existing shrink-wrapped reorderable list.

**Constraints**: below 600 dp every screen is pixel-for-pixel today's layout (FR-002); Chi tiêu shows amount, 12 keys,
chooser (two rows of chips, at least eight accounts with names of up to nine characters) and Save with no scrolling from 600 × 640 dp (FR-005); keys ≤ 64 dp (spec cap 72); touch targets
≥ 48 dp everywhere; pop-ups ≤ 560 dp; resize never loses typed values or selections (FR-004); every new string (one: the delete key's tooltip and label), and any other,
in `vi` and `en`.

**Scale/Scope**: 7 stories: the screens the spec names (Chi tiêu with its scan tab, Thu nhập, Thu chi, Kế hoạch with
its pop-ups, Hồ sơ with its pop-up, and the three placeholder entry points that share one widget), plus shared
theme/layout code, and a sweep over the 18-row inventory in `data-model.md` §3.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 design (below).*

Constitution v1.7.0.

| Principle / rule | Status | How the plan meets it |
|------------------|--------|-----------------------|
| **I. Code Quality**: analyze clean; logic out of `build()`; no dead code | PASS | Layout numbers and the key mapping are pure classes (`ExpenseEntryLayout`, `adaptiveGutterFor`, `expenseKeyActionFor`) with unit tests; widgets only read them. Extracting `_FormulaLabel` lets the group card reuse it instead of copying it. `flutter analyze` and `dart format` gate every PR. |
| **II. Testing**: pinned default viewport; compact **and** expanded coverage for breakpoint-dependent screens; tests ship with the change | PASS | Each story lists its tests (quickstart §1); every changed screen gets a compact (412) and expanded (1440) case; the existing screen tests run unmodified as the compact-unchanged proof; the sweep adds a standing matrix. |
| **III. UX & Adaptive**: layout from window size class, never platform; single breakpoint scale; content capped and centered; ≥ 48 dp targets; hover, tooltips, keyboard on pointer platforms; light/dark; localization | PASS | Everything keys off `windowSizeClassFor`/`MediaQuery.sizeOf` (no `Platform`, no `kIsWeb`); new tokens live in `core/theme/app_layout.dart`; 520 dp entry width and 960 dp shared width are tokens; Chi tiêu gets full keyboard operation, hover/focus audit covers rows and menu items; light and dark in the browser pass; one new string (the delete key's tooltip and screen-reader label, which the number pad lacks today) ships in both ARBs, and the reorder handle's tooltip reuses an existing string. |
| **IV. Performance** | PASS | No extra rebuild scope: `AdaptiveGutters` rebuilds only its builder on size changes; no eager lists introduced. |
| **Multi-Platform: Web is fully supported; state Web verification** | PASS | Web is the verified target: real-browser matrix (quickstart §2, `contracts/final-sweep.md`) at 1440 × 900, 1366 × 650, 1000 × 640, 1000 × 500 and the width ladder; Android + iOS verified unchanged at compact. |
| **Security** | PASS | No auth, storage, network or dependency change. QA credentials only through `.env.test-credentials`, never printed; nothing in this feature changes a password. |
| **Offline-first data & sync** | N/A | No data access change. |
| **Dev Workflow: shared-code defects fixed at the root; call out `core/` changes in the PR** | PASS | The wheel dead zone (shared `AdaptiveBody` usage) is fixed at the root in the sweep, not worked around; the 560 dp pop-up limit is one theme entry, not five call-site wrappers; PRs 1, 4 and 7 call out the `core/` additions and the finished screens they touch (tokens, `AdaptiveGutters`, the dialog theme, the migrated Tổng quan / Báo cáo / Lịch sử). |

**Post-design re-check (Phase 1)**: the design adds three tokens, one pure function, one widget and one theme entry in
`core/`, with two consumers each on day one (the "≥ 2 consumers" rule for `core/` holds: stories 1–6 all consume the
primitive). No violation; Complexity Tracking lists the one deliberate duplication of mechanism.

## Project Structure

### Documentation (this feature)

```text
specs/20261007-100751-adaptive-web-remaining-screens/
├── plan.md                  # This file
├── research.md              # Phase 0: 13 decisions with evidence, alternatives
├── data-model.md            # Phase 1: layout values, state that must survive resizes, screen inventory
├── quickstart.md            # Phase 1: per-story verification recipe
├── contracts/               # Phase 1: UI contracts (one per story group)
│   ├── adaptive-layout-primitives.md
│   ├── expense-entry-ui.md
│   ├── income-and-hub-ui.md
│   ├── plan-screen-ui.md
│   ├── profile-and-placeholders-ui.md
│   └── final-sweep.md
├── checklists/requirements.md
├── spec.md
└── tasks.md                 # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

Flutter single project; files by story (a story's files never depend on a later story's files):

```text
lib/
├── core/
│   ├── theme/
│   │   ├── app_layout.dart                  # US1: + entryContentMaxWidth, screenGutter, adaptiveGutterFor
│   │   └── app_theme.dart                   # US4: + DialogThemeData(constraints: 280–560)
│   ├── l10n/app_vi.arb, app_en.arb          # US1: + expenseKeypadDeleteSemantic (+ regenerated app_localizations*.dart)
│   ├── router/app_router.dart               # US4: discard-changes prompt defaults to the safe option; device review: no left inset beside the rail, bottom-bar labels capped at 110 % text scale
│   └── widgets/
│       ├── adaptive_gutters.dart            # US1: NEW
│       ├── page_title.dart                  # device review: NEW (icon chip + title, shared by Hồ sơ, Thu chi, placeholders)
│       ├── adaptive_body.dart               # unchanged (US7 may migrate its callers)
│       ├── not_available_placeholder_screen.dart   # US6
│       └── empty_state_view.dart            # US6 (checked)
└── features/
    ├── expenses/presentation/
    │   ├── expense_screen.dart              # US1: wide layout, slots, keyboard
    │   ├── expense_entry_layout.dart        # US1: NEW pure metrics
    │   ├── expense_key_mapping.dart         # US1: NEW pure key → action
    │   ├── income_screen.dart               # US2
    │   ├── spending_screen.dart             # US3
    │   ├── overview_screen.dart, report_screen.dart, transaction_history_screen.dart   # US7: finished screens moved to AdaptiveGutters (wheel dead zones)
    │   └── widgets/balance_group_card.dart, balance_item_row.dart   # US3: hover/focus audit
    ├── expense_control/presentation/
    │   ├── expense_control_screen.dart      # US4: gutters, dialogs' keyboard behavior
    │   └── widgets/expense_group_card.dart, expense_item_row.dart   # US4: inline allocation box (ExpenseFormulaLabel)
    └── account/presentation/
        ├── account_screen.dart              # US5
        └── biometric_enable_prompt.dart     # US4/US5: dialog focus contract (checked)

test/
├── support/                                                          # shared harnesses and fixtures (new)
│   ├── adaptive_sweep.dart, load_app_fonts.dart                      # US7 matrix, real font for width-sensitive tests
│   ├── expense_screen_harness.dart, expense_control_fixtures.dart    # US1, US4
│   ├── history_fixtures.dart, account_harness.dart, app_shell_harness.dart   # US7, US5, US4
├── unit/core/theme/adaptive_gutter_test.dart                         # US1
├── unit/core/l10n/l10n_key_parity_test.dart                          # US1: + expenseKeypadDeleteSemantic
├── unit/features/expenses/expense_entry_layout_test.dart, expense_key_mapping_test.dart   # US1
└── widget/
    ├── core/widgets/adaptive_gutters_test.dart                       # US1
    ├── core/widgets/page_title_test.dart                             # device review
    ├── core/router/app_shell_display_inset_test.dart, app_shell_nav_text_scale_test.dart   # device review
    ├── core/widgets/not_available_placeholder_screen_adaptive_test.dart   # US6
    ├── core/theme/dialog_constraints_test.dart                       # US4
    ├── core/router/app_shell_discard_prompt_focus_test.dart          # US4
    ├── core/adaptive_sweep_{auth,overview_report,history,spending,account,static}_test.dart   # US7 (helper: test/support/adaptive_sweep.dart)
    └── features/
        ├── expenses/expense_screen_{adaptive_layout,keyboard,resize_state}_test.dart   # US1
        ├── expenses/income_screen_adaptive_test.dart, spending_screen_adaptive_test.dart   # US2, US3
        ├── expense_control/expense_control_{adaptive,dialogs}_test.dart  # US4
        └── account/account_screen_adaptive_test.dart, biometric_enable_prompt_dialog_test.dart   # US5, US4
```

**Structure Decision**: keep the existing layered-by-feature layout; add only shared layout code to `core/theme` and
`core/widgets` (consumed by ≥ 2 screens from the first story) and feature-local pure helpers beside their screen. No new
packages, folders or architectural layers.

### Delivery slices (one pull request each, in order)

| PR | Story | Contents | Depends on |
|----|-------|----------|------------|
| 1 | US1 Chi tiêu | tokens + `adaptiveGutterFor` + `AdaptiveGutters`; `ExpenseEntryLayout`, key mapping, `ExpenseScreen` wide layout and keyboard; the delete key's label (one ARB string in `vi` and `en`); tests; verification | — |
| 2 | US2 Thu nhập | `IncomeScreen` gutters (520); tests; verification | PR 1 (primitive) |
| 3 | US3 Thu chi | `SpendingScreen` gutters; hover/focus audit of balance rows; tests | PR 1 |
| 4 | US4 Kế hoạch | gutters; `ExpenseFormulaLabel` inline on wide; shared dialog constraints; pop-up focus/Enter/Escape contract; tests | PR 1 |
| 5 | US5 Hồ sơ | `AccountScreen` gutters; language pop-up contract; tests | PR 1, PR 4 (dialog theme) |
| 6 | US6 placeholders | `AdaptiveBody` around the empty state; tests | — |
| 7 | US7 sweep | matrix test, wheel dead-zone fix on finished screens, every other defect found, verification README | PRs 1–6 |

Each PR is built from `origin/master` after the previous one merges (or stacked while waiting), passes the full suite
alone, and records its own browser and compact verification as text.

**Delivered as one pull request.** The slices depend on the first one (the tokens and `AdaptiveGutters`), the owner
squash-merges, and a stack of seven would need an `--onto` rebase after every merge; the stories were built, tested and
verified in the order above on one branch, and the pull request description lists them in that order.

## Complexity Tracking

> Filled because one decision deliberately keeps two mechanisms side by side; no principle is violated.

| Item | Why needed | Simpler alternative rejected because |
|------|------------|--------------------------------------|
| `AdaptiveGutters` introduced next to the existing `AdaptiveBody` (two ways to bound content) | `AdaptiveBody` wraps a scroll view and leaves dead wheel/trackpad zones beside the column (measured on Tổng quan at 1440 × 500); Chi tiêu also needs pinned bars that share the scroll view's column | Reusing `AdaptiveBody` for the new screens would copy a measured defect into six more screens; replacing it in the finished screens inside story 1 would break the "one page at a time" order. The sweep (US7) migrates the finished callers it affects, after which `AdaptiveBody` remains only where it is correct (non-scrolling content: the placeholders, Bảo mật's `ListView → AdaptiveBody` shape). |
