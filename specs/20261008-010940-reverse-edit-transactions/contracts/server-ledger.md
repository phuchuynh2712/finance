# Contract: Server Ledger (Supabase migration)

**Stories**: US1–US5 (US5 above all) | **Requirements**: FR-007, FR-013, FR-014, FR-015 | **File**: `supabase/migrations/<timestamp>_transaction_corrections.sql`

The migration is applied before the app is released. Everything in it is idempotent (`if not exists`, `create or
replace`, `drop trigger if exists`).

## 1. Schema

```text
alter table financial_transactions add column if not exists reverses_id uuid references financial_transactions (id);
alter table financial_transactions add constraint financial_transactions_no_self_reversal check (reverses_id is null or reverses_id <> id);
create unique index if not exists financial_transactions_reverses_id_uidx on financial_transactions (reverses_id) where reverses_id is not null;
create index if not exists financial_transactions_item_idx on financial_transactions (expense_control_item_id);
alter table expense_control_items add column if not exists balance_base integer not null default 0;
```

Row Level Security is unchanged: the existing owner-only policies cover the new columns.

## 2. Functions

```text
tx_effect(direction text, amount integer, reverses_id uuid) returns integer   -- immutable
  = (case direction when 'income' then amount else -amount end) * (case when reverses_id is null then 1 else -1 end)

recompute_item_balance(item uuid) returns void
  update expense_control_items set balance = balance_base + coalesce((select sum(tx_effect(direction, amount, reverses_id))
      from financial_transactions where expense_control_item_id = item and deleted_at is null), 0) where id = item
```

## 3. Backfill (before any trigger below is created, inside the same migration)

```text
update expense_control_items i set balance_base = i.balance - coalesce((select sum(tx_effect(t.direction, t.amount, t.reverses_id))
    from financial_transactions t where t.expense_control_item_id = i.id and t.deleted_at is null), 0);
```

After it, `recompute_item_balance(i.id)` gives exactly the balance `i` had.

## 4. Triggers on `financial_transactions`

| Trigger (fires in name order) | When | Rule | Refusal code |
|-------------------------------|------|------|--------------|
| `a_financial_transactions_guard` | before insert | a reversal copies `direction`, `amount`, item and snapshot from its original; refused if the original is missing, deleted, itself a reversal, or belongs to another user | `TX001` invalid_reversal |
| same | before update | `deleted_at` once set is kept (a later update cannot clear it) | none: the row is returned deleted |
| same | before update | a reversal row cannot change other than being deleted by the cascade (`pg_trigger_depth() > 1`); a repeated identical update (a retried push) is accepted; `reverses_id` of an existing row cannot change | `TX002` reversal_immutable |
| same | before update | amount, direction or item of a row that has a live reversal cannot change | `TX003` transaction_reversed |
| `financial_transactions_set_updated_at` (existing) | before insert or update | `updated_at = now()`; it runs after the guard so a returned-as-is row still gets a newer `updated_at` and reaches the devices | none |
| `z_financial_transactions_ledger` | after insert or update | when `deleted_at` goes from null to set, soft-delete the live reversal of the row (`deleted_at = now()`); then `recompute_item_balance` for the new item and, if it changed, the old item | none |

A second reversal of the same row fails on the unique index (`23505`, mapped to `already_reversed`); a violated
`check (amount > 0)` is `23514`.

## 5. Trigger on `expense_control_items`

Before insert or update: `balance_base` is kept as stored (a client cannot change it; on insert it is 0) and `balance`
is set to `balance_base + the sum of the effects`, whatever the client sent. The existing `updated_at` trigger is
unchanged.

## 6. What the server does not do

- It does not look at the clock: the 24-hour window is the device's decision (research Decision 3).
- It does not decide what the person may edit beyond structure: amount greater than zero, one reversal per original,
  no change to a reversed row, delete wins.
- It does not push balances: the new `balance` reaches the devices as the item row that the item trigger and the
  `updated_at` trigger produce, through the existing Realtime publication. A device stores it as `server_balance` and
  compares it with its own derived `balance` (`sync-reconciliation.md`); the server never learns the device's figure.

## 7. Verification (real project, QA account, rows prefixed `zz-`, hard-deleted afterwards)

Insert an item, an expense and an income, then check by REST that the item's balance moved by the effects; delete; edit
(refused after a reversal); reverse twice (the second is refused); delete a reversed original (its reversal is deleted
too and the balance is back); update a deleted row (stays deleted and gets a newer `updated_at`); send a different
`balance` on an item update (ignored). Record each result in `verification/README.md`.
