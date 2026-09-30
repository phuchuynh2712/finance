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

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/expense_control_items_table.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';

/// Idempotency (FR-004, research.md Decision 8 step 1): if [row]'s
/// `updatedAt` is less than or equal to the local row's current
/// `updatedAt` (not merely equal — this also covers an in-flight batch
/// delivering a stale value after a newer one already landed locally,
/// research.md Decision 8's race-condition note), this call is a no-op.
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
  ExpenseControlItemRow row,
) async {
  if (row.userId != userId) return;

  final existing =
      await (db.select(
        db.expenseControlItems,
      )..where((t) => t.id.equals(row.id))).getSingleOrNull();
  if (existing != null && !row.updatedAt.isAfter(existing.updatedAt)) {
    return;
  }

  await db
      .into(db.expenseControlItems)
      .insertOnConflictUpdate(row.toCompanion(true));
}

/// See [applyRemoteExpenseControlItem] — identical contract (no outbox
/// entry, idempotent on `updatedAt` not strictly newer, uniform
/// soft-delete handling), applied to `financial_transactions` instead.
Future<void> applyRemoteFinancialTransaction(
  AppDatabase db,
  String userId,
  FinancialTransactionRow row,
) async {
  if (row.userId != userId) return;

  final existing =
      await (db.select(
        db.financialTransactions,
      )..where((t) => t.id.equals(row.id))).getSingleOrNull();
  if (existing != null && !row.updatedAt.isAfter(existing.updatedAt)) {
    return;
  }

  await db
      .into(db.financialTransactions)
      .insertOnConflictUpdate(row.toCompanion(true));
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
  Map<String, dynamic> json,
) async {
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
          isSavingsReceiver: json['is_savings_receiver'] as bool,
          createdAt: DateTime.parse(json['created_at'] as String),
          updatedAt: DateTime.parse(json['updated_at'] as String),
          deletedAt: itemDeletedAtRaw == null
              ? null
              : DateTime.parse(itemDeletedAtRaw),
        ),
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
        ),
      );
  }
}
