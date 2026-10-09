# Verification: Delete, Edit and Reverse Saved Transactions

Evidence recorded as text while implementing `tasks.md`. No screenshots are committed. The QA account is only read and
written through the public URL and publishable key; every row a script creates is named `zz-…` and hard-deleted.

## Baseline (T001)

- Branch `20261008-010940-reverse-edit-transactions`, commit `b2aae00` (master), plus the Spec Kit files of this feature.
- `dart format --output=none --set-exit-if-changed lib test`: 261 files, 0 changed.
- `flutter analyze`: only the 2 existing `onReorder` infos
  (`expense_control_screen.dart:198`, `expense_group_card_test.dart:44`).
- `flutter test`: **1828 tests, all passed.**
- Line coverage (`flutter test --coverage`, a throwaway scratchpad script over `coverage/lcov.info`):

  | Layer | Lines hit / found | Coverage |
  |-------|-------------------|----------|
  | `lib/features/*/domain/` | 121 / 124 | 97.6 % |
  | `lib/features/*/data/` | 264 / 272 | 97.1 % |
  | **domain + data** | **385 / 396** | **97.2 %** |
  | `lib/core/database/` (non-generated) | 60 / 101 | 59.4 % |
  | `lib/core/sync/` (non-generated) | 141 / 202 | 69.8 % |

  The constitution's 80 % gate is for domain + data; `core/database` and `core/sync` were already below it before this
  feature (their baseline is the figure to hold or improve).
- No new package is added, so the constitution's dependency review does not apply.

## Inputs (T002)

- `tool/env.json` and `.env.test-credentials` exist and are untracked.
- Android emulator `Pixel_10` exists (adb at `~/Library/Android/sdk/platform-tools/adb`); iOS simulators `iPhone 17 Pro`
  and `iPhone 17 Pro Max` exist (there is no plain `iPhone 17`); the Python `playwright` module is not installed in the
  system Python, earlier sessions drove Chrome through the helpers kept in the session scratchpad.
- **The feature's Supabase migration is not applied yet.** With the QA login, `select=reverses_id` on
  `financial_transactions` returns `400 / 42703 column financial_transactions.reverses_id does not exist`, and
  `select=balance_base` on `expense_control_items` returns the same code. The QA account holds 8 live items and 7
  transactions.

## Before (T003)

- **Writers of `balance`** (`grep -rn balance lib/features/expense_control/data lib/core/sync`): the two
  `customUpdate` statements `balance = balance + ?` in `applyIncomeAllocation` (line 407) and `balance = balance - ?`
  in `recordExpense` (line 477) of `expense_control_repository_impl.dart`; `_payloadOf` sends `'balance': item.balance`
  (line 89); `remote_row_writer.dart:109` stores the pulled `balance` as-is.
- **Outbox entries per record action:** two (the item row carrying its new absolute balance, and the transaction row).
- **Tests that pin the retired behavior:** `test/unit/core/sync/conflict_resolution_test.dart` cases (c) "a balance
  field always takes the pulled/live value as-is" and (T029). The comment at the top of
  `lib/core/sync/sync_worker.dart` (lines 19-23) says reconciliation of `ExpenseControlItem.balance` is deferred "if and
  when that becomes necessary".
- **Root cause behind research Decision 6:** `applyRemoteExpenseControlItem` and `applyRemoteFinancialTransaction` ignore
  a server row whose `updated_at` is not strictly later than the local one (`remote_row_writer.dart:45` and `:67`). A
  local write carries the device's clock while the server issues its own, so a device whose clock runs fast ignores the
  server's answer.

## Tooling note (T014)

`dart run build_runner build --delete-conflicting-outputs` without a filter crashes in `riverpod_generator` with
`Missing implementation of visitDotShorthandPropertyAccess`: the `analyzer` that `build_runner` resolves (language
version 3.9) is older than the SDK (3.13) and cannot read the dot-shorthand syntax in `lib/core/auth/activity_tracker.dart`
(merged with the inactivity-lock feature). The Drift code is regenerated with
`--build-filter="lib/core/database/app_database.g.dart"`, which never resolves that file. This predates this feature and
is not fixed here (upgrading the generator toolchain is its own change).

## Migration review (T029)

`supabase/migrations/20261008120000_transaction_corrections.sql`, read line by line against
`contracts/server-ledger.md`. **No Postgres tool exists on this machine** (`psql`, `docker` and `supabase` are not
installed), so this review is the only check before the owner applies the file; the real check is the run of T032.

| Contract row | Where it is implemented |
|--------------|-------------------------|
| §1 columns, self-reversal check, unique index, item index | section 1 of the file (`add column if not exists`; the check guarded by a `do $$` block; `create … if not exists` indexes) |
| §2 `tx_effect`, `recompute_item_balance` | section 2; the recompute writes only when the value changes, so an unchanged item raises no Realtime event |
| §3 backfill before any trigger | section 3, placed before sections 4 and 5; a repeat is a no-op because `balance` is already `base + effects` |
| §4 insert: a reversal copies direction, amount, item and snapshot from its original; refused if the original is missing, deleted, itself a reversal or another user's | `financial_transactions_guard`, `tg_op = 'INSERT'` branch, `TX001` |
| §4 update: a deleted row stays deleted | `old.deleted_at is not null` → `new := old` (only `updated_at` moves, through the existing trigger that follows) |
| §4 update: a reversal never changes except by the cascade | `old.reverses_id is not null` branch → `TX002`; a repeated, identical upsert (a retried push) is accepted; the cascade is recognised by `pg_trigger_depth() > 1` |
| §4 update: a reversed transaction cannot be edited, a delete still goes through | `TX003` when amount, direction or item change while a live reversal exists and `deleted_at` is still null |
| §4 `reverses_id` never changes on an existing row | `TX002` |
| second reversal | the unique index → `23505` |
| after-row: delete cascades to the reversal, then both items are recomputed | `financial_transactions_ledger` (`z_…`), recompute for the new and, if it moved, the old item |
| §5 items: base kept, balance derived, new item starts at 0 | `expense_control_items_derive_balance` (before insert or update) |

- **Firing order:** Postgres fires triggers of one kind in name order: `a_financial_transactions_guard`, then the existing
  `financial_transactions_set_updated_at`, all before the write; `z_financial_transactions_ledger` after it.
- **Cascade at depth 2:** the ledger trigger's `update … set deleted_at` fires the guard at trigger depth 2, where the
  reversal branch accepts exactly a delete with unchanged amount, direction and item.
- **Realtime:** `recompute_item_balance` updates the item row, which fires `expense_control_items_derive_balance` and the
  existing `expense_control_items_set_updated_at`, so the new balance reaches the devices as an item row; that row's
  `balance` is what a device stores as `server_balance`.
- **Re-running the file** is harmless: every function is `create or replace`, every trigger is dropped and recreated,
  every column and index is `if not exists`, the constraint is guarded, and the backfill gives the same result.
- **Two decisions made while reviewing**, beyond the contract text: (1) a *repeated, identical* update of a reversal is
  accepted instead of refused (`TX002`), because the app retries a push whose answer was lost and the retry is an upsert
  that would otherwise be refused, making the device delete a reversal the server already holds; (2) the migration also
  refuses (`TX002`) any change of `reverses_id` on an existing row.

## Before fingerprints (T030)

Taken before anything is applied to the project, with throwaway scratchpad scripts (never committed):

- **Server** (REST with the QA login): 9 `expense_control_items` rows (8 live) and 7 `financial_transactions` rows; every
  field except the timestamps the server sets.
- **Device, old build:** `origin/master` (`b2aae00`) built in a separate worktree, installed on the Android emulator
  `Pixel_10`, signed in with the QA account, synchronised; `app_flutter/finance.sqlite` copied out with `adb exec-out
  run-as` and read with the `sqlite3` CLI: schema version 7, the same 9 items and 7 transactions, and every live item's
  balance equal to the server's.

## PR 1 test run before the project is touched (T034, part)

- `flutter analyze`: only the 2 existing `onReorder` infos. `dart format`: 0 changed.
- `flutter test`: **1907 tests, all passed** after the last fixes of T033 (baseline 1828; 79 new or rewritten).
- Coverage (`flutter test --coverage`, same script as the baseline):

  | Layer | Baseline | Now |
  |-------|----------|-----|
  | domain + data (`features/*/domain`, `features/*/data`) | 97.2 % | 97.0 % |
  | `lib/core/database/` | 59.4 % | 72.9 % |
  | `lib/core/sync/` | 69.8 % | 80.5 % |

  Files this pull request adds: `ledger_writes.dart` 100 %, `balance_ledger.dart` 97.1 %, `sync_notice.dart` 100 %,
  `sync_notices_provider.dart` 100 %, `reconciliation_monitor.dart` 89.1 %, `sync_notice_host.dart` 81.5 %. Changed files:
  `remote_row_writer.dart` 96.9 %, `app_database.dart` 98.8 %, `expense_control_repository_impl.dart` 96.8 %,
  `sync_worker.dart` 76.0 % and `pull_service.dart` 69.2 % (their uncovered lines are the real Supabase wiring of
  `_defaultPush`, `_defaultSubscribe` and `_defaultFetchBatch`, which the tests replace with closures, as before this
  feature).

## Applying the migration (T031)

The owner asked for the migration to be applied from here (it is their project), so it was applied directly over Postgres
with the database password from the repository's local `.env` (never printed), through the session pooler
(`aws-0-ap-southeast-1`, because the direct host is IPv6-only and does not resolve on this machine), using a throwaway
script and a throwaway Python venv in the session scratchpad:

1. **Dry run:** the whole file plus the guard checks inside one transaction, then `ROLLBACK`: the file executed without
   error in 0.15 s and every check passed except two that cannot be observed inside one transaction (`now()` is constant
   there, so `updated_at` does not move); those two are checked over REST below.
2. **Applied:** the same file in one transaction, `COMMIT`. Before and after, the 9 items kept exactly their balances
   (SC-006 on the server), and `balance == balance_base + Σ effects` holds for every item.

## SQL against the real project (T032)

23 checks inside a rolled-back transaction as `postgres`, and 21 checks over REST as the QA user (upserts exactly like the
sync worker, rows `zz-tc-…`, hard-deleted afterwards; nothing left over). All pass:

| Check | Result |
|-------|--------|
| a new item starts at balance 0 / base 0 | pass |
| income +1000, expense −300 → balance 700; an edit and a soft delete recompute it | pass |
| the item row's `updated_at` moves with each change, so Realtime delivers the new balance | pass (REST) |
| a `balance` and a `balance_base` sent by a client are ignored | pass |
| a retried identical upsert of a transaction and of a reversal is accepted | pass |
| a reversal sent as income/1 is normalised to expense/200 (copied from its original) | pass |
| a second reversal is refused | `23505` |
| editing or moving a reversed transaction is refused | `TX003` |
| reversing a reversal, a deleted transaction or a missing one is refused | `TX001` |
| deleting a reversal by hand is refused | `TX002` |
| an upsert that tries to change a reversal's amount is normalised back by the insert guard | pass (so `TX002` on this path is reached only by `deleted_at`) |
| deleting a reversed original is accepted and deletes its reversal; the balance is right | pass |
| an update to a deleted row keeps it deleted and unchanged, and its `updated_at` moves | pass (REST) |
| moving a transaction between items recomputes both | pass |
| the server fingerprint (9 items, 7 transactions) after all of this equals the one before | identical |

## SC-006 and the reconciliation on a real build (T033)

- **In-place upgrade:** the new build installed over the old one on the emulator (`adb install -r`, same application id)
  upgraded the local database from v7 to v8 with the columns present; every real item and transaction was identical to
  the "before" fingerprint (the only differences were `zz-` rows the old build had received live from my own REST test
  runs, and that the server had since hard-deleted: a hard delete never reaches a device, which is expected).
- **Fresh sync of the new build** (app data cleared, signed in again): the device fingerprint equals the old build's,
  item for item (balances, names, 7 transactions), schema v8, `server_balance` filled from the server, and the home
  screen shows the same total, 4.577.778 ₫.
- **Recording on the new build:** 1.000 ₫ on "Rac": the preview showed 49.000 ₫ (50.000 − 1.000), the device stored
  balance 49000 / base 0, the outbox got **one** entry (the transaction, nothing for the item) which synced, and the
  server's derived balance came back as 49000. Undone afterwards by a soft delete (the server balance went back to
  50000) and a hard delete; the server fingerprint is again identical to the original. Recording an income on the device
  was not repeated by hand: the income path is covered by the repository tests and by an income inserted from the other
  "device" below.
- **Another device (REST) → the emulator, no restart:** an income, an expense, a soft delete, a new expense and its
  reversal made through REST each reached the emulator's database as the same derived balance, with `server_balance`
  equal, within the 1.7 s polling granularity of the check (SC-004 for the pull direction).
- **Reconciliation, self-heal:** `server_balance` of "Tiet Kiem" set to 1 in the emulator's database while the app was
  stopped; within about 15 s of starting the app it was back to 6.000.000, with no notice. This needs the resync to replace
  a row whose `updated_at` is unchanged, which the first version of `resync` did not do: **found here and fixed**
  (`resync` now replaces any local row except one with a change waiting in the outbox; unit test added).
- **Reconciliation, persistent difference (SC-008):** a local-only transaction of 777 ₫ inserted into the database (not on
  the server, not in the outbox). The app logged the diagnostic line (item id only, no amount), and after the person
  unlocked the app the snack bar "Số dư của "Tao Phuc" chưa khớp với máy chủ. Hãy kết nối mạng và mở lại ứng dụng để
  đồng bộ." appeared (3 s after unlocking); neither figure was changed. The notice waits for the app shell, which does
  not exist while the app is locked, so nothing about an item is shown on the lock screen.
- **Observation, not caused by this feature:** on a cold start the Android debug build always shows the sign-in form
  (`sign_in_screen.dart` doubles as the lock screen when `appLockProvider` is locked); the old build behaves the same.
  Background sync, and therefore the monitor, keeps running while the app is locked.
- **Not checked here:** a Chrome window (done in the PR 2 and PR 3 manual checks, where the new screens exist), and the
  iOS simulator.

## Current implementation run

- The complete Flutter test suite passes: **2122 tests, 0 failures**.
- `flutter analyze`: no issues found after the package-import/deprecation cleanup.
- `flutter build web --release` succeeds. Flutter reports the existing WebAssembly dry-run incompatibilities in
  `flutter_secure_storage_web` (`dart:html`, `dart:js_util`, `package:js`) and an icon-font discovery warning; neither
  prevents the regular Web build.
- `flutter build apk --debug` succeeds. The Android build emits existing upcoming-support warnings for Gradle 8.14.0,
  AGP 8.11.1 and Kotlin 2.2.20.
- The debug app was installed and launched on the connected Android emulator, and the app was launched in Chrome. These
  are launch/build checks only; no manual UI verification was performed here.
- The editor and reconnect drain callbacks are now wired (`T083`/`T084`); `PullService` coverage asserts a drain request
  on each ready/reconnect callback. The full sync two-device scenarios are still outstanding because the planned
  `FakeServerLedger` and `two_device_corrections_test.dart` have not been implemented.
- No emulator-to-emulator reconnect latency was measured; SC-004's under-10-second push-direction measurement remains
  for manual verification. Do not treat the manual checks or the overall PR 3 gate as complete.
