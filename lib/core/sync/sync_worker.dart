import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/balance_ledger.dart';
import 'package:finance/core/sync/push_failure.dart';
import 'package:finance/core/sync/remote_row_writer.dart';
import 'package:finance/core/sync/sync_notice.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';

/// Drains the local outbox to Supabase on a periodic timer.
///
/// Scheduling is intentionally minimal for v1 (periodic polling, no
/// connectivity-change listener) per research.md §7 — the transactional
/// outbox write path (every local write appends a row here) is the part
/// that must be correct from day one; drain scheduling can iterate later
/// without changing that contract.
///
/// Balances are not pushed: an item's `balance` is derived from its
/// transactions on every device and, by Postgres triggers, on the server
/// (`BalanceLedger`, research.md Decision 1 of the transaction-corrections
/// feature), so the outbox carries rows, never a balance. The device checks
/// its derived balance against the server's in the `ReconciliationMonitor`,
/// which this worker triggers through [onIdle] whenever a drain leaves
/// nothing waiting. (FR-019 deleted the older `envelope_balances`
/// reconciliation outright; this is its replacement.)
///
/// Pushes one row's payload to Supabase and returns the row Postgres
/// actually stored (post-trigger, e.g. FR-005a's server-issued
/// `updated_at`) as snake_case JSON. Injectable so tests can substitute a
/// plain closure instead of mocking the Supabase SDK's builder-chain
/// classes (`PostgrestFilterBuilder` et al. have no practical hand-rolled
/// fake) — the real implementation ([SyncWorker._defaultPush]) is what
/// production code actually uses.
typedef PushRow =
    Future<Map<String, dynamic>> Function(
      String table,
      Map<String, dynamic> payload,
    );

typedef FetchRow =
    Future<Map<String, dynamic>?> Function(String table, String id);

class SyncWorker {
  SyncWorker(
    this._db,
    SupabaseClient client, {
    Duration interval = const Duration(seconds: 30),
    PushRow? push,
    FetchRow? fetchRow,
    SyncNotices? notices,
    DateTime Function()? now,
    FutureOr<void> Function()? onIdle,
  }) : _interval = interval,
       _push = push ?? _defaultPush(client),
       _fetchRow = fetchRow ?? _defaultFetchRow(client),
       _notices = notices,
       _now = now ?? DateTime.now,
       _onIdle = onIdle;

  final AppDatabase _db;
  final Duration _interval;
  final PushRow _push;
  final FetchRow _fetchRow;
  final SyncNotices? _notices;
  final DateTime Function() _now;

  /// Called at the end of every drain that leaves no entry waiting (even a
  /// drain of an empty outbox): a settled point for the reconciliation of the
  /// derived balances against the server's (FR-018). A failure in it never
  /// breaks the drain.
  final FutureOr<void> Function()? _onIdle;
  Timer? _timer;
  Future<void>? _activeDrain;
  bool _drainRequested = false;

  static PushRow _defaultPush(SupabaseClient client) {
    return (table, payload) async {
      return client.from(table).upsert(payload).select().single();
    };
  }

  static FetchRow _defaultFetchRow(SupabaseClient client) {
    return (table, id) async {
      final row = await client.from(table).select().eq('id', id).maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    };
  }

  void start() {
    _timer ??= Timer.periodic(_interval, (_) => drainOutbox());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> requestDrain() => drainOutbox();

  Future<void> drainOutbox() {
    final activeDrain = _activeDrain;
    if (activeDrain != null) {
      _drainRequested = true;
      return activeDrain;
    }

    final drain = _runDrains();
    _activeDrain = drain;
    return drain;
  }

  Future<void> _runDrains() async {
    try {
      do {
        _drainRequested = false;
        await _drainOnce();
      } while (_drainRequested);
    } finally {
      _activeDrain = null;
    }
  }

  Future<void> _drainOnce() async {
    final pending = await (_db.select(
      _db.syncOutbox,
    )..where((row) => row.syncedAt.isNull() & row.rejectedAt.isNull())).get();

    for (final row in pending) {
      Map<String, dynamic> payload = {};
      try {
        payload = jsonDecode(row.payload) as Map<String, dynamic>;
        switch (row.operation) {
          case SyncOperation.insert:
          case SyncOperation.update:
          case SyncOperation.delete:
            // Soft-delete: a "delete" is an upsert carrying a populated
            // `deleted_at` (research.md's rejected-hard-delete decision) —
            // never a real DELETE, which would break FK-referencing rows
            // (e.g. financial_transactions) permanently, with no local undo.
            //
            // FR-005a/research.md Decision 1: `_push` (via `.select()
            // .single()` in the real implementation) reads back the row
            // Postgres actually stored — the trigger
            // (supabase/migrations/20260929183846_realtime_pull_setup.sql)
            // overrides whatever `updated_at` the payload above sent with
            // the server's own now(), so the response, not the payload, is
            // this push's authoritative result. Reconciling the local row
            // to match goes through the same remote-row write helper pulled
            // rows use (research.md Decision 7) — never a second, separate
            // local-write mechanism.
            //
            // The response is applied unconditionally (research.md
            // Decision 6): the strictly-newer check is for rows that arrive
            // from elsewhere, and it ignores the server's answer whenever
            // this device's clock runs ahead of the server's — so "delete
            // wins" and the normalised reversal would never reach the device
            // that acted. The one exception is a change to the same row that
            // is still waiting in the outbox: it will push and its own
            // response settles the row, so the newer local edit is not
            // rolled back in between.
            final response = await _push(row.entityTable, payload);
            _reportPushOverride(row, payload, response);
            if (!await _hasOtherEntryWaiting(row)) {
              await applyRemoteRowJson(
                _db,
                row.entityTable,
                response,
                overwrite: true,
                detectOverrides: false,
              );
            }
        }
        await (_db.update(_db.syncOutbox)..where((r) => r.id.equals(row.id)))
            .write(SyncOutboxCompanion(syncedAt: Value(_now())));
      } catch (error, stackTrace) {
        final failure = PushFailure.classify(
          error,
          entityTable: row.entityTable,
        );
        if (failure case final PushRefused refusal) {
          try {
            await _handleRefusal(row, payload, refusal);
            continue;
          } catch (repairError, stackTrace) {
            // Keep the refusal retryable if its authoritative row could not
            // be fetched or its local repair could not be committed.
            developer.log(
              'Could not repair refused outbox row ${row.id}; it will retry.',
              name: 'SyncWorker',
              error: repairError,
              stackTrace: stackTrace,
              level: 1000,
            );
          }
        }
        developer.log(
          'Outbox push for row ${row.id} was deferred for retry.',
          name: 'SyncWorker',
          error: error,
          stackTrace: stackTrace,
          level: 800,
        );
        await _incrementRetryCount(row);
      }
    }

    await _notifyIfIdle();
  }

  Future<void> _handleRefusal(
    SyncOutboxRow outboxRow,
    Map<String, dynamic> payload,
    PushRefused refusal,
  ) async {
    final hasLaterEntry = await _hasOtherEntryWaiting(outboxRow);
    final serverRow =
        !hasLaterEntry && outboxRow.operation != SyncOperation.insert
        ? await _fetchRow(outboxRow.entityTable, outboxRow.rowId)
        : null;

    await _db.transaction(() async {
      if (!hasLaterEntry && outboxRow.entityTable == 'financial_transactions') {
        if (outboxRow.operation == SyncOperation.insert || serverRow == null) {
          final local =
              await (_db.select(_db.financialTransactions)..where(
                    (transaction) => transaction.id.equals(outboxRow.rowId),
                  ))
                  .getSingleOrNull();
          final itemId =
              local?.expenseControlItemId ??
              payload['expense_control_item_id'] as String?;
          await (_db.delete(
                _db.financialTransactions,
              )..where((transaction) => transaction.id.equals(outboxRow.rowId)))
              .go();
          if (itemId != null) {
            await BalanceLedger.recomputeBalances(_db, [itemId]);
          }
        } else {
          await applyRemoteRowJson(
            _db,
            outboxRow.entityTable,
            serverRow,
            overwrite: true,
            detectOverrides: false,
          );
        }
      } else if (!hasLaterEntry && serverRow != null) {
        await applyRemoteRowJson(
          _db,
          outboxRow.entityTable,
          serverRow,
          overwrite: true,
          detectOverrides: false,
        );
      }

      await (_db.update(
        _db.syncOutbox,
      )..where((row) => row.id.equals(outboxRow.id))).write(
        SyncOutboxCompanion(
          rejectedAt: Value(_now()),
          rejectReason: Value(refusal.rejectReason),
        ),
      );
    });

    final reason = refusal.noticeReason;
    if (reason != null) {
      _notices?.report(
        SyncNotice(
          id: 'outbox:${outboxRow.id}',
          reason: reason,
          itemName: payload['display_name'] as String? ?? '',
          transactionId: outboxRow.rowId,
          amount: (payload['amount'] as num?)?.toInt(),
        ),
      );
    }
  }

  Future<void> _incrementRetryCount(SyncOutboxRow row) async {
    await (_db.update(_db.syncOutbox)..where((r) => r.id.equals(row.id))).write(
      SyncOutboxCompanion(retryCount: Value(row.retryCount + 1)),
    );
  }

  void _reportPushOverride(
    SyncOutboxRow outboxRow,
    Map<String, dynamic> pushed,
    Map<String, dynamic> response,
  ) {
    if (outboxRow.entityTable != 'financial_transactions') return;
    final changed =
        pushed['amount'] != response['amount'] ||
        pushed['expense_control_item_id'] !=
            response['expense_control_item_id'] ||
        _dateValue(pushed['deleted_at']) != _dateValue(response['deleted_at']);
    if (!changed) return;

    _notices?.report(
      SyncNotice(
        id: 'push-override:${outboxRow.id}',
        reason: response['deleted_at'] == null
            ? SyncNoticeReason.editedElsewhere
            : SyncNoticeReason.deleted,
        itemName:
            response['display_name'] as String? ??
            pushed['display_name'] as String? ??
            '',
        transactionId: outboxRow.rowId,
        amount: (response['amount'] as num?)?.toInt(),
      ),
    );
  }

  DateTime? _dateValue(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  /// Whether another entry for the same row (any operation) is still waiting
  /// to be pushed: unsynced and not refused.
  Future<bool> _hasOtherEntryWaiting(SyncOutboxRow row) async {
    final others =
        await (_db.select(_db.syncOutbox)..where(
              (o) =>
                  o.entityTable.equals(row.entityTable) &
                  o.rowId.equals(row.rowId) &
                  o.id.equals(row.id).not() &
                  o.syncedAt.isNull() &
                  o.rejectedAt.isNull(),
            ))
            .get();
    return others.isNotEmpty;
  }

  Future<void> _notifyIfIdle() async {
    final onIdle = _onIdle;
    if (onIdle == null) return;
    final waiting =
        await (_db.select(_db.syncOutbox)
              ..where((o) => o.syncedAt.isNull() & o.rejectedAt.isNull())
              ..limit(1))
            .get();
    if (waiting.isNotEmpty) return;
    try {
      await onIdle();
    } catch (_) {
      // A check that fails must not stop the worker; the next idle drain
      // runs it again.
    }
  }

  void dispose() {
    stop();
  }
}
