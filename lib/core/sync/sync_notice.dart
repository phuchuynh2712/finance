import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:finance/core/database/app_database.dart';

/// Why the person is being told something about their data.
enum SyncNoticeReason {
  /// The transaction was deleted on another device, so their change to it no
  /// longer applies (also: a reversal of a transaction that is gone).
  deleted,

  /// The transaction was reversed on another device, so it can no longer be
  /// changed.
  reversed,

  /// Another device had already reversed the same transaction.
  alreadyReversed,

  /// Another device edited the same transaction later; its edit was kept.
  editedElsewhere,

  /// After synchronising, the device's balance for an item still differs from
  /// the server's (FR-018).
  balanceMismatch;

  /// The reason a stored `reject_reason` of the outbox stands for, or null for
  /// a refusal that is never shown to the person (`check_violation`).
  static SyncNoticeReason? fromRejectReason(String? rejectReason) =>
      switch (rejectReason) {
        'invalid_reversal' => deleted,
        'reversal_immutable' => reversed,
        'transaction_reversed' => reversed,
        'already_reversed' => alreadyReversed,
        _ => null,
      };
}

/// One thing the person should be told once. Plain data: the sync layer
/// produces it, one host in the app shell shows it.
class SyncNotice {
  const SyncNotice({
    required this.id,
    required this.reason,
    required this.itemName,
    this.transactionId,
    this.amount,
  });

  /// Unique while the notice is open: `outbox:<outbox row id>` for a refusal
  /// stored on the outbox, `mismatch:<item id>` for a balance mismatch.
  final String id;
  final SyncNoticeReason reason;
  final String itemName;

  /// Null for [SyncNoticeReason.balanceMismatch].
  final String? transactionId;

  /// The amount of the transaction concerned; null for a balance mismatch,
  /// whose notice never carries a figure.
  final int? amount;
}

/// Holds the notices waiting to be shown, once each.
///
/// A notice reported while nobody listens is kept and delivered to the first
/// listener; one already delivered is not delivered again to a later listener.
/// A refusal of the server survives a restart because it stays on its outbox
/// row (`rejected_at`) until [acknowledge]d, when the row is deleted;
/// overrides and mismatches live in memory only.
class SyncNotices {
  SyncNotices(this._db) {
    loaded = _loadPersistedRefusals();
  }

  final AppDatabase _db;

  /// Completes once the refusals stored on the outbox have been read.
  late final Future<void> loaded;

  late final StreamController<SyncNotice> _controller =
      StreamController<SyncNotice>.broadcast(
        onListen: () => scheduleMicrotask(_flush),
      );
  final List<SyncNotice> _buffer = [];
  final Set<String> _open = {};

  Stream<SyncNotice> get stream => _controller.stream;

  /// Reports [notice]; ignored while a notice with the same id is still open.
  void report(SyncNotice notice) {
    if (!_open.add(notice.id)) return;
    if (_controller.hasListener) {
      _controller.add(notice);
    } else {
      _buffer.add(notice);
    }
  }

  /// The notice was shown: it may be reported again, and a refusal stored on
  /// the outbox is deleted so it never shows twice.
  Future<void> acknowledge(String id) async {
    _open.remove(id);
    const prefix = 'outbox:';
    if (id.startsWith(prefix)) {
      await (_db.delete(
        _db.syncOutbox,
      )..where((o) => o.id.equals(id.substring(prefix.length)))).go();
    }
  }

  Future<void> dispose() => _controller.close();

  void _flush() {
    if (!_controller.hasListener) return;
    final pending = List.of(_buffer);
    _buffer.clear();
    pending.forEach(_controller.add);
  }

  Future<void> _loadPersistedRefusals() async {
    final List<SyncOutboxRow> rows;
    try {
      rows =
          await (_db.select(_db.syncOutbox)..where(
                (o) =>
                    o.entityTable.equals('financial_transactions') &
                    o.rejectedAt.isNotNull(),
              ))
              .get();
    } catch (_) {
      // Best effort: a notice that cannot be read now is read at the next
      // start, and a missing database must never stop the app.
      return;
    }
    for (final row in rows) {
      final reason = SyncNoticeReason.fromRejectReason(row.rejectReason);
      if (reason == null) continue;
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      report(
        SyncNotice(
          id: 'outbox:${row.id}',
          reason: reason,
          transactionId: row.rowId,
          itemName: payload['display_name'] as String? ?? '',
          amount: payload['amount'] as int?,
        ),
      );
    }
  }
}
