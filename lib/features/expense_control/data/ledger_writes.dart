import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';

/// The writes every repository of this feature shares: appending a change to
/// the sync outbox and building the `financial_transactions` payload the
/// server expects. One copy, used by the record flows and by the corrections
/// (delete, edit, reverse) alike (contract `correction-operations.md` §3a).
///
/// Both methods must be called inside the repository's own
/// `AppDatabase.transaction`, so a row, its balance and its outbox entry are
/// committed together or not at all.
class LedgerWrites {
  const LedgerWrites(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  /// Queues [payload] for [entityTable] (an item row by default).
  Future<void> appendOutbox(
    String rowId,
    SyncOperation operation,
    Map<String, dynamic> payload, {
    String entityTable = 'expense_control_items',
  }) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: _uuid.v4(),
            entityTable: entityTable,
            rowId: rowId,
            operation: operation,
            payload: jsonEncode(payload),
          ),
        );
  }

  /// Snake_case payload for a `financial_transactions` outbox row, matching
  /// the Supabase migration's column names exactly. Distinct from the item
  /// payload — that shape is for `expense_control_items` rows only and MUST
  /// NOT be reused here.
  ///
  /// Every `timestamptz` field is sent as an ISO 8601 string
  /// ([DateTime.toIso8601String]), not a raw epoch integer — PostgREST's
  /// JSON-to-`timestamptz` coercion only accepts date-time strings; a bare
  /// integer triggers Postgres error 22008 ("date/time field value out of
  /// range") because it's parsed as malformed date-time text, not
  /// interpreted as Unix epoch seconds.
  Map<String, dynamic> transactionPayload(FinancialTransactionRow row) => {
    'id': row.id,
    'user_id': row.userId,
    'expense_control_item_id': row.expenseControlItemId,
    'direction': row.direction.name,
    'amount': row.amount,
    'occurred_at': row.occurredAt.toIso8601String(),
    'created_at': row.createdAt.toIso8601String(),
    'display_name': row.displayName,
    'display_group_name': row.displayGroupName,
    'display_icon_key': row.displayIconKey,
    'updated_at': row.updatedAt.toIso8601String(),
    'deleted_at': row.deletedAt?.toIso8601String(),
    'reverses_id': row.reversesId,
  };
}
