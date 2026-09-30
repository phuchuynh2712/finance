/// Orchestrates pulling remote Supabase data into the local database:
/// subscribe to live Realtime changes first, then run a keyset-paginated
/// initial catch-up fetch (research.md Decision 2) — any row both
/// mechanisms happen to deliver is a safe no-op the second time via
/// `remote_row_writer.dart`'s `<=` idempotency check (research.md
/// Decision 8).
///
/// **UI-isolate note** (`/speckit-analyze` finding C1, constitution
/// Principle IV): per-batch/per-event work here is JSON-map-to-typed-Row
/// field mapping (`applyRemoteRowJson`) plus Drift writes — I/O-bound
/// `async`/`await`, not CPU-bound parsing of a large payload (no JSON
/// string decoding happens in this file; PostgREST/Realtime already hand
/// back parsed `Map<String, dynamic>` objects). This stays on the UI
/// isolate as ordinary async work; there is no CPU-bound step to offload
/// via `compute()` at this feature's "thousands of rows per table" scale.
/// If a future profiling pass on a real device shows otherwise, revisit —
/// but nothing in this file's current design does synchronous, large-N
/// computation on the UI thread.
library;

import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/database/app_database.dart';
import 'remote_row_writer.dart';

/// The two syncable tables this feature pulls (spec.md Assumptions — scope
/// is limited to these two; no generic multi-table abstraction ahead of
/// need).
const syncableTables = ['expense_control_items', 'financial_transactions'];

/// Establishes the live change subscription for [tables] and returns an
/// unsubscribe function — WITHOUT waiting for the subscription to actually
/// become active (research.md Decision 2's mechanics note explains why
/// "subscribe requested" and "subscribed" are different moments; this
/// function may legitimately take a long time, or never resolve at all,
/// if the device is offline when it's called — `/speckit-analyze` finding
/// E1). [onEvent] is called with the entity table name and the changed
/// row's data (snake_case JSON, matching Supabase's own row shape — same
/// convention `remote_row_writer.dart`'s `applyRemoteRowJson` already
/// parses) for every insert/update the subscription delivers. [onReady]
/// is called every time the channel reports a working subscription —
/// including the very first time (there is no separate "initial connect"
/// vs. "reconnect" distinction here; both the offline-at-sign-in case
/// (FR-006) and the disconnect-after-connecting case (FR-002a) are the
/// same event from [PullService]'s perspective: "we can now (re)run the
/// catch-up pull." Collapsing them into one signal is deliberate —
/// treating "first successful connect" specially would have to guess how
/// long to wait before deciding a slow-but-eventually-successful first
/// connect isn't happening, which [onReady] firing whenever it actually
/// happens avoids needing to guess at all).
///
/// Injectable so tests substitute a plain closure instead of needing a
/// live Supabase connection or a hand-rolled fake of
/// `RealtimeChannel`/`PostgresChangePayload` (same rationale as
/// `SyncWorker`'s `PushRow` seam) — the real implementation is wired by
/// [pullServiceProvider].
typedef Subscribe =
    Future<void> Function()
    Function(
      List<String> tables,
      void Function(String table, Map<String, dynamic> row) onEvent,
      void Function() onReady,
    );

/// Fetches one keyset-paginated batch for [table], scoped to [userId],
/// starting after [cursor] (`null` means "from the beginning" — FR-001).
/// [cursor], when non-null, is `{'updated_at': (ISO-8601 string), 'id':
/// (string)}` — the last successfully-committed row's keyset position
/// (research.md Decision 4). Returns each row as snake_case JSON, same
/// shape [Subscribe]'s `onEvent` delivers.
typedef FetchBatch =
    Future<List<Map<String, dynamic>>> Function(
      String table,
      String userId,
      Map<String, dynamic>? cursor,
    );

class PullService {
  /// [client] is required unless both [subscribe] and [fetchBatch] are
  /// supplied (the test-only path — see those typedefs' docs); production
  /// callers ([pullServiceProvider]) pass a real [SupabaseClient] and no
  /// overrides, getting [_defaultSubscribe]/[_defaultFetchBatch].
  factory PullService(
    AppDatabase db, {
    SupabaseClient? client,
    required String userId,
    Subscribe? subscribe,
    FetchBatch? fetchBatch,
    int batchSize = 500,
  }) {
    assert(
      client != null || (subscribe != null && fetchBatch != null),
      'PullService requires either a SupabaseClient, or both subscribe '
      'and fetchBatch overrides (the test-only path).',
    );
    return PullService._(
      db,
      userId: userId,
      subscribe: subscribe ?? _defaultSubscribe(client!),
      fetchBatch: fetchBatch ?? _defaultFetchBatch(client!, batchSize),
      batchSize: batchSize,
    );
  }

  PullService._(
    this._db, {
    required String userId,
    required Subscribe subscribe,
    required FetchBatch fetchBatch,
    required int batchSize,
  }) : _userId = userId,
       _subscribe = subscribe,
       _fetchBatch = fetchBatch,
       _batchSize = batchSize;

  final AppDatabase _db;
  final String _userId;
  final Subscribe _subscribe;
  final FetchBatch _fetchBatch;
  final int _batchSize;

  /// Real subscription: `RealtimeChannelConfig(replicationReady: true)`,
  /// firing [onReady] every time `onSystemEvents` reports "ok" — including
  /// the first time, whenever that actually happens. Plain `.subscribe()`
  /// firing `RealtimeSubscribeStatus.subscribed` does NOT itself guarantee
  /// Postgres replication is live yet (verified against `realtime_client`
  /// 2.11.0 source; research.md Decision 2's mechanics note), so
  /// `onSystemEvents`'s own "ok" is the real signal, not the subscribe
  /// callback. This function itself returns synchronously (does not await
  /// connection at all — see [Subscribe]'s own doc for why: a device
  /// offline when this is called must not block forever).
  static Subscribe _defaultSubscribe(SupabaseClient client) {
    return (tables, onEvent, onReady) {
      final channel = client.channel(
        'pull-service-${DateTime.now().microsecondsSinceEpoch}',
        opts: const RealtimeChannelConfig(replicationReady: true),
      );
      for (final table in tables) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) {
            // A real DELETE never happens in this app (soft-delete via
            // deleted_at, research.md §0) — newRecord is only ever {} for
            // an event this app doesn't produce; skip defensively rather
            // than passing an empty row through the parse path.
            if (payload.newRecord.isEmpty) return;
            onEvent(payload.table, payload.newRecord);
          },
        );
      }
      channel.onSystemEvents((payload) {
        final map = Map<String, dynamic>.from(payload as Map);
        if (map['extension'] == 'system' && map['status'] == 'ok') {
          onReady();
        }
      });
      channel.subscribe();

      return () async {
        await client.removeChannel(channel);
      };
    };
  }

  /// Real fetch: keyset pagination via the standard PostgREST OR-expansion
  /// of the row-value comparison `(updated_at, id) > (cursor_updated_at,
  /// cursor_id)` — PostgREST has no direct tuple-comparison operator, so
  /// this expresses it as `updated_at > X OR (updated_at = X AND id > Y)`
  /// (research.md Decision 4; verified against `postgrest` 2.8.0 source
  /// and PostgREST's own query-parameter grammar during
  /// `/speckit-implement`).
  static FetchBatch _defaultFetchBatch(SupabaseClient client, int batchSize) {
    return (table, userId, cursor) async {
      var query = client.from(table).select().eq('user_id', userId);
      if (cursor != null) {
        final cursorUpdatedAt = cursor['updated_at'] as String;
        final cursorId = cursor['id'] as String;
        query = query.or(
          'updated_at.gt.$cursorUpdatedAt,'
          'and(updated_at.eq.$cursorUpdatedAt,id.gt.$cursorId)',
        );
      }
      final rows = await query
          .order('updated_at', ascending: true)
          .order('id', ascending: true)
          .limit(batchSize);
      return rows.cast<Map<String, dynamic>>();
    };
  }

  Future<void> Function()? _unsubscribe;
  Future<void> _liveWriteTail = Future<void>.value();

  /// Starts the subscription — WITHOUT waiting for it to actually connect
  /// (`/speckit-analyze` finding E1: a device offline at the moment this
  /// is called must not block here forever; [_subscribe] itself already
  /// returns synchronously for this reason). Call once per sign-in/
  /// cold-launch-with-restored-session (T022 wires the two triggering
  /// cases). The actual catch-up pull — both the very first one (FR-001)
  /// and every later one after a disconnect→reconnect (FR-002a) — runs
  /// from [_handleReady], triggered whenever the subscription reports it's
  /// genuinely live, however long that takes or however many times it
  /// happens. There is no separate "did the very first connect succeed"
  /// path to get wrong or leave unhandled — [_handleReady] IS that path,
  /// every time.
  Future<void> start() async {
    _unsubscribe = _subscribe(syncableTables, _handleLiveEvent, _handleReady);
  }

  Future<void> stop() async {
    await _unsubscribe?.call();
    _unsubscribe = null;
  }

  /// FR-001 (first connect) and FR-002a (every later reconnect) are the
  /// same event here — see [Subscribe]'s own doc for why collapsing them
  /// is deliberate. Runs the catch-up pull, resuming from each table's
  /// current `PullCursor` position (not restarting from scratch) so
  /// nothing that happened while disconnected — or before the first
  /// connect ever succeeded — is missed, without re-fetching rows already
  /// applied. Chained onto a serial tail for the same reason
  /// [_handleLiveEvent] is (the subscribe layer's status callback is not
  /// awaitable by the SDK; [drainReadyPulls] lets tests observe completion
  /// deterministically).
  Future<void> _readyTail = Future<void>.value();

  void _handleReady() {
    _readyTail = _readyTail.then((_) => runInitialPull()).catchError((_) {});
  }

  /// Awaits any ready-triggered catch-up pulls still in flight — for tests
  /// that need to observe post-connect/post-reconnect state
  /// deterministically. Production code has no reason to call this.
  @visibleForTesting
  Future<void> drainReadyPulls() => _readyTail;

  /// The Realtime subscription's callback is synchronous — it cannot itself
  /// be awaited by the SDK — so each event's write is chained onto a serial
  /// [Future] tail rather than fired-and-forgotten. This gives: (a) no two
  /// events' writes interleave mid-write on the same row, (b) a thrown
  /// error is caught rather than becoming an unhandled Future — silently,
  /// matching `SyncWorker.drainOutbox()`'s own existing `catch (_) {}`
  /// convention for this class of failure (a network/parse failure here is
  /// not fatal: the row will still arrive via the next reconnect's
  /// catch-up pull, FR-002a, so there is nothing actionable for this
  /// device to do besides let that natural retry happen), (c)
  /// [drainLiveWrites] lets tests (and only tests) observe when in-flight
  /// live writes have actually landed. Correctness-wise, ordering relative
  /// to an in-flight fetch batch still doesn't matter — `<=`
  /// (remote_row_writer.dart) makes whichever write lands second either a
  /// no-op (older/equal) or the new authoritative state (newer), regardless
  /// of which mechanism (fetch or live event) delivered it.
  void _handleLiveEvent(String table, Map<String, dynamic> row) {
    _liveWriteTail = _liveWriteTail
        .then((_) => applyRemoteRowJson(_db, table, row))
        .catchError((_) {});
  }

  /// Awaits any live-event writes still in flight from the subscription's
  /// callback ([_handleLiveEvent]) — for tests that need to observe
  /// post-event state deterministically. Production code has no reason to
  /// call this; a live pull's whole point is applying writes as they
  /// arrive, not waiting for them.
  @visibleForTesting
  Future<void> drainLiveWrites() => _liveWriteTail;

  /// Runs the keyset-paginated catch-up fetch for every syncable table
  /// (FR-001), resuming from each table's existing `PullCursor` position
  /// rather than restarting (FR-002a/research.md Decision 5). Each batch is
  /// written as its own local transaction (FR-010), and the cursor advances
  /// only after that transaction commits (SC-007).
  Future<void> runInitialPull() async {
    for (final table in syncableTables) {
      await _pullTable(table);
    }
  }

  Future<void> _pullTable(String table) async {
    var cursor = await _loadCursor(table);
    while (true) {
      final batch = await _fetchBatch(table, _userId, cursor?.toKeyset());
      if (batch.isEmpty) {
        // An empty batch always means "no more pages" — whether this is
        // the very first fetch (a genuinely empty account, cursor == null)
        // or a later fetch that follows a batch whose size happened to
        // exactly equal _batchSize (cursor != null, isLastPage below would
        // have miscalculated `false` for that prior batch). Marking
        // complete here, unconditionally on emptiness rather than only
        // when cursor == null, is what makes FR-011's loading state
        // resolve correctly in both cases — leaving initialPullCompleted
        // false here in the cursor != null case was a real bug found
        // during implementation (a table whose row count is an exact
        // multiple of _batchSize would never complete). Passing the
        // EXISTING cursor position back (not null) is equally important —
        // insertOnConflictUpdate would otherwise overwrite a real,
        // already-recorded keyset position with null, corrupting the
        // resume state FR-002a's reconnect depends on.
        await _markCompleted(table, cursor: cursor);
        return;
      }

      await _db.transaction(() async {
        for (final row in batch) {
          await applyRemoteRowJson(_db, table, row);
        }
      });

      final isLastPage = batch.length < _batchSize;
      final lastRow = batch.last;
      cursor = _Cursor(
        updatedAt: DateTime.parse(lastRow['updated_at'] as String),
        id: lastRow['id'] as String,
      );
      await _advanceCursor(table, cursor: cursor, completed: isLastPage);
      if (isLastPage) return;
    }
  }

  Future<_Cursor?> _loadCursor(String table) async {
    final row =
        await (_db.select(_db.pullCursor)..where(
          (t) => t.userId.equals(_userId) & t.syncTableName.equals(table),
        )).getSingleOrNull();
    if (row == null || row.lastUpdatedAt == null || row.lastId == null) {
      return null;
    }
    return _Cursor(updatedAt: row.lastUpdatedAt!, id: row.lastId!);
  }

  /// Marks a table's initial pull complete without changing its keyset
  /// cursor position — used when an empty batch signals "no more pages"
  /// (see `_pullTable`'s call site for why this must not overwrite an
  /// already-recorded [cursor] with null).
  Future<void> _markCompleted(String table, {required _Cursor? cursor}) {
    return _advanceCursor(table, cursor: cursor, completed: true);
  }

  Future<void> _advanceCursor(
    String table, {
    required _Cursor? cursor,
    required bool completed,
  }) async {
    await _db
        .into(_db.pullCursor)
        .insertOnConflictUpdate(
          PullCursorCompanion.insert(
            userId: _userId,
            syncTableName: table,
            lastUpdatedAt: drift.Value(cursor?.updatedAt),
            lastId: drift.Value(cursor?.id),
            initialPullCompleted: drift.Value(completed),
          ),
        );
  }
}

class _Cursor {
  const _Cursor({required this.updatedAt, required this.id});

  final DateTime updatedAt;
  final String id;

  Map<String, dynamic> toKeyset() => {
    'updated_at': updatedAt.toIso8601String(),
    'id': id,
  };
}
