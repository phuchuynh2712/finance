import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/balance_ledger.dart';
import 'package:finance/core/database/tables/expense_control_items_table.dart'
    as tables;
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expense_control/domain/transaction_history_repository.dart';
import 'ledger_writes.dart';

class ExpenseControlRepositoryImpl
    implements ExpenseControlRepository, TransactionHistoryRepository {
  ExpenseControlRepositoryImpl(this._db, {required String userId})
    : _userId = userId;

  final AppDatabase _db;
  final String _userId;
  static const _uuid = Uuid();

  ExpenseControlItem _toDomain(ExpenseControlItemRow row) {
    return ExpenseControlItem(
      id: row.id,
      userId: row.userId,
      parentId: row.parentId,
      name: row.name,
      iconKey: row.iconKey,
      description: row.description,
      sortOrder: row.sortOrder,
      allocationMethod: switch (row.allocationMethod) {
        tables.ExpenseAllocationMethod.percentage =>
          ExpenseAllocationMethod.percentage,
        tables.ExpenseAllocationMethod.fixed => ExpenseAllocationMethod.fixed,
        null => null,
      },
      allocationValue: row.allocationValue,
      balance: row.balance,
      isSavingsReceiver: row.isSavingsReceiver,
    );
  }

  tables.ExpenseAllocationMethod? _toTableMethod(
    ExpenseAllocationMethod? method,
  ) {
    return switch (method) {
      ExpenseAllocationMethod.percentage =>
        tables.ExpenseAllocationMethod.percentage,
      ExpenseAllocationMethod.fixed => tables.ExpenseAllocationMethod.fixed,
      null => null,
    };
  }

  late final LedgerWrites _writes = LedgerWrites(_db);

  Map<String, dynamic> _payloadOf(
    ExpenseControlItem item, {
    DateTime? deletedAt,
  }) => {
    'id': item.id,
    'user_id': item.userId,
    'parent_id': item.parentId,
    'name': item.name,
    'icon_key': item.iconKey,
    'description': item.description,
    'sort_order': item.sortOrder,
    'allocation_method': item.allocationMethod?.name,
    'allocation_value': item.allocationValue,
    'is_savings_receiver': item.isSavingsReceiver,
    'deleted_at': deletedAt?.toIso8601String(),
  };

  TransactionHistoryRecord _toHistoryRecord(
    FinancialTransactionRow row, {
    required bool isReversed,
  }) {
    return TransactionHistoryRecord(
      id: row.id,
      sourceItemId: row.expenseControlItemId,
      direction: switch (row.direction) {
        TransactionDirection.income => TransactionHistoryDirection.income,
        TransactionDirection.expense => TransactionHistoryDirection.expense,
      },
      amount: row.amount,
      occurredAt: row.occurredAt,
      displayName: row.displayName ?? 'Archived Item',
      displayGroupName: row.displayGroupName,
      displayIconKey: row.displayIconKey,
      reversesId: row.reversesId,
      isReversed: isReversed,
    );
  }

  /// A history query over this user's live transactions that also tells, per
  /// row, whether a live reversing entry cancels it — in any month, so the
  /// stream re-emits when a reversal appears or is deleted. [filter] adds the
  /// caller's own conditions; [limit] caps the rows.
  Stream<List<TransactionHistoryRecord>> _watchHistory(
    Expression<bool> Function($FinancialTransactionsTable row) filter, {
    int? limit,
  }) {
    final transactions = _db.financialTransactions;
    final reversal = _db.alias(_db.financialTransactions, 'reversal');
    final isReversed = existsQuery(
      _db.select(reversal)..where(
        (r) => r.reversesId.equalsExp(transactions.id) & r.deletedAt.isNull(),
      ),
    );
    final query = _db.select(transactions).join([])
      ..addColumns([isReversed])
      ..where(
        transactions.userId.equals(_userId) &
            transactions.deletedAt.isNull() &
            filter(transactions),
      )
      ..orderBy([
        OrderingTerm.desc(transactions.occurredAt),
        OrderingTerm.desc(transactions.createdAt),
      ]);
    if (limit != null) query.limit(limit);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          _toHistoryRecord(
            r.readTable(transactions),
            isReversed: r.read(isReversed) ?? false,
          ),
      ],
    );
  }

  @override
  Stream<List<ExpenseControlItem>> watchAll() {
    return (_db.select(_db.expenseControlItems)
          ..where((row) => row.userId.equals(_userId) & row.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<ExpenseControlItem>> getAll() async {
    final rows =
        await (_db.select(_db.expenseControlItems)..where(
              (row) => row.userId.equals(_userId) & row.deletedAt.isNull(),
            ))
            .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<TransactionHistoryRecord>> watchTransactionHistory({
    required DateTime start,
    required DateTime end,
  }) {
    return _watchHistory(
      (row) =>
          row.occurredAt.isBiggerOrEqualValue(start) &
          row.occurredAt.isSmallerThanValue(end),
    );
  }

  @override
  Stream<List<TransactionHistoryRecord>> watchRecent({required int limit}) {
    return _watchHistory((row) => const Constant(true), limit: limit);
  }

  Future<int> _childCount(String parentId) async {
    final rows =
        await (_db.select(_db.expenseControlItems)..where(
              (row) => row.parentId.equals(parentId) & row.deletedAt.isNull(),
            ))
            .get();
    return rows.length;
  }

  @override
  Future<void> create(ExpenseControlItem item) async {
    await _db.transaction(() async {
      final parentId = item.parentId;
      // FR-004: adding the first child clears the parent's own formula.
      if (parentId != null && await _childCount(parentId) == 0) {
        final parentRow = await (_db.select(
          _db.expenseControlItems,
        )..where((row) => row.id.equals(parentId))).getSingle();
        await (_db.update(
          _db.expenseControlItems,
        )..where((row) => row.id.equals(parentId))).write(
          const ExpenseControlItemsCompanion(
            allocationMethod: Value(null),
            allocationValue: Value(null),
            isSavingsReceiver: Value(false),
          ),
        );
        await _writes.appendOutbox(
          parentId,
          SyncOperation.update,
          _payloadOf(_toDomain(parentRow).clearFormula()),
        );
      }

      await _db
          .into(_db.expenseControlItems)
          .insert(
            ExpenseControlItemsCompanion.insert(
              id: item.id,
              userId: item.userId,
              parentId: Value(item.parentId),
              name: item.name,
              iconKey: item.iconKey,
              description: Value(item.description),
              sortOrder: Value(item.sortOrder),
              allocationMethod: Value(_toTableMethod(item.allocationMethod)),
              allocationValue: Value(item.allocationValue),
              isSavingsReceiver: Value(item.isSavingsReceiver),
            ),
          );
      await _writes.appendOutbox(
        item.id,
        SyncOperation.insert,
        _payloadOf(item),
      );
    });
  }

  @override
  Future<void> update(ExpenseControlItem item) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.expenseControlItems,
      )..where((row) => row.id.equals(item.id))).write(
        ExpenseControlItemsCompanion(
          name: Value(item.name),
          iconKey: Value(item.iconKey),
          description: Value(item.description),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _writes.appendOutbox(
        item.id,
        SyncOperation.update,
        _payloadOf(item),
      );
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      final children =
          await (_db.select(_db.expenseControlItems)..where(
                (row) => row.parentId.equals(id) & row.deletedAt.isNull(),
              ))
              .get();
      final now = DateTime.now();
      await (_db.update(_db.expenseControlItems)
            ..where((row) => row.id.equals(id)))
          .write(ExpenseControlItemsCompanion(deletedAt: Value(now)));
      final deletedRow = await (_db.select(
        _db.expenseControlItems,
      )..where((row) => row.id.equals(id))).getSingle();
      await _writes.appendOutbox(
        id,
        SyncOperation.delete,
        _payloadOf(_toDomain(deletedRow), deletedAt: now),
      );
      for (final child in children) {
        await (_db.update(_db.expenseControlItems)
              ..where((row) => row.id.equals(child.id)))
            .write(ExpenseControlItemsCompanion(deletedAt: Value(now)));
        await _writes.appendOutbox(
          child.id,
          SyncOperation.delete,
          _payloadOf(_toDomain(child), deletedAt: now),
        );
      }
    });
  }

  @override
  Future<void> reorderTopLevel(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(
          _db.expenseControlItems,
        )..where((row) => row.id.equals(orderedIds[i]))).write(
          ExpenseControlItemsCompanion(
            sortOrder: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
        );
        // A full payload, not just the changed field — SyncWorker's push
        // path is an `upsert()`, which PostgREST/Postgres treats as a
        // candidate INSERT on conflict, not a partial `UPDATE SET`: any
        // column missing from the payload is written as NULL (or its
        // column default), not "left as whatever the server already has."
        // A payload with only `sort_order` violates every other NOT NULL
        // column (name, icon_key, ...), and separately, a payload missing
        // `user_id` fails the RLS `WITH CHECK (auth.uid() = user_id)`
        // policy outright — both silently swallowed by drainOutbox()'s
        // catch-all, which just increments retry_count forever. Read the
        // row back (already updated above, in the same transaction) so
        // every column is present, matching every other call site's use of
        // `_payloadOf`.
        final row = await (_db.select(
          _db.expenseControlItems,
        )..where((r) => r.id.equals(orderedIds[i]))).getSingle();
        await _writes.appendOutbox(
          orderedIds[i],
          SyncOperation.update,
          _payloadOf(_toDomain(row)),
        );
      }
    });
  }

  @override
  Future<void> saveFormulas(Map<String, PendingItemEdit> changes) async {
    await _db.transaction(() async {
      for (final entry in changes.entries) {
        final id = entry.key;
        final edit = entry.value;
        // Only fields the edit actually set are written — a null field on
        // PendingItemEdit means "unchanged," so it's left `Value.absent()`
        // (Companion's default) rather than overwritten with null.
        await (_db.update(
          _db.expenseControlItems,
        )..where((row) => row.id.equals(id))).write(
          ExpenseControlItemsCompanion(
            name: edit.name == null ? const Value.absent() : Value(edit.name!),
            iconKey: edit.iconKey == null
                ? const Value.absent()
                : Value(edit.iconKey!),
            description: edit.description == null
                ? const Value.absent()
                : Value(edit.description),
            allocationMethod: edit.method == null
                ? const Value.absent()
                : Value(_toTableMethod(edit.method)),
            allocationValue: edit.value == null
                ? const Value.absent()
                : Value(edit.value),
            isSavingsReceiver: edit.isSavingsReceiver == null
                ? const Value.absent()
                : Value(edit.isSavingsReceiver!),
            updatedAt: Value(DateTime.now()),
          ),
        );
        // A full payload, not just the edited fields — see
        // reorderTopLevel's comment on why a partial payload silently
        // breaks against SyncWorker's `upsert()` push (missing NOT NULL
        // columns, missing `user_id` failing RLS). Read the row back
        // (already updated above, in the same transaction).
        final row = await (_db.select(
          _db.expenseControlItems,
        )..where((r) => r.id.equals(id))).getSingle();
        await _writes.appendOutbox(
          id,
          SyncOperation.update,
          _payloadOf(_toDomain(row)),
        );
      }
    });
  }

  @override
  Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas) async {
    await _db.transaction(() async {
      // Captured once, before the loop, and reused for every history row
      // this call produces — every row created by one "Lưu thu nhập"
      // action represents the same user-facing event, not several events
      // that happened to occur at slightly different microseconds
      // (research.md Decision 4 of the expense-transaction feature; also
      // how the corrections of this feature recognise an income event).
      final now = DateTime.now();
      final touchedItemIds = <String>{};
      for (final entry in balanceDeltas.entries) {
        final itemId = entry.key;
        final delta = entry.value;
        if (delta <= 0) continue;
        // Read the item first: a missing id throws here and rolls back
        // every row this call produced (atomicity guardrail, FR-013).
        final row = await (_db.select(
          _db.expenseControlItems,
        )..where((r) => r.id.equals(itemId))).getSingle();

        // FR-013: one income Financial Transaction row per non-zero delta.
        // The balance is derived from the transactions, so inserting the row
        // IS the balance change; it is recomputed below, in this same
        // `_db.transaction()`, so a failure anywhere in this loop rolls back
        // every history row and leaves every balance as it was. Do NOT move
        // the recompute or this insert out of this transaction (research.md
        // Decision 6 of the expense-transaction feature).
        final transactionId = _uuid.v4();
        await _db
            .into(_db.financialTransactions)
            .insert(
              FinancialTransactionsCompanion.insert(
                id: transactionId,
                userId: _userId,
                expenseControlItemId: itemId,
                direction: TransactionDirection.income,
                amount: delta,
                occurredAt: now,
                displayName: Value(row.name),
                displayIconKey: Value(row.iconKey),
                updatedAt: Value(now),
              ),
            );
        final transactionRow = await (_db.select(
          _db.financialTransactions,
        )..where((r) => r.id.equals(transactionId))).getSingle();
        await _writes.appendOutbox(
          transactionId,
          SyncOperation.insert,
          _writes.transactionPayload(transactionRow),
          entityTable: 'financial_transactions',
        );
        touchedItemIds.add(itemId);
      }
      await BalanceLedger.recomputeBalances(_db, touchedItemIds);
    });
  }

  @override
  Future<void> recordExpense({
    required String itemId,
    required int amount,
  }) async {
    await _db.transaction(() async {
      final now = DateTime.now();
      // Read first: a missing item throws and rolls everything back.
      final row = await (_db.select(
        _db.expenseControlItems,
      )..where((r) => r.id.equals(itemId))).getSingle();

      // FR-009: the expense row and the recompute of the balance share this
      // transaction — a failure rolls back both, never leaving one without
      // the other (SC-002). The balance is derived, so there is no item
      // write and no item outbox entry.
      final transactionId = _uuid.v4();
      await _db
          .into(_db.financialTransactions)
          .insert(
            FinancialTransactionsCompanion.insert(
              id: transactionId,
              userId: _userId,
              expenseControlItemId: itemId,
              direction: TransactionDirection.expense,
              amount: amount,
              occurredAt: now,
              displayName: Value(row.name),
              displayGroupName: Value(await _groupNameFor(row)),
              displayIconKey: Value(row.iconKey),
              updatedAt: Value(now),
            ),
          );
      final transactionRow = await (_db.select(
        _db.financialTransactions,
      )..where((r) => r.id.equals(transactionId))).getSingle();
      await _writes.appendOutbox(
        transactionId,
        SyncOperation.insert,
        _writes.transactionPayload(transactionRow),
        entityTable: 'financial_transactions',
      );
      await BalanceLedger.recomputeBalances(_db, [itemId]);
    });
  }

  Future<String> _groupNameFor(ExpenseControlItemRow item) async {
    final parentId = item.parentId;
    if (parentId == null) return item.name;
    final parent = await (_db.select(
      _db.expenseControlItems,
    )..where((row) => row.id.equals(parentId))).getSingleOrNull();
    return parent?.name ?? item.name;
  }
}
