# Phase 1 Data Model: Home Overview Screen

No persisted schema changes. Every type below is a read-only, in-memory value derived from existing data (existing `expense_control_items` and `financial_transactions` Drift tables, existing Supabase auth user metadata) — this feature adds no migration, no new table, and no new column.

## OverviewAccountSummary

A read-only projection of one top-level account (an `ExpenseControlNode` root), for the horizontal accounts list.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | The root `ExpenseControlItem.id`. |
| `name` | `String` | `ExpenseControlItem.name` of the root. |
| `iconKey` | `String?` | `ExpenseControlItem.iconKey` of the root, for the icon badge. |
| `balance` | `int` | VND minor-unit-free integer (matches the rest of the app's convention — see `ExpenseControlItem.balance`); computed via `ExpenseControlPlanService.computeItemBalance(node)`, so a group's balance is the live sum of its children, never a stale stored value. |

Derived, not stored: `isNegative => balance < 0`.

## OverviewSummary

The single derived object backing the total-balance card and the negative-balance warning.

| Field | Type | Notes |
|---|---|---|
| `totalBalance` | `int` | Fold of every `OverviewAccountSummary.balance` in `accounts`. |
| `accounts` | `List<OverviewAccountSummary>` | One entry per root account, in the same order `expenseControlTreeProvider` already returns them. |

Derived, not stored: `negativeAccounts => accounts.where((a) => a.isNegative).toList()`; the warning banner shows iff `negativeAccounts.isNotEmpty`, naming `negativeAccounts.first` (FR-003, Edge Cases).

**Validation / invariants**: `totalBalance` MUST always equal the sum of `accounts[*].balance` (enforced by construction — it is computed from the same list, never set independently) — this is the mechanism that keeps the total-balance card and the per-account cards from ever visually disagreeing.

## OverviewRelativeDay

A small enum describing how far in the past a transaction's `occurredAt` falls, *before* localization.

```dart
sealed class OverviewRelativeDay {
  const factory OverviewRelativeDay.today() = _Today;
  const factory OverviewRelativeDay.yesterday() = _Yesterday;
  const factory OverviewRelativeDay.daysAgo(int days) = _DaysAgo;
}
```

(Or an equivalent closed shape — the exact Dart encoding is an implementation detail; the contract is that the *presentation* layer, not `application/`, turns this into the localized string "Hôm nay" / "Hôm qua" / "{n} ngày trước", per research.md Decision 4.)

**Computation rule**: compare the calendar date of `occurredAt` against the calendar date of an injected `now` (never `DateTime.now()` read inside the pure function, for testability) — 0 days difference → `today`; 1 day → `yesterday`; ≥2 days → `daysAgo(n)`.

## OverviewTransactionItem

A read-only projection of one `TransactionHistoryRecord` (existing type, `lib/features/expense_control/domain/transaction_history_record.dart`), for the recent-activity list.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Passed through from `TransactionHistoryRecord.id`. |
| `displayName` | `String` | Passed through (already defaults to "Archived Item" upstream when the source item was deleted — see existing `_toHistoryRecord` mapping). |
| `groupLabel` | `String?` | `TransactionHistoryRecord.displayGroupName`, shown as the "{{nhóm}}" part of the subtitle. |
| `relativeDay` | `OverviewRelativeDay` | See above. |
| `direction` | `TransactionHistoryDirection` | Existing enum (`income` / `expense`), passed through unchanged. |
| `amount` | `int` | Passed through; sign/color handled at render time from `direction`, matching the existing transaction-history screen's convention. |

**Ordering & cap**: the list is already ordered `occurredAt DESC, createdAt DESC` by the repository query (`watchRecent`); the application layer does not re-sort. The cap (`limit`) is a provider-level constant (5, per spec.md Assumptions), passed as the `limit:` argument to `watchRecent` — not a client-side `.take()` after a larger fetch (research.md Decision 3).

## Relationship to existing entities

```text
ExpenseControlItem (existing, expense_control/domain)
  └── read via ExpenseControlNode tree (existing)
        └── OverviewAccountSummary  (new, one per root, via ExpenseControlPlanService.computeItemBalance)
              └── folds into → OverviewSummary.totalBalance / .negativeAccounts

TransactionHistoryRecord (existing, expense_control/domain)
  └── read via TransactionHistoryRepository.watchRecent(limit) (new method, existing interface)
        └── OverviewTransactionItem (new, one per record, adds relativeDay bucketing only)
```

No new entity is persisted; no existing entity's stored shape changes.
