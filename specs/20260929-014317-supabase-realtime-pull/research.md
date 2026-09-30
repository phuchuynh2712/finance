# Research: Pull Remote Data From Supabase Into Local Database

**Feature**: [spec.md](./spec.md) | **Date**: 2026-09-29

This research phase resolves the technical design questions FR-001 through
FR-011 leave open. Every decision below is grounded in a direct read of the
current codebase (file:line references throughout) — no part of this feature
starts from an existing partial implementation; §1's grep confirms the pull
path is fully greenfield.

---

## 0. Current-state survey (evidence baseline)

Confirmed by directly reading the relevant files (not inferred):

- **`SyncWorker`** (`lib/core/sync/sync_worker.dart:23-77`) is push-only: a
  30-second `Timer.periodic` drains `sync_outbox` via
  `_client.from(table).upsert(payload)` for all three operations (insert/
  update/delete — soft-deletes are `upsert`s carrying a populated
  `deleted_at`, never a real SQL `DELETE`). No connectivity-change listener,
  no exponential backoff (failure just increments `retry_count` and retries
  on the next timer tick, uncapped).
- **`updated_at` is 100% client-clock today.** `sync_worker.dart` never
  touches it — the value is set at write time in
  `expense_control_repository_impl.dart` via `DateTime.now()` (e.g. lines
  253, 302, 342) or raw-SQL-bound `now.millisecondsSinceEpoch` (lines 391,
  458), then sent as an explicit field in the `upsert()` payload. Postgres's
  `default now()` column default (present in both tables' DDL) never fires
  for these writes because an explicit value is always supplied — it only
  helps a bare `INSERT` with no `updated_at` field at all, which this app
  never does.
- **Realtime is fully greenfield.** Grep for
  `realtime|channel|onPostgresChanges|RealtimeChannel|postgresChanges`
  across `lib/` returns exactly one match, an unrelated doc-comment
  ("platform channel") in `app_lifecycle_observer.dart:63`. Grep for
  `ALTER PUBLICATION|REPLICA IDENTITY|supabase_realtime` across
  `supabase/migrations/` returns zero matches — Realtime publication is not
  enabled for either table at the database level.
- **Drift schema**: `schemaVersion = 6` (`app_database.dart:32`), 3 tables
  registered (`ExpenseControlItems`, `FinancialTransactions`, `SyncOutbox`).
  Both syncable tables already have `updatedAt`/`deletedAt` columns; neither
  has a sync-cursor/metadata column. Migrations use a cumulative
  `if (from <= N)` pattern (documented rationale at lines 37-43: `onUpgrade`
  fires once with `from` fixed at the actual starting version).
- **DI pattern**: plain Riverpod `Provider`s (no `@riverpod` codegen despite
  it being a dev dependency), e.g. `expenseControlRepositoryProvider`
  (`expense_dependencies.dart:11-14`). The closest precedent for a
  long-lived, auto-started background service is `syncWorkerProvider`
  (`sync_worker_provider.dart:12-20`): instantiates once, calls `.start()`,
  registers `ref.onDispose`, watched at the widget-tree root by `FinanceApp`.
- **Repository write pattern**: every mutation in
  `ExpenseControlRepositoryImpl` wraps a Drift write and a call to a private
  `_appendOutbox(...)` helper in the same `_db.transaction(...)` (lines
  57-74) — this is how local writes get queued for push. **A pull-writer
  must not call `_appendOutbox`**, or a pulled remote row would loop back
  out to Supabase as if it were a fresh local edit.
- **Auth trigger point**: `authStateChangesProvider`
  (`auth_state_provider.dart:21-23`) wraps `AuthRepository.onAuthStateChange`
  (the raw `supabase_flutter` `_client.auth.onAuthStateChange` stream),
  emitting `AuthChangeEvent.signedIn` transitions. `AppLockNotifier`
  (lines 70-92) is the closest existing "act once per relevant event"
  precedent, though its exact semantics (fire once per app instance) are
  *not* what FR-001 needs — FR-001 needs "pull whenever local data isn't
  yet caught up for the signed-in user," which is a per-user bootstrap flag,
  not a per-app-instance flag (see §5).
- **`AppLifecycleObserver`** (`app_lifecycle_observer.dart:32-39`) only
  reacts to app foreground/background, not network connectivity — it is not
  a usable reconnect hook for FR-002a. That hook must come from
  `supabase_flutter`'s own Realtime channel subscribe-status callback.
- **`supabase_flutter: ^2.8.0`** (`pubspec.yaml`) — this pins the modern
  `RealtimeChannel`/`.channel(...).onPostgresChanges(event:, schema:,
  table:, callback:)` API surface, not the deprecated 1.x `.on(...)` style.
- **No `connectivity_plus` or any connectivity-detection package** is
  present (`pubspec.yaml` grep, confirmed empty). A prior feature
  (`specs/20260922-003635-rename-app-error-mapper/research.md:34`)
  explicitly rejected adding one as out of scope. This feature does not
  re-open that decision — see Decision 8.

---

## Decision 1: `updated_at` becomes server-issued (FR-005a)

**Decision**: Two layers, not either/or:

1. A Postgres `BEFORE INSERT OR UPDATE` trigger on both `expense_control_items`
   and `financial_transactions` unconditionally sets `NEW.updated_at = now()`,
   overriding whatever the client sends. This is what makes the value
   *actually* server-authoritative — a client-side "just omit the field"
   convention is not enforced by anything and breaks the moment a future
   write path forgets to omit it.
2. The client (`SyncWorker.drainOutbox()`) changes its push call from
   `.upsert(payload)` to `.upsert(payload).select().single()`, reads the
   `updated_at` Postgres actually recorded back from the response, and
   writes it into the local Drift row through the same idempotent apply
   path used for pulled rows (Decision 7) — never a second, separate local
   write path.

**Rationale**: The trigger is the enforcement mechanism (correct even if
some future code path forgets to omit `updated_at`); the read-back is what
the spec's FR-005a explicitly requires ("the client MUST reconcile its
local `updated_at` to match the value Supabase actually recorded"). Neither
alone satisfies both needs — a trigger without read-back leaves the local
row silently stale relative to the server; read-back without a trigger is
an unenforced convention.

**Alternatives considered**:

- **Client omits `updated_at` from the payload, relying on the column
  default.** Rejected — nothing prevents a future write path from
  re-introducing an explicit value (e.g. copy-pasting an existing mutation
  method), silently reopening the clock-skew bug FR-005a exists to close.
  A trigger makes this structurally impossible, not merely a convention.
- **Trigger only, no client read-back.** Rejected — the spec's FR-005a is
  explicit that the client MUST reconcile its local value; without
  read-back, the local row's `updated_at` would diverge from the server's
  immediately after every push, breaking the very last-write-wins
  comparisons this feature is trying to make trustworthy.

**Migration note** (recorded here, and added to spec.md's Assumptions):
historical rows already on Supabase keep their client-clock `updated_at`
values after this trigger ships — the trigger only affects future
INSERT/UPDATE statements. This is deliberately not backfilled/rewritten;
the existing timestamp is the best available record of when that historical
write actually happened, and rewriting it to "now" would be a strictly less
accurate value, not a more accurate one.

**Testability mechanics note** (found while implementing the read-back's
unit tests): `SyncWorker` had no seam for substituting the Supabase push
call, and this project has no mocking-framework dependency to fake
`SupabaseClient`'s builder-chain classes (`PostgrestFilterBuilder` et al.
have no practical hand-rolled fake, and adding a mocking framework is a
project-level dependency decision out of scope for one test file).
`SyncWorker` gained an injectable `PushRow` typedef (`Future<Map<String,
dynamic>> Function(String table, Map<String, dynamic> payload)`) —
production code's default implementation still calls
`.upsert(payload).select().single()` exactly as before; tests pass a plain
closure instead. This keeps constitution Principle II's "unit-testable
without a live Supabase connection" requirement satisfiable without a new
dependency.

---

## Decision 2: Subscribe before initial fetch

**Decision**: On startup (or reconnect), the pull service subscribes to the
Realtime channel (`.channel(...).onPostgresChanges(...).subscribe()`)
*first*, starts buffering/applying live change events as they arrive, and
only then runs the initial keyset-paginated catch-up fetch (Decision 4).
Both the live stream and the initial fetch write through the same
idempotent apply path (FR-004; Decision 7), so any row that both mechanisms
happen to deliver is a safe no-op the second time.

**Rationale**: This is the standard ordering for this class of sync system
(Firestore, WatermelonDB, PowerSync-style local-first apps). Fetching first
and subscribing second leaves a real gap between "fetch completed" and
"subscription active" during which a remote change is silently missed
forever (nothing re-delivers it, since it's not a reconnect scenario). FR-004's
idempotency guarantee already has to exist for other reasons (SC-003,
FR-008), so relying on it to make subscribe-first safe costs nothing extra.

**Alternatives considered**:

- **Fetch first, then subscribe.** Rejected — the gap described above is a
  real, silent data-loss window with no natural detection or recovery
  mechanism; subscribe-first has no equivalent downside given idempotency
  is already required.

**Mechanics note, verified against `realtime_client` 2.11.0 source (this
project's exact resolved version, per `pubspec.lock`) during
`/speckit-implement`**: `RealtimeChannel.subscribe()`'s status callback
firing `RealtimeSubscribeStatus.subscribed` does **not** itself guarantee
Postgres replication is actually live yet — the join reply optimistically
echoes the requested config before the server has finished wiring up
replication, per the package's own source comment at
`realtime_channel.dart:162-172`. Plain `.subscribe()` therefore closes the
subscribe/fetch gap only *probabilistically* (replication typically
activates within seconds, and the fetch's own idempotent `<=` write
absorbs anything missed in that narrow window). The implementation
instead closes it *structurally*: the real `subscribe` closure passes
`RealtimeChannelConfig(replicationReady: true)` when creating the channel
and listens for an `onSystemEvents` payload with `status == 'ok'` — the
actual signal that replication is genuinely streaming, not the `subscribe`
callback's own `subscribed` status.

**Further mechanics note, found while implementing T021a/FR-006's
offline-at-sign-in case**: the function that establishes the subscription
does **not** await that `onSystemEvents` "ok" signal before returning — a
device offline when this is called would otherwise block forever, since
neither `.subscribe()` completing nor a real connection succeeding is
guaranteed to happen at all while offline. Instead, the "ok" signal is
delivered via a callback (`onReady`) that fires **every time** it occurs —
including the very first time, whenever that actually happens (seconds
later on a healthy connection, or much later if the device started
offline), and every subsequent reconnect after a disconnect (FR-002a).
This collapses what tasks.md originally planned as two separate
mechanisms (an initial-connect retry loop for FR-006, a reconnect callback
for FR-002a) into one: [`PullService`] has no special-cased "was this the
first successful connect" branch to get wrong, because `onReady` firing at
all — on whatever attempt — is the only signal it ever needs, and it
always responds to it the same way (re-run the catch-up pull, resuming
from each table's current cursor). No connectivity-detection package is
added for this (research.md Decision 9's rejection of `connectivity_plus`
stands unchanged) — the Realtime subscription's own retry/backoff already
handles "device offline, eventually online" without this feature needing
to detect connectivity itself.

## Decision 3: `REPLICA IDENTITY DEFAULT` is sufficient — do not set `FULL`

**Decision**: Neither table needs `ALTER TABLE ... REPLICA IDENTITY FULL`.
The existing default (`DEFAULT` — primary-key-only old-row data in the WAL)
is left as-is; only `ALTER PUBLICATION supabase_realtime ADD TABLE
expense_control_items, financial_transactions;` is needed to enable
Realtime for these tables.

**Rationale**: `REPLICA IDENTITY FULL` matters when a consumer needs the
*old* values of columns that aren't in the primary key (e.g. to see what a
row looked like before an UPDATE). This feature only needs the *new* row
state after each change (the change events are applied as upserts via the
same idempotent path regardless of what changed) — and RLS filtering
(`auth.uid() = user_id`) is enforced on the *new* row's `user_id`, which is
always present regardless of replica identity setting. Soft-deletes are
UPDATEs (never real `DELETE`s, per §0), so there is no scenario in this
feature where old-row data is needed. Setting `FULL` would add WAL overhead
for every write on both tables with no corresponding benefit here.

**Alternatives considered**:

- **`REPLICA IDENTITY FULL` "to be safe."** Rejected — no code path in this
  feature's design consumes old-row data; the overhead would be unjustified
  speculative cost, not a real requirement.

---

## Decision 4: Keyset pagination by `(updated_at, id)` for the initial pull (FR-010)

**Decision**: The initial catch-up fetch pages through each table using:

```sql
WHERE (updated_at, id) > ($cursor_updated_at, $cursor_id)
ORDER BY updated_at, id
LIMIT $batch_size
```

Each returned batch is written to Drift as its own local transaction (per
FR-010), and the bootstrap cursor (Decision 5) advances to the last row's
`(updated_at, id)` only after that batch's transaction commits
successfully.

**Rationale**: Offset/limit pagination (`OFFSET n LIMIT m`) skips or
duplicates rows when concurrent writes change the underlying row order
between pages — a real risk at the "thousands of rows" scale this feature
is explicitly designed for (Clarifications). Keyset pagination is stable
under concurrent writes and its cursor state is exactly what SC-007 (resume
without re-fetching completed batches) and FR-002a (reconnect re-runs "the
same full pull," which resumes from current cursor position rather than
literally re-fetching from the beginning) both need — the same cursor
mechanism serves both requirements.

**Alternatives considered**:

- **Offset/limit pagination.** Rejected — unstable under concurrent writes,
  and does not naturally provide a resumable cursor for SC-007 without a
  separate resume-tracking mechanism.

---

## Decision 5: Bootstrap cursor as a new Drift table, keyed per `(user_id, table_name)`

**Decision**: A new Drift table (`PullCursor` or similar; exact naming
decided in data-model.md) with columns `userId TEXT`, `tableName TEXT`,
`lastUpdatedAt DATETIME`, `lastId TEXT`, `initialPullCompleted BOOL`,
primary key `(userId, tableName)`. This requires a schema migration:
`schemaVersion` 6 → 7, following the existing cumulative `if (from <= 6)`
pattern (`app_database.dart`'s established convention).

The cursor advances after each successful batch commit (Decision 4),
serving SC-007 directly. `initialPullCompleted` becomes `true` only once
every batch for that `(user_id, table_name)` has been fetched and committed
— this is what FR-011's loading-state provider reads (Decision 6).

On reconnect (FR-002a), "re-run a full pull" resumes from the cursor's
current position rather than literally restarting from the first row —
this is consistent with the spec's intent (nothing is missed regardless of
disconnection duration) without discarding already-completed work, and
reuses the same idempotent apply path so there is no behavioral difference
between "resuming an interrupted pull" and "reconnecting after a gap."

**Rationale**: Keying per `(user_id, table_name)` rather than a single
global flag is necessary because: (a) the two syncable tables complete
their initial pulls independently (different data volumes, different batch
counts), and FR-011's loading state must reflect both being done, not just
one; (b) a signed-out-then-signed-in-as-a-different-user flow must not
reuse another user's completed-pull state — scoping by `user_id` makes a
different account's sign-in correctly require its own fresh bootstrap.

**Alternatives considered**:

- **A single boolean flag (e.g. in `SharedPreferences` or a settings
  table), not scoped per table or user.** Rejected — cannot distinguish
  "table A done, table B still pulling" (breaks FR-011's per-screen
  accuracy if screens read different tables), and would incorrectly report
  "already pulled" for a second user signing into the same device.
- **Reusing `AppLockNotifier`'s "fire once per app instance" pattern.**
  Rejected — FR-001's actual requirement is per-user, per-table bootstrap
  state that persists across app restarts (so a user who signs out and
  back in on the same device doesn't needlessly re-pull data already
  cached locally), not a per-process-lifetime flag.

---

## Decision 6: FR-011 loading state via a single `initialPullCompleteProvider`

**Decision**: One Riverpod `StreamProvider<bool>` in `core/sync/`,
`initialPullCompleteProvider`, computed as the logical AND of
`initialPullCompleted` (Decision 5) across all syncable tables for
`currentUserIdProvider`. Every screen that reads pulled data consumes it
alongside its existing stream:

```dart
final pullDone = ref.watch(initialPullCompleteProvider).valueOrNull ?? false;
final rowsAsync = ref.watch(existingStreamProvider);
if (!pullDone) return const Center(child: CircularProgressIndicator());
return rowsAsync.when(...); // existing empty/data/error handling, unchanged
```

**Loading widget, found during `/speckit-implement`**: this codebase has
no skeleton-shaped loading widget anywhere — every existing screen's
loading state (Home Overview, Report, Transaction History, Expense
Control, every Auth screen) is either a bare `Center(child:
CircularProgressIndicator())` or a private, screen-local wrapper around
exactly that (`_SummaryLoading`, `_SectionLoading`). Per explicit user
direction (asked directly rather than assumed, since the constitution's
"reuse the existing pattern" phrasing presumes a pattern that turned out
not to exist), FR-011 reuses this exact spinner convention rather than
introducing a new skeleton widget — consistent with the rest of the app,
zero new UI surface, and avoids designing 4 different skeleton shapes for
4 differently-laid-out screens.

**Rationale**: FR-011 applies uniformly to every screen that reads pulled
data (Home Overview, Expense Control, Transaction History, Monthly Report)
— a single shared provider in `core/` is the Recommended Architecture
section's own rule (something used by 2+ features belongs in `core/`), and
keeps the loading/empty distinction logic in exactly one place rather than
reimplemented per screen. This composes with each screen's *existing*
`StreamProvider`-based empty/data/error handling rather than replacing it —
the screen's own logic is unchanged below the new guard.

**Alternatives considered**:

- **A wrapper widget in `core/widgets/` that every screen wraps its content
  in.** Rejected as unnecessary indirection — a single provider each screen
  reads directly is simpler and matches how every other cross-cutting
  Riverpod state in this app already works (e.g. `isSignedInProvider`);
  introducing a new structural widget pattern for this one concern is not
  justified.
- **Per-screen local state, each screen tracking its own "have I ever
  received data" flag.** Rejected — duplicates the same logic 4+ times and
  risks drifting out of sync with the actual bootstrap-cursor state in
  Drift, which is the actual source of truth.

---

## Decision 7: Pull writes never touch the outbox — a `core/sync/` write path, not the feature repository

**Decision**: `applyRemoteRow(...)`-style write logic (one per syncable
table) lives inside `core/sync/` — as private/internal helpers `PullService`
and `SyncWorker`'s read-back both call — writing directly to Drift using
the same idempotent-upsert semantics FR-004 requires, and **never** calling
the existing private `_appendOutbox(...)` helper on
`ExpenseControlRepositoryImpl`. This path is used by both the initial pull
(Decision 4) and the live Realtime stream (FR-002), and also by the
push-side `updated_at` read-back (Decision 1) — all three are "write an
authoritative remote value into Drift without re-queuing it for push."

**This corrects an earlier version of this same decision** (caught during
`/speckit-implement`, before any code was written against it): the original
version put `applyRemoteRow` on `ExpenseControlRepository`/
`ExpenseControlRepositoryImpl` — the feature-layer domain interface and its
implementation. That placement was wrong for a concrete reason found while
starting to implement it: the domain entity `ExpenseControlItem`
(`features/expense_control/domain/expense_control_item.dart`) deliberately
has no `updatedAt`/`createdAt`/`deletedAt` fields — sync metadata has never
been part of this app's domain vocabulary, by design, and `applyRemoteRow`
cannot function without exactly those fields (the idempotency check *is*
the `updatedAt` comparison; FR-003's tombstone handling *is* the
`deletedAt` field). Putting the method on the domain interface would force
one of three bad options: take a raw Drift row as a domain-interface
parameter (violates the constitution's "domain has zero dependency on
Drift" rule directly), invent a new domain-layer DTO that exists only to
carry sync metadata into a domain interface that otherwise doesn't need it
(unjustified new type), or add sync metadata fields to `ExpenseControlItem`
itself (changes an entity every existing constructor/copyWith/test
touches, for a concern the domain layer has never needed to know about).

**The actual correct precedent was already in this codebase**: `SyncWorker`
itself (`core/sync/sync_worker.dart`) is sync infrastructure that lives in
`core/sync/` and operates directly on `AppDatabase` (`_db.select(_db.
syncOutbox)`, raw table access) — it goes through no feature repository at
all, because outbox draining is sync-infrastructure work, not a
feature-domain operation. Pull-writing is the same category of work: it
operates on remote-authoritative row state that has no meaning in the
domain vocabulary ("what Supabase says this row is right now," not "what
a user's expense-control item is"), so it belongs alongside `SyncWorker`
in `core/sync/`, not inside a feature's `domain/`/`data/` layers. This
keeps `ExpenseControlRepository`'s interface and
`ExpenseControlRepositoryImpl`'s implementation **completely unchanged** —
no new method, no domain-entity change, no leakage of sync concerns into
feature code.

**Rationale for the outbox-bypass rule itself (unchanged from the original
decision)**: `_appendOutbox` is what queues a row for the *next* push —
calling it for a row that just arrived *from* a pull would create an
infinite pull→outbox→push→pull loop.

**Alternatives considered** (the original three, still rejected for the
same reasons, plus the placement correction above):

- **A single write method with a `bool isFromRemote` (or similar) flag
  gating the `_appendOutbox` call.** Rejected — flags like this are easy to
  get wrong at a call site (default value matters, easy to omit), and mix
  two conceptually different operations ("the user changed this" vs. "the
  server told us this changed") into one method signature.
- **`applyRemoteRow` on the domain interface, taking a Drift row.**
  Rejected — see above; violates the constitution's domain/Drift
  independence rule directly.
- **`applyRemoteRow` on the domain interface, taking a new domain-layer
  sync DTO.** Rejected — an unjustified new type whose only purpose is
  carrying sync metadata through a layer boundary that pull-writing
  doesn't actually need to cross; `core/sync/` can reference `core/
  database/tables/` directly without needing a domain-layer intermediary.
- **Extend `ExpenseControlItem` with `updatedAt`/`deletedAt`/`createdAt`.**
  Rejected — expands a deliberately-scoped domain entity for a concern
  (sync bookkeeping) the domain layer has never needed and every other
  domain-layer consumer would now carry regardless of relevance.

**Accepted trade-off**: modest code duplication between the two per-table
apply-and-idempotency-check helpers (roughly 15 lines each) rather than a
single generic one — consistent with this feature's own Assumptions
("no generic multi-table abstraction... ahead of need").

---

## Decision 8: Conflict resolution algorithm for FR-005/FR-005a's intersection

**Decision**: With `updated_at` now server-issued (Decision 1), the
constitution's last-write-wins-by-`updated_at` policy reduces to a simple,
concrete algorithm:

1. A pulled/live row arrives for a given `id`. If the incoming row's
   `updated_at` is **less than or equal to** the local row's `updated_at`
   (not merely equal), skip — equal is FR-004's idempotency case (nothing
   changed, including the case where this is the Realtime echo of this
   device's own just-pushed write); less-than closes a race an
   equality-only check misses (see "Race condition closed by `<=`, not
   `==`" below).
2. Otherwise, apply the incoming row via `applyRemoteRow` (Decision 7).
   Because `updated_at` is now server-issued and monotonic per row, the
   incoming row is authoritative whenever its `updated_at` differs from
   the local value — there is no scenario left where the *pull* needs to
   compare against a *pending outbox entry's* timestamp, because:
3. The outbox is **never** touched or cleared by a pull — a pending,
   not-yet-pushed local edit stays queued regardless of what the pull just
   wrote to the same row's other columns, and drains normally on the next
   `SyncWorker` tick.
4. When that queued push eventually reaches Supabase, the trigger
   (Decision 1) stamps it with the actual `now()` at push time, and the
   read-back writes that authoritative value back locally via the same
   `applyRemoteRow` path.
5. The Realtime channel then rebroadcasts that same push back to this
   device as a live change event; step 1 catches it as a no-op (its
   `updated_at` already matches what was just read back locally).

Balance fields remain server-authoritative per the constitution's existing
carve-out — `applyRemoteRow` always writes the pulled/live balance value
as-is; balances are never computed or preserved from a local pending edit
in the first place (the existing `applyIncomeAllocation`/`recordExpense`
methods already treat balance as derived, not user-editable).

**Rationale**: This directly satisfies SC-004 ("never a silent,
undocumented loss of the local edit") because the outbox entry is never
discarded by a pull — it always gets its own chance to reach the server and
becomes the new authoritative state once it does, per the server's actual
`now()` at that moment. It also satisfies FR-005's requirement that "the
pull does not unconditionally overwrite a newer local edit" — with
server-issued timestamps, "newer" is now well-defined and this algorithm
naturally converges to whichever write actually happened later in real
time, not whichever device's local clock claims to be later.

**Race condition closed by `<=`, not `==`** (found via advisor review of
the integrated design, not by any single decision in isolation): consider
push A draining from the outbox, the trigger stamping it `T1`, and the
`.select()` read-back writing `T1` to Drift via `applyRemoteRow` — all
while a batch from an initial pull or an FR-002a reconnect fetch, *issued
before* that push landed, is still in flight carrying this same row's
*older* value `T0`. If step 1 only skipped on exact equality, that
in-flight batch's `applyRemoteRow(row=T0)` would see `T0 ≠ T1` and
overwrite the local row back to `T0` — a real, if transient, regression:
FR-004's "re-applying MUST NOT alter anything beyond what the first
application already did" is violated (T0-over-T1 is an alteration), and
FR-008's "already-correct local state MUST NOT be... regressed" holds only
until the next Realtime rebroadcast of `T1` eventually corrects it back.
This is not covered by SC-003's own verification method (SC-003 compares
before/after "a pull cycle with no actual remote changes" — this race
specifically requires a *concurrent* write to manifest). Changing step 1's
comparison from strict equality to `<=` (skip whenever the incoming value
is not strictly newer than the local value) closes this window entirely
while remaining strictly stronger than the equality check — every case
that was already idempotent under `==` stays idempotent under `<=`, and
the previously-missed case (incoming `T0 <= local T1`) is now correctly
skipped instead of incorrectly applied.

**Alternatives considered**:

- **Pull compares its incoming `updated_at` against the local row's
  `updated_at` and skips applying if local is "newer" — i.e. exactly the
  `<=` rule adopted above.** Initially rejected (in an earlier pass of
  this decision) as unnecessary complexity, reasoning that "since the pull
  never touches the outbox (step 3), a pending local edit is never at risk
  of being lost... the pending edit will simply overwrite those fields
  again once it pushes." That reasoning holds only while the outbox
  *still holds* the pending edit — it does not cover the race above, where
  the outbox has already drained and there is nothing left to re-push and
  re-correct with. Re-accepted as step 1 once this gap was found; not
  "unnecessary branching for a cosmetic difference" as first assessed, but
  the specific mechanism that keeps FR-004/FR-008 correct under concurrent
  writes, not merely under sequential ones.
- **Accept `==`-only and rely on eventual consistency via Realtime
  rebroadcast to self-correct the race.** Rejected once the race was
  identified — the window is real and observable via `watch()` (any
  screen showing this row mid-window sees the stale `T0` value), and the
  fix (`<=` instead of `==`) is strictly free (no case becomes
  non-idempotent that wasn't already), so there is no correctness/cost
  trade-off that would justify accepting transient incorrectness here.

---

## Decision 9: No `connectivity_plus` — reactive-only connectivity handling

**Decision**: This feature does not add `connectivity_plus` or any other
connectivity-detection package. FR-006 ("pull MUST work correctly
regardless of connectivity at sign-in") and FR-002a (reconnect handling)
are both satisfied reactively: the Realtime channel's own subscribe-status
callback (`supabase_flutter`'s channel status stream) reports
connect/disconnect/reconnect events, and the initial fetch's HTTP calls
simply fail and get retried the same way `SyncWorker`'s push calls already
do (catch, leave state as "not yet complete," rely on the next trigger —
here, the channel's reconnect callback — to retry).

**Rationale**: A prior feature
(`specs/20260922-003635-rename-app-error-mapper/research.md:34`) explicitly
evaluated and rejected adding `connectivity_plus` for proactive
online/offline checks as out of scope for this project. This feature's
connectivity needs (know when Realtime reconnects; retry a failed initial
fetch) are fully covered by APIs the Realtime subscription itself already
exposes, so there is no new justification to reopen that prior decision.

**Alternatives considered**:

- **Add `connectivity_plus` to proactively detect connectivity changes and
  trigger a pull/retry.** Rejected — redundant with the Realtime channel's
  own status callback, and reopens a dependency decision a prior feature
  already closed for this project without new justification.

---

## Decision 10: DateTime storage precision — switch Drift to text storage

**Decision**: Enable `store_date_time_values_as_text: true` in this
project's Drift codegen configuration (`build.yaml`, new file — none
exists today), so every `DateTimeColumn` (existing and new) is persisted
as ISO-8601 text instead of Drift's default unix-seconds integer. This
requires a `schemaVersion` migration (part of the same 6→7 bump Decision 5
already introduces) that converts every existing `DateTimeColumn` value
in `expense_control_items` and `financial_transactions`
(`created_at`, `updated_at`, `deleted_at` on both tables) from its current
integer-seconds representation to text, in place.

**Rationale — the precision gap this closes**: Drift's default
unix-seconds storage truncates sub-second precision. The FR-005a trigger
stamps `updated_at` with Postgres `now()`, which carries microsecond
precision — but if the local column only stores whole seconds, two
server-issued timestamps that differ by, say, 400ms within the same
wall-clock second become *indistinguishable* once round-tripped through
local storage. This directly undermines Decision 8's `<=` idempotency
fix: if device Y receives a newer write first (stored, truncated, as
`12:34:56`) and then a batch delivers an older write that was genuinely
issued at `12:34:56.100`, the truncated-to-integer local comparison
(`12:34:56.100 <= 12:34:56.000`) evaluates false, and the older value
incorrectly overwrites the newer one — reopening, at the storage layer,
exactly the kind of correctness gap Decision 8 was written to close at
the algorithm layer. Text storage preserves the full precision Postgres
already sends, making the `<=` comparison actually correct rather than
merely correct-in-most-cases.

**Explicit user direction**: this was raised as an open question during
`/speckit-plan` (not left implicit) — the user confirmed Drift itself
remains the right local-database choice (no library change), and chose
switching to text storage over accepting the narrow same-second race as a
documented, self-correcting risk. This matches this feature's established
pattern (FR-005a's server-issued timestamps, FR-010's thousands-of-rows
batching) of closing a known correctness gap at its root once identified,
rather than deferring it as an accepted risk.

**Migration mechanics**: Drift's `store_date_time_values_as_text` option
changes how *new* writes are encoded; it does not itself rewrite existing
rows. The 6→7 migration (already required by Decision 5's `PullCursor`
table) additionally converts each existing `DateTimeColumn` value across
both tables from integer-seconds to the equivalent ISO-8601 text
representation, in the same migration step — no separate schema bump is
needed since both changes land in the same version transition.

**Migration mechanics, verified against Drift's own documentation and
source** (not assumed — confirmed via Drift's official "DateTime Storage"
migration guide, `drift.simonbinder.eu/guides/datetime-migrations/`, its
real snippet source in the `simolus3/drift` GitHub repo, and GitHub
Discussion #3603's documented pitfall):

- Once `store_date_time_values_as_text` flips, the generated typed API
  (`row.updatedAt` etc.) assumes text encoding — it MUST NOT be used to
  read the old integer-encoded values during migration. Drift's own
  official pattern for this exact scenario uses `Migrator.alterTable`
  with `TableMigration`'s `columnTransformer`, reading the old value via
  `column.dartCast<int>()` (an explicit override telling Drift "treat
  this column as `int` at the SQL/Expression level, ignoring what the
  generated column now believes it is") and converting via
  `DateTimeExpressions.fromUnixEpoch(...)` — this is a single
  `onUpgrade`/`from<N>To<N+1>` step, not a raw-SQL two-phase
  dump→convert→reload; `TableMigration` handles the
  create-new/copy-with-transform/drop-old/rename mechanics internally.
- **Critical, non-optional detail**: inside a step-by-step migration, the
  tables to migrate MUST be sourced from `schema.entities.whereType<TableInfo>()`
  (the schema snapshot for *that specific migration step*), **not
  `allTables`** (which reflects the current/final schema). GitHub
  Discussion #3603 documents a real data-loss incident caused by using
  `allTables` in exactly this situation — `/speckit-tasks`'s migration
  task MUST use the step-scoped schema, and this is worth a dedicated
  regression test given the documented precedent.
- `drift: ^2.22.1` (this project's pinned version) already includes both
  APIs this migration needs (`TableMigration`/`columnTransformer` since
  Drift 2.4; a 2.22.1 changelog fix specifically to `alterTable` for
  databases where `legacy_alter_table` is not writable) — no dependency
  version bump is required for this migration.
- Query-level code (raw `customStatement`/`customSelect`, `.drift` files,
  comparison/sort expressions built against these DateTime columns) is
  explicitly out of scope for the column-storage migration itself per
  Drift's own guide — `/speckit-tasks` MUST separately confirm no existing
  query in this codebase assumes integer DateTime encoding.

**Concrete instance found by that audit — MUST be fixed, not merely
noted**: `ExpenseControlRepositoryImpl.applyIncomeAllocation()`
(`expense_control_repository_impl.dart:386-396`) and `.recordExpense()`
(same file, lines 453-463) both write `updated_at` via raw
`_db.customUpdate('UPDATE expense_control_items SET ... updated_at = ? ...',
variables: [..., Variable(now.millisecondsSinceEpoch ~/ 1000), ...])` —
hardcoded integer-seconds encoding, bypassing the generated typed column
entirely (grep-confirmed: these are the only 2 call sites in `lib/` using
`millisecondsSinceEpoch` for a DateTime column write). After
`store_date_time_values_as_text` ships, these two raw writes MUST be
changed to write an ISO-8601 string (`now.toIso8601String()`, matching
what the generated API now produces for every other `DateTimeColumn`
write) instead of the integer expression — otherwise these two methods
silently write malformed data into a TEXT-typed column (SQLite's dynamic
typing accepts the INTEGER bind value without erroring, but every other
code path, including this feature's own `<=` conflict-resolution
comparison, would then be comparing a malformed integer-as-text value
against correctly-encoded ISO-8601 strings — a correctness break this
feature would have introduced, not merely failed to fix). This is a
required implementation task, not an optional audit finding.

**Alternatives considered**:

- **Accept the narrow same-second race as a documented, self-correcting
  risk (no storage change).** Rejected per explicit user direction — the
  window is real and the fix (enabling an existing Drift storage option
  plus a migration already being written for Decision 5) is not
  disproportionate to the correctness gap it closes, consistent with this
  feature's broader pattern of closing known gaps rather than accepting
  them.
- **Switch to a different local-database package with native sub-second
  precision.** Rejected — not needed. The precision loss is a Drift
  *configuration* default, not a limitation of Drift or SQLite itself;
  `store_date_time_values_as_text` is Drift's own built-in mechanism for
  exactly this case. Replacing Drift would abandon the ACID/typed-schema/
  reactive-`watch()` guarantees the constitution's Offline-First Data &
  Sync section specifically chose Drift for, to solve a problem Drift
  already has a configuration flag for.

---

## Summary of resolved unknowns

| Area | Resolution |
|---|---|
| `updated_at` server-authoritativeness | Postgres trigger + client read-back (Decision 1) |
| Realtime subscribe/fetch ordering | Subscribe first, then initial fetch (Decision 2) |
| `REPLICA IDENTITY` | `DEFAULT` is sufficient, do not set `FULL` (Decision 3) |
| Initial-pull pagination | Keyset `(updated_at, id)` (Decision 4) |
| Bootstrap/resume state | New Drift table, keyed `(user_id, table_name)` (Decision 5) |
| FR-011 loading vs. empty | Single `initialPullCompleteProvider` in `core/sync/` (Decision 6) |
| Pull/outbox interaction | Separate `applyRemoteRow` write path, never calls `_appendOutbox` (Decision 7) |
| Conflict resolution algorithm | Concrete 5-step algorithm using `<=` (not `==`) idempotency skip to close a concurrent-write race; outbox never touched by pull (Decision 8) |
| Connectivity detection | None added; reactive-only via Realtime status callback (Decision 9) |
| DateTime storage precision | Switch to `store_date_time_values_as_text`, migrate existing columns (Decision 10) |

No `NEEDS CLARIFICATION` markers remain — every Technical Context unknown
is resolved above.
