# Tasks: Pull Remote Data From Supabase Into Local Database

**Input**: Design documents from `specs/20260929-014317-supabase-realtime-pull/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Included — constitution Principle II mandates unit tests for the sync worker and conflict-resolution logic (unit-testable without a live Supabase connection), and widget/golden coverage at both breakpoints for any screen with new behavior; this feature's FR-011 loading-state change touches every screen reading pulled data, so per-screen test tasks are included.

**Organization**: Tasks are grouped by user story per spec.md's priorities: User Story 1 (P1, MVP — data appears on a second device) and User Story 2 (P2 — a pulled row never destructively collides with an unsynced local edit). Foundational work — the schema migration, the Supabase-side trigger/publication, the conflict-resolution algorithm, and the `core/sync/` remote-row write path — is Phase 2 because **both** user stories depend on it; neither story is meaningfully testable without it.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- File paths are exact, per plan.md's Project Structure

## Path Conventions

Single Flutter project (existing structure) — `lib/`, `test/`, `supabase/migrations/`, `build.yaml` (new, repo root), per plan.md.

---

## Phase 1: Setup

**Purpose**: Enable the DateTime text-storage build option before any table/migration work depends on it (research.md Decision 10) — this MUST happen first since it changes what "correct" DateTime-writing code looks like for every subsequent task.

- [X] T001 Create `build.yaml` at the repository root enabling `store_date_time_values_as_text: true` for `drift_dev` codegen (research.md Decision 10) — follow the exact key path Drift's official `build.yaml` documentation specifies for this build option; verify `flutter pub run build_runner build --delete-conflicting-outputs` regenerates `app_database.g.dart` (and the two table `.g.dart` files) with `DateTimeColumn`s now mapping to `TEXT` instead of `INTEGER` in the generated schema before proceeding to any other task.

**Checkpoint**: `build.yaml` in place, codegen regenerated. Every subsequent task that touches a `DateTimeColumn` write path now operates against the new (not-yet-migrated-on-disk) expectation.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure both user stories depend on — the schema migration (new table + DateTime encoding conversion), the Supabase-side trigger/publication, the outbox-bypassing write path, and the conflict-resolution algorithm. Neither User Story 1 nor User Story 2 can be meaningfully implemented or tested before this phase completes.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Local schema migration (research.md Decisions 5, 10; data-model.md)

- [X] T002 Define the `PullCursor` Drift table in `lib/core/database/tables/pull_cursor_table.dart` per data-model.md: `userId TextColumn`, `tableName TextColumn`, `lastUpdatedAt DateTimeColumn` (nullable), `lastId TextColumn` (nullable), `initialPullCompleted BoolColumn` (default `false`), composite primary key `(userId, tableName)` via `@override Set<Column> get primaryKey => {userId, tableName};` — matching this codebase's existing table-definition style (see `sync_outbox_table.dart` for the sibling sync-infrastructure table's conventions).
- [X] T003 Register `PullCursor` in `lib/core/database/app_database.dart`'s `@DriftDatabase(tables: [...])` annotation, alongside the existing 3 tables.
- [X] T004 In `lib/core/database/app_database.dart`, bump `schemaVersion` from `6` to `7` and add a new `if (from <= 6) { ... }` branch to the migration strategy (following the existing cumulative pattern documented at the top of the `migration` getter) that: (a) creates the `PullCursor` table (`await m.createTable(pullCursor)`); (b) converts every existing `DateTimeColumn` on `ExpenseControlItems` and `FinancialTransactions` (`created_at`, `updated_at`, `deleted_at` on both) from integer-seconds to ISO-8601 text, using Drift's official `Migrator.alterTable(TableMigration(...))` pattern with `columnTransformer` reading via `column.dartCast<int>()` and converting via `DateTimeExpressions.fromUnixEpoch(...)` (research.md Decision 10's verified mechanics — the exact pattern is documented at `drift.simonbinder.eu/guides/datetime-migrations/` and mirrored in research.md). **MUST** source the tables to migrate from `schema.entities.whereType<TableInfo>()` (the step-scoped schema snapshot), **NOT** `allTables` — using `allTables` in a step-by-step migration is a documented data-loss pitfall (GitHub Discussion #3603, cited in research.md Decision 10); do not deviate from this without re-reading that discussion first.
- [X] T005 [P] Write a migration-path unit test in `test/unit/core/database/app_database_migration_test.dart` (existing file — add to it, don't replace) covering the 6→7 step specifically: seed a v6 in-memory database with integer-encoded `updated_at`/`created_at`/`deleted_at` values on both tables (including at least one row with a non-null `deleted_at`, and one with sub-second-losing values to document the precision the OLD encoding lacked), run the migration, and assert (a) `PullCursor` exists and is empty, (b) every migrated row's DateTime values round-trip correctly as ISO-8601 text and are readable via the regenerated typed API, (c) no row is lost or duplicated (directly guards against the Discussion #3603 failure mode T004 must avoid).
- [X] T006 [P] Fix `ExpenseControlRepositoryImpl.applyIncomeAllocation()` and `.recordExpense()` in `lib/features/expense_control/data/expense_control_repository_impl.dart` (lines ~386-396 and ~453-463) — change both raw `_db.customUpdate(...)` calls' `updated_at = ?` binding from `Variable(now.millisecondsSinceEpoch ~/ 1000)` to `Variable(now.toIso8601String())`, matching the encoding every other `DateTimeColumn` write now uses post-T001/T004 (research.md Decision 10's audit finding — required for correctness, not optional; these two call sites bypass the generated typed API via raw SQL and would otherwise silently write malformed data into a TEXT-typed column).

### Supabase-side setup (research.md Decisions 1, 3; contracts/supabase-realtime-contract.md)

- [X] T007 [P] Create `supabase/migrations/<timestamp>_realtime_pull_setup.sql` (timestamp per the existing chronological-naming convention — use the actual current date/time when this task is executed) containing: (a) `alter publication supabase_realtime add table expense_control_items, financial_transactions;`; (b) the `set_updated_at_to_now()` trigger function and both tables' `BEFORE INSERT OR UPDATE` triggers, exact SQL per contracts/supabase-realtime-contract.md §§1-2. Do **not** add a `REPLICA IDENTITY FULL` statement (research.md Decision 3 explicitly rejects it).
- [X] T008 Apply the T007 migration to the local/dev Supabase project (per this repo's existing `supabase/` migration-application workflow) and manually verify via the Supabase dashboard or `psql`: the publication now includes both tables, and a test `UPDATE` on either table with an explicit stale `updated_at` in the statement is overridden by the trigger to the actual `now()`.

### Outbox-bypassing write path (research.md Decision 7; contracts/pull-write-helper.md)

- [~] T009 ~~Add `applyRemoteRow(ExpenseControlItemRow row)` to the `ExpenseControlRepository` interface~~ **OBSOLETE — superseded during `/speckit-implement`.** Found while starting to implement this: `ExpenseControlItem` (the domain entity) has no `updatedAt`/`deletedAt` fields by design, so this method cannot live on the domain interface without violating the constitution's domain/Drift-independence rule or inventing an unjustified new type. See research.md Decision 7's correction and T011 below for the actual placement. Kept here (not deleted/renumbered) so `/speckit-analyze`'s prior findings that reference T009-T012 remain traceable.
- [~] T010 ~~Add the parallel `applyRemoteRow(FinancialTransactionRow row)` method~~ **OBSOLETE — same reason as T009.**
- [X] T011 Write the remote-row write helper in a new `lib/core/sync/remote_row_writer.dart` (research.md Decision 7's corrected placement — `core/sync/`, not the feature repository, matching `SyncWorker`'s own existing precedent of operating directly on `AppDatabase`): `applyRemoteExpenseControlItem(AppDatabase db, ExpenseControlItemRow row)` and `applyRemoteFinancialTransaction(AppDatabase db, FinancialTransactionRow row)`, both idempotent upserts (skip if incoming `updatedAt <= local updatedAt`, per research.md Decision 8 step 1's `<=` fix), writing the full incoming row (including `deletedAt`) into Drift via a raw idempotent-upsert `INSERT ... ON CONFLICT` guarded by the `<=` check, and **never** calling `ExpenseControlRepositoryImpl`'s private `_appendOutbox(...)` (this helper doesn't have access to it — it's a different class entirely, which is itself part of why this placement structurally prevents the pull→outbox→push loop, not just a convention). Also checks `row.userId` equals the helper's own scoping `userId` parameter as a defense-in-depth guard per contracts/pull-write-helper.md's stated precondition (`/speckit-analyze` finding G1 — RLS is the primary enforcement mechanism for FR-007, this is a second, cheap layer) — a mismatch is a silent no-op, not a thrown assertion (found while writing T012's own tests: `assert()` crashes in debug/test builds, inappropriate for a legitimate runtime condition).
- [X] T012 [P] Write unit tests for both helpers in a new `test/unit/core/sync/remote_row_writer_test.dart` (relocated from the originally-planned `test/unit/features/expense_control/...` path, per T011's corrected placement): (a) first application of a new row inserts it; (b) re-applying an unchanged row is a no-op (FR-004); (c) applying a row with `updatedAt` older-than-or-equal-to the local value is skipped, not applied (the `<=` fix, research.md Decision 8's race-condition case); (d) applying a row with `deletedAt` set correctly tombstones it (FR-003); (e) confirm no `sync_outbox` row is created by any of the above (research.md Decision 7); (f) a row whose `userId` does not match the passed-in `userId` is rejected rather than silently applied (`/speckit-analyze` finding G1). Depends on T011.

### Conflict-resolution algorithm & read-back (research.md Decisions 1, 8)

- [X] T013 Modify `SyncWorker.drainOutbox()` in `lib/core/sync/sync_worker.dart`: change `_client.from(table).upsert(payload)` to `_client.from(table).upsert(payload).select().single()`, read the returned row's `updated_at`, and write it into the local Drift row via the appropriate `remote_row_writer.dart` helper (not a second, separate local-write mechanism) — per research.md Decision 1's read-back requirement and Decision 7's "one write path for remote-authoritative values."
- [X] T014 [P] Write unit tests for T013's read-back behavior in `test/unit/core/sync/sync_worker_test.dart` (new file). **Mechanics note**: mocking `SupabaseClient`'s builder-chain classes (`PostgrestFilterBuilder` etc.) directly has no practical hand-rolled fake and this project has no mocking framework dependency — instead, `SyncWorker` gained an injectable `PushRow` seam (a plain `Future<Map<String, dynamic>> Function(String table, Map<String, dynamic> payload)` typedef; the real implementation still uses `.upsert(payload).select().single()`, wired as the default when no `push` override is passed), so tests substitute a plain closure with no framework needed. Confirms: the local row's `updatedAt` matches the injected fake's server-returned value; the read-back write does not append a new `sync_outbox` entry (Decision 7); `financial_transactions` read-back parses correctly too, not just `expense_control_items`.
- [X] T015 [P] Write unit tests for the full conflict-resolution algorithm (research.md Decision 8's 5 steps) in `test/unit/core/sync/conflict_resolution_test.dart` (new file): (a) a pending outbox entry survives an incoming pull for the same row unmodified (SC-004 — the outbox is never touched by the remote-row write helper); (b) after that pending entry eventually drains and its read-back lands, a subsequent Realtime rebroadcast of the same push is a no-op (step 5); (c) a balance field always takes the pulled/live value as-is regardless of any pending non-balance edit (constitution's server-authoritative-balance carve-out, spec.md User Story 2 Acceptance Scenario 2).
- [X] T015a [P] Write a unit test for SC-006's clock-skew scenario in the same `conflict_resolution_test.dart`, using `package:clock`'s `withClock` to deterministically simulate two "devices" with skewed local clocks (one ahead, one behind real time) both writing to the same row: confirm the resolution follows the *server's* actual write order (via the FR-005a trigger's `now()`, not either device's skewed local `DateTime.now()`) — this is SC-006's literal verification method, expressed as a fast, deterministic unit test rather than the manual two-device clock-adjustment quickstart.md leaves as an option; add `clock: ^1.1.1` (or current compatible version) as a dev dependency — confirmed absent from this project's `pubspec.yaml` (grep-checked during task planning), so this is a required addition, not conditional.

**Checkpoint**: Foundation ready — schema migrated (including the precision fix), Supabase trigger/publication live, `core/sync/` remote-row write path in place and tested, conflict resolution verified. User story implementation can now begin.

---

## Phase 3: User Story 1 - Data created on one device appears on another (Priority: P1) 🎯 MVP

**Goal**: A fresh sign-in on a second device pulls existing Supabase data into the local database automatically, and subsequent live changes on any device propagate without a restart — the app's own constitution-mandated pull half of sync, finally implemented.

**Independent Test** (per spec.md): On Device A, create an item and a transaction, confirm they sync (already working). On a freshly-installed Device B, sign in with the same account and confirm both appear without any manual "sync now" action.

### Tests for User Story 1 ⚠️

> Write these first; they exercise the pull service in isolation before Phase 3's implementation tasks make them pass.

- [X] T016 [P] [US1] Write unit tests for keyset pagination in `test/unit/core/sync/pull_service_test.dart` (new file): a fetch with no cursor starts from the beginning (FR-001); a fetch with an existing cursor uses `WHERE (updated_at, id) > (cursor_updated_at, cursor_id)` (research.md Decision 4); a batch returning fewer rows than the batch size marks `initialPullCompleted = true` (data-model.md's `PullCursor` lifecycle step 3).
- [X] T017 [P] [US1] Write unit tests for subscribe-before-fetch ordering in the same `pull_service_test.dart`: the Realtime channel subscription is established before the initial fetch begins (research.md Decision 2); a change event arriving during the initial fetch is applied via the same idempotent path and does not corrupt or duplicate the fetch's own application of that row.
- [X] T018 [P] [US1] Write unit tests for FR-010's per-batch transactionality in the same file: each batch is committed as its own local transaction; the cursor advances only after a batch's transaction commits successfully (SC-007's foundation — full interruption/resume behavior against a real, large dataset is covered by Phase 5's T035a).

### Implementation for User Story 1

- [X] T019 [US1] Create `lib/core/sync/pull_service.dart`: a `PullService` class taking `AppDatabase`, `SupabaseClient`, and the signed-in `userId`, implementing subscribe-first-then-fetch orchestration (research.md Decision 2) — `.channel(...).onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: <each syncable table>, callback: ...)`, `.subscribe()`, then keyset-paginated fetch (research.md Decision 4) writing each batch through the `remote_row_writer.dart` helper inside its own Drift transaction, advancing `PullCursor` after each successful commit (data-model.md). Depends on T011 (write path), T016-T018 (tests, must fail first). **UI-isolate note** (`/speckit-analyze` finding C1, constitution Principle IV): confirm during this task whether per-batch JSON-map-to-`Companion` conversion is cheap enough to stay on the UI isolate as ordinary `async`/`await` I/O-bound work (the likely answer, given it's JSON field mapping, not CPU-bound parsing of a large payload) — if profiling during `/speckit-implement` shows otherwise at the "thousands of rows" scale, offload the conversion step via `compute()`; state which was chosen and why in this file's own doc comment, don't leave it unstated either way.
- [X] T020 [US1] Add reconnect handling to `PullService` (FR-002a, research.md Decision 5's "resume from cursor position, not from zero"): wire the Realtime channel's subscribe-status callback so a disconnect→reconnect transition re-runs the catch-up fetch starting from the current `PullCursor` position for each table (not a fresh subscribe-and-fetch from scratch — the subscription itself is re-established, and the fetch resumes rather than restarts).
- [X] T021 [P] [US1] Write unit tests for T020's reconnect behavior in `pull_service_test.dart`: simulate a disconnect-then-reconnect status transition and assert the resumed fetch's first request uses the existing cursor position, not a null/reset one.
- [X] T021a [US1] Handle FR-006's distinct failure mode in `PullService` (`/speckit-analyze` finding E1). **Resolved by redesign, not a separate code path from T020**: `PullService.start()` no longer awaits the subscription connecting at all (a device offline when `start()` is called would otherwise block forever, since `RealtimeChannel.subscribe()` firing `subscribed` doesn't even guarantee replication is live, let alone that a fully offline device connects at all — verified against `realtime_client` 2.11.0 source). Instead, `Subscribe`'s `onReady` callback fires every time the subscription reports genuinely live — including the very first time, whenever that actually happens, and every later reconnect (FR-002a) — collapsing "offline at sign-in, eventually connects" and "was connected, disconnected, reconnected" into the exact same signal `PullService._handleReady()` handles once. This is simpler than the originally-planned separate retry-loop-vs-reconnect-callback split and covers both FR-006 and FR-002a with one mechanism (research.md updated accordingly).
- [X] T021b [P] [US1] Write unit tests for T021a in `pull_service_test.dart`: `PullService.start()` called while offline does not throw/silently give up; once connectivity becomes available (`onReady` fires), the initial subscribe+fetch completes without requiring `start()` to be called again.
- [X] T022 [US1] Create `lib/core/sync/pull_service_provider.dart`: `pullServiceProvider`, a `Provider<PullService>` mirroring `syncWorkerProvider`'s lifecycle pattern (`sync_worker_provider.dart:12-20`) — instantiate, start (subscribe + initial fetch), `ref.onDispose` cleanup. Wire it to start on **both** of the two cases that mean "there is now a signed-in user this device hasn't caught up for": (a) a fresh `AuthChangeEvent.signedIn` transition observed while the app is running (the common "user just signed in" case), **and** (b) a cold launch where `authStateChangesProvider`'s first-ever emitted value already carries a non-null session (the common "user was already signed in, app relaunched" case — e.g. from `AppLockNotifier`'s own `fireImmediately: true` pattern at `auth_state_provider.dart:72-79`, but do NOT reuse `AppLockNotifier`'s "only ever act on the first event this app instance sees, then stop" guard — case (a) must keep firing on every subsequent sign-in too, e.g. after a sign-out/sign-in-as-different-user cycle, which `AppLockNotifier`'s exact pattern would suppress after the first one). Scope the started pull to the signed-in `userId` in both cases (research.md §0).
- [X] T023 [US1] Watch `pullServiceProvider` at the widget-tree root in `FinanceApp` (wherever `syncWorkerProvider` and `appLifecycleObserverProvider` are currently watched — locate via grep for `syncWorkerProvider` in the app's root widget) so the pull service starts/stops with the same lifetime as the other root-level services.
- [X] T023a [P] [US1] Write unit tests for T022's two start-trigger cases in `test/unit/core/sync/pull_service_provider_test.dart` (new file): (a) a fresh `signedIn` event while the provider is already listening starts a pull for that user; (b) a cold-start scenario where the auth stream's first-ever emitted value already has a non-null session starts a pull immediately, without waiting for a further `signedIn` transition (the case T022 added beyond `AppLockNotifier`'s pattern); (c) a sign-out followed by a different user signing in starts a **new** pull scoped to the new `userId` (confirms T022's explicit non-reuse of `AppLockNotifier`'s "only the first event ever" guard).
- [X] T024 [US1] Create `lib/core/sync/initial_pull_complete_provider.dart`: `initialPullCompleteProvider`, a **`StreamProvider<bool>`** (not a plain `Provider<bool>` as originally scoped — a one-shot `Provider` cannot itself update as the pull progresses; found while implementing) computed as the logical AND of `PullCursor.initialPullCompleted` across both syncable tables for `currentUserIdProvider` (research.md Decision 6) — built on Drift's own `.watch()` so it re-emits automatically whenever any relevant `PullCursor` row changes, the same reactive convention every other screen-facing stream in this app already uses.
- [X] T025 [P] [US1] Write unit tests for `initialPullCompleteProvider` in `test/unit/core/sync/initial_pull_complete_provider_test.dart` (new file): `false` when no `PullCursor` rows exist for the user; `false` when one table is complete but the other isn't; `true` only when both are `true`; updates reactively when the underlying `PullCursor` rows change.
- [X] T026 [US1] Wire `initialPullCompleteProvider` into every screen that reads pulled data, per FR-011: `overview_screen.dart`, `report_screen.dart`, `expense_control_screen.dart`, `transaction_history_screen.dart` — each guarded with `if (!pullComplete) return const Center(child: CircularProgressIndicator())` (per explicit user direction, this project's actual existing loading convention — confirmed via survey that no skeleton widget exists anywhere in this codebase, contrary to the provider doc's original illustrative "LoadingSkeleton" name). **Consequence found while wiring**: every existing widget test reaching one of these 4 screens (or the app shell/router tests that render them transitively) needed a new `initialPullCompleteProvider` override added to its `ProviderScope`/`ProviderContainer`, since the provider's un-overridden default (`AsyncLoading`, no `PullCursor` row in a fresh test database) is production-correct but makes `pumpAndSettle()` hang forever in a test that isn't itself testing the pull-loading state. Created `test/support/pull_complete_override.dart` (a shared `pullCompleteOverride` constant) and applied it across 6 affected test files (`overview_screen_test.dart`, `report_screen_test.dart`, `expense_control_screen_test.dart`, `transaction_history_screen_test.dart`, `spending_screen_test.dart`, `app_shell_nav_bar_test.dart`, `app_shell_discard_prompt_test.dart`) — 500/500 tests pass afterward.
- [X] T027 [P] [US1] Add/modify widget tests for T026's loading-vs-empty distinction, one per touched screen (at minimum `test/widget/features/expenses/transaction_history_screen_test.dart`, existing file): with `initialPullCompleteProvider` overridden to `false`, the screen shows the loading state, not the empty state, even when the underlying data stream is empty; with it overridden to `true` and an empty stream, the screen shows its normal empty state (SC-008).

**Checkpoint**: User Story 1 should be fully functional and independently testable — a second device's sign-in pulls existing data, live changes propagate, and the loading-vs-empty distinction holds. Manually run quickstart.md Scenario 1 now as this story's own smoke test (its measurable content — SC-001's timing, SC-008's loading state — is separately covered by T035a/T027; this manual run confirms the story feels correct end-to-end before moving on). Scenarios 2-5, 7, and 8 are all deferred to Phase 5's T035-T035e (all US1-scoped, but grouped there so every remaining manual scenario is tracked as an explicit, checkable task rather than left to Checkpoint prose alone — `/speckit-analyze` findings F1 and E4).

---

## Phase 4: User Story 2 - A pulled row never collides destructively with an unsynced local edit (Priority: P2)

**Goal**: A device with a pending, unsynced local edit that receives a conflicting pull for the same row never silently loses that edit — the documented last-write-wins/server-authoritative resolution is what actually happens, verifiably.

**Independent Test** (per spec.md): Device A offline, edits an item's name. Device B (online) edits the same item's name differently and syncs. Reconnect Device A; confirm last-write-wins resolves per the constitution, and Device A's pending outbox write is not silently dropped.

**Note**: The conflict-resolution *algorithm itself* (research.md Decision 8, including the `<=` race fix) was already implemented and unit-tested in Phase 2 (T011, T012, T015) because User Story 1's pull path depends on it functioning correctly even in the no-conflict case. This phase's tasks focus on **end-to-end verification** that the already-implemented algorithm behaves correctly under the specific concurrent-edit scenario User Story 2 describes — there is no additional conflict-resolution *code* to write here, only verification that Phase 2's implementation satisfies this story's acceptance criteria in practice.

### Tests for User Story 2

- [X] T028 [P] [US2] Write an integration-style unit test in `test/unit/core/sync/conflict_resolution_test.dart` (extends T015's file) exercising User Story 2's *exact* Acceptance Scenario 1 (spec.md) through `ExpenseControlRepositoryImpl`'s real public API on the local-edit side — this is what makes T028 non-duplicative of T015's generic algorithm-step tests (`/speckit-analyze` finding A1: T015 tests the abstract `<=`/idempotency steps against a synthetic row; T028 tests the same underlying algorithm through the actual `update()`/outbox call sequence a real rename produces, at a higher fidelity than T015's direct algorithm-step invocation): call `.update()` on an `ExpenseControlItem` via `ExpenseControlRepositoryImpl` to rename it (producing a real `sync_outbox` entry via `_appendOutbox`, not a hand-constructed one), then call the `remote_row_writer.dart` helper (T011, research.md Decision 7's corrected placement — not a repository method) with a different name and a newer `updated_at` (simulating Device B's already-synced rename reaching this device via pull) — assert the outbox entry from the real `.update()` call is untouched and still queued; then drain that outbox entry (simulating its push landing with a fresh, even-newer server-issued `updated_at`, applied via the same helper) and assert the final name reflects that later real-world write, not whichever call happened to apply last. If this ends up asserting nothing beyond what T015 already covers once written, fold it into T015's file as an additional case instead of keeping it as a separate task — do not keep both if they turn out identical in practice.
- [X] T029 [P] [US2] Write a unit test for the balance-specific carve-out (spec.md User Story 2, Acceptance Scenario 2) in the same file: with a pending non-balance local edit (e.g. a queued name change) and an incoming pull carrying a different `balance` value, assert the pulled balance is applied as-is (server-authoritative, per the constitution) regardless of the pending edit's presence — balance is never held back or merged with local state.

### Implementation for User Story 2

- [X] T030 [US2] Manually execute quickstart.md Scenario 6 (name-edit variant) against two real devices/profiles (Android emulator + Chrome) signed into the same test account — the name-edit variant is verified: renaming the same item on both devices, the later-pushed rename (server `updated_at`-ordered) won and propagated to the other device via Realtime pull with no restart, matching SC-004's "never a silent, undocumented loss" bar. **This run also found and fixed a real, pre-existing shared-code bug** (unrelated to this feature's own pull-side code): `ExpenseControlRepositoryImpl.saveFormulas()`/`reorderTopLevel()` appended partial outbox payloads (only the changed fields), which `SyncWorker`'s `upsert()` push silently rejected server-side on every real rename/reorder — either a 403 (payload missing `user_id`, failing RLS's `WITH CHECK`) or a 400 (payload missing other `NOT NULL` columns, which PostgREST's `upsert()` treats as literal `NULL`, not "leave as the server's existing value"). Both failures were swallowed by `drainOutbox()`'s catch-all as silent infinite retries — any real user who ever renamed/reordered an item had a permanently wedged outbox row. Fixed at the two call sites (read the row back after the local Drift write, emit `_payloadOf()`'s full-row payload like every other call site already does) — this is the correct root-cause fix per `/speckit-constitution`'s shared-code-bug clause; changing `SyncWorker`'s push mechanics instead was considered and rejected (see this task's PR discussion) because it would introduce an ordering coupling between insert/update outbox rows that doesn't currently exist. Two regression tests added (`expense_control_repository_impl_test.dart`) asserting the outbox payload is full-row, not partial. Also added a success/error snackbar on "Lưu công thức" (`expense_control_screen.dart`) — the missing-feedback gap that let this bug go unnoticed (a save that failed server-side looked identical to one that succeeded) was itself a real UX bug, fixed alongside per the user's explicit request. **The balance-affecting variant was not separately re-run after the fix** — T029's unit-level simulation already covers the balance-carve-out algorithm, and the fix only changed which payload fields are sent, not the conflict-resolution logic itself, so the fixed payload contents (now including `balance`) are covered by the same full-row-payload regression tests.

**Checkpoint**: User Stories 1 AND 2 both work independently and together — the pull mechanism is complete and its conflict behavior is verified both at the unit level and against real concurrent devices.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Full-suite regression, Web verification, and the constitution-mandated PR-description call-out for this feature's shared-code changes.

- [X] T031 [P] Run `flutter analyze` across the full project and confirm zero errors/warnings (constitution Principle I gate). Confirmed clean (0 issues) as of the final commit on this branch.
- [X] T032 [P] Run the full existing test suite (`flutter test`) and confirm zero regressions — pay particular attention to any existing test that reads/writes a `DateTimeColumn` on `ExpenseControlItems`/`FinancialTransactions` directly (the text-storage migration, T001/T004, is the change most likely to surface an unexpected existing-test assumption about integer encoding). Confirmed: 508/508 tests passing as of the final commit on this branch.
- [X] T033 Repeat quickstart.md's "Web-specific verification" section (Scenarios 1, 2, and 6) with one device/profile being a Chrome browser session, per constitution Multi-Platform Support's "every new feature's plan MUST state whether it was verified on Web" requirement — record the result in this feature's eventual PR description. Verified against the real Supabase project with Chrome as one of the two devices (paired with the Android emulator): Scenario 1 (sign-in + initial pull, including FR-011's loading state) confirmed via Playwright network log showing the expected `signInWithPassword` → keyset-paginated pulls of both syncable tables; Scenario 2 (live update, no restart) and Scenario 6 (conflict resolution, name-edit variant) confirmed manually — a rename made on the emulator propagated to Chrome via Realtime pull with no page refresh. (Playwright's bundled Chromium initially appeared to show a router/redirect bug post-sign-in due to its `WasmStorageImplementation.sharedIndexedDb` fallback from missing SharedArrayBuffer/dedicated-worker support — ruled out as a Playwright-environment artifact, not a real bug, by cross-checking against both a real Chrome window and the Android emulator, which both redirected correctly.)
- [X] T034 Confirm the eventual PR description explicitly calls out the shared-code changes this feature makes outside its own feature directory, per constitution Development Workflow's "breaking changes to shared `core/` utilities REQUIRE explicit call-out" rule: `core/sync/sync_worker.dart`'s read-back change, the new `core/sync/` additions (`pull_service.dart` and providers), the `core/database/` schema migration (including the DateTime text-storage conversion), and a reference to research.md Decisions 1, 8, and 10 for reviewers who need the full rationale.
  **Result**: done in pull request #23, whose description has the section
  "Shared-code changes outside this feature's own directory" (the `sync_worker`
  read-back, the `core/sync` additions, the v6→v7 schema migration); ticked in
  the 2026-10-07 task audit.
- [X] T035 [P] Run quickstart.md Scenario 3 (tombstone exclusion on a third fresh device, SC-002) manually (`/speckit-analyze` finding F2 — split from a previous combined Scenario 3+4 task for consistency with the one-scenario-per-task pattern T035a-d establish).
  **Result (2026-10-07)**: the test rows (one item and five transactions, all created by a script with the QA login)
  were soft-deleted on the server; a brand-new browser profile with an empty local database signed in and showed none of them
  on Tổng quan, Kế hoạch, Thu chi, Báo cáo or the history screen, while the live items were all there (4/4).

- [ ] T035a [P] Run quickstart.md Scenario 5 (large-dataset batching/resumability) manually (`/speckit-analyze` finding E2): seed a genuinely large dataset per quickstart.md's own note (thousands of rows in at least one syncable table, matching SC-001's stated scale), and in addition to Scenario 5's own resumability check, **explicitly time the initial pull end-to-end and assert it completes within SC-001's 10-second bound under normal connectivity** — this timing assertion is SC-001's literal verification method and was previously missing from this feature's task list entirely.
  **PARTIAL (2026-10-07)**: 1000 items and 3000 transactions were seeded with the QA login and hard-deleted afterwards (the
  server is back to its 9 items and 7 transactions). A fresh Android emulator pulled all 1011 items and 3012 transactions
  (tombstones included): profile build 5.7 to 6.2 s from the first rows to complete in three runs, so SC-001's 10 s is met;
  the debug build takes about 11 s. Interrupting after the first batch (500 items): the committed batch stayed, the stored
  cursor was exactly that batch's last (updated_at, id) with `initial_pull_completed = 0`, and relaunching completed with
  exactly the server's row counts and no duplicates. **Not observed**: the first request after the restart starting at the
  cursor (no request log was available), which only the unit tests cover; so the box stays open.

- [X] T035b [P] Run quickstart.md Scenario 7 (no regression for an already-correct device, FR-008/SC-003) manually (`/speckit-analyze` finding E3 — this scenario was promised by Phase 3's Checkpoint but had been dropped from Phase 5 with zero task coverage): on a device with correct, complete local data and nothing pending in the outbox, record row counts/content before letting the pull mechanism run its normal course, then assert zero duplicate rows and zero unexpected value changes afterward, per SC-003's explicit verification method.
  **Result (2026-10-07)**: Android emulator, 9 items (one a tombstone) and 7 transactions, nothing in the outbox: the local
  database fingerprinted field by field before and after an app restart is identical, and its counts equal the server's.

- [X] T035c [P] Run quickstart.md Scenario 8 (reconnect mid-session on a real device, FR-002a — the real-device counterpart to T020/T021's unit-level simulation) manually (`/speckit-analyze` finding F1 — promised by Phase 3's Checkpoint, previously missing from Phase 5's task list): disconnect a signed-in, already-pulled device's network mid-session (not app backgrounding), make a change on another device while it's disconnected, reconnect, and confirm the change made during the disconnection window appears.
  **Result (2026-10-07)**: Android emulator (not physical hardware) in the foreground and in airplane mode; a transaction was
  created on the server meanwhile and was absent locally; once the network returned the row was in the local database after
  about 13 s and on screen about 15 s later, with no restart (three runs; an early failed run was only the debug build's 20 s
  inactivity lock covering the screen).

- [X] T035d [P] Run quickstart.md Scenario 4 (offline-at-sign-in, FR-006 — the real-device counterpart to T021a/T021b's unit-level simulation) manually (`/speckit-analyze` finding F2 — split from the same previously-combined task as T035 above).
  **Result (2026-10-07)**: Android emulator (not physical hardware), variant for a device whose session is kept but whose local
  database is empty: the database file was deleted, the app launched in airplane mode and opened with the PIN. It showed no
  data and no empty-state text; 2.4 s after connectivity returned the real data was there, with no sign-out and in. A fresh
  sign-in while offline was not tried (it needs the network).

- [X] T035e [P] Run quickstart.md Scenario 2 (a live remote change appears on a real mobile device's UI without a restart, for both an insert and an update — SC-005) manually (`/speckit-analyze` finding E4): this closes the one remaining requirement whose real-device verification existed only as Phase 3 Checkpoint prose rather than a tracked task — T017 verifies `PullService`'s subscribe/apply ordering at the service layer only, and T033 verifies this same scenario on Web only, so neither substitutes for a real mobile-device check; on Device B (already signed in, initial pull already complete), create a transaction and separately rename an item on Device A, and confirm both appear on Device B's UI without an app restart or manual refresh.

---
  **Result (2026-10-07)**: Android emulator (not physical hardware) in the foreground: a new item appeared 2.3 s, its rename
  2.5 s and a new transaction 2.3 s after the server write (polling resolution about 1.5 s), with no restart or refresh.

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — the `build.yaml` change must land before any task that writes or migrates a `DateTimeColumn`.
- **Foundational (Phase 2)**: Depends on Phase 1. BLOCKS both user stories — the migration, the trigger/publication, the write path, and the conflict-resolution algorithm are all prerequisites neither story can be correctly implemented or tested without.
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion. No dependency on User Story 2.
- **User Story 2 (Phase 4)**: Depends on Phase 2 completion (the algorithm it verifies was implemented there) AND on Phase 3's `PullService`/remote-row-write-helper wiring being live end-to-end (T028/T030 need a working pull path to simulate/execute against) — unlike the template's default assumption of story independence, US2 is a verification-focused story that specifically needs US1's delivery mechanism running, not a standalone code path of its own. This is a deliberate deviation from "user stories are independently implementable," documented here rather than left implicit, because US2's spec.md scope is explicitly "verify the algorithm already required by US1's own correctness," not a separate feature.
- **Polish (Phase 5)**: Depends on Phases 3 and 4 both being complete. T035-T035e specifically require a fully working end-to-end pull (real devices, real Supabase project) — they are the manual quickstart.md scenarios deferred from Phase 3's Checkpoint (see that Checkpoint's note).

### Within Phase 2

- T002 → T003 → T004 (table must be defined and registered before the migration can create it)
- T004 → T005 (migration must exist before its test can run against it)
- T006 is independent of T002-T005 (different file) but depends on T001 (build.yaml) — can run in parallel with T002-T005
- T007 → T008 (migration file must exist before it can be applied)
- T009, T010: obsolete, no dependency edges (superseded by T011's corrected placement — see their strikethrough text)
- T011 → T012 (implementation before its tests)
- T011 → T013 (read-back needs the `remote_row_writer.dart` helper to exist)
- T013 → T014
- T011 → T015 (conflict-resolution tests need the write helper)
- T011 → T015a (same dependency; independent test file section from T015, can run in parallel with it)

### Within Phase 3

- T016, T017, T018 (tests) before T019 (implementation) — write first, confirm they fail
- T019 → T020 → T021
- T019 → T021a → T021b
- T019 → T022 → T023
- T022 → T023a
- T024 → T025
- T024, T026 → T027 (tests need the provider and the screen wiring both in place)

### Within Phase 4

- T028, T029 depend on Phase 2's T011/T015 (the algorithm and its base tests already exist) — these are additional scenario-specific tests, not blocked by anything in Phase 3 except needing the `remote_row_writer.dart` helper to exist (already true after Phase 2)
- T030 depends on Phase 3 being fully complete (needs a working end-to-end pull to execute the manual scenario against)

### Parallel Opportunities

- T005, T006 can run in parallel with each other (different files) once their respective dependencies (T004, T001) are met
- T007 can run in parallel with the entire local-schema-migration track (T002-T006) — independent systems (Supabase vs. Drift)
- T012, T014, T015, T015a can run in parallel (different/independent test sections) once T011/T013 respectively are done
- T016, T017, T018 can run in parallel (same file, but independent test cases — coordinate to avoid merge conflicts if worked by different people simultaneously)
- T021, T021b, T023a, T025, T027 can run in parallel with each other once their respective prerequisites land
- T028, T029 can run in parallel (same file, independent test cases)
- T031, T032, T033, T035, T035a, T035b, T035c, T035d, T035e can run in parallel (independent verification activities — T035a-e each need their own device/profile setup per quickstart.md, but don't depend on each other)

---

## Parallel Example: Phase 2 Foundational

```bash
# Once T001 (build.yaml) and T004 (migration) are done, these can run together:
Task: "Write migration-path unit test in test/unit/core/database/app_database_migration_test.dart"
Task: "Fix applyIncomeAllocation()/recordExpense()'s raw customUpdate() calls in expense_control_repository_impl.dart"

# Once T011 (remote_row_writer.dart implementation) is done, these can run together:
Task: "Write unit tests for the remote-row write helper in remote_row_writer_test.dart"
Task: "Modify SyncWorker.drainOutbox() for read-back"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (`build.yaml`)
2. Complete Phase 2: Foundational (CRITICAL — migration, trigger, write path, conflict algorithm; blocks everything)
3. Complete Phase 3: User Story 1 (includes running quickstart.md Scenarios 1 and 2 at its Checkpoint)
4. **STOP and VALIDATE**: Run Phase 5's T035-T035e (quickstart.md Scenarios 2, 3, 4, 5, 7, 8) against real devices before calling US1 done — these are the remaining scenarios the Phase 3 Checkpoint defers rather than a separate, optional step
5. This is deployable/demoable as the MVP — data now flows both directions, which is this feature's core value

### Incremental Delivery

1. Setup + Foundational → foundation ready (migration applied, trigger live, write path tested)
2. Add User Story 1 → validate independently → this is already a complete, shippable improvement (the second-device gap is closed)
3. Add User Story 2 → validate independently (its own scenario plus regression on US1) → conflict behavior now explicitly verified, not merely assumed correct
4. Polish → full-suite regression, Web verification, PR call-out prepared

### Notes specific to this feature

- Unlike a typical multi-story feature, Phase 2 (Foundational) is unusually large relative to the two user-story phases — this reflects spec.md's own scope: three of this feature's four Clarifications-session decisions (clock skew/FR-005a, data volume/FR-010, and the DateTime-precision issue found during planning) are cross-cutting correctness fixes that both stories depend on, not story-specific work.
- The DateTime text-storage migration (T001, T004-T006) touches every existing row in `expense_control_items`/`financial_transactions` — treat T005's migration test as a hard gate, not a formality, given the documented real-world data-loss precedent (GitHub Discussion #3603) research.md Decision 10 cites.
- User Story 2's phase is verification-heavy rather than implementation-heavy by design (see the Dependencies section's note on why) — do not interpret Phase 4's short implementation-task list as the story being lower-effort than User Story 1; its correctness depends entirely on Phase 2 having been done right.
