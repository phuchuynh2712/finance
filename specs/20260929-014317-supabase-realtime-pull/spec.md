# Feature Specification: Pull Remote Data From Supabase Into Local Database

**Feature Branch**: `20260929-014317-supabase-realtime-pull`

**Created**: 2026-09-29

**Status**: Draft

**Input**: User description: "Pull dữ liệu từ Supabase về local Drift database — thiết lập cơ chế đồng bộ 2 chiều thực sự (hiện tại chỉ có push local lên server, chưa có pull remote về local)"

## Clarifications

### Session 2026-09-29

- Q: FR-005/SC-004's last-write-wins conflict resolution compares
  `updated_at` — but that field is currently written using each device's
  own local clock (`DateTimeColumn.withDefault(currentDateAndTime)`), not
  a server-issued timestamp. If two devices' clocks are skewed,
  last-write-wins can silently pick the wrong row. Should this feature
  address that risk, and if so, where? → A: Yes, fix it at the root,
  within this feature — `updated_at` MUST become a server-issued
  timestamp (Postgres `now()`, not a client-supplied value) for every
  push, and the client MUST read that authoritative value back so local
  and remote `updated_at` are always the same clock's output. This
  extends this feature's scope to include the push path
  (`sync_worker.dart`) and a Supabase-side change (trigger or
  column default) — deliberately, per the constitution's
  shared-code-bug-found-during-a-feature rule (Development Workflow,
  v1.7.0): the risk was discovered while specifying this feature's own
  conflict-resolution requirement, so it is fixed here rather than
  deferred to a separate feature.
- Q: If the Realtime connection drops mid-session (not at sign-in, but
  during active use — e.g. a temporary network loss) and later
  reconnects, what must happen to avoid missing changes that occurred
  while disconnected? → A: Auto-reconnect, then re-run a full pull (the
  same one used at sign-in) — simpler than tracking exactly what was
  missed, and guarantees nothing is lost regardless of how long the
  disconnection lasted.
- Q: SC-001's 10-second target for the initial pull needs a data-volume
  assumption to be a meaningful, testable number — real production data
  today is ~15 rows total (a personal/family finance app, not
  multi-tenant), but what scale should the pull be designed to handle
  well? → A: Thousands of rows per table, with batching/pagination
  designed in from the start — deliberately more than current real usage
  needs, per explicit user direction to build this robustly now rather
  than as a later upgrade.
- Q: While the initial catch-up pull is still in progress (most notably
  right after sign-in on a brand-new device), does the user need an
  explicit indication that data is loading — to avoid mistaking "still
  pulling" for "this account genuinely has no data"? → A: Yes — the
  screen MUST show a loading/skeleton state, not the empty-state UI,
  until the first full pull completes; only after that pull finishes
  with genuinely zero rows does the existing empty-state UI apply.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Data created on one device appears on another (Priority: P1) 🎯 MVP

A user who has already been using the app on their phone (where their
accounts, budget items, and transactions were created and pushed to
Supabase) opens the app for the first time on a second device — a new
phone, a browser, or after reinstalling — and signs in with the same
account. Today, the app shows a completely empty state on that second
device even though their data genuinely exists on the server, because
nothing ever brings server data down into the local database that every
screen actually reads from.

**Why this priority**: This is the single missing half of the sync
architecture the app's own constitution already mandates ("the app MUST
use Supabase Realtime... to receive remote updates and upsert them into
Drift") — every screen in the app (Home Overview, Expense Control,
Transaction History, Monthly Report) reads exclusively from the local
database, so until this exists, "multi-device" and "reinstall-safe" are
false claims for every one of them, not a gap in one screen.

**Independent Test**: On Device A, create an expense-control item and a
transaction, confirm they sync to Supabase (already verified working).
On a freshly-installed Device B (or a fresh browser profile), sign in with
the same account and confirm both the item and the transaction appear,
without the user performing any manual "sync now" action.

**Acceptance Scenarios**:

1. **Given** a user has expense-control items and transactions already on
   Supabase from a prior session on another device, **When** they sign in
   on a device/browser that has never held that data locally, **Then**
   every one of those rows appears in the app within a bounded time after
   sign-in, without requiring the user to create or touch anything first.
2. **Given** the user is signed in and the app is already running, **When**
   a row is created, updated, or soft-deleted on Supabase from another
   device (e.g. an item's balance changes after an allocation on Device A),
   **Then** that change appears in this app's own UI without the user
   restarting the app or manually refreshing.
3. **Given** the device is offline when it first signs in, **When**
   connectivity returns, **Then** the pull completes automatically — the
   user is not required to be online at the exact moment of sign-in.
4. **Given** a row was soft-deleted on the server (its `deleted_at` is
   set), **When** that row is pulled to a device that has never seen it
   before, **Then** it does NOT appear anywhere the app already filters
   out soft-deleted rows (item lists, transaction history) — a pull must
   respect the same tombstone convention the rest of the app already
   does, not resurrect deleted data.

---

### User Story 2 - A pulled row never collides destructively with an unsynced local edit (Priority: P2)

A user is offline and edits an expense-control item (renames it, changes
its formula) while, unknown to them, a different edit to that same item
happened on another device and already reached Supabase. When this
device reconnects, both the outbox's pending push and the newly-arriving
pull for that same row are in flight around the same time.

**Why this priority**: This is a real correctness risk specific to adding
a pull path to an existing push-only outbox system — getting it wrong
could silently discard a user's own unsynced edit, which the constitution
treats as a first-class concern ("the client MUST NOT trust a locally
computed balance as final... surface a reconciliation conflict to the
user rather than silently overwriting local data if the two diverge
unexpectedly"). It is P2, not P1, because it only matters once pulling
exists at all (P1) and requires an actual conflict to occur, which is
less common than the base "second device sees nothing" gap.

**Independent Test**: On Device A, go offline, edit an item's name. On
Device B (still online), edit the same item's name to something
different and let it sync. Reconnect Device A and confirm the documented
resolution (last-write-wins by `updated_at`, per the constitution) is
what actually happens — and that Device A's own pending outbox write is
not silently dropped without the user ever finding out which version won.

**Acceptance Scenarios**:

1. **Given** a local row has a pending, not-yet-synced outbox entry,
   **When** a pull delivers a remote version of that same row, **Then**
   the resolution follows the constitution's last-write-wins-by-
   `updated_at` rule for user-editable fields — the pull does not
   unconditionally overwrite a newer local edit, and a push does not
   unconditionally overwrite a newer remote edit.
2. **Given** a balance field specifically (not a user-editable field like
   name/description), **When** local and remote diverge, **Then** the
   server-authoritative value wins — per the constitution's explicit
   carve-out that balances are never trusted from a local computation as
   final.

---

### Edge Cases

- What happens the very first time a brand-new account (no data on
  Supabase yet) signs in? The initial pull still runs and completes with
  zero rows; only once it has finished does the existing empty-state UI
  (already implemented on every screen) appear — a genuinely new account
  is not shown the empty state before the pull has had a chance to
  confirm there is, in fact, nothing to show.
- What happens if the initial catch-up pull is still in progress when the
  user navigates to a data screen? The screen shows a loading/skeleton
  state (FR-011) rather than the empty-state UI, so the user cannot
  mistake "still pulling" for "this account has no data." Once the
  initial pull completes, the screen switches to its normal reactive
  `watch()`-driven display — either the pulled rows, or the empty state
  if there genuinely are none — and any rows that stream in afterward
  (live updates, not the initial pull) continue to appear incrementally
  as they always would.
- What happens to a device that already has full local data (the normal,
  already-working case — e.g. the phone where the data was created) once
  this feature ships? It must not regress — an already-correct local
  device must not have its own data overwritten or duplicated by
  redundant pulls of rows it already holds correctly.
- What happens if the same row is pulled twice (e.g. a reconnect
  re-delivers something already applied)? The result must be idempotent
  — applying the same remote row state twice must not create a duplicate
  or change anything beyond the first application.
- What happens if the live connection to Supabase drops mid-session (not
  at sign-in) and later reconnects? The app MUST automatically reconnect
  and then re-run a full pull (the same catch-up fetch used at sign-in)
  — not merely resume listening for new changes — so nothing that
  happened while disconnected is missed, regardless of how long the gap
  was. This relies on FR-004's idempotency guarantee to make re-pulling
  already-known rows safe.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On sign-in, for a device/browser whose local database does
  not yet hold a given user's data, the system MUST fetch that user's
  existing rows from every syncable table (`expense_control_items`,
  `financial_transactions`) and write them into the local database.
- **FR-002**: While the app is running and the user remains signed in,
  the system MUST continue receiving row-level changes (insert, update,
  soft-delete) made to that user's data on Supabase — by any device — and
  apply them to the local database without requiring an app restart.
- **FR-002a**: If the live connection drops mid-session, the system MUST
  automatically reconnect and then re-run a full catch-up pull (the same
  fetch used at sign-in) upon reconnecting — not merely resume listening
  for new changes — so that changes made while disconnected are not
  missed, regardless of the disconnection's duration.
- **FR-003**: A pulled row's soft-delete state (`deleted_at`) MUST be
  applied locally using the same tombstone convention already used for
  local soft-deletes — a pulled deleted row MUST NOT appear anywhere the
  app already excludes soft-deleted rows.
- **FR-004**: Applying a pulled row MUST be idempotent — re-applying an
  already-applied row's unchanged state MUST NOT create a duplicate row,
  change `updated_at` unnecessarily, or otherwise alter anything beyond
  what the first application already did.
- **FR-005**: When a row has a pending, unsynced local outbox entry at
  the moment a pull delivers a remote version of that same row, the
  system MUST resolve the conflict per the constitution's existing
  policy — last-write-wins by `updated_at` for user-editable fields,
  server-authoritative for balance fields — rather than the pull
  unconditionally overwriting the pending local edit or the pending
  local edit unconditionally blocking the pull.
- **FR-005a**: `updated_at` MUST be a server-issued timestamp for every
  row pushed to Supabase — the client MUST NOT supply its own
  device-clock value as the authoritative `updated_at` a last-write-wins
  comparison relies on. After a push, the client MUST reconcile its local
  `updated_at` to match the value Supabase actually recorded, so a
  device's own local clock skew cannot cause it to lose or incorrectly
  win a future conflict comparison against another device's writes.
- **FR-006**: The pull MUST work correctly regardless of connectivity at
  the moment of sign-in — if the device is offline when the user signs
  in, the pull MUST complete once connectivity is available, without
  requiring the user to sign out and back in.
- **FR-007**: The pull MUST only ever retrieve rows belonging to the
  signed-in user — this MUST be enforced the same way every other data
  access in this app already is (Supabase RLS owner-only policies), not
  by a client-side filter alone.
- **FR-008**: A device that already holds a user's data correctly and
  up to date MUST NOT have that data altered, duplicated, or regressed
  by this feature — pulling is additive/corrective, never destructive to
  already-correct local state.
- **FR-009**: The UI MUST reflect newly-pulled rows through the app's
  existing reactive read path (`watch()` streams already consumed by
  every screen) — this feature MUST NOT require any screen to add a
  manual refresh action or poll for pulled data.
- **FR-010**: The initial catch-up pull MUST fetch rows in bounded
  batches (not one unbounded query returning an entire table's rows at
  once) and write each batch to the local database as its own local
  transaction — so a table with thousands of rows does not require
  holding an entire result set in memory at once or blocking the UI
  thread for the full duration of the pull, and so a batch failing
  partway through does not require re-fetching batches that already
  completed successfully.
- **FR-011**: While a device's initial catch-up pull for the signed-in
  user has not yet completed, every screen that reads pulled data MUST
  show a loading/skeleton state rather than that screen's normal
  empty-state UI — so a device that is still receiving a user's existing
  data cannot be mistaken for an account that genuinely has none. Once
  the initial pull completes, this loading state MUST NOT reappear for
  that sign-in session (it applies once, at startup, not to every
  subsequent live update from FR-002).

### Key Entities

- **Remote change feed subscription**: represents this device's live
  connection to Supabase's row-level change stream for the signed-in
  user's own rows, scoped per syncable table, active for as long as the
  user is signed in.
- **Initial pull cursor / bootstrap state**: represents whether a given
  local database has already completed its first full pull for the
  currently signed-in user, so the app can distinguish "still needs an
  initial catch-up fetch" from "already caught up, only needs live
  updates from here."

*(No new user-facing entity — this feature reads and writes the same
`ExpenseControlItem`/`FinancialTransaction` local rows and Supabase
tables that already exist; see Assumptions for what is explicitly out of
scope.)*

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user's existing Supabase data is fully visible on a
  freshly-signed-in device within 10 seconds of sign-in completing, under
  normal connectivity, for a dataset of up to several thousand rows per
  table, verified across both syncable tables.
- **SC-002**: 100% of soft-deleted rows pulled to a new device are
  excluded from every list/view that already excludes local soft-deletes
  — zero tombstone-resurrection defects across both tables.
- **SC-003**: A device with an already-complete, already-correct local
  dataset shows zero duplicate rows and zero unexpected data changes
  after this feature is active — verified by comparing local row counts
  and content before and after a pull cycle with no actual remote
  changes.
- **SC-004**: A conflict between a pending local outbox edit and an
  in-flight pull for the same row resolves according to the documented
  last-write-wins/server-authoritative rules in 100% of tested conflict
  scenarios — never a silent, undocumented loss of the local edit.
- **SC-005**: A live remote change (made on a second device while this
  device is running and signed in) appears in this app's UI without an
  app restart, verified for both an insert and an update.
- **SC-006**: After a push, a row's local `updated_at` matches what
  Supabase actually recorded for that row in 100% of tested cases —
  verified by deliberately setting one test device's clock ahead of or
  behind another's and confirming last-write-wins still resolves
  correctly (the earlier real-world write wins, regardless of which
  device's local clock reads later).
- **SC-007**: If the app is closed or loses connectivity partway through
  an initial catch-up pull, resuming does not require re-fetching batches
  already written to the local database — verified by interrupting a
  multi-batch pull and confirming only the remaining, not-yet-applied
  batches are re-fetched.
- **SC-008**: A brand-new device signing in with an account that has
  existing Supabase data never displays that screen's empty-state UI
  before the initial pull completes — verified by signing in on a fresh
  device with a non-trivial dataset and confirming a loading/skeleton
  state, not the empty state, is what appears first on every data
  screen.

## Assumptions

- **Scope covers both the pull path and the push-side `updated_at` fix**
  (FR-005a) — the clock-skew risk was found while specifying this
  feature's own conflict-resolution requirement (Clarifications, Session
  2026-09-29), so per the constitution's shared-code-bug rule it is fixed
  here rather than deferred; this is the one place this feature's scope
  extends beyond "pull only" into the existing push path.
- **Scope is otherwise limited to the 2 currently-syncable tables**
  (`expense_control_items`, `financial_transactions`) — a generic "pull
  any future table" abstraction is out of scope because no third table
  exists yet to design against; adding one now would be guessing at a
  shape instead of building to a known requirement. This is unrelated to
  FR-010's batching: batching is not a hypothetical, it is a specified,
  known requirement (per explicit user direction, Clarifications, Session
  2026-09-29) that the pull must correctly handle thousands of rows per
  table from the start, even though real production data today is ~15
  rows total. The two are governed by the same standard — build correctly
  for requirements that are actually known — not by a tradeoff between
  "minimal scope" and "robust engineering."
- **Supabase Realtime is the pull mechanism**, per the constitution's
  explicit mandate ("the app MUST use Supabase Realtime... rather than
  polling") — this is not re-litigated as an open choice in this spec;
  `/speckit-plan`'s research phase covers the concrete setup (Postgres
  Realtime publication is not yet enabled on either table at the database
  level — confirmed by reading the existing migrations — so enabling it
  is in scope as part of this feature, not a separate prerequisite
  feature).
- **Conflict resolution reuses the constitution's already-decided
  policy** (last-write-wins by `updated_at` for user-editable fields,
  server-authoritative for balances) — this feature implements that
  existing decision for the pull path, it does not invent a new conflict
  policy.
- **Account-level multi-device testing, not new auth work**: this
  feature assumes the existing single-account, RLS-owner-scoped auth
  model is unchanged — "another device" in the scenarios above means the
  same signed-in account on two separate app installs, not a new
  multi-user sharing/collaboration feature.
- **No new UI is introduced** — no manual "sync now" button, no sync
  status indicator is required to satisfy this spec's functional
  requirements (FR-009 explicitly rules out requiring a manual refresh
  action); a future feature MAY add sync-status visibility, but it is not
  needed for pulled data to correctly reach the existing reactive UI.
