import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/expense_control_items_table.dart'
    as tables;
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';

class ExpenseControlRepositoryImpl implements ExpenseControlRepository {
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

  Future<void> _appendOutbox(
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

  Map<String, dynamic> _payloadOf(ExpenseControlItem item) => {
    'id': item.id,
    'user_id': item.userId,
    'parent_id': item.parentId,
    'name': item.name,
    'icon_key': item.iconKey,
    'description': item.description,
    'sort_order': item.sortOrder,
    'allocation_method': item.allocationMethod?.name,
    'allocation_value': item.allocationValue,
    'balance': item.balance,
    'is_savings_receiver': item.isSavingsReceiver,
  };

  /// Snake_case payload for a `financial_transactions` outbox row, matching
  /// the Supabase migration's column names exactly. Distinct from
  /// [_payloadOf] — that method's shape is for `expense_control_items` rows
  /// only and MUST NOT be reused here (research.md/tasks.md's explicit
  /// warning against payload-shape confusion between the two tables).
  Map<String, dynamic> _payloadOfTransaction(FinancialTransactionRow row) => {
    'id': row.id,
    'user_id': row.userId,
    'expense_control_item_id': row.expenseControlItemId,
    'direction': row.direction.name,
    'amount': row.amount,
    'occurred_at': row.occurredAt.millisecondsSinceEpoch ~/ 1000,
    'created_at': row.createdAt.millisecondsSinceEpoch ~/ 1000,
  };

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
        await _appendOutbox(
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
      await _appendOutbox(item.id, SyncOperation.insert, _payloadOf(item));
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
      await _appendOutbox(item.id, SyncOperation.update, _payloadOf(item));
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
      await _appendOutbox(id, SyncOperation.delete, {'id': id});
      for (final child in children) {
        await (_db.update(_db.expenseControlItems)
              ..where((row) => row.id.equals(child.id)))
            .write(ExpenseControlItemsCompanion(deletedAt: Value(now)));
        await _appendOutbox(child.id, SyncOperation.delete, {'id': child.id});
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
        await _appendOutbox(orderedIds[i], SyncOperation.update, {
          'id': orderedIds[i],
          'sort_order': i,
        });
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
        await _appendOutbox(id, SyncOperation.update, {
          'id': id,
          if (edit.name != null) 'name': edit.name,
          if (edit.iconKey != null) 'icon_key': edit.iconKey,
          if (edit.description != null) 'description': edit.description,
          if (edit.method != null) 'allocation_method': edit.method!.name,
          if (edit.value != null) 'allocation_value': edit.value,
          if (edit.isSavingsReceiver != null)
            'is_savings_receiver': edit.isSavingsReceiver,
        });
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
      // (research.md Decision 4 of the expense-transaction feature).
      final now = DateTime.now();
      for (final entry in balanceDeltas.entries) {
        final itemId = entry.key;
        final delta = entry.value;
        if (delta <= 0) continue;
        // A single atomic `balance = balance + delta` statement — not a
        // read-then-write pair — so a concurrent write to the same row
        // within this transaction window can never be silently lost
        // (Constitution Principle II: money-math correctness).
        //
        // `customUpdate` (not `customStatement`) is required here: a raw
        // `customStatement` writes to SQLite correctly but does NOT notify
        // Drift's reactive `.watch()` streams, since Drift can't infer
        // which table a raw statement touches — `watchAll()`'s stream
        // would silently never re-emit after this write, even though the
        // data itself is correct (caught during T036's manual walkthrough:
        // "Thu chi" balances stayed at 0 on screen despite the DB holding
        // the right values). `updates: {expenseControlItems}` tells Drift
        // exactly which table changed so dependent streams refresh.
        await _db.customUpdate(
          'UPDATE expense_control_items SET balance = balance + ?, '
          'updated_at = ? WHERE id = ?',
          variables: [
            Variable(delta),
            Variable(now.millisecondsSinceEpoch ~/ 1000),
            Variable(itemId),
          ],
          updates: {_db.expenseControlItems},
          updateKind: UpdateKind.update,
        );
        final row = await (_db.select(
          _db.expenseControlItems,
        )..where((r) => r.id.equals(itemId))).getSingle();
        await _appendOutbox(
          itemId,
          SyncOperation.update,
          _payloadOf(_toDomain(row)),
        );

        // FR-013: one income Financial Transaction row per non-zero delta,
        // atomic with the balance increment above — both are inside this
        // same `_db.transaction()`, so a failure anywhere in this loop
        // rolls back every balance change AND every history row from this
        // call, never leaving one without the other. Do NOT move this
        // insert out of this transaction in any future refactor — see
        // research.md Decision 6's guardrail.
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
              ),
            );
        final transactionRow = await (_db.select(
          _db.financialTransactions,
        )..where((r) => r.id.equals(transactionId))).getSingle();
        await _appendOutbox(
          transactionId,
          SyncOperation.insert,
          _payloadOfTransaction(transactionRow),
          entityTable: 'financial_transactions',
        );
      }
    });
  }

  @override
  Future<void> recordExpense({
    required String itemId,
    required int amount,
  }) async {
    await _db.transaction(() async {
      final now = DateTime.now();
      // Same atomic-decrement requirement as applyIncomeAllocation's
      // increment: a single `balance = balance - amount` statement, and
      // `customUpdate` (not `customStatement`) so Drift's `.watch()`
      // streams are notified (research.md Decision 5).
      await _db.customUpdate(
        'UPDATE expense_control_items SET balance = balance - ?, '
        'updated_at = ? WHERE id = ?',
        variables: [
          Variable(amount),
          Variable(now.millisecondsSinceEpoch ~/ 1000),
          Variable(itemId),
        ],
        updates: {_db.expenseControlItems},
        updateKind: UpdateKind.update,
      );
      final row = await (_db.select(
        _db.expenseControlItems,
      )..where((r) => r.id.equals(itemId))).getSingle();
      await _appendOutbox(
        itemId,
        SyncOperation.update,
        _payloadOf(_toDomain(row)),
      );

      // FR-009: the expense Financial Transaction row is inside the same
      // transaction as the balance decrement above — a failure here rolls
      // back the decrement too, never leaving one without the other
      // (SC-002).
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
            ),
          );
      final transactionRow = await (_db.select(
        _db.financialTransactions,
      )..where((r) => r.id.equals(transactionId))).getSingle();
      await _appendOutbox(
        transactionId,
        SyncOperation.insert,
        _payloadOfTransaction(transactionRow),
        entityTable: 'financial_transactions',
      );
    });
  }
}
