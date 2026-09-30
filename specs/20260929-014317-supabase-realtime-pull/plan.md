# Implementation Plan: Pull Remote Data From Supabase Into Local Database

**Branch**: `20260929-014317-supabase-realtime-pull` | **Date**: 2026-09-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/20260929-014317-supabase-realtime-pull/spec.md`

## Summary

Add the missing pull half of the app's offline-first sync architecture:
subscribe to Supabase Realtime for both syncable tables
(`expense_control_items`, `financial_transactions`), run a keyset-paginated
initial catch-up fetch on sign-in, and apply every pulled/live row to Drift
through a new, outbox-bypassing write path so pulled data never loops back
out as a fake local edit. A new per-`(user, table)` bootstrap-cursor table
tracks pull progress (resumable batching, FR-010/SC-007) and completion
(loading-vs-empty distinction, FR-011/SC-008). This also fixes a
clock-skew bug in the *existing* push path found while specifying this
feature's own conflict-resolution requirement: `updated_at` becomes a
Postgres-trigger-enforced, server-issued timestamp instead of the device
clock, with the client reading the authoritative value back after every
push (FR-005a/SC-006) — a deliberate, constitution-mandated (Development
Workflow, v1.7.0) root-cause fix to the shared push path, not scope creep.

**Scope note (read before assuming this is pull-only)**: per the
constitution's shared-code-bug rule, this feature's scope was deliberately
extended during `/speckit-clarify` to include `SyncWorker.drainOutbox()`
(`lib/core/sync/sync_worker.dart`) and a Supabase-side trigger, because the
clock-skew risk in the existing push path was discovered while specifying
this feature's own pull-side conflict-resolution requirement (FR-005). See
[research.md Decision 1](./research.md#decision-1-updated_at-becomes-server-issued-fr-005a)
for the full design and rejected alternatives.

## Technical Context

**Language/Version**: Dart (project-pinned SDK, via `pubspec.yaml`), Flutter stable channel

**Primary Dependencies**: `supabase_flutter: ^2.8.0` (Realtime `RealtimeChannel`/`.onPostgresChanges` API — already in use for auth/push, no version change needed), `drift: ^2.22.1` + `drift_flutter: ^0.2.4` (local DB, already in use), `flutter_riverpod: ^2.6.1` (DI/state, already in use) — no new package dependency is introduced by this feature (research.md Decision 9 explicitly rejects adding `connectivity_plus`)

**Storage**: Drift (SQLite/`drift_flutter`, already configured for Web via `DriftWebOptions`) — this feature adds one new table (bootstrap/resume cursor, research.md Decision 5) and switches DateTime column storage from Drift's default unix-seconds to ISO-8601 text (`store_date_time_values_as_text`, research.md Decision 10 — required for the conflict-resolution algorithm's `<=` comparison to hold at server-issued microsecond precision), both via a single `schemaVersion` 6→7 migration, following the existing cumulative `if (from <= N)` pattern in `app_database.dart`; Supabase Postgres gains a `BEFORE INSERT OR UPDATE` trigger on both syncable tables (research.md Decision 1) and a Realtime publication grant (research.md Decision 3)

**Testing**: `flutter_test` unit/widget tests (existing pattern) for the pull service, cursor/batching logic, conflict-resolution algorithm, and the `initialPullCompleteProvider` loading-state guard, per constitution Principle II's requirement that the sync worker and conflict-resolution logic be unit-testable without a live Supabase connection (repository interface already wraps the Supabase client per the Offline-First Data & Sync section)

**Target Platform**: Android, iOS, Web (per constitution's Multi-Platform Support) — Realtime subscription and the bootstrap pull must work identically on Web (Drift-on-Web via `DriftWebOptions`, already configured) as on mobile; no platform-conditional pull logic

**Project Type**: Mobile/Web Flutter app (existing single-project structure, no new top-level directory)

**Performance Goals**: SC-001's 10-second initial-pull target for a dataset of up to several thousand rows per table; FR-010's batching MUST NOT block the UI thread for the full pull duration (constitution Principle IV's off-UI-isolate mandate for non-trivial payloads) or hold an entire table's result set in memory at once

**Constraints**: FR-008 — a device with already-correct local data MUST see zero duplicate rows or unexpected changes from a redundant pull (idempotent apply path, research.md Decision 7); FR-007 — the pull MUST rely on Supabase RLS owner-only policies for user-scoping, never a client-side filter alone (RLS already enabled on both tables, confirmed in research.md §0); no new UI beyond the FR-011 loading/skeleton state (spec.md Assumptions explicitly rules out a manual "sync now" button or sync-status indicator)

**Scale/Scope**: 2 syncable tables (`expense_control_items`, `financial_transactions`), 1 new Drift table (bootstrap cursor), 1 new Postgres migration (trigger + Realtime publication grant), modifications to `SyncWorker` (read-back), `ExpenseControlRepositoryImpl` (new `applyRemoteRow` write path), a new pull-service provider following the `syncWorkerProvider` lifecycle pattern, and a new `initialPullCompleteProvider` consumed by every screen that reads pulled data (Home Overview, Expense Control, Transaction History, Monthly Report)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (Code Quality)**: PASS. The new pull service and
  `applyRemoteRow` methods follow this codebase's existing
  single-responsibility pattern (one repository method per distinct write
  intent — see `expense_control_repository.dart`'s existing method list);
  no business logic moves into `build()` methods (the pull service and
  cursor logic are plain Dart, framework-independent, per the Recommended
  Architecture's `domain`/`data` layering).
- **Principle II (Testing Standards)**: PASS. The pull service, keyset
  cursor/batching, and conflict-resolution algorithm (research.md
  Decision 8) are all unit-testable without a live Supabase connection —
  the Supabase client is already wrapped behind repository interfaces
  (`ExpenseControlRepository`, `TransactionHistoryRepository`) per the
  Offline-First Data & Sync section's testability mandate. `SyncWorker`'s
  read-back change (`upsert().select()`) is testable the same way its
  existing `drainOutbox()` logic already is. `/speckit-tasks` owes the
  concrete test file list; no domain-coverage gate is newly at risk since
  this is exactly the kind of domain/data logic the 80% coverage floor
  targets.
- **Principle III (User Experience Consistency & Adaptive Design)**:
  PASS. FR-011's loading/skeleton state reuses this app's existing
  loading-state UI pattern (the constitution already requires "loading
  states... MUST follow the same reusable patterns across the app") rather
  than inventing a bespoke one; no new breakpoint, layout, or navigation
  change is introduced by this feature.
- **Principle IV (Performance Requirements)**: PASS. FR-010's batched,
  per-batch-transaction fetch is designed specifically to satisfy this
  principle's off-UI-isolate and non-blocking mandates for the "thousands
  of rows" scale this feature targets; `/speckit-tasks`/`/speckit-implement`
  own profiling if a concrete batch size needs tuning, but the design
  itself (bounded batches, not one unbounded query) is what the principle
  requires.
- **Recommended Architecture**: PASS, with a disclosed, deliberate scope
  expansion — same pattern as the immediately preceding
  transaction-history-redesign feature. This feature's change is not
  confined to a single feature directory: it also modifies
  `lib/core/sync/sync_worker.dart` (FR-005a read-back) and adds a new
  `core/sync/` provider (`initialPullCompleteProvider`) and Drift table
  (bootstrap cursor). Both are exactly what `core/` is for per this
  section's own rule ("something belongs in `core/` only if it is used by
  two or more features") — the pull mechanism and its loading state are
  used by every screen that reads syncable data, not one feature. No
  feature reaches into another feature's internals; `ExpenseControlRepositoryImpl`
  gains new methods (`applyRemoteRow`) but its existing public interface
  and call sites are unchanged.
- **Offline-First Data & Sync**: PASS — this section's own text already
  mandates the pull mechanism this feature builds ("the app MUST use
  Supabase Realtime... to receive remote updates and upsert them into
  Drift, rather than polling"); this feature is that mandate's first
  implementation, not a new policy. Conflict resolution
  (research.md Decision 8) implements this section's already-decided
  last-write-wins-by-`updated_at`/server-authoritative-balances policy
  without inventing a new one. The FR-005a trigger is what makes
  `updated_at` actually trustworthy for that comparison, closing a gap in
  this section's existing policy rather than changing the policy itself.
- **Multi-Platform Support**: PASS. The pull/Realtime path is
  platform-uniform — no `Platform.is*`/`kIsWeb`/`defaultTargetPlatform`
  branch is introduced; Drift-on-Web (`DriftWebOptions`, already
  configured per research.md §0) is unmodified and the bootstrap-cursor
  table is just another Drift table, working identically on Web as on
  mobile. `/speckit-tasks`'s Polish phase MUST verify the pull on Web
  alongside mobile, per this section's "every new feature's plan MUST
  state whether it was verified on Web" requirement.
- **Security**: PASS. The pull relies exclusively on Supabase RLS
  owner-only policies (already enabled on both tables, confirmed in
  research.md §0) for user-scoping (FR-007) — no client-side filter is
  the sole enforcement mechanism. The Realtime channel subscription
  inherits the same authenticated Supabase client already used for
  push/auth (no new credential/token surface). No raw financial data is
  newly logged — the pull service follows the same logging-discipline
  constraint as existing sync code.
- **Development Workflow**: PASS. Feature branch already created. This
  plan's scope expansion into `core/sync/sync_worker.dart` is exactly the
  scenario the Development Workflow section's shared-code-bug bullet
  (v1.7.0) describes and requires — a real bug (client-clock
  `updated_at`) found in shared code while specifying an unrelated,
  narrower feature (the pull path), fixed at its root rather than
  patched or deferred, with the rationale documented here and in
  research.md Decision 1. Per this section's "breaking changes to shared
  `core/` utilities REQUIRE explicit call-out in the PR description" rule,
  the eventual PR MUST explicitly call out the `sync_worker.dart` change,
  the new `core/sync/` additions, and reference research.md Decision 1 —
  not optional, independent of this plan's own recommendation.

No violations — Complexity Tracking table is not needed. The `core/sync/`
and `sync_worker.dart` changes are a disclosed, constitution-mandated scope
expansion, not an unjustified complexity requiring a Complexity Tracking
entry.

**Post-Design Re-check**: re-evaluated after Phase 1 produced
[data-model.md](./data-model.md) (the new `PullCursor` table + the
`BEFORE INSERT OR UPDATE` trigger's schema-adjacent impact) and
[contracts/](./contracts/) (the `applyRemoteRow` repository addition and
the Supabase-side Realtime/trigger contract). No new violation surfaces:
`PullCursor` is exactly the kind of shared sync-infrastructure state
`core/database/` already holds (`SyncOutbox` is the existing precedent);
`applyRemoteRow` extends an existing repository interface rather than
introducing a new architectural layer; the Postgres trigger and
publication grant are additive schema/config changes on tables that
already have RLS and the columns they need, not a new table or a new
access pattern. All gates above still hold as written.

**Second Post-Design Re-check**: a further advisor-assisted review of the
*integrated* design (not any single decision in isolation) surfaced two
issues after the first re-check above, both resolved and folded back into
research.md/data-model.md before this plan was closed: (1) research.md
Decision 8's conflict-resolution idempotency check needed `<=` instead of
`==` to close a real concurrent-write race between an in-flight pull batch
and a just-completed push; (2) that fix's correctness in turn depends on
DateTime precision Drift does not provide by default (unix-seconds
truncates the sub-second precision Postgres's trigger-issued timestamps
carry), resolved by research.md Decision 10 (switch to
`store_date_time_values_as_text`, explicitly confirmed with the user rather
than assumed, per Constitution Check's root-cause-over-patch standard).
Neither changes this Constitution Check's verdict on any principle — both
are refinements within the already-approved `core/database/`/`core/sync/`
scope, not a new violation or a new architectural surface.

## Project Structure

### Documentation (this feature)

```text
specs/20260929-014317-supabase-realtime-pull/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── checklists/
│   └── requirements.md  # /speckit-specify output, re-validated by /speckit-clarify
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
build.yaml                                                     # NEW: enables store_date_time_values_as_text for drift_dev codegen (research.md Decision 10)

lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart                              # MODIFIED: register new PullCursor table, schemaVersion 6→7, new if (from <= 6) migration branch that creates PullCursor AND converts existing DateTime columns to text storage (research.md Decisions 5 and 10)
│   │   └── tables/
│   │       └── pull_cursor_table.dart                      # NEW: (user_id, table_name) PK, last_updated_at, last_id, initial_pull_completed (research.md Decision 5)
│   └── sync/
│       ├── sync_worker.dart                                # MODIFIED: drainOutbox() reads updated_at back via .upsert().select(), writes it through the shared remote-row write helper below (research.md Decision 1)
│       ├── remote_row_writer.dart                           # NEW: applyRemoteExpenseControlItem()/applyRemoteFinancialTransaction() — the outbox-bypassing, idempotent-on-<= write path (research.md Decision 7, CORRECTED placement — operates directly on AppDatabase, same core/sync/ pattern SyncWorker already uses, NOT on ExpenseControlRepository/Impl; contracts/pull-write-helper.md)
│       ├── pull_service.dart                                # NEW: subscribe-first-then-fetch orchestration (research.md Decision 2), keyset batching (Decision 4), cursor advancement (Decision 5) — calls remote_row_writer.dart
│       ├── pull_service_provider.dart                       # NEW: Provider<PullService>, lifecycle pattern mirrors sync_worker_provider.dart — instantiate, start, ref.onDispose
│       └── initial_pull_complete_provider.dart               # NEW: Provider<bool>, AND of PullCursor.initialPullCompleted across syncable tables for currentUserIdProvider (research.md Decision 6)
├── features/
│   └── expense_control/
│       └── data/
│           └── expense_control_repository_impl.dart         # MODIFIED, but ONLY for the unrelated FR-005a text-storage audit fix: applyIncomeAllocation()/recordExpense()'s raw customUpdate() calls now write now.toIso8601String() instead of millisecondsSinceEpoch~/1000 (research.md Decision 10's audit finding). NOT modified for pull — no new method, per Decision 7's corrected placement; ExpenseControlRepository/TransactionHistoryRepository interfaces are untouched.
└── features/
    ├── expenses/presentation/                                # transaction_history_screen.dart and others: consume initialPullCompleteProvider per FR-011 (research.md Decision 6)
    ├── accounts/ (or wherever Home Overview lives)            # same FR-011 consumption
    └── reports/ (Monthly Report)                              # same FR-011 consumption

supabase/
└── migrations/
    └── <timestamp>_realtime_pull_setup.sql                   # NEW: BEFORE INSERT OR UPDATE trigger on both tables (research.md Decision 1), ALTER PUBLICATION supabase_realtime ADD TABLE ... (research.md Decision 3) — no REPLICA IDENTITY change

test/
├── unit/
│   └── core/
│       ├── database/
│       │   └── app_database_migration_test.dart              # MODIFIED (existing file): add schemaVersion 6→7 migration coverage — PullCursor creation AND DateTime-to-text conversion of existing rows (research.md Decisions 5 and 10)
│       └── sync/
│           ├── pull_service_test.dart                        # NEW: subscribe/fetch ordering, batching, cursor advancement, idempotency
│           └── conflict_resolution_test.dart                 # NEW: research.md Decision 8's 5-step algorithm (including the `<=` sub-second-precision race case, research.md Decision 10), including the pending-outbox-entry-survives case (SC-004)
└── widget/
    └── features/
        ├── expenses/transaction_history_screen_test.dart      # MODIFIED (existing file): add FR-011 loading-vs-empty coverage
        └── (other screens consuming initialPullCompleteProvider): same FR-011 coverage
```

**Structure Decision**: Single Flutter project, existing feature-first
layout (constitution's Recommended Architecture). Per the Constitution
Check and research.md above, this feature's primary work lives in
`core/sync/` (new pull service, cursor table, loading-state provider) and
`core/database/` (new table + migration) — a deliberate `core/` placement
because the pull mechanism and its loading state are shared by every
screen reading syncable data, not owned by one feature. The
`expense_control` feature's repository gains new methods
(`applyRemoteRow`) but its existing public interface and all current call
sites are unchanged. Every screen that already reads pulled data through
its existing `StreamProvider` gains one additional `ref.watch` on
`initialPullCompleteProvider` (research.md Decision 6) — no screen's
existing empty/data/error handling logic is restructured.

## Complexity Tracking

Not applicable — the Constitution Check above has no violations to justify.
