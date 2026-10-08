/// Writes a remote-authoritative row (from the initial pull, a live
/// Realtime event, or SyncWorker's push read-back) into the local database.
///
/// Deliberately lives in `core/sync/`, not on `ExpenseControlRepository`/
/// `ExpenseControlRepositoryImpl` — the domain entity `ExpenseControlItem`
/// has no `updatedAt`/`deletedAt` fields by design, so this logic cannot be
/// expressed as a domain-interface method without violating the
/// constitution's domain/Drift-independence rule. This mirrors
/// `SyncWorker`'s own existing precedent of operating directly on
/// `AppDatabase` for sync-infrastructure work (research.md Decision 7,
/// corrected placement; contracts/pull-write-helper.md).
///
/// Neither function ever appends a `sync_outbox` entry — the row's
/// authoritative state already came FROM Supabase, so re-queuing it for
/// push would create an infinite pull→outbox→push→pull loop.
library;

import 'package:drift/drift.dart' show Value;

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/balance_ledger.dart';
import 'package:finance/core/database/tables/expense_control_items_table.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';

/// Idempotency (FR-004, research.md Decision 8 step 1): if [row]'s
/// `updatedAt` is less than or equal to the local row's current
/// `updatedAt` (not merely equal — this also covers an in-flight batch
/// delivering a stale value after a newer one already landed locally,
/// research.md Decision 8's race-condition note), this call is a no-op.
/// [overwrite] skips that check: used where the server's row must replace
/// the local one whatever the two timestamps say (a push response, a refused
/// change repaired from the server; research.md Decision 6).
///
/// The row's `balance` is the figure the **server** reports: it is kept in
/// `serverBalance` for the reconciliation, never displayed. The displayed
/// balance is derived (`BalanceLedger`) from the row's `balanceBase` and the
/// local transactions, which may include changes the server has not seen yet.
/// With [touchedItemIds] the recompute is left to the caller (a pull batch
/// recomputes each item once); without it the item is recomputed here.
///
/// [userId] MUST equal [row]'s own `userId` — checked as a defense-in-depth
/// guard (FR-007; RLS is the primary enforcement mechanism, this is a
/// second, cheap layer per `/speckit-analyze` finding G1). A mismatch is a
/// silent no-op, not a thrown error — this can occur legitimately (a stale
/// in-flight fetch racing a sign-out, for instance) and must never crash
/// the caller; RLS is what actually prevents a foreign row from ever
/// reaching this function in the first place.
Future<void> applyRemoteExpenseControlItem(
  AppDatabase db,
  String userId,
  ExpenseControlItemRow row, {
  Set<String>? touchedItemIds,
  bool overwrite = false,
}) async {
  if (row.userId != userId) return;

  await db.transaction(() async {
    final existing = await (db.select(
      db.expenseControlItems,
    )..where((t) => t.id.equals(row.id))).getSingleOrNull();
    if (!overwrite &&
        existing != null &&
        !row.updatedAt.isAfter(existing.updatedAt)) {
      return;
    }

    await db
        .into(db.expenseControlItems)
        .insertOnConflictUpdate(
          row.copyWith(serverBalance: Value(row.balance)).toCompanion(true),
        );
    await _settleBalances(db, touchedItemIds, [row.id]);
  });
}

/// See [applyRemoteExpenseControlItem] — identical contract (no outbox
/// entry, idempotent on `updatedAt` not strictly newer unless [overwrite],
/// uniform soft-delete handling), applied to `financial_transactions`
/// instead. A transaction row changes the balance of the item it belonged to
/// and of the item it belongs to now (an edit can move it), so both are
/// recomputed.
Future<void> applyRemoteFinancialTransaction(
  AppDatabase db,
  String userId,
  FinancialTransactionRow row, {
  Set<String>? touchedItemIds,
  bool overwrite = false,
}) async {
  if (row.userId != userId) return;

  await db.transaction(() async {
    final existing = await (db.select(
      db.financialTransactions,
    )..where((t) => t.id.equals(row.id))).getSingleOrNull();
    if (!overwrite &&
        existing != null &&
        !row.updatedAt.isAfter(existing.updatedAt)) {
      return;
    }

    await db
        .into(db.financialTransactions)
        .insertOnConflictUpdate(row.toCompanion(true));
    await _settleBalances(db, touchedItemIds, [
      row.expenseControlItemId,
      if (existing != null) existing.expenseControlItemId,
    ]);
  });
}

/// Either hands [itemIds] to the caller's collector (to recompute once per
/// batch) or recomputes them now.
Future<void> _settleBalances(
  AppDatabase db,
  Set<String>? collector,
  Iterable<String> itemIds,
) async {
  if (collector != null) {
    collector.addAll(itemIds);
  } else {
    await BalanceLedger.recomputeBalances(db, itemIds);
  }
}

/// Parses a PostgREST/Realtime row (snake_case JSON, matching the actual
/// SQL column names — NOT the camelCase Drift's own generated `fromJson`
/// expects, which is keyed by Dart field name instead) into the typed
/// Drift row [applyRemoteExpenseControlItem]/[applyRemoteFinancialTransaction]
/// need, then applies it. Shared by `SyncWorker`'s push read-back and
/// `PullService`'s pull/live paths — both consume the same JSON shape
/// (Supabase's own row representation), so this parsing logic has exactly
/// one owner rather than being duplicated at each call site.
Future<void> applyRemoteRowJson(
  AppDatabase db,
  String entityTable,
  Map<String, dynamic> json, {
  Set<String>? touchedItemIds,
  bool overwrite = false,
}) async {
  final userId = json['user_id'] as String;
  switch (entityTable) {
    case 'expense_control_items':
      final allocationMethodRaw = json['allocation_method'] as String?;
      final itemDeletedAtRaw = json['deleted_at'] as String?;
      await applyRemoteExpenseControlItem(
        db,
        userId,
        ExpenseControlItemRow(
          id: json['id'] as String,
          userId: userId,
          parentId: json['parent_id'] as String?,
          name: json['name'] as String,
          iconKey: json['icon_key'] as String,
          description: json['description'] as String?,
          sortOrder: json['sort_order'] as int,
          allocationMethod: allocationMethodRaw == null
              ? null
              : ExpenseAllocationMethod.values.byName(allocationMethodRaw),
          allocationValue: (json['allocation_value'] as num?)?.toDouble(),
          balance: json['balance'] as int,
          balanceBase: json['balance_base'] as int,
          serverBalance: json['balance'] as int,
          isSavingsReceiver: json['is_savings_receiver'] as bool,
          createdAt: DateTime.parse(json['created_at'] as String),
          updatedAt: DateTime.parse(json['updated_at'] as String),
          deletedAt: itemDeletedAtRaw == null
              ? null
              : DateTime.parse(itemDeletedAtRaw),
        ),
        touchedItemIds: touchedItemIds,
        overwrite: overwrite,
      );
    case 'financial_transactions':
      final transactionDeletedAtRaw = json['deleted_at'] as String?;
      await applyRemoteFinancialTransaction(
        db,
        userId,
        FinancialTransactionRow(
          id: json['id'] as String,
          userId: userId,
          expenseControlItemId: json['expense_control_item_id'] as String,
          direction: TransactionDirection.values.byName(
            json['direction'] as String,
          ),
          amount: json['amount'] as int,
          occurredAt: DateTime.parse(json['occurred_at'] as String),
          displayName: json['display_name'] as String?,
          displayGroupName: json['display_group_name'] as String?,
          displayIconKey: json['display_icon_key'] as String?,
          createdAt: DateTime.parse(json['created_at'] as String),
          updatedAt: DateTime.parse(json['updated_at'] as String),
          deletedAt: transactionDeletedAtRaw == null
              ? null
              : DateTime.parse(transactionDeletedAtRaw),
          reversesId: json['reverses_id'] as String?,
        ),
        touchedItemIds: touchedItemIds,
        overwrite: overwrite,
      );
  }
}
