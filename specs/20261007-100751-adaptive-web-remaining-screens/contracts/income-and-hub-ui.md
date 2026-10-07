# Contract: Thu nhập and the Thu chi Hub on Wide Windows

**Feature**: `20261007-100751-adaptive-web-remaining-screens` | **Stories**: US2 (P2), US3 (P3) | **Date**: 2026-10-07
**Files**: `lib/features/expenses/presentation/income_screen.dart`, `spending_screen.dart`,
`widgets/balance_group_card.dart`, `widgets/balance_item_row.dart`

## Thu nhập (US2)

Column of `AdaptiveGutters(maxWidth: entryContentMaxWidth, activatesAt: medium)`.

| ID | Rule | Verified by |
|----|------|-------------|
| I1 | The total, the "Nguồn thu" eyebrow, the source rows, the add-source button and the pinned Save bar share one column of ≤ 520 dp, centered (±8 px) beside the rail. | widget test 1440 × 900; browser |
| I2 | Each row keeps `icon · name · 150 dp amount field`; the name and its amount box are ≤ 520 dp apart (today ~1250 px). No row, controller or formatter change. | widget test: `Rect` of name vs field |
| I3 | The list scrolls with the mouse wheel anywhere over the window (the scroll view spans the viewport), Save stays pinned and reachable; with 12 sources at 1440 × 500 every row and Save are reachable. | widget test (drag/scroll over the gutter), browser wheel at x = 150 |
| I4 | Typing an amount updates the total as today; Tab moves name → amount → next row → add button → Save; Enter in an amount field behaves as today. | existing + one new widget test |
| I5 | Resize 1440 → 412 → 1440 with typed amounts: the typed values, the total and the focus stay (rows are not remounted). | widget test with `tester.view` resize |
| I6 | Compact: unchanged; `income_screen_test.dart` passes unmodified. | existing tests |
| I7 | Empty state (no plan items): the same bounded, centered `EmptyStateView`. | widget test |
| I8 | Rows' amount fields, the add-source button and Save show hover feedback under a mouse and a visible keyboard focus. | widget test with a mouse `TestGesture` and focus traversal; browser |

## Thu chi hub (US3)

Column of `AdaptiveGutters()` (960 dp, activated at expanded): the fixed header (two entry buttons, history link) and the
balance list below it share the gutters.

| ID | Rule | Verified by |
|----|------|-------------|
| H1 | At ≥ 840 dp the content column is ≤ 960 dp and centered (±8 px) beside the rail; at 600–839 dp it is the viewport width minus 36 dp, as Tổng quan. | widget test; browser |
| H2 | The "Thu nhập" and "Chi tiêu" buttons sit side by side, each `64 dp` high (inside the 48–72 range) and ≤ 50 % of the column width (`Expanded` in one `Row`; unchanged widgets). | widget test: `Rect` heights and widths at 600, 840, 1440, 2560 |
| H3 | The history link navigates to Lịch sử giao dịch as today; the three entry points keep their `context.push` targets. | existing tests |
| H4 | Balance groups expand/collapse as today; each balance row (name left, balance right) shows a hover tint under the mouse (added to the read-only `BalanceItemRow`, which has no other interaction and is therefore not focusable); a group's header, the only activatable part, is an `InkWell` with hover feedback and a focus ring (verified, unchanged). This is the operational meaning of spec US3 acceptance 3. | widget test (`tester.createGesture(kind: mouse)` hover; `Focus` traversal); browser hover |
| H5 | Long account/item names wrap or ellipsize inside the row without pushing the balance out; large balances (≥ 1.000.000.000 ₫) fit. | widget test with a 60-character name and a 12-digit balance at 320 and 1440 |
| H6 | The scroll view spans the viewport (wheel works over the gutters). | browser wheel at x = 150 |
| H7 | Compact: unchanged; `spending_screen_test.dart` and `balance_*_test.dart` pass unmodified. | existing tests |
| H8 | The page is the first screen of the stack Thu chi → Thu nhập / Chi tiêu / Lịch sử and returns correctly with Back. | existing router tests |

Non-goals: card grids, a side-by-side hub/detail layout, changing how balances are computed or ordered.
