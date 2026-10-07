# Contract: Kế hoạch (Kiểm soát chi tiêu) and Its Pop-ups on Wide Windows

**Feature**: `20261007-100751-adaptive-web-remaining-screens` | **Story**: US4 (P4) | **Date**: 2026-10-07
**Files**: `lib/features/expense_control/presentation/expense_control_screen.dart`,
`widgets/expense_group_card.dart`, `widgets/expense_item_row.dart` (extracts `ExpenseFormulaLabel`),
`widgets/allocation_summary_banner.dart` (checked), `lib/core/theme/app_theme.dart` (dialog constraints),
`lib/core/router/app_router.dart` (discard prompt checked)

## Layout contract

`_ScreenContent`'s `ListView` is wrapped in `AdaptiveGutters()` (960 dp from 840 dp). The 62 dp title strip stays
full-width like the other tabs' headers.

| ID | Rule | Verified by |
|----|------|-------------|
| P1 | Hint banner, group cards, the dashed "add item" button, the allocation summary banner and the pending-changes block are one column ≤ 960 dp, centered (±8 px). | widget test at 1440, 2560; browser |
| P2 | Wide (window ≥ 600 dp): an item row is `icon · name (flexible) · allocation box · edit · delete`, the allocation box (`ExpenseFormulaLabel`) sized to its text within `[96, 200]` dp, 40 dp high, **not** the row width. A top-level leaf's header shows its box in the same place. Compact (< 600 dp): the box stays below the name as today. | widget tests at 412 and 1440; `Rect` width ≤ 200 |
| P3 | Allocation boxes of different items start at the same x on wide windows (right-aligned beside the actions), so a column of values reads as a column. | widget test comparing right edges |
| P4 | The pending-changes Save button is 52 dp high and ≤ 360 dp wide, centered, on wide windows; full-width on compact as today. | widget test |
| P5 | Expanding/collapsing a group, add/edit/delete item, add child, delete group, reorder (drag handle) behave as on a phone at 412, 840 and 1440. | existing + new widget tests; browser drag at 1440 |
| P6 | Mouse-wheel scrolling works over the whole window, including the gutters. | browser wheel at x = 150 |
| P7 | Hover and keyboard focus are visible on the group header, the add buttons, the edit/delete icons; the icon-only buttons have tooltips (already present, verified); the reorder drag handle, also icon-only, shows a tooltip with the existing `expenseControlReorderSemantic` text (added if missing, no new string). | widget test; browser |
| P8 | Long group/item names (60 characters) ellipsize in the name slot without moving the allocation box or the actions; large fixed amounts (12 digits) fit within 200 dp or ellipsize at the label's own edge. | widget test |
| P9 | Resize across 600 and 840 with groups expanded and unsaved edits pending: expanded groups, pending edits and the open pop-up stay. | widget test with `tester.view` resize |
| P10 | Compact: unchanged; `expense_control_screen_test.dart`, `expense_group_card_test.dart`, `expense_item_row_test.dart` pass unmodified. | existing tests |

## Pop-up contract

Applies to every `AlertDialog`/`Dialog` in the app through one shared theme entry:
`DialogThemeData(constraints: BoxConstraints(minWidth: 280, maxWidth: 560))`.

| ID | Pop-up | Rule |
|----|--------|------|
| D1 | all | centered, ≤ 560 dp wide, fully visible at 1440 × 900 and 412 × 915; scrolls its own content when the window is shorter than the dialog (`SingleChildScrollView` already used by the item form) |
| D2 | all | Escape dismisses (framework `DismissIntent`; verified, not re-implemented) |
| D3 | Item add/edit form | on a desktop platform (a hardware keyboard): initial focus on the name field; Enter in the last field submits only when the same validation as the Save button passes; Tab order name → icon → mode → value → Cancel → Save. On a phone or tablet (Android, iOS) nothing takes the focus by itself and the on-screen keyboard keeps its own action keys: the keyboard must not open unasked and its "done" key must not save |
| D4 | Delete-group confirmation | initial focus on **Cancel**; Enter activates the focused button; Escape cancels |
| D5 | Language choice (story 5) | initial focus on the selected language; Enter confirms it; Escape dismisses |
| D6 | Biometric offer | initial focus on the primary ("enable") button; Enter confirms; Escape = "not now" as the existing dismiss |
| D7 | Discard-changes prompt (app shell) | initial focus on the safe option (keep editing); Escape = keep editing |
| D8 | resize while open | dialog stays centered and visible; typed text stays |

Tests: `test/widget/core/theme/dialog_constraints_test.dart` (an `AlertDialog` with a 2000 dp-wide child at 1440 is
≤ 560 dp); one widget test per pop-up for D3–D8; browser pass for Escape/Enter at 1440.

## Non-goals

No new fields, no inline editing of amounts (editing stays in the item pop-up), no multi-column cards, no change to
reorder rules, formulas, validation or the 100 % budget check.
