import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/expense_control_items_table.dart'
    as tables;
import '../../../core/sync/sync_outbox_table.dart';
import '../domain/expense_control_item.dart';
import '../domain/expense_control_repository.dart';

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
    Map<String, dynamic> payload,
  ) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: _uuid.v4(),
            entityTable: 'expense_control_items',
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
        });
      }
    });
  }
}
