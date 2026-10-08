# Contract: Sync Notices, Push Responses and Balance Reconciliation (`core/sync`)

**Stories**: US5 and the foundation | **Requirements**: FR-014, FR-018, SC-004, SC-008 | **Code**: `lib/core/sync/{sync_notice,sync_notices_provider,push_failure,reconciliation_monitor,pull_service_provider,sync_worker,pull_service,remote_row_writer}.dart`, `lib/core/widgets/sync_notice_host.dart`, `lib/core/database/balance_ledger.dart`

Everything here is shared code (`core/`), called out in the pull request descriptions.

## 1. Notices

```text
enum SyncNoticeReason { deleted, reversed, alreadyReversed, editedElsewhere, balanceMismatch }

class SyncNotice { String id; SyncNoticeReason reason; String? transactionId; String itemName; int? amount }
// amount and transactionId are null for balanceMismatch

class SyncNotices                         // lib/core/sync/sync_notice.dart; provider: sync_notices_provider.dart
  SyncNotices(AppDatabase db)
  Future<void> loaded                     // the rejected outbox rows have been read (best effort: a read error is ignored)
  void report(SyncNotice notice)          // in-memory; the same id is reported at most once until it is acknowledged
  Stream<SyncNotice> get stream           // broadcast; a notice is delivered to the first listener (buffered until one attaches) and not replayed to a later one; rejected outbox rows are reported at start
  Future<void> acknowledge(String id)     // shown: deletes the rejected outbox row the notice came from (a no-op for in-memory ones)
```

Refusals survive a restart (their outbox row stays until acknowledged); overrides and mismatches are in-memory.
`SyncNoticeHost` (`lib/core/widgets/sync_notice_host.dart`) is mounted once in the app shell, shows one snack bar per
notice, one after the other, and acknowledges each after showing it. It costs nothing when there is none.

## 2. Push responses and refusals (`SyncWorker`)

1. A response row is applied **unconditionally** (it replaces the local row whatever the two `updated_at` say) unless a
   later outbox entry for the same row is still waiting; the local timestamp is thereby replaced by the server's.
2. For `financial_transactions`: when the response differs from the payload in `amount`, `expense_control_item_id` or
   `deleted_at`, one notice is reported (`deleted` when the response is deleted, otherwise `editedElsewhere`).
3. Failure classifier (pure, `push_failure.dart`):

| Error | Class | `reject_reason` | Notice reason |
|-------|-------|-----------------|---------------|
| `TX001` | refused | `invalid_reversal` | `deleted` |
| `TX002` | refused | `reversal_immutable` | `reversed` |
| `TX003` | refused | `transaction_reversed` | `reversed` |
| `23505` on `financial_transactions` | refused | `already_reversed` | `alreadyReversed` |
| `23514` | refused | `check_violation` | none (cannot come from the app's own operations) |
| anything else (network, 5xx, other code, other table) | transient | | retried as today |

4. A refused row gets `rejected_at` and `reject_reason`, is skipped by every later drain, and is repaired locally: an
   insert is removed (the server never had it); an update is replaced by the server's current row through the
   `FetchRow` seam, unconditionally. Balances are recomputed.
5. `requestDrain()` drains now; calls made during a drain coalesce into one more drain. It is called right after a
   correction commits and when the Realtime channel reports ready (`PullService.onConnected`).
6. When a drain leaves no entry waiting, `onIdle` runs the reconciliation check.

## 3. Pull-time rules (`remote_row_writer.dart`)

- A remote reversal row arriving while a **different, unsynced** local reversal of the same original exists removes the
  local row and its outbox entries and reports `alreadyReversed` (the local unique index never stalls the apply).
- A remote soft-delete of an original also soft-deletes the live local reversals of it (the server cascades the same).
- A pulled transaction row that changes amount, item or deleted state of a row for which this device synced an edit
  within the last 24 hours (outbox `synced_at`, `row_id`) reports `editedElsewhere` or `deleted`, once. Not for rows
  this device's own push returned.
- `applyRemoteRowJson(..., {touchedItemIds, overwrite, notices})`: with a collector the caller recomputes once per batch;
  `overwrite: true` skips the strictly-newer check (used by items 1 and 4 above).

## 4. Reconciliation (`ReconciliationMonitor`, FR-018, SC-008)

```text
class ReconciliationMonitor
  ReconciliationMonitor({required Future<List<String>> Function() findDivergent, required Future<String> Function(String) itemName,
                        required void Function(SyncNotice) report, required Future<bool> Function() resync,   // answers false when it cannot run (signed out): nothing is reported then
                        Duration settleDelay = const Duration(seconds: 10), DateTime Function() now = DateTime.now})
  ReconciliationMonitor.forDatabase(AppDatabase db, SyncNotices notices, {required Future<bool> Function() resync, Duration settleDelay})
  Future<void> check()      // called at settled points: PullService.onCaughtUp and SyncWorker.onIdle (wired in reconciliationMonitorProvider, pull_service_provider.dart)
```

`check()` reads `BalanceLedger.findDivergent`:

| Situation | Action |
|-----------|--------|
| an item is no longer divergent | forget it (so a later divergence starts again) |
| divergent for the first time | remember when; schedule one more `check()` after `settleDelay` |
| still divergent after `settleDelay` and not yet re-synchronised | call `resync()` once (full re-fetch of both tables, idempotent, cursors untouched), then check again at once |
| still divergent after the re-synchronisation and not yet reported | report `balanceMismatch` once; neither figure is changed; a diagnostic line names the item id only, never an amount |

`PullService.resync()` pulls both tables from the beginning without saving or moving the cursors and without touching
`initial_pull_completed`, recomputing once per batch. Every fetched row replaces the local one (`overwrite: true`), except a
row with a change still waiting in the outbox, which keeps the strictly-newer rule so that change is not rolled back.

## 5. Guarantees (each has a test)

- A push response with a device-made `updated_at` in the future still replaces the local row (the delete-wins and the
  normalised reversal reach a device whose clock runs fast).
- A refusal is never retried, never lost across a restart before it was shown, and shown exactly once.
- A difference that goes away after the one re-synchronisation produces no notice; one that remains produces exactly
  one, within 30 seconds of the device settling.
- A divergent item that has a transaction waiting in the outbox is never reported.
