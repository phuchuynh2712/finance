import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
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
class SyncWorker {
  SyncWorker(
    this._db,
    this._client, {
    Duration interval = const Duration(seconds: 30),
  }) : _interval = interval;

  final AppDatabase _db;
  final SupabaseClient _client;
  final Duration _interval;
  Timer? _timer;

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
        final table = _client.from(row.entityTable);
        switch (row.operation) {
          case SyncOperation.insert:
          case SyncOperation.update:
            await table.upsert(payload);
          case SyncOperation.delete:
            await table.delete().eq('id', row.rowId);
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
