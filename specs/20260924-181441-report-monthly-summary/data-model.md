# Phase 1 Data Model: Monthly Report Screen

All types below are read-only, derived, in-memory value objects computed
from already-persisted data (`financial_transactions` via
`TransactionHistoryRecord`, and `expense_control_items` via
`ExpenseControlNode`). No new persisted table, column, or migration is
introduced.

## `ReportTotals`

Produced by `reportTotalsProvider(month)`; depends only on that month's
`TransactionHistoryRecord`s (see research.md Decision 4).

| Field | Type | Meaning |
|---|---|---|
| `totalIncome` | `int` (VND) | Sum of every `direction: income` record's `amount` for the selected month. |
| `totalExpense` | `int` (VND) | Sum of every `direction: expense` record's `amount` for the selected month. |

Derivation: a single pass (`fold`) over
`transactionHistoryRecordsProvider(month)`'s list, branching on
`record.direction`. Pure function, no Flutter import — lives in
`lib/features/expenses/application/report_summary.dart`.

## `ReportItemEntry`

One row of the per-item breakdown. Produced by `reportBreakdownProvider
(month)`; depends on that month's `TransactionHistoryRecord`s **and** the
current `expenseControlTreeProvider` tree (see research.md Decision 4).

| Field | Type | Meaning |
|---|---|---|
| `itemId` | `String` | The underlying `ExpenseControlItem.id` (`TransactionHistoryRecord.sourceItemId`). |
| `name` | `String` | The item's current display name if it still exists in the tree; otherwise the transaction's own snapshotted `displayName` (already non-null with an "Archived Item"-style fallback baked in at the repository layer — same fallback already relied on elsewhere, e.g. `transaction_history_screen.dart`). |
| `groupName` | `String?` | The name of the item's current parent top-level group, resolved via the new `ExpenseControlPlanService.groupNameFor` (research.md Decision 9); `null` when the item is itself a standalone top-level item with no parent group. |
| `spent` | `int` (VND) | Sum of `direction: expense` record amounts for this item in the selected month. |
| `allocated` | `int` (VND) | Sum of `direction: income` record amounts for this item in the selected month. |
| `usagePercent` | `double?` | `null` when `allocated == 0` (see `ReportItemUsageState` below); otherwise `spent / allocated * 100`, uncapped (can exceed 100). |

**List membership** (FR-011): an item appears in the breakdown if and only
if it has at least one `income` or `expense` record in the selected month
(`spent > 0 || allocated > 0`). An item with neither is omitted entirely —
it is never represented as a zero-valued row.

**Derived display state** (`ReportItemUsageState`, a pure getter/helper on
`ReportItemEntry`, not a separate persisted field): one of three cases,
directly mirroring spec.md's Acceptance Scenarios for User Story 3:

- `notAllocated` — `allocated == 0 && spent > 0` (FR-014: distinct "not
  allocated this month" indicator, no percentage/bar shown).
- `unused` — `allocated > 0 && spent == 0` (0% used; bar renders at empty
  fill).
- `tracked` — `allocated > 0 && spent > 0` (normal case; bar renders at
  `min(usagePercent, 100)%` fill, color depends on whether `usagePercent`
  exceeds 100 — research.md Decision 7).

(The `allocated == 0 && spent == 0` case cannot occur given the list-
membership rule above — such an item is simply not present as an entry.)

**Sort order**: the list `reportBreakdownProvider` exposes is pre-sorted by
`spent` descending (research.md Decision 13) — the presentation layer does
not re-sort.

## Relationship to existing entities

```text
TransactionHistoryRecord (existing, unchanged)
  ├─ direction, amount, occurredAt  → folded into ReportTotals
  └─ sourceItemId, amount, direction → grouped by sourceItemId into
                                        ReportItemEntry.spent / .allocated

ExpenseControlNode (existing, unchanged) / ExpenseControlItem (existing)
  └─ current name + parent-group name → ReportItemEntry.name / .groupName
     (via new ExpenseControlPlanService.groupNameFor)
```

No existing entity's shape changes. `ExpenseControlPlanService` gains one
new pure method (`groupNameFor`); `TransactionHistoryRepository`'s
interface is unchanged (research.md Decision 1).
