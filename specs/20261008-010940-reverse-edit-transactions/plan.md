# Implementation Plan: Delete, Edit and Reverse Saved Transactions

**Branch**: `20261008-010940-reverse-edit-transactions` | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/20261008-010940-reverse-edit-transactions/spec.md`

## Summary

A person can delete or edit a transaction for 24 hours after recording it, and after that only reverse it, and every
balance moves with the transaction in the same step. Doing that correctly on several devices exposes a gap in the app
today: an item's balance is a number each device writes as an absolute value and the last write wins, so two devices
(or a rename made offline, which also pushes the stale balance) can silently lose a correction. The constitution
already says balances are server-authoritative and must reconcile against the transaction log; the sync worker's own
comment says that redesign was deferred "if and when it becomes necessary". This feature is where it becomes necessary.

The approach, in one line: **an item's balance becomes a function of its transactions**, and every transaction change
(record, delete, edit, reverse, and the same changes arriving from another device) goes through one recompute step.

1. **Balance = `balance_base` + sum of the effects of the item's live transactions.** `balance_base` (new column) holds
   whatever balance the item had before this feature (backfilled by the migration, so nothing visible changes). The
   effect of a transaction is its amount, positive for income and negative for expense, and inverted for a reversal.
   The device recomputes it locally after each change (a small Dart helper, inside the same database transaction); the
   server does the same in Postgres triggers. Devices stop pushing balances. Applying the same change twice gives the
   same balance, which is what makes "corrected exactly once" true by construction.
2. **A reversal is an ordinary row with a positive amount** in `financial_transactions`, same direction as the
   original, carrying `reverses_id`. "Reversed" is derived (a live reversal row exists); a unique index on
   `reverses_id` makes a second reversal impossible, whichever device makes it.
3. **Server guards decide conflicts**, the same on every device: a delete can never be undone by a later edit, a row
   that is reversed cannot be edited, a reversal is normalized to the original it cancels, and deleting an original
   deletes its reversal. A change the server refuses is reported back to the person whose change it was.
4. **The 24-hour window is judged on the device that acts**, because the app is offline-first; the server enforces only
   structure, never the clock.
5. **Reports** show a reversal as its own figure in the month it is made (refunded expenses, withdrawn income), so no
   total goes negative and no closed month changes.
6. **The device reconciles against the server.** The constitution says a client must not trust a locally computed
   balance as final. Each device keeps the balance the server last reported (`server_balance`, local only), a
   `ReconciliationMonitor` compares it with the derived balance at settled points, re-synchronises once if they differ
   and, if they still differ, tells the person without overwriting either figure (FR-018, research Decision 10).
7. **A push response is applied unconditionally** (unless a later change to the same row is still waiting), so a device
   whose clock runs fast still receives "delete wins" and the normalised reversal (research Decision 6).

## Technical Context

**Language/Version**: Dart 3.13.4 / Flutter 3.47.5; Postgres on Supabase for the server migration.

**Primary Dependencies**: existing `drift` 2.22 (local database, `store_date_time_values_as_text`), `supabase_flutter`,
`flutter_riverpod` 2.6.1, `go_router`. **No new package.**

**Storage**: Drift schema **v7 → v8** (`financial_transactions.reverses_id`, `expense_control_items.balance_base` and the
local-only `server_balance`, outbox `rejected_at`/`reject_reason`, two indexes) and a new Supabase migration (same columns, a unique index, guard and recompute triggers). See
`data-model.md`.

**Testing**: `flutter_test` with an in-memory Drift database; a randomized sequence test (seeded `Random`) for the
balance invariant; a fake server in Dart that applies the same rules as the SQL (so two-device scenarios run
without a network); widget tests at compact and expanded widths; the SQL itself is exercised against the real
Supabase project with the QA account (rows prefixed `zz-`, hard-deleted afterwards), as done for the pull feature.
Line coverage of the domain and data layers (constitution, Principle II: at least 80 %) is measured at every pull
request gate with `flutter test --coverage` and a throwaway script (the repository has no coverage tooling yet); the
figure is recorded in `verification/README.md`. See `quickstart.md`.

**Target Platform**: Android, iOS, Web (all share the code). **Web verification (constitution, Multi-Platform):** this
feature is verified on Web alongside mobile: the manual checks of pull requests 2 and 3 run in a wide Chrome window and
the unit and widget tests cover the shared code; Drift on Web uses the existing same-origin `sqlite3.wasm` and
`drift_worker.js`, and nothing in this feature is platform-specific.

**Project Type**: Flutter mobile + web app with a Supabase back end.

**Performance Goals**: delete, edit and reverse feel instant (one local database transaction; a recompute is one
indexed sum per touched item); the initial pull of thousands of rows must stay within the existing 10 s budget, so the
pull recomputes once per batch per touched item, not once per row.

**Constraints**: FR-017 / SC-006 (an account that never uses the feature sees zero differences); no direct
`balance` write left anywhere; every correction in one local database transaction together with its outbox entries
(constitution, Offline-First); the app keeps working while a server migration is not applied yet only for reading
(mixed versions are out of scope, see the spec).

**Scale/Scope**: 5 stories; roughly 5 new files in `features/expense_control` (domain policy, correction repository and
its implementation, the shared ledger writes helper), new and changed files in `core/database` and `core/sync`, 4 new
screens, sheets or dialogs and 4 changed screens in `features/expenses`, 1 server migration, 1 pair of ARB files.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 design (below).* Constitution **v1.8.0**.

| Rule | Status | Note |
|------|--------|------|
| I. Code Quality (typed, small, documented, no dead code) | PASS | the old `balance = balance ± ?` statements and the item-row balance pushes are removed, not left behind |
| II. Testing (money math unit-tested; TDD for logic; 80 % line coverage of domain + data) | PASS | the effect function, the window, the action availability, the recompute and the conflict rules are pure and unit-tested first; a randomized test pins SC-002; coverage is measured at each PR gate (the repository has no tooling for it yet, so the first measurement is the baseline) |
| III. UX consistency (shared design system, confirmation dialog before deleting a transaction, empty/loading/error states, 48 dp, Semantics) | PASS | one confirmation pattern (the existing `AlertDialog` look), shared currency formatter, new strings in `vi` and `en`, adaptive sweep cases added |
| IV. Performance (local-first, no jank) | PASS | one indexed sum per touched item inside the writing transaction; batch recompute in the pull |
| Offline-First (outbox, soft delete, `updated_at`, server-authoritative balances, last-write-wins for editable fields) | PASS | balances are derived from the log on the server too and devices stop pushing them; each device reconciles its derived balance against the server's, re-synchronises once on a difference and surfaces a persisting one instead of overwriting (FR-018, Decision 10); the outbox carries the transaction rows |
| Multi-Platform (Web verified alongside mobile) | PASS | stated in Technical Context; checked in the manual-check tasks of pull requests 2 and 3 |
| Security (RLS on every table, no secrets in logs) | PASS | existing owner-only policies cover the new columns; triggers run as the caller; nothing new is logged |
| Money math in integers, one formatter | PASS | amounts stay `int` VND; the recompute is integer addition |
| Architecture (domain independent of Drift; repository interfaces; mappers) | PASS | the policy and the new repository interface live in `domain/`; the Drift code is in `data/` and `core/` |
| Development Workflow (shared `core/` changes called out; bug in shared code fixed at the root) | PASS | the PR descriptions list the `core/database` and `core/sync` changes; the stale-balance push is fixed at the root (Decision 1), not worked around |

**Post-design re-check**: unchanged; the one point worth a reviewer's attention is that this feature changes how
balances are produced for the existing record flows too (Complexity Tracking).

## Project Structure

### Documentation (this feature)

```text
specs/20261008-010940-reverse-edit-transactions/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── correction-operations.md   # what record/delete/edit/reverse do to rows and balances
│   ├── server-ledger.md           # the Postgres migration: columns, guards, recompute, what is refused
│   └── correction-ui.md           # actions per state, confirmations, messages, report figures
├── checklists/requirements.md
└── tasks.md                       # created by /speckit-tasks
```

### Source Code (repository root)

```text
supabase/migrations/<timestamp>_transaction_corrections.sql      # NEW: columns, backfill, guards, recompute

lib/core/database/
├── tables/financial_transactions_table.dart                     # + reverses_id
├── tables/expense_control_items_table.dart                      # + balance_base, server_balance (local only)
├── balance_ledger.dart                                          # NEW: effect(), recomputeBalances(db, itemIds), findDivergent(db)
└── app_database.dart                                            # schema v8 + migration (backfill balance_base)

lib/core/sync/
├── remote_row_writer.dart                                       # item apply keeps the derived balance; transaction apply recomputes; overwrite path, collision and cascade rules
├── pull_service.dart                                            # recompute once per batch; onCaughtUp; resync(); onConnected kicks a drain
├── sync_worker.dart                                             # push response applied unconditionally; refusals not retried forever; requestDrain; onIdle; override detection
├── sync_outbox_table.dart                                       # + rejected_at / reject_reason (a refusal the person is told about)
├── push_failure.dart                                            # NEW (pure): refusal vs transient classifier
├── sync_notice.dart, sync_notices_provider.dart                 # NEW: notices shown once (refusals, overrides, balance mismatch)
└── reconciliation_monitor.dart                                  # NEW: compares server_balance with the derived balance (FR-018)

lib/core/widgets/sync_notice_host.dart                           # NEW: shows each notice once (mounted in the app shell)

lib/features/expense_control/
├── domain/
│   ├── transaction_correction_policy.dart                       # NEW (pure): window, available actions
│   ├── transaction_correction_repository.dart                   # NEW (interface): delete, editExpense, reverse
│   └── transaction_history_record.dart                          # + reversesId, isReversed
└── data/
    ├── ledger_writes.dart                                       # NEW: appendOutbox + transactionPayload, shared by both repositories
    ├── expense_control_repository_impl.dart                     # recordExpense / applyIncomeAllocation use the recompute, no balance push
    └── transaction_correction_repository_impl.dart              # NEW

lib/features/expenses/
├── application/{transaction_history,report_summary,overview_recent_transactions}.dart  # reversal rows, refund figures
└── presentation/
    ├── transaction_actions_sheet.dart                           # NEW: details + the actions that apply
    ├── correction_confirm_dialog.dart                           # NEW: the one confirmation used by delete and reverse
    ├── edit_expense_dialog.dart                                 # NEW: amount + item, balance preview
    ├── transaction_history_screen.dart / overview_screen.dart   # rows open the sheet; reversed/reversal marks
    └── report_screen.dart                                       # refund figures

lib/core/l10n/app_vi.arb, app_en.arb                             # + correction strings

test/
├── unit/core/database/balance_ledger_test.dart
├── support/{correction_fixtures,fake_server_ledger}.dart
├── unit/core/sync/{remote_row_writer_ledger,sync_worker_response,sync_notices,reconciliation_monitor,sync_worker_rejection,fake_server_ledger,two_device_corrections}_test.dart
├── unit/features/expense_control/{transaction_correction_policy,transaction_correction_repository,balance_invariant_random}_test.dart
├── widget/features/expenses/{transaction_actions_sheet,edit_expense_dialog,report_refund}_test.dart
├── widget/core/widgets/sync_notice_host_test.dart
└── widget/core/adaptive_sweep_corrections_test.dart
```

**Structure Decision**: keep the layered, feature-first layout. The balance arithmetic is shared by every writer of
transactions (the record flows, the corrections and the sync paths), so it lives in `core/database` as one helper; the
rules of a correction (window, which actions apply, what a reversal is) are domain logic in `features/expense_control/
domain` with no Drift import; the screens stay in `features/expenses/presentation` next to the history they open from.

### Delivery slices

| PR | Stories | Contents | Depends on |
|----|---------|----------|------------|
| 1 | foundation (no visible change) | schema v8, `balance_base`, `server_balance`, the ledger helper, the record flows and the sync paths moved to it, no balance pushed, the push response applied unconditionally, sync notices and their host, the reconciliation monitor with `resync`, the server migration (columns, recompute, guards) | the server migration is applied to the Supabase project first |
| 2 | US1, US2 | delete and edit a recent transaction, the actions sheet, the confirmation, the edit dialog, history and overview rows; an income entry is deleted as a whole event from this slice on (FR-005), so the row selection that finds an income event ships here | PR 1 |
| 3 | US3, US4, US5 | reversal (income events reuse the same row selection), refund figures in the report, refusal and override notices, collision rules and prompt pushing | PR 2 |

The foundation ships alone first because it changes how every balance is produced; its whole acceptance test is SC-006
(nothing visible changes), which is easy to judge before any new screen exists.

## Complexity Tracking

| Item | Why it is needed | Simpler alternative rejected because |
|------|------------------|--------------------------------------|
| Balances derived from the log, recomputed on both sides | FR-014, FR-015, SC-002 and SC-004 cannot hold with absolute balances written by several devices: a correction made twice or a rename made offline overwrites another device's change | keeping absolute pushes loses updates; per-device deltas replayed on other devices double count when the item row also arrives (research Decision 1) |
| `balance_base` column and a backfill | keeps every existing balance exactly as it is, including balances that came from allocations made before the transaction log existed | recomputing from the log alone would change legacy balances (SC-006) |
| Server triggers for the conflict rules | the same outcome on every device, whatever the order the changes arrive in, including a device that is offline for days | resolving conflicts on the clients cannot give one outcome without the server's order |
| A unique index on `reverses_id` | "reversed at most once" for any number of devices (FR-007, FR-014) | a client-side check cannot see another device's reversal made offline |
| `rejected_at` / `reject_reason` on the outbox | a change the server refuses must be shown to the person once, and must not be retried forever (today every failure is retried) | silently dropping or endlessly retrying the row |
| `server_balance` column and the reconciliation monitor | the constitution requires reconciling a locally computed balance against the server's and surfacing a divergence; derived balances make a divergence rare, which is why it must be detectable (FR-018) | ignoring the server's balance (no reconciliation); adopting it silently (overwrites local data); comparing when the item row is applied (false alarms while its transactions are in flight) |
| A push response applied unconditionally | a device whose clock runs fast would otherwise ignore the server's "delete wins" and normalised reversal, and keep a future-dated `updated_at` that blocks later changes (research Decision 6) | keeping the strictly-newer check for responses; a clock-skew correction table (more machinery for the same result) |
