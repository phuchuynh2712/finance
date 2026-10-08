# Research: Delete, Edit and Reverse Saved Transactions

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-10-08

What the code does today, what the options are, and what was decided. Every spec clarification is already settled, so
nothing here is an open question for the owner.

## What exists today (read from the code)

- A transaction is a row of `financial_transactions` (`direction` income or expense, `amount` > 0, `occurred_at`, the
  item's name, group and icon as they were, `updated_at`, `deleted_at`). An income action writes one row **per item**,
  all with the same `occurred_at`.
- `recordExpense` and `applyIncomeAllocation` change the item's `balance` with a local `balance = balance ± ?`
  statement, write the transaction row, and append **two** outbox entries (the whole item row with its new absolute
  balance, and the transaction row), all in one local database transaction.
- The sync worker pushes each outbox row as an upsert and applies the row Postgres returns. Any failure is retried
  forever (`retry_count` only grows).
- A pulled row (initial pull, live event, push read-back) replaces the local row only if its `updated_at` is strictly
  newer (`remote_row_writer.dart`). `updated_at` is set by the server on every write.
- The server balance view that once reconciled balances was dropped with the envelope tables; the worker's comment
  says reconciliation for `ExpenseControlItem.balance` would be redesigned "if and when it becomes necessary".
- `update(item)` (a rename) pushes the item row **including the balance the device last saw**.
- Reports and the history sum transactions by month of `occurred_at`; reports show per-item spent and allocated.

**Consequence**: balances are last-write-wins absolute numbers. Two devices recording expenses offline, or a rename
made offline after another device spent, silently lose a change today. This feature's requirements (a correction must
apply exactly once, on every device, in any order) cannot be met on top of that.

## Decision 1: balances become a function of the transactions

**Decision**: `balance(item) = balance_base(item) + Σ effect(t)` over the item's transactions that are not deleted.
`effect(t)` is `+amount` for income and `−amount` for expense, negated for a reversal. `balance_base` is a new
column that holds whatever the balance was before this feature, so every existing balance is unchanged (SC-006). The
device recomputes the balance of each touched item inside the same local transaction as the change; the server
recomputes in triggers; devices no longer push `balance`, and the server ignores a balance it is sent. The balance the
server last reported for an item is kept on the device in a local-only column `server_balance`, never used for display
and never pushed, so the device can reconcile its figure against the server's (Decision 10).

**Rationale**: recomputing from the set of transactions (not applying deltas) is idempotent and order-independent: the
same transaction state always gives the same balance, however many times or in whatever order it arrives. That makes
"corrected exactly once" (FR-014) and "equals the sum of the effects" (FR-015) true by construction, and it is what the
constitution already asks for (server-authoritative balances reconciled against the log).

**Alternatives considered**:
- *Keep absolute balances, push after each change.* Today's model. Two devices acting on the same item overwrite each
  other, and a rename pushes a stale balance; FR-014 cannot hold.
- *Deltas applied by the server and replayed on devices.* A device that applies a delta and then receives the item row
  containing the same delta counts it twice, and an offline device cannot know which deltas the server already
  applied.
- *SQLite triggers instead of a Dart helper.* They would also fire for remote rows, but Drift's streams do not see
  changes made by triggers, so every table would need manual update notifications, and the logic would live in two
  languages with no unit test. A Dart helper called by every writer is one tested function.
- *Compute the balance on every read* (no stored column). Every screen reads `balance` from the item; a stored,
  recomputed value keeps all of them unchanged.

## Decision 2: a reversal is a normal positive row with `reverses_id` (the answer to "a negative transaction")

**Decision**: a reversal is a new `financial_transactions` row with the same `direction` and the same `amount` as the
original, the original's item, `occurred_at` = the moment of the reversal, and `reverses_id` = the original's id. Its
effect is the original's effect negated. "Reversed" is derived: an original is reversed when a live row with
`reverses_id` = its id exists. A unique index on `reverses_id` allows at most one.

**Rationale**: `amount` is always positive in the table and on the server (`check (amount > 0)`), and every report adds
amounts by direction. A negative amount would break both, or would silently subtract from a total in the month it is
made. A row that says "I cancel that one" keeps both honest: reports can show it as its own figure (Decision 7), and
the link makes the pair visible in the history. This is the standard accounting reversing entry, and it does not
affect any other logic than the ones this plan lists (balances, reports, history rows, sync guards).

**Alternatives considered**:
- *Negative `amount`.* Needs the check constraint dropped and every sum to learn about signs.
- *Opposite `direction`* (an expense reversed by an income row). A refund would count as income in every total and in
  the "allocated" side of the per-item report, and an old device would show it as income.
- *A `reversed` flag on the original.* A second write to a row another device may be changing at that moment, and no
  once-only guarantee without a server rule anyway.

## Decision 3: the correction window is judged on the device

**Decision**: the policy is `now − occurred_at < 24 h`, evaluated on the device at the moment the person acts, using
the transaction's `occurred_at`. The server checks structure (Decision 5) but never the clock.

**Rationale**: the spec requires an action allowed offline to be kept when it syncs later (FR-002). The server cannot
know the device's clock at that moment, and rejecting a late arrival would make a visibly successful action vanish.
An edit never changes `occurred_at`, so the window cannot be extended by editing.

**Alternatives considered**: judging by server time at push (rejects offline work, rejected by the owner); a signed
timestamp from the server (needs a round trip the offline case does not have).

## Decision 4: income events are the rows with the same `occurred_at`

**Decision**: the entries of one income are the rows with `direction = income`, no `reverses_id`, and the same
`occurred_at` (and the same user). Deleting inside the window soft-deletes all of them in one local transaction;
reversing creates one reversal row per entry in one local transaction, all with the same `occurred_at`. The balance
restored for each entry is the amount recorded in that row.

**Rationale**: `applyIncomeAllocation` already captures one `now` for every row of an action, so this identifies events
for new and for existing rows alike, with no new column and no migration of history.

**Alternatives considered**: an `event_id` column (cleaner but needs a backfill that can only guess for old rows, and a
server and app change for no behavior the same-time rule does not give); one row for the whole income (a rewrite of
the allocation model).

## Decision 5: the server guards decide every conflict, the same everywhere

**Decision**: Postgres triggers on `financial_transactions` (full text in `contracts/server-ledger.md`):
1. *Delete wins.* Once `deleted_at` is set it cannot be cleared, and deleting an original also deletes its reversal.
2. *A reversed row is frozen for edits.* An update that changes the amount or the item of a row that has a live
   reversal is refused (`transaction_reversed`); a delete is still accepted.
3. *A reversal is normalized.* On insert, its direction, amount and item are copied from the original as it stands
   then; it is refused if the original is itself a reversal, is deleted, or does not exist.
4. *A reversal never changes.* An update of a reversal row other than the cascaded delete is refused.
5. *Once only.* The unique index on `reverses_id` refuses a second reversal.
6. After each change, the balances of the old and the new item are recomputed (Decision 1).

**Rationale**: these rules give one outcome for any arrival order (spec FR-014): a delete beats an edit and beats a
reversal, two edits keep the last (the existing last-write-wins by `updated_at`), and a reversal cancels the amount the
server holds when it is applied.

**Alternatives considered**: client-side resolution (two offline devices cannot agree without the server's order);
Postgres `SECURITY DEFINER` functions called through RPC (a second path next to the upsert the sync worker already
uses; triggers keep one path).

## Decision 6: a refused change is reported once and never retried forever

**Decision**: the sync worker separates a transient failure (network, 5xx: retry as today) from a refusal (an error
code raised by the guards, a unique violation, a check violation): a refused outbox row gets `rejected_at` and
`reject_reason`, is not retried, and the local data is repaired (a refused insert is removed locally, because the
server never had the row; a refused update is replaced by the server's current row **unconditionally**, because a local
edit carries a device-made `updated_at` that may be newer than the server's and the usual "strictly newer wins" check
would keep the refused edit); the balances are recomputed, and the sync notices holder exposes the refusal once so the
screen can tell the person that their change no longer applies (FR-014). Showing the notice deletes the rejected
outbox row. Outbox rows that are not about transactions behave exactly as before.

The person is also told about a change that was **overridden** without being refused, because the guards return the
row as it now stands (a delete beating an edit) and last-write-wins replaces an earlier edit: (a) at push time, when the
row the server returns differs from what was pushed in its amount, item or `deleted_at`; (b) when a pulled row changes
the amount, item or deleted state of a transaction for which this device synced an edit within the last 24 hours (read
from the outbox, `synced_at` and the row id). Both raise the same one-time notice (`SyncNotice`, reason `deleted`,
`reversed`, `alreadyReversed` or `editedElsewhere`). Overrides are held in memory until shown; refusals survive a
restart because they stay on their outbox row until acknowledged.

A push **response** is applied unconditionally, not through the strictly-newer check, unless a later entry for the same
row is still waiting in the outbox (that entry will push and its own response will settle the row). Root cause: the
`updated_at` of a local write is the device's clock while the server issues its own, so when the device clock runs
ahead the strictly-newer check ignores the server's row, and "delete wins" or the normalisation of a reversal would
never reach the device that acted; the device would also keep a future-dated `updated_at` that makes it ignore every
later change made elsewhere. Applying the response replaces the device-made timestamp with the server's.

**Rationale**: today every failure is retried forever, which is wrong for a refusal that can never succeed and gives
the person no signal. Two columns on the outbox are the smallest honest record of "this was refused"; the overridden
cases need no column, only a comparison, so nothing is stored for them.

**Alternatives considered**: deleting the outbox row on refusal (the person is never told, and the audit of what was
refused is lost); a separate notifications table (more machinery than two columns).

## Decision 7: reports show reversals as their own figures

**Decision**: `computeReportTotals` and `computeReportBreakdown` ignore reversal rows in the income, spending, spent and
allocated figures and sum them into two new figures, `refundedExpense` and `withdrawnIncome`, in the month of the
reversal's own `occurred_at`. The history list and the overview list show reversal rows as rows (linked to their
original) and mark a reversed original; filters and the monthly expense total follow the same rule.

**Rationale**: it is exactly the spec's FR-010 and SC-007: a closed month never changes because of a later reversal, no
figure goes negative, and a transaction and its reversal are not added together. Existing code already filters out
rows with `deleted_at`, so deleted transactions need no new handling.

**Alternatives considered**: netting the reversal against its original's month (changes closed months, rejected in the
clarification); netting it in its own month (can go negative).

## Decision 8: rollout and mixed versions

**Decision**: the Supabase migration is applied first (it only adds columns, a backfill and triggers, and an old app keeps
working against it except that it can no longer set a balance), then the app is released. Mixed-version behavior is
out of scope (spec Assumptions), but the migration's backfill makes the server and the local migration agree on
`balance_base`, so an updated device never shows a different balance from before.

**Rationale**: the project has one owner and a handful of devices; the safest order is server first, app second.

## Decision 9: testing the invariant and the conflicts

**Decision**: (a) a seeded random-sequence test records, deletes, edits and reverses against an in-memory database and
checks after every step that each balance equals `balance_base` plus the sum of the effects (SC-002); (b) a `FakeServer`
in Dart applies the rules of Decision 5 and the recompute, so two simulated devices with their own database and outbox
can be driven through every conflict of User Story 5 without a network; (c) the SQL is exercised once against the real
project with the QA account using rows prefixed `zz-`, hard-deleted afterwards (the way the pull feature was verified).

**Rationale**: the rules exist twice (SQL and the fake) so the fake must be checked against the real server; (c) is that
check, and it is written into `quickstart.md`.

## Decision 10: the device reconciles its derived balance against the server's, and tells the person when they differ

**Decision**: every item row that arrives from the server (pull, live event or push response) stores its `balance` in
the local-only column `server_balance`; the displayed `balance` stays the value derived from the local transactions. A
`ReconciliationMonitor` runs at settled points (after a catch-up pull completes and after a drain that leaves the
outbox empty) and looks for items whose `server_balance` differs from `balance` while no transaction row of that item
is waiting in the outbox. A difference must be seen twice, at least 10 seconds apart, before it counts (the item row
and its transaction rows can legitimately arrive a moment apart). The first confirmed difference triggers one full
re-fetch of both tables (`PullService.resync`: cursors untouched, every fetched row replaces the local one except a row
with a change still waiting in the outbox, so a stale local copy is really refreshed); if the difference remains after it, the
person is told once (`SyncNotice`, reason `balanceMismatch`) and neither figure is overwritten (FR-018, SC-008).

**Rationale**: the constitution (Offline-First, conflict resolution) says a client must not trust a locally computed
balance as final, must reconcile against the balance recomputed on the Supabase side, and must surface a divergence
rather than silently overwrite local data. Deriving the balance on both sides from the same rows makes a divergence
rare, which is exactly why it must be detected when it does happen (a lost row, a bug).

**Alternatives considered**: adopting the server's figure whenever it differs (silently overwrites, and shows a wrong
figure while rows are still in flight); comparing at the instant the item row is applied (false alarms, because the
item row can arrive before its transactions); amending the constitution to accept "derived by one rule on both sides"
(a governance decision for the owner, kept out of this feature).

## Observations recorded but out of scope

- The `balance` column on the server stays (derived there too) so older readers and the dashboard keep working.
- `ExpenseControlRepository.update` and `create` are changed only to stop sending `balance`; no other behavior of the
  budget plan changes.
