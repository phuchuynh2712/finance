# Internal UI Contract: Monthly Report Screen

## Purpose

Define the application-facing data and state contract used by the Báo cáo
(Report) tab. This is an internal Flutter application contract, not a
public HTTP API. The Report screen is read-only — it exposes no
write/command contract of its own; all mutation (recording income/expense)
stays owned by the Thu chi tab's existing contracts.

## Gateway Contracts

- **`TransactionHistoryRepository.watchTransactionHistory({required start,
  required end})`** (existing, unchanged — no new repository method). Both
  `reportTotalsProvider` and `reportBreakdownProvider` read from this same
  underlying stream, via the existing
  `transactionHistoryRecordsProvider(month)` family provider.
- **`ExpenseControlPlanService.groupNameFor(List<ExpenseControlNode> tree,
  String leafId)`** (new method, additive — research.md Decision 9). Pure
  Dart, no Flutter/Drift import, consistent with this service's existing
  charter.
- **`expenseControlTreeProvider`** (existing, unchanged —
  `lib/core/di/expense_dependencies.dart`) — only `reportBreakdownProvider`
  depends on this; `reportTotalsProvider` does not.

Neither contract exposes Drift, Supabase, or widget types to the
presentation layer — `report_summary.dart`'s pure functions
(`computeReportTotals`, `computeReportBreakdown`) are the only things
`report_screen.dart` depends on for data shaping.

## Presentation Inputs

| Input | Behavior |
|---|---|
| Selected month | `selectedReportMonthProvider` (research.md Decisions 2–3), defaults to the current calendar month, persists across tab switches. |
| This month's transaction records | `transactionHistoryRecordsProvider(selectedMonth)` (existing, reused). |
| Expense-control tree | `expenseControlTreeProvider` (existing, reused) — only for the breakdown section. |
| Locale | `Localizations.localeOf(context)`, used for `CurrencyFormatter`, `formatPercent`, and the month label's locale-aware formatting (`intl`'s `DateFormat`). |

## Presentation Outputs

The screen renders, top to bottom:

1. Header: fixed title + icon badge (FR-002).
2. Month selector: previous/next controls + month label (FR-004, FR-005,
   FR-006) — a stock `IconButton` per control (constitution touch-target
   reconciliation, research.md).
3. Two total cards (income, expense) — FR-007, FR-008, FR-009, FR-010.
4. Item breakdown section: eyebrow header + flat list of `ReportItemEntry`
   rows (FR-011–FR-014), or an empty-state message when the selected
   month has no income/expense activity at all (FR-015).

All new strings are sourced from `AppLocalizations` in both `vi` and `en`;
no screen text is hardcoded.

## State Outcomes Per Section

There are **two** independent underlying providers, matching research.md
Decision 4 — a slow or failed breakdown load must never delay or block the
total cards, and vice versa:

| State | Total cards (`reportTotalsProvider`) | Item breakdown (`reportBreakdownProvider`) |
|---|---|---|
| Loading | `CircularProgressIndicator` in place of both amounts | `CircularProgressIndicator` in place of the list |
| Empty (no activity this month) | Both cards render "0 ₫" (always computable) | `EmptyStateView`, no action (FR-015) |
| Error | `EmptyStateView` with retry action, in place of both amounts | `EmptyStateView` with retry action, invalidating only this provider |
| Data | Income + expense totals | Sorted (research.md Decision 13) list of item rows, each in one of three states below |

**Per-row states** (mirrors data-model.md's `ReportItemUsageState`):

| Row state | Condition | Rendering |
|---|---|---|
| `notAllocated` | `allocated == 0 && spent > 0` | Name, group label, spent amount; a distinct "not allocated this month" indicator; no bar, no percentage (FR-014). |
| `unused` | `allocated > 0 && spent == 0` | Name, group label, spent amount ("0 ₫"); bar at 0% fill; "0%" text. |
| `tracked` | `allocated > 0 && spent > 0` | Name, group label, spent amount; bar fill = `min(usagePercent, 100)%`; fill color = danger semantic when `usagePercent > 100`, else primary (research.md Decision 7); percentage text always shows the true, uncapped value. |

Changing the selected month re-evaluates both providers for the new month
key (the `.family` pattern already does this by construction — no manual
refresh/invalidate call is needed).

## Error Contract

Data failures surface a localized, retryable error per affected section
(`EmptyStateView` + `onAction` invalidating that section's provider only).
No raw exception text or financial values are logged, matching the
constitution's logging-discipline rule.

## Navigation Contract

None. The Report screen introduces no outbound navigation of its own (no
"Xem tất cả," no drill-down push) — this is a deliberate consequence of the
flat, non-nested breakdown design (spec.md Assumptions): every figure a
user needs is already visible on this one screen without a further tap.

The only routing change from this feature is the existing
`GoRoute(path: '/history', ...)`'s `builder` changing from
`NotAvailablePlaceholderScreen(...)` to `ReportScreen()` (research.md
Decision 12 — path unchanged), and the fourth `NavigationDestination`'s
icon changing to `LucideIcons.pieChart` (research.md Decision 11).
