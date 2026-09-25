# Quickstart: Monthly Report Verification

## Prerequisites

- Run from the repository root with Flutter dependencies available.
- Use a signed-in test user with: at least one leaf item that received an
  income allocation this month and has been spent from (partially); at
  least one leaf item allocated this month but not yet spent from; at
  least one leaf item spent from this month with no income allocation
  saved into it this month; at least one top-level standalone item (no
  parent group) and at least one leaf item that belongs to a group with
  other siblings.

## Verification Flow

1. Confirm the bottom navigation's fourth tab shows a pie-chart icon
   (replacing the old history/clock icon) with the label "Báo cáo",
   unchanged position (FR-001).
2. Tap the fourth tab. Confirm the "not available" placeholder is gone and
   a real Report screen renders (FR-002), defaulting to the current
   calendar month (FR-003) with a human-readable month label (FR-004).
3. Confirm the two total cards show this month's total income and total
   expense, matching the sum of this month's actual `income`/`expense`
   transactions (FR-007–FR-009), and that the income card never shows a
   per-source breakdown (FR-010).
4. Tap the previous-month control. Confirm the month label, both totals,
   and the item breakdown all update to that earlier month (FR-005). Step
   back several months and confirm it keeps working with no fixed limit.
5. Tap forward back to the current month. Confirm the forward control
   becomes unable to advance past the current month (FR-006).
6. Switch to a different bottom-nav tab, then back to Báo cáo. Confirm the
   previously-selected month is still shown, not reset to the current
   month (research.md Decision 3).
7. Confirm the item breakdown lists: the partially-spent allocated item
   (with its group name shown, spent amount, and a usage bar/percentage
   under 100%); the allocated-but-unspent item (0% used, bar at empty
   fill); the spent-but-unallocated item (a distinct "not allocated this
   month" indicator, no percentage) (FR-011–FR-014). Confirm an item with
   no activity at all this month does not appear anywhere in the list.
8. Confirm the standalone top-level item's row shows no group label, while
   the item belonging to a group shows that group's name.
9. Record an expense large enough to push one allocated item's usage past
   100%. Confirm its bar visually caps at full width, its fill color
   changes to the danger/red semantic color, and the percentage text still
   shows the true value above 100% (research.md Decision 7).
10. Navigate to a month with no income or expense transactions at all.
    Confirm both total cards still render ("0 ₫") and the item breakdown
    area shows an empty-state message instead of a list (FR-015).
11. Record a new income allocation or expense while on the Report tab (or
    return to it after recording one elsewhere). Confirm the totals and
    breakdown for the affected month update without a manual refresh
    (FR-016).
12. Force a data-load failure for one section (e.g. temporarily break a
    provider override in a debug build) and confirm only that section
    (totals or breakdown) shows a retryable error state while the other
    continues to render normally.
13. Verify Vietnamese and English labels, light/dark modes, screen-reader
    labels, the month-navigation buttons' ≥48dp tap target, and
    locale-aware currency/percentage/date formatting throughout.

## Automated Checks

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/unit/features/expense_control
flutter test test/unit/features/expenses
flutter test test/widget/features/expenses
flutter test test/widget/core/router
flutter test
```

## Required Regression Coverage

- `ExpenseControlPlanService.groupNameFor`: returns the correct top-level
  node's name for a nested leaf, returns `null` for a standalone top-level
  leaf, and returns a sensible result for an id not present in the tree
  (e.g. an item since removed).
- `report_summary.dart`'s pure functions (`computeReportTotals`,
  `computeReportBreakdown`): income/expense fold correctness; per-item
  `spent`/`allocated` aggregation by `sourceItemId`; all three
  `ReportItemUsageState` branches (`notAllocated`, `unused`, `tracked`),
  including the `usagePercent > 100` case; list-membership exclusion of
  items with zero activity; descending sort by `spent`.
- `selectedReportMonthProvider` persistence: selecting a past month,
  switching tabs, and switching back preserves the selection (research.md
  Decision 3) — a widget test driving the full `StatefulShellRoute` shell,
  not just the Report screen in isolation.
- Independent per-section loading/error: a slow or failed
  `reportBreakdownProvider` must not delay or block `reportTotalsProvider`'s
  render, and vice versa (mirrors the Home Overview feature's equivalent
  test).
- Bottom-nav icon: a widget test asserting the fourth
  `NavigationDestination`'s icon is `LucideIcons.pieChart`, not
  `LucideIcons.history` — `test/widget/core/router/app_shell_nav_bar_test.dart`
  currently only asserts label text, not icon identity, so this is new
  coverage, not a modification of an existing assertion.
- Overspend rendering: a widget test seeding an item with
  `usagePercent > 100` and asserting the bar's fill is visually capped
  while the percentage text shows the true, uncapped value.
- Widget coverage for the empty-month state (both totals at "0 ₫", empty
  state shown in place of the breakdown list).
- Integration coverage: recording income allocation or an expense while on
  (or before returning to) the Report tab is reflected in its totals and
  breakdown without a manual refresh.
