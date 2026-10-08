# Contract: Correction Operations (domain and data layer)

**Stories**: US1–US5 | **Requirements**: FR-001…FR-018 | **Code**: `lib/features/expense_control/domain/transaction_correction_policy.dart`,
`transaction_correction_repository.dart`, `data/transaction_correction_repository_impl.dart`, `lib/core/database/balance_ledger.dart`

## 1. Policy (pure Dart, no Drift import)

```text
enum CorrectionAction { delete, edit, reverse }

class TransactionCorrectionPolicy
  static const Duration window = Duration(hours: 24)
  bool isInsideWindow(DateTime occurredAt, DateTime now)           // now - occurredAt < window; a clock before occurredAt counts as inside
  Set<CorrectionAction> availableActions(TransactionHistoryRecord record, DateTime now)
```

| Record | Inside the window | Past the window |
|--------|-------------------|-----------------|
| expense, not reversed, not a reversal | delete, edit | reverse |
| income entry, not reversed | delete (whole event) | reverse (whole event) |
| original that is reversed | none | none |
| reversal row | none | none |

## 2. Repository interface

```text
abstract interface class TransactionCorrectionRepository
  Future<CorrectionResult> delete(String transactionId, {required DateTime now})
  Future<CorrectionResult> editExpense(String transactionId, {required int amount, required String itemId, required DateTime now})
  Future<CorrectionResult> reverse(String transactionId, {required DateTime now})
  Future<CorrectionPreview> previewDelete(String transactionId)    // the balances after, for the confirmation
  Future<CorrectionPreview> previewReverse(String transactionId)

sealed class CorrectionResult: CorrectionDone(itemsWithoutBalance) | CorrectionNotAllowed(CorrectionDenial)
enum CorrectionDenial { windowEnded, windowStillOpen, alreadyReversed, isReversal, itemRemoved, invalidAmount, notEditable, notFound }
// windowStillOpen: reverse inside the window; notEditable: edit of an income entry
class CorrectionPreview { List<({String itemId, String itemName, int balanceAfter, bool itemRemoved})> items; int amount }
```

`now` is passed in so the window is testable and so the device clock is used exactly at the moment of the action.

Changes the server refused or replaced, and balance mismatches, are not part of this interface: they are `SyncNotice`s
of the sync layer (`sync-reconciliation.md`), shown by one host in the app shell.

## 3. What each operation does (one local database transaction each)

1. Read the row(s); re-check the policy against the row **as stored now** (a pull may have changed it) →
   `CorrectionNotAllowed` with the reason, nothing written.
2. Write the rows (table in `data-model.md` §4), always bumping `updated_at`; append one outbox entry per written
   transaction row (**never** an item row for a balance).
3. `BalanceLedger.recomputeBalances(db, touchedItemIds)`; notify the item stream.
4. Commit. Any failure rolls back every row, every balance and every outbox entry (FR-003, FR-004, FR-006).

| Operation | Rows | Notes |
|-----------|------|-------|
| `delete` | `deleted_at = now`, `updated_at = now` on the row, or on all rows of the income event | never on a reversal row or on a row with a live reversal |
| `editExpense` | `amount`, `expense_control_item_id`, `display_name`, `display_group_name`, `display_icon_key` from the new item | `occurred_at` untouched; refused when the item is removed or is not a leaf |
| `reverse` | one new row per original: same `direction`, `amount`, item; `reverses_id`; `occurred_at = now`; snapshot copied | refused when the original is a reversal or already has a live reversal |

## 3a. Shared writes

The record flows and the three operations append outbox entries and build the `financial_transactions` payload through
one helper, `LedgerWrites` (`lib/features/expense_control/data/ledger_writes.dart`): `appendOutbox(...)` and
`transactionPayload(row)` (which includes `reverses_id`). Neither is copied into the correction repository.

## 4. `BalanceLedger`

```text
int effectOf(TransactionDirection direction, int amount, {required bool isReversal})
Future<void> recomputeBalances(AppDatabase db, Iterable<String> itemIds)
// sets balance = balance_base + Σ effect over live rows of each item, in one UPDATE per item; skips unknown items; leaves updated_at and server_balance alone
Future<List<String>> findDivergent(AppDatabase db)
// ids of live items whose server_balance differs from balance and that have no transaction row waiting in the outbox
```

Used by: the record flows, the three operations above, `remote_row_writer` (once per batch in the pull, once per live
event and per push read-back), and the local migration.

## 5. Guarantees (each has a test)

- After any sequence of record, delete, edit and reverse, every item's balance equals `balance_base` plus the sum of the
  effects of its live rows (seeded random sequences, SC-002).
- No operation writes `balance` anywhere but the recompute; no outbox entry for an item carries a balance.
- A repeated call (a double tap) changes nothing the second time: delete on a deleted row and reverse on a reversed row
  return `CorrectionNotAllowed`.
- An account that never uses the operations has the same balances, history rows and report figures as before the
  feature (SC-006): the migration test compares them.
- Applying a pulled transaction row twice, or in a different order from another, gives the same balances.
- A reversal and a delete/edit made by the same call never leave the displayed balance different from `balance_base` plus the sum of the effects (the random test, SC-002).
- A device whose derived balance differs from the server's after both settled is told (FR-018, `sync-reconciliation.md`).
