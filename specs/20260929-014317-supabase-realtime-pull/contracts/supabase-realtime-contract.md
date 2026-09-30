# Contract: Supabase-Side Realtime & Trigger Setup

**Feature**: [spec.md](../spec.md) | **Date**: 2026-09-29

This documents the database-level contract this feature depends on —
what the new Postgres migration must establish, and what the Dart pull
service can therefore assume is true about the server side.

## 1. Realtime publication grant

```sql
alter publication supabase_realtime add table expense_control_items;
alter publication supabase_realtime add table financial_transactions;
```

**Idempotency note** (found during implementation, not anticipated in the
original design): `ALTER PUBLICATION ... ADD TABLE` errors if the table is
already a publication member — this is not idempotent by default, unlike
`CREATE OR REPLACE FUNCTION`. Since Supabase migrations are normally
applied once and tracked, this is not an issue in the deployed history,
but a local `supabase db reset` re-runs every migration from scratch
against a fresh database, where it's still a first application and thus
still fine — the actual risk is only a *manual* re-run of this specific
file in isolation. The implementation wraps both grants in a
`pg_publication_tables` existence check (see the actual migration file,
`supabase/migrations/20260929183846_realtime_pull_setup.sql`) for
resilience against that case, at negligible cost.

**Contract**: once applied, both tables' row-level INSERT/UPDATE changes
are delivered to any subscribed, RLS-authorized client via
`supabase_flutter`'s `.channel(...).onPostgresChanges(...)` API
(research.md §0 confirms `supabase_flutter: ^2.8.0`'s modern API surface).
`REPLICA IDENTITY` is left at its Postgres default (research.md
Decision 3) — old-row column data is not part of this contract; only the
new/current row state is guaranteed to be present in each change event,
which is all the pull service needs (research.md Decision 7's
`applyRemoteRow` only ever consumes the new row state).

**RLS interaction**: Realtime change events are still subject to each
table's existing owner-only RLS policy (`expense_control_items_owner_only`,
`financial_transactions_owner_only` — both already present, research.md
§0). A client only receives change events for rows it's authorized to
read under RLS — this is what makes FR-007 hold for the *live* stream, not
only the initial fetch.

## 2. `updated_at` server-authoritative trigger

```sql
create or replace function set_updated_at_to_now()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger expense_control_items_set_updated_at
  before insert or update on expense_control_items
  for each row
  execute function set_updated_at_to_now();

create trigger financial_transactions_set_updated_at
  before insert or update on financial_transactions
  for each row
  execute function set_updated_at_to_now();
```

**Contract**: after this migration, **no client-supplied `updated_at`
value ever reaches storage** on either table, regardless of what any
current or future client code sends in an `upsert()` payload — this is
the enforcement mechanism research.md Decision 1 requires (not merely a
client-side convention). A single shared trigger function is used for
both tables since the logic is identical (`NEW.updated_at = now()`) —
this follows the DRY principle without needing to be a per-table
special-case.

**What the Dart client can now assume**: after any successful `.upsert()`
call, the row Postgres actually stored has an `updated_at` that reflects
the moment the write was processed server-side, not whatever the client
sent. The client MUST read this back via `.upsert(payload).select().single()`
(research.md Decision 1) — the trigger does not itself communicate the
new value back to the client; `.select()` on the same request is what
retrieves it, per Supabase PostgREST's standard "return the row after
write" behavior.

**Idempotency note**: this trigger fires on every INSERT or UPDATE,
including the read-back-driven local reconciliation write — but the local
reconciliation write (research.md Decision 1) only ever writes to Drift,
never back to Supabase, so this does not create a second round-trip or a
trigger-firing loop.

## 3. Migration file placement

New file:
`supabase/migrations/<timestamp>_realtime_pull_setup.sql`, following the
existing chronological-timestamp naming convention already used by all 6
prior migration files (research.md §0's file list). Both the publication
grant (§1) and the trigger setup (§2) belong in this single migration —
they are both prerequisites for this one feature and were both discovered/
decided together during this feature's planning, matching the existing
precedent of one migration file covering one feature's related schema
changes (e.g. `20260924080000_transaction_history_snapshots.sql` covering
several related column additions for one feature).

## Explicitly NOT part of this contract

- **No `REPLICA IDENTITY FULL`** — research.md Decision 3 explicitly
  rejects this; omitted from the migration entirely, not merely left at
  an implicit default.
- **No RLS policy changes** — both tables' existing owner-only policies
  are sufficient and unmodified; this feature does not introduce a new
  access pattern requiring a new policy.
- **No changes to the two tables' column schema** — `updated_at` already
  exists on both (research.md §0); only *how its value is produced*
  changes (the trigger), not the schema itself. See
  [data-model.md](../data-model.md)'s "Modified: `updated_at`
  value-production" section.
