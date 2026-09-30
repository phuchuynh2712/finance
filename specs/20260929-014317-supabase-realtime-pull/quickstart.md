# Quickstart: Verifying the Pull Mechanism

**Feature**: [spec.md](./spec.md) | **Date**: 2026-09-29

Manual/integration verification scenarios, matching each user story's own
Independent Test plus the spec's Success Criteria. These are the scenarios
`/speckit-tasks`' Polish phase and this feature's own manual QA pass should
run before considering the feature done — automated widget/unit tests
(per plan.md's test file list) cover the same logic at a finer grain, but
these end-to-end scenarios are what actually exercise two real devices/
browser profiles against a real Supabase project, which no unit test can
substitute for.

## Prerequisite setup

1. Apply the new migration (`supabase/migrations/<timestamp>_realtime_pull_setup.sql`)
   to the target Supabase project (local dev project, per this repo's
   existing `supabase/` workflow).
2. Have two ways to run the app as two independent "devices": e.g. one
   Android emulator + one Chrome browser profile, or two separate Chrome
   profiles — anything that gives two independent local Drift databases
   signed into the same Supabase account.

## Scenario 1 — User Story 1, Acceptance Scenario 1 (SC-001, SC-008)

**Matches**: spec.md User Story 1, Acceptance Scenario 1; SC-001; SC-008.

1. On Device A, sign in and create several expense-control items and
   transactions (a "non-trivial dataset," per SC-008 — a handful of rows
   is enough to observe the loading-vs-empty distinction; use FR-010's
   batching test, Scenario 5 below, for a genuinely large dataset).
   Confirm they sync to Supabase (already-working push path).
2. On Device B — freshly installed, or a fresh browser profile that has
   never held this account's data locally — sign in with the same
   account.
3. **Expect**: immediately after sign-in, every data screen shows a
   loading/skeleton state (FR-011), not the empty-state UI, even though
   Device B's local database is genuinely empty at that instant.
4. **Expect**: within 10 seconds (SC-001), every item and transaction
   created on Device A appears on Device B, without the user touching
   anything beyond signing in.
5. **Expect**: once the pull completes, the loading state disappears and
   does not reappear for the remainder of this session (FR-011's "applies
   once, at startup" clause).

## Scenario 2 — User Story 1, Acceptance Scenario 2 (SC-005)

**Matches**: spec.md User Story 1, Acceptance Scenario 2; SC-005.

1. With both Device A and Device B signed in and Device B's initial pull
   already complete (Scenario 1), leave Device B's app open and in the
   foreground on a data screen.
2. On Device A, create a new transaction, then separately edit an
   existing expense-control item's name.
3. **Expect**: both changes appear on Device B's UI without restarting
   the app or performing any manual refresh — verified for both an insert
   (the new transaction) and an update (the renamed item), per SC-005's
   explicit requirement to check both.

## Scenario 3 — User Story 1, Acceptance Scenario 4 (SC-002)

**Matches**: spec.md User Story 1, Acceptance Scenario 4; SC-002.

1. On Device A, delete an expense-control item (soft-delete —
   `deleted_at` gets set, per the existing convention).
2. On Device C — a third, freshly-signed-in device/profile that has never
   held this account's data locally — sign in.
3. **Expect**: the soft-deleted item does NOT appear anywhere Device C's
   UI already excludes soft-deleted rows (item lists, any place a
   deleted item's transactions might otherwise show) — zero
   tombstone-resurrection, across both syncable tables (repeat with a
   soft-deleted transaction too).

## Scenario 4 — User Story 1, Acceptance Scenario 3 (FR-006)

**Matches**: spec.md User Story 1, Acceptance Scenario 3; FR-006.

1. Put Device D into airplane mode / disable network *before* signing in.
2. Attempt sign-in (this MUST still succeed against a cached/offline auth
   session if one exists, or wait until step 3 if a fresh sign-in requires
   connectivity — the pull specifically, not auth, is what this scenario
   verifies).
3. Re-enable connectivity.
4. **Expect**: the initial pull completes automatically once connectivity
   returns, without the user needing to sign out and back in.

## Scenario 5 — FR-010/SC-007 (batching and resumability)

**Matches**: spec.md FR-010; SC-007.

1. Seed a test Supabase project with a genuinely large dataset (several
   thousand rows in at least one syncable table — matching the
   Clarifications' explicit data-volume decision) — a seed script, not
   manual entry, per FR-010's actual target scale.
2. On a freshly-signed-in device, begin sign-in, and force-quit the app
   (or kill connectivity) partway through the initial pull — after at
   least one batch has visibly committed (e.g. some rows already visible
   in the UI) but before the pull reports complete.
3. Relaunch the app / restore connectivity.
4. **Expect**: the pull resumes and completes without re-fetching the
   batches that had already committed before the interruption (verifiable
   via logging/instrumentation showing the resumed fetch's first request
   starting from the interrupted cursor position, not from the beginning)
   — this is SC-007's literal verification method.

## Scenario 6 — User Story 2 (SC-004, conflict resolution)

**Matches**: spec.md User Story 2, both Acceptance Scenarios; SC-004.

1. On Device A, go offline, then rename an expense-control item.
2. On Device B (online), rename the *same* item to a different name and
   let it sync to Supabase.
3. Reconnect Device A.
4. **Expect**: per research.md Decision 8's algorithm — Device A's
   pending outbox entry is never silently discarded by the incoming pull;
   it drains normally, reaches Supabase, gets a fresh server-issued
   `updated_at` via the trigger (research.md Decision 1), and (per the
   constitution's last-write-wins-by-`updated_at` policy) becomes the
   final state precisely because it was pushed *after* Device B's write
   reached the server — verify the final name matches whichever edit's
   push actually landed later in real server time, and that neither
   device's UI silently reverts without the user being able to tell what
   happened (SC-004's "never a silent, undocumented loss" bar).
5. Repeat with a balance-affecting operation (e.g. an income allocation)
   instead of a name edit — **expect** the server-authoritative balance
   value wins regardless of push ordering, per the constitution's
   explicit balance carve-out (spec.md User Story 2, Acceptance
   Scenario 2).

## Scenario 7 — FR-008 (no regression for an already-correct device)

**Matches**: spec.md Edge Cases ("already has full local data"); SC-003.

1. On Device A (the original device, with correct, complete local data
   and nothing pending in the outbox), record its current local row
   counts and a few representative row values for both tables.
2. Let the pull mechanism run its normal course on Device A (e.g. via an
   app restart, triggering the reconnect-or-startup pull path).
3. **Expect**: zero duplicate rows, zero unexpected value changes —
   local row counts and content are byte-for-byte identical before and
   after, per SC-003's explicit verification method.

## Scenario 8 — FR-002a (reconnect mid-session)

**Matches**: spec.md Edge Cases ("live connection... drops mid-session");
FR-002a.

1. With Device B signed in and its initial pull already complete, disable
   its network connectivity (not app backgrounding — an actual network
   drop, e.g. airplane mode) while the app stays in the foreground.
2. While Device B is disconnected, make a change on Device A (create a
   transaction).
3. Re-enable Device B's connectivity.
4. **Expect**: Device B automatically reconnects and the change made
   during the disconnection window appears — verifying the "re-run a full
   catch-up pull on reconnect" behavior (FR-002a) actually recovers a
   change that a live-subscription-only recovery would have missed
   (since the subscription itself was down when the change happened).

## Web-specific verification

Per constitution Multi-Platform Support's "every new feature's plan MUST
state whether it was verified on Web alongside mobile" — repeat at least
Scenarios 1, 2, and 6 with one of the two devices/profiles being a Chrome
browser session (Drift-on-Web via `DriftWebOptions`), confirming the pull,
live updates, and conflict resolution all behave identically to the mobile
case.
