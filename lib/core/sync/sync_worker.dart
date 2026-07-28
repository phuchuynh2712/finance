import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import 'sync_outbox_table.dart';

/// Reported when a synced envelope's local balance diverges from the
/// server-recomputed `envelope_balances` view (research.md §2). Surfaced,
/// never silently auto-corrected — per the constitution's Offline-First
/// mandate that a locally computed balance must not be trusted as final.
class ReconciliationWarning {
  ReconciliationWarning({
    required this.envelopeId,
    required this.localBalance,
    required this.serverComputedBalance,
  });

  final String envelopeId;
  final int localBalance;
  final int serverComputedBalance;
}

/// Drains the local outbox to Supabase and periodically reconciles envelope
/// balances against the server's transaction-log-derived view.
///
/// Scheduling is intentionally minimal for v1 (periodic polling, no
/// connectivity-change listener) per research.md §7 — the transactional
/// outbox write path (every local write appends a row here) is the part
/// that must be correct from day one; drain scheduling can iterate later
/// without changing that contract.
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

  final _reconciliationController =
      StreamController<ReconciliationWarning>.broadcast();
  Stream<ReconciliationWarning> get reconciliationWarnings =>
      _reconciliationController.stream;

  void start() {
    _timer ??= Timer.periodic(_interval, (_) => drainAndReconcile());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> drainAndReconcile() async {
    await _drainOutbox();
    await _reconcileBalances();
  }

  Future<void> _drainOutbox() async {
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

  Future<void> _reconcileBalances() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final localEnvelopes =
        await (_db.select(_db.envelopes)..where(
              (row) => row.userId.equals(userId) & row.deletedAt.isNull(),
            ))
            .get();
    if (localEnvelopes.isEmpty) return;

    final serverRows = await _client
        .from('envelope_balances')
        .select('envelope_id, computed_balance')
        .eq('user_id', userId);

    final serverBalanceByEnvelopeId = <String, int>{
      for (final row in serverRows as List)
        row['envelope_id'] as String: (row['computed_balance'] as num).toInt(),
    };

    for (final envelope in localEnvelopes) {
      final serverBalance = serverBalanceByEnvelopeId[envelope.id];
      if (serverBalance != null && serverBalance != envelope.balance) {
        _reconciliationController.add(
          ReconciliationWarning(
            envelopeId: envelope.id,
            localBalance: envelope.balance,
            serverComputedBalance: serverBalance,
          ),
        );
      }
    }
  }

  void dispose() {
    stop();
    _reconciliationController.close();
  }
}
