import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/database/app_database.dart';
import 'remote_row_writer.dart';
import 'sync_outbox_table.dart';

/// Drains the local outbox to Supabase on a periodic timer.
///
/// Scheduling is intentionally minimal for v1 (periodic polling, no
/// connectivity-change listener) per research.md §7 — the transactional
/// outbox write path (every local write appends a row here) is the part
/// that must be correct from day one; drain scheduling can iterate later
/// without changing that contract.
///
/// FR-019: this worker previously also reconciled `Envelope` balances
/// against the Supabase `envelope_balances` view; that logic is deleted
/// outright (not stubbed) along with the view and its backing tables
/// (research.md Decision 9) — a future feature redesigns reconciliation
/// for `ExpenseControlItem.balance` if and when that becomes necessary.
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

class SyncWorker {
  SyncWorker(
    this._db,
    SupabaseClient client, {
    Duration interval = const Duration(seconds: 30),
    PushRow? push,
  }) : _interval = interval,
       _push = push ?? _defaultPush(client);

  final AppDatabase _db;
  final Duration _interval;
  final PushRow _push;
  Timer? _timer;

  static PushRow _defaultPush(SupabaseClient client) {
    return (table, payload) async {
      return client.from(table).upsert(payload).select().single();
    };
  }

  void start() {
    _timer ??= Timer.periodic(_interval, (_) => drainOutbox());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> drainOutbox() async {
    final pending = await (_db.select(
      _db.syncOutbox,
    )..where((row) => row.syncedAt.isNull())).get();

    for (final row in pending) {
      try {
        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
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
            final response = await _push(row.entityTable, payload);
            await applyRemoteRowJson(_db, row.entityTable, response);
        }
        await (_db.update(_db.syncOutbox)..where((r) => r.id.equals(row.id)))
            .write(SyncOutboxCompanion(syncedAt: Value(DateTime.now())));
      } catch (_) {
        // Network/server failure: leave the row unsynced and back off via
        // retry_count. The next periodic drain will retry it.
        await (_db.update(_db.syncOutbox)..where((r) => r.id.equals(row.id)))
            .write(SyncOutboxCompanion(retryCount: Value(row.retryCount + 1)));
      }
    }
  }

  void dispose() {
    stop();
  }
}
