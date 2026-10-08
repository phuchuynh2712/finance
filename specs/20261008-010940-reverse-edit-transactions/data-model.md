# Data Model: Delete, Edit and Reverse Saved Transactions

**Feature**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## 1. Stored data

### 1.1 `financial_transactions` (Drift v8 and Postgres)

Existing columns are unchanged (`id`, `user_id`, `expense_control_item_id`, `direction`, `amount`, `occurred_at`,
`display_name`, `display_group_name`, `display_icon_key`, `created_at`, `updated_at`, `deleted_at`). New:

| Column | Type | Meaning |
|--------|------|---------|
| `reverses_id` | text / uuid, nullable, references the same table | set only on a reversal row: the id of the transaction it cancels |

Indexes (both sides): `(expense_control_item_id)` for the recompute; **unique** `(reverses_id)` where `reverses_id is
not null` (at most one reversal per transaction). Server only: `check (reverses_id <> id)`.

### 1.2 `expense_control_items` (Drift v8 and Postgres)

| Column | Type | Meaning |
|--------|------|---------|
| `balance_base` | integer, default 0 | the part of the balance not explained by transactions: what the item had before this feature, and 0 for an item created later |
| `balance` | integer (existing) | now derived: `balance_base` + Σ effect of the item's live transactions; written only by the recompute |
| `server_balance` | integer, nullable (**Drift only**, never on the server, never pushed) | the `balance` the server last reported for the item (from a pulled, live or push-returned row); null until the first one; used only to reconcile (research Decision 10) |

Migration backfill (local and server, before any trigger exists): `balance_base = balance − Σ effect(live transactions of
the item)`, so the derived balance equals the stored one at the moment of migration.

### 1.3 `sync_outbox` (Drift v8)

| Column | Type | Meaning |
|--------|------|---------|
| `rejected_at` | datetime, nullable | the server refused this change; it is never retried; the row is deleted once the person has been shown the notice |
| `reject_reason` | text, nullable | the refusal code (`transaction_reversed`, `already_reversed`, `invalid_reversal`, `reversal_immutable`, `check_violation`) |

## 2. Derived values

| Name | Definition |
|------|------------|
| `effect(t)` | `s × amount`, where `s = +1` for income, `−1` for expense, multiplied by `−1` when `reverses_id` is set |
| `balance(item)` | `balance_base + Σ effect(t)` over rows with `expense_control_item_id = item`, `deleted_at is null` |
| kind of a row | *original* (`reverses_id` null) or *reversal* (`reverses_id` set) |
| `isReversed(original)` | a live row exists with `reverses_id = original.id` |
| `isInsideWindow(t, now)` | `now − t.occurred_at < 24 h` (device clock, at the moment of the action) |
| income event of `t` | rows of the same user with `direction = income`, `reverses_id` null, `occurred_at = t.occurred_at` |
| refunded expense of a month | Σ `amount` of reversal rows with `direction = expense` and `occurred_at` in the month |
| withdrawn income of a month | Σ `amount` of reversal rows with `direction = income` and `occurred_at` in the month |
| divergent item | a live item whose `server_balance` is not null and differs from `balance`, with no transaction row of the item waiting in the outbox (unsynced and not rejected) |

## 3. State of a transaction

```text
 original ─ record ─▶ ACTIVE ─ delete (inside window, or by cascade) ─▶ DELETED   (final, nowhere shown)
                        │  ▲
                        │  └─ edit (expense, inside window): amount, item
                        └─ reverse (past window) ─▶ REVERSED  (original stays, plus one reversal row, itself final)
```

Allowed actions (policy, pure): inside the window an expense offers delete and edit and an income entry offers delete
of its event; past the window any original that is not reversed offers reverse (an income reverses as a whole event);
a reversed original and every reversal row offer none.

## 4. Per-operation row effects

| Operation | Rows written (one local transaction, outbox entries for each) | Balances recomputed |
|-----------|---------------------------------------------------------------|---------------------|
| record expense / allocate income | insert the transaction row(s) | each touched item |
| delete (inside window) | set `deleted_at` (and `updated_at`) on the row, or on every row of the income event | each item of those rows |
| edit expense | update `amount`, `expense_control_item_id`, and the item's snapshot columns (`display_*`); `occurred_at` untouched | the old and the new item |
| reverse | insert one reversal row per original (income: per entry of the event) | each item of those rows |
| pull / push read-back of a transaction row | the existing idempotent apply | the old and the new item of that row, once per batch |
| pull of an item row | the existing apply, but `balance_base` is taken from the row, the row's `balance` goes to `server_balance` and is not displayed | that item, from the local transactions (which may include changes not pushed yet) |
| push response (any row) | applied unconditionally, unless a later outbox entry for the same row is still waiting | the touched items |
| refused push | an insert is removed locally; an update is replaced by the server's row unconditionally; the outbox row gets `rejected_at` and is deleted once its notice is shown | the touched items |

## 5. Validation rules (client policy, mirrored by the server guards)

- `amount > 0` on edit; the chosen item must exist, not be deleted, and be a leaf.
- An edit or a delete is refused on the device when the row is past the window or already has a live reversal.
- A reversal needs an original that is live, not itself a reversal, and not already reversed.
- A reversal row is never edited or deleted by the person.

## 6. Mapping to the domain

`TransactionHistoryRecord` gains `reversesId` (nullable) and `isReversed` (computed in the query from the existence of
a reversal row), so the screens and the policy work from the domain object and never see a Drift type.
