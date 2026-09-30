# Data Model: Pull Remote Data From Supabase Into Local Database

**Feature**: [spec.md](./spec.md) | **Date**: 2026-09-29

This feature introduces exactly one new persisted entity (the bootstrap
cursor). It does not add any new domain-facing entity — pulled rows are the
same `ExpenseControlItem`/`FinancialTransactionRow` local rows and
`expense_control_items`/`financial_transactions` Supabase tables that
already exist (spec.md Key Entities). This document also records the
non-additive schema change (FR-005a's trigger) since it changes how an
existing column's value is produced, even though it adds no new column.

## New entity: `PullCursor`

Drift table, `lib/core/database/tables/pull_cursor_table.dart` (new file).
Tracks whether a given user's given syncable table has completed its
initial catch-up pull, and where a resumable batch fetch should continue
from (research.md Decisions 4 and 5).

| Column (Dart) | SQL name | Type | Notes |
|---|---|---|---|
| `userId` | `user_id` | `TextColumn` | Part of composite PK. Matches `expense_control_items.user_id`/`financial_transactions.user_id` in shape (both are `TextColumn` locally, backed by `uuid` server-side per existing tables). |
| `syncTableName` | `table_name` | `TextColumn` | Part of composite PK. One of the two syncable table names (`expense_control_items`, `financial_transactions`) — stored as plain text, not an enum, to avoid a schema change if a third syncable table is added later (spec.md Assumptions explicitly scopes that out of *this* feature, but the column itself needn't hardcode the count). **Named `syncTableName` in Dart, not `tableName`** — discovered during implementation that `tableName` collides with Drift's `Table.tableName` override point (a real compile error, not a style choice); the SQL column name stays `table_name` via `.named('table_name')` so the on-disk schema matches this document unchanged. |
| `lastUpdatedAt` | `last_updated_at` | `DateTimeColumn`, nullable | The `updated_at` of the last successfully-committed row in keyset order (research.md Decision 4). Null until the first batch commits. |
| `lastId` | `last_id` | `TextColumn`, nullable | The `id` of the last successfully-committed row, breaking ties when multiple rows share `lastUpdatedAt` (keyset pagination requires both columns — research.md Decision 4's `WHERE (updated_at, id) > (...)`). Null until the first batch commits. |
| `initialPullCompleted` | `initial_pull_completed` | `BoolColumn`, default `false` | Becomes `true` once every batch for this `(user_id, table_name)` has been fetched and its transaction committed — read by `initialPullCompleteProvider` (research.md Decision 6). |

**Primary key**: `(userId, tableName)` — composite, declared via Drift's
`@override Set<Column> get primaryKey => {userId, tableName};` pattern
(matching this codebase's existing composite-constraint style, e.g. the
partial index already used on `SyncOutbox`).

**Lifecycle**:

1. Row does not exist for a given `(user_id, table_name)` → the pull
   service treats this as "never started," beginning keyset pagination
   from the start (`lastUpdatedAt`/`lastId` both null → no `WHERE`
   lower-bound clause on the first fetch).
2. After each batch's Drift transaction commits (research.md Decision 4),
   the row is upserted with the batch's last row's `(updated_at, id)`.
3. Once a fetch returns fewer rows than the batch size (the standard
   keyset-pagination "no more pages" signal), `initialPullCompleted` is
   set `true` in the same final upsert.
4. On reconnect (FR-002a), the pull service reads the existing row (if
   `initialPullCompleted` is already `true`, this is "re-run a full pull"
   in the spec's sense — see research.md Decision 5 for why this resumes
   from the existing cursor position rather than resetting it) and
   continues/re-verifies from there.
5. A different user signing in on the same device has no `PullCursor` row
   for their `user_id` yet — their bootstrap starts fresh, independent of
   whatever the previously-signed-in user's rows show (this is the
   per-user scoping research.md Decision 5 requires).

**Migration**: `schemaVersion` 6 → 7 in `app_database.dart`, new
`if (from <= 6) { await m.createTable(pullCursor); }` branch appended to
the existing cumulative migration list (matching the established pattern
— see research.md §0 for the existing `if (from <= N)` precedent and its
documented rationale). This same 6→7 migration step also performs the
DateTime storage conversion required by research.md Decision 10 (see
below) — both changes land in one version bump, not two.

**Not modeled as a domain entity**: `PullCursor` is pure sync-infrastructure
state, analogous to `SyncOutbox` — it has no repository-interface,
domain-layer representation, or UI-facing read path of its own (only
`initialPullCompleteProvider`, a boolean projection, is consumed outside
`core/sync/`).

## Modified: `updated_at` value-production (no schema change, FR-005a)

No new column is added to `expense_control_items` or
`financial_transactions` — `updated_at` already exists on both (confirmed
in research.md §0). What changes is *how its value is produced*:

- **Before this feature**: client-supplied (`DateTime.now()` at write
  time), sent explicitly in every `upsert()` payload.
- **After this feature**: a Postgres `BEFORE INSERT OR UPDATE` trigger
  (new migration, `supabase/migrations/<timestamp>_realtime_pull_setup.sql`)
  unconditionally sets `NEW.updated_at = now()`, ignoring any
  client-supplied value. The client's local Drift row is then reconciled
  to match via `SyncWorker`'s `.upsert().select()` read-back (research.md
  Decision 1), applied through the same `core/sync/` remote-row write
  helper pulled rows use (research.md Decision 7 — corrected placement:
  a `core/sync/` helper, not a repository method) — not a second,
  separate local-write mechanism.

Historical rows already on Supabase are **not** backfilled/rewritten —
their existing client-clock `updated_at` remains as the best available
record of when that write actually happened (research.md Decision 1's
migration note; also recorded in spec.md Assumptions).

## Modified: DateTime column storage encoding (schema-adjacent, Decision 10)

Not a column addition or removal, but a change to how every existing
`DateTimeColumn` is encoded locally: `store_date_time_values_as_text: true`
is enabled in a new `build.yaml` (research.md Decision 10), switching
Drift's local storage from unix-seconds integers to ISO-8601 text for
`created_at`, `updated_at`, and `deleted_at` on both `ExpenseControlItems`
and `FinancialTransactions`, and for `PullCursor.lastUpdatedAt` (defined
as text-backed from creation, since it's a new column in the same
migration). The same 6→7 migration that creates `PullCursor` also converts
every existing DateTime value on both pre-existing tables from
integer-seconds to the equivalent ISO-8601 text representation — this is
necessary for research.md Decision 8's `<=` conflict-resolution comparison
to be correct at full server-issued (microsecond) precision rather than
truncated to whole seconds.

## Entity relationships

```text
PullCursor (new)
  (user_id, table_name) — no FK constraint to expense_control_items/
  financial_transactions (table_name is a name, not a row reference;
  this table tracks pagination progress across a whole table, not a
  per-row relationship)

expense_control_items (existing, unmodified schema)
  updated_at production changes (server trigger, see above)
  local reads/writes for user-initiated edits: unchanged, still via
  ExpenseControlRepositoryImpl
  remote-authoritative writes (pull/live/read-back): via a new
  core/sync/ helper (applyRemoteExpenseControlItem), NOT via
  ExpenseControlRepositoryImpl (research.md Decision 7, corrected)

financial_transactions (existing, unmodified schema)
  updated_at production changes (server trigger, see above)
  local reads/writes for user-initiated edits: unchanged, still via
  ExpenseControlRepositoryImpl (same class implements
  TransactionHistoryRepository)
  remote-authoritative writes (pull/live/read-back): via a new
  core/sync/ helper (applyRemoteFinancialTransaction), same correction

sync_outbox (existing, unmodified schema)
  UNCHANGED by pull writes — the core/sync/ remote-row write helper
  never inserts into this table (research.md Decision 7); only
  user-initiated edits via ExpenseControlRepositoryImpl do
```

## Validation rules

- `PullCursor.userId`/`syncTableName` MUST NOT be empty strings — mirrors the
  existing non-empty-string check pattern already used elsewhere in this
  schema (e.g. `expense_control_items.name`'s
  `check (char_length(name) > 0)` on the Supabase side; the Drift-side
  equivalent is enforced at the repository/service layer since Drift
  itself doesn't have a direct `CHECK` constraint API for this).
- `PullCursor.lastUpdatedAt`/`lastId` MUST both be null or both be
  non-null — never one without the other, since keyset pagination's
  `WHERE (updated_at, id) > (...)` clause requires both values together
  (research.md Decision 4).
- A pulled/live row's write via the `core/sync/` remote-row write helper
  (research.md Decision 7, corrected placement) MUST use the exact
  idempotency check from research.md Decision 8 step 1 (skip if incoming
  `updated_at` is less than or equal to local `updated_at` — not merely
  equal) before writing — this is what makes FR-004's idempotency
  guarantee and FR-008's "no duplicate/unexpected changes for an
  already-correct device" hold under concurrent writes, not only
  sequential ones (research.md Decision 8's race-condition note).
