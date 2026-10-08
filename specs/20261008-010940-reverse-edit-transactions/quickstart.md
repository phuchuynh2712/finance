# Quickstart: Verifying Delete, Edit and Reverse

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-10-08

Run the gate after every slice; the manual checks are recorded as text in `verification/README.md` (screenshots are
reviewed and deleted, not committed).

## 0. Prerequisites

```bash
flutter pub get
cp tool/env.example.json tool/env.json   # public Supabase URL + publishable key
```

The Supabase migration (`supabase/migrations/<timestamp>_transaction_corrections.sql`) is applied to the project
**before** the app is run against it (the owner applies it). The QA account is in `.env.test-credentials` (read by
scripts only, never printed); every row a script creates is named with the prefix `zz-` and hard-deleted afterwards,
so the account ends as it started.

## 1. Automated gate (every slice)

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze        # only the 2 existing onReorder infos
flutter test
flutter test --coverage   # then a throwaway script reads coverage/lcov.info (domain + data layers, at least 80 %)
```

The repository has no coverage tooling, so the first measurement (Setup) is the baseline; each gate records the figure
for the domain and data layers in `verification/README.md`. A file this feature adds or changes stays at 80 % or more.

## 2. Manual checks, per slice

### Foundation (PR 1): nothing visible changes (SC-006)

Before applying the migration and the app, fingerprint the QA account on the server and on a device running the old
build (every item's name, balance and `updated_at`-independent fields, every transaction row); apply the migration;
install the new build over the old one; fingerprint again: identical. Record an expense and an income on the new build
and compare the balances with the old arithmetic. Two devices: record on one, see the balance on the other without
restarting.

Reconciliation (FR-018): on the emulator, with the app stopped, set `server_balance` of one item to a wrong value in the
device database (copy `app_flutter/finance.sqlite` out with `adb exec-out run-as`, edit it with the `sqlite3` CLI,
push it back); start the app: within about 15 seconds the value is back to the server's (the one new synchronisation) and
**no** notice is shown. For a difference that stays, insert a local-only transaction row (not in the outbox) and fix the
item's `balance` accordingly: after the one new synchronisation the snack bar "does not match the server's" appears once
the app is unlocked. (On a cold start the Android debug build shows the lock screen, which is the sign-in form.)

### US1, US2 (PR 2): delete and edit a recent transaction

| Check | Pass |
|-------|------|
| Record an expense, open it in Lịch sử, delete, confirm | the balance is what it was before; the row is gone from Lịch sử, Tổng quan and Báo cáo |
| Cancel the confirmation | nothing changes |
| Record an expense, edit the amount, then the item | both balances right; date and time unchanged; the name and group of the new item show |
| Edit to an empty or zero amount | save is blocked with a message |
| Edit an expense so that its item becomes negative | a warning shows and the edit is saved |
| Count the steps for delete, edit and reverse (SC-001) | at most three each, under 20 seconds |
| Airplane mode, delete, then reconnect | the same result on the other device |

### US3, US4, US5 (PR 3): reverse, income events, conflicts

| Check | Pass |
|-------|------|
| A transaction past 24 h (create one with an old `occurred_at` through the QA script) offers only Reverse | confirmed; the reversal row appears, the original is tagged, the balance moves by the amount |
| Reverse again, or open the reversal | no action offered |
| Record an income that allocates to several items; delete it from any entry | all balances return together |
| The same income past 24 h; reverse | one reversal per item, all balances reduced |
| Report of a closed month after a reversal in this month | unchanged; the refund figure shows in this month |
| Two devices offline: delete on one, edit on the other; reconnect | deleted on both, the editing device is told once |
| Two devices offline: reverse the same transaction on both | one reversal only, balance corrected once, the second device is told |
| Delete on one device (inside the window) and reverse on another | deleted, no reversal row left, balance corrected once |
| Two devices offline: edit the same expense on both; reconnect | the last edit is kept on both, the first editor is told once |
| A device whose clock is ahead (if the emulator allows setting it, 10 minutes) edits a transaction that another device deleted | after syncing the edit is gone on the fast device too and its balance matches the server's |

### SQL against the real project

The checks listed in `contracts/server-ledger.md` §7, by REST with the QA account.

## 3. Regression (SC-006) and layout

A tapped row opens the sheet at every width of the sweep; the history, the overview and the report are otherwise as
before for an account that never uses the actions; screenshots reviewed on the Android emulator and the iOS simulator
(compact), and a wide browser window, in light and dark, and deleted.

## 4. Done checklist

- [ ] Contract rows of the slice pass (`contracts/`, recorded in `verification/README.md`).
- [ ] Format, analyze and the full suite are green; the domain and data coverage figure is recorded and not below 80 % (or not below the recorded baseline, with the reason, if the baseline was already lower).
- [ ] Manual checks above done and written down as text; screenshots deleted; the QA account is as it started.
- [ ] Layout and accessibility checks of `contracts/correction-ui.md` §7 pass for every new screen.
- [ ] New strings exist in `vi` and `en`.
- [ ] `tasks.md` items checked off.
- [ ] The pull request description lists the `core/database` and `core/sync` changes and the server migration, as the
      constitution's Development Workflow requires.
