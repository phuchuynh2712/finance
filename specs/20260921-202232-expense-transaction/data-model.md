# Phase 1 Data Model: Expense Transaction Recording

## Entities

### Financial Transaction (new)

A single record of money moving into or out of one budget item — the shared underlying shape of both Expense Transaction and Income Transaction (spec.md's Key Entities).

| Field | Type | Notes |
|---|---|---|
| `id` | `String` (uuid) | Generated app-side via `package:uuid`, matching `ExpenseControlItem.id`'s own convention. |
| `userId` | `String` | Owner. |
| `expenseControlItemId` | `String` | The leaf budget item this transaction affected. Always a leaf (FR-011) — never a group. |
| `direction` | `TransactionDirection` (`income` \| `expense`) | Determines the sign of this transaction's effect on the item's balance; `amount` itself is always positive (research.md Decision 3). |
| `amount` | `int` | Whole VND units, always `> 0`. |
| `occurredAt` | `DateTime` | The moment this transaction is considered to have happened. For an expense, this is "now" at save time. For income, every row produced by the same "Lưu thu nhập" action shares one `occurredAt` (research.md Decision 4). |

**Validation**:
- `amount` MUST be `> 0` — enforced at the Postgres layer via `check (amount > 0)` (research.md Decision 3) and MUST also be validated app-side before a write is attempted (FR-008's blank/zero rejection is the expense-recording-time instance of this).
- `expenseControlItemId` MUST reference a leaf item (no children) at the time of the write — enforced at the presentation layer by only offering leaf items in the picker (FR-011); not re-validated at the repository layer beyond what the existing `expense_control_items` FK already guarantees (the row must exist).

**Persistence**: New Drift table `FinancialTransactions` → new Supabase table `financial_transactions`. See contracts/ and the Project Structure section of plan.md for exact column mapping.

**Note**: `ExpenseControlPlanService._flattenLeaves` is currently private. It becomes public (rename `flattenLeaves`, or add a thin public wrapper) so the "Chi tiêu" screen's presentation layer can call it for the "Trừ vào khoản nào" picker (research.md Decision 8) — this is a required code change, not just a reuse note.

### Expense Transaction (conceptual — not a separate table)

A Financial Transaction with `direction: expense`. Created by the new `ExpenseControlRepository.recordExpense()` method (FR-009), one row per "Lưu giao dịch" tap, always exactly one row per save.

### Income Transaction (conceptual — not a separate table)

A Financial Transaction with `direction: income`. Created automatically inside the existing `ExpenseControlRepository.applyIncomeAllocation()` method (FR-013) — one row per non-zero entry in that call's `balanceDeltas` map, all sharing one `occurredAt` (research.md Decision 4). Zero, one, or many rows can result from a single "Lưu thu nhập" action, matching how the existing allocation already produces zero-to-many `balance` deltas.

## Existing entities referenced (not modified by this feature, except where noted)

### `ExpenseControlItem` (unchanged shape)

`balance` is decremented by `recordExpense` (new) exactly the way it is already incremented by `applyIncomeAllocation` (existing) — same column, same atomic-`customUpdate` discipline, no schema change to this table. Only leaf items (`children.isEmpty` in tree form, i.e. `ExpenseControlNode.isGroup == false`) are valid `recordExpense` targets (FR-011).

## State Transitions

### Expense recording (`recordExpense`)

```
[Chi tiêu screen: amount entered, item picked]
        │  tap "Lưu giao dịch" (FR-008 gate: amount > 0 AND item picked)
        ▼
one atomic Drift transaction:
  1. customUpdate: expense_control_items.balance -= amount  (item may go negative — FR-010)
  2. insert: financial_transactions (direction: expense, amount, occurredAt: now)
  3. append sync_outbox row for the changed expense_control_items row
  4. append sync_outbox row for the new financial_transactions row
        │  all four succeed, or all four roll back (FR-009)
        ▼
[Thu chi screen: item's balance reflects the decrement]
```

### Income recording (`applyIncomeAllocation`, extended)

```
[Income screen: "Lưu thu nhập" tapped, deltas computed by ExpenseControlPlanService]
        │
        ▼
one atomic Drift transaction (existing transaction, extended — not a new one):
  for each (itemId, delta) in deltas where delta > 0:
    1. customUpdate: expense_control_items.balance += delta  (existing behavior, unchanged)
    2. insert: financial_transactions (direction: income, amount: delta, occurredAt: <shared "now">)
    3. append sync_outbox row for the changed expense_control_items row (existing)
    4. append sync_outbox row for the new financial_transactions row (new)
        │  every step for every item succeeds, or the whole transaction rolls back (FR-013)
        ▼
[Thu chi screen: every touched item's balance reflects its increment; a matching
 financial_transactions row exists for each]
```

## Test Helper Reference

Any test constructing an `ExpenseControlItem` fixture must supply all 11 constructor fields in this order (confirmed via `lib/features/expense_control/domain/expense_control_item.dart`): `id, userId, parentId, name, iconKey, description, sortOrder, allocationMethod, allocationValue, balance, isSavingsReceiver`. Existing test helpers (e.g. `_leaf(...)` in `expense_control_repository_impl_test.dart`) already do this — reuse rather than re-deriving.
