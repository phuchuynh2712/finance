# Contract: `core/sync/` Remote-Row Write Helper

**Feature**: [spec.md](../spec.md) | **Date**: 2026-09-29

**Corrected placement** (found during `/speckit-implement`, before any code
was written against the original version of this contract): this write
logic does **not** live on `ExpenseControlRepository`/
`ExpenseControlRepositoryImpl` — the domain entity `ExpenseControlItem` has
no `updatedAt`/`deletedAt` fields by design (sync metadata has never been
part of this app's domain vocabulary), so a domain-interface method cannot
receive the fields this logic actually needs without violating the
constitution's "domain has zero dependency on Drift" rule or inventing an
unjustified new type. This document instead describes an internal `core/
sync/` helper — the same placement `SyncWorker` already uses for
sync-infrastructure work that operates directly on `AppDatabase` rather
than through a feature repository. See research.md Decision 7 for the full
correction and rejected alternatives. `ExpenseControlRepository`'s public
interface and `ExpenseControlRepositoryImpl`'s implementation are
**unchanged** by this feature.

## `applyRemoteExpenseControlItem` — expense control items

```dart
/// Writes a remote-authoritative row (from the initial pull or a live
/// Realtime event) into the local expense_control_items table. Lives in
/// `core/sync/` (e.g. as a private method on PullService, or a small
/// shared helper both PullService and SyncWorker's read-back call) — NOT
/// on ExpenseControlRepository/ExpenseControlRepositoryImpl (research.md
/// Decision 7's correction).
///
/// Unlike every write method on ExpenseControlRepositoryImpl (`create`,
/// `update`, `reorderTopLevel`, `saveFormulas`, `applyIncomeAllocation`,
/// `recordExpense`), this MUST NOT append an entry to `sync_outbox` — the
/// row's authoritative state already came FROM Supabase, so re-queuing it
/// for push would create an infinite pull→outbox→push→pull loop
/// (research.md Decision 7).
///
/// Idempotency (FR-004, research.md Decision 8 step 1): if [row]'s
/// `updatedAt` is less than or equal to the local row's current
/// `updatedAt` (not merely equal — this also covers an in-flight batch
/// delivering a stale value after a newer one already landed locally,
/// research.md Decision 8's race-condition note), this call MUST be a
/// no-op — no write, no local `updatedAt` change, nothing beyond what
/// the first application of this exact-or-newer row state already did.
///
/// A soft-deleted remote row (non-null `deletedAt`) is applied using the
/// same tombstone convention local soft-deletes already use (FR-003) —
/// this does not special-case deletion, since the local schema treats
/// "row has deletedAt set" uniformly regardless of write origin.
Future<void> applyRemoteExpenseControlItem(
  AppDatabase db,
  ExpenseControlItemRow row,
);
```

**Preconditions**: `row.userId` MUST equal the currently signed-in user's
ID — the pull service is responsible for only ever fetching/receiving rows
scoped to the signed-in user (FR-007, enforced primarily by Supabase RLS;
this is a defense-in-depth check, not the primary enforcement mechanism).
**A mismatch is a silent no-op, not a thrown error** (found during
`/speckit-implement`: an `assert()`-based version crashes in debug/test
builds — inappropriate for a runtime data condition that can occur
legitimately, e.g. a stale in-flight fetch racing a sign-out — rather
than a programmer error `assert` exists to catch).

**Postconditions**:

- If `row.updatedAt` is less than or equal to the existing local row's
  `updatedAt`: no change (idempotent no-op).
- Otherwise: the local row is upserted (inserted if it doesn't exist
  locally yet, updated if it does) to exactly match `row`'s field values,
  including `deletedAt`. No `sync_outbox` entry is created.
- Callers (the pull service and `SyncWorker`'s read-back path) are
  responsible for calling this inside the same batch/transaction boundary
  their own consistency requirements need (e.g. FR-010's "each batch as
  its own local transaction") — this itself does not impose a transaction
  scope beyond its own single-row write.

## `applyRemoteFinancialTransaction` — financial transactions

Same contract, parallel signature, for the other syncable table:

```dart
/// See applyRemoteExpenseControlItem above — identical contract (no
/// outbox entry, idempotent on updatedAt <= local, uniform soft-delete
/// handling), applied to financial_transactions instead.
Future<void> applyRemoteFinancialTransaction(
  AppDatabase db,
  FinancialTransactionRow row,
);
```

## Explicitly NOT part of this contract

- **No batch/bulk variant** (e.g. a list-taking version) is required — the
  pull service (research.md Decision 4) is responsible for iterating a
  fetched batch and calling the single-row helper per row inside its own
  transaction, matching this codebase's existing pattern of
  transaction-wrapping at the call site (`_db.transaction(() async { ...
  })` in every existing mutation method, research.md §0). A future
  performance pass MAY introduce a batched variant if profiling shows it's
  needed — not assumed necessary here.
- **No conflict-resolution logic lives inside these helpers themselves** —
  the idempotency check (skip if `updatedAt` not strictly newer) is the
  only comparison either helper makes. The broader conflict-resolution
  algorithm (research.md Decision 8, including "the outbox is never
  touched by a pull") is the pull service's responsibility, not either
  helper's; each is a straightforward idempotent upsert, not a merge
  function.
- **No `ExpenseControlRepository`/`TransactionHistoryRepository` interface
  change of any kind** — both interfaces and their shared implementation
  class are untouched by this feature.
