import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/features/expense_control/data/expense_control_repository_impl.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';

const _userId = 'test-user';

ExpenseControlItem _leaf(
  String id, {
  String? parentId,
  ExpenseAllocationMethod method = ExpenseAllocationMethod.percentage,
  double value = 10,
  int sortOrder = 0,
}) {
  return ExpenseControlItem(
    id: id,
    userId: _userId,
    parentId: parentId,
    name: id,
    iconKey: 'home',
    description: null,
    sortOrder: sortOrder,
    allocationMethod: method,
    allocationValue: value,
  );
}

void main() {
  late AppDatabase db;
  late ExpenseControlRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ExpenseControlRepositoryImpl(db, userId: _userId);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'saveFormulas persists all changed items in one transaction with outbox rows',
    () async {
      await repository.create(_leaf('a', value: 10));
      await repository.create(_leaf('b', value: 20));

      await repository.saveFormulas({
        'a': const PendingItemEdit(
          method: ExpenseAllocationMethod.percentage,
          value: 40,
        ),
        'b': const PendingItemEdit(
          method: ExpenseAllocationMethod.fixed,
          value: 200000,
        ),
      });

      final all = await repository.getAll();
      final a = all.firstWhere((item) => item.id == 'a');
      final b = all.firstWhere((item) => item.id == 'b');
      expect(a.allocationValue, 40);
      expect(b.allocationMethod, ExpenseAllocationMethod.fixed);
      expect(b.allocationValue, 200000);

      final outboxRows = await db.select(db.syncOutbox).get();
      final formulaUpdates = outboxRows.where(
        (row) => row.entityTable == 'expense_control_items',
      );
      // insert(a) + insert(b) + update(a) + update(b) from saveFormulas.
      expect(formulaUpdates.length, 4);
    },
  );

  test('reorderTopLevel persists new sort order', () async {
    await repository.create(_leaf('a', sortOrder: 0));
    await repository.create(_leaf('b', sortOrder: 1));

    await repository.reorderTopLevel(['b', 'a']);

    final all = await repository.getAll();
    final a = all.firstWhere((item) => item.id == 'a');
    final b = all.firstWhere((item) => item.id == 'b');
    expect(b.sortOrder, 0);
    expect(a.sortOrder, 1);
  });

  test(
    'create() clears the parent formula in the same transaction as the first child insert (FR-004)',
    () async {
      await repository.create(_leaf('family', value: 30));
      await repository.create(
        ExpenseControlItem(
          id: 'groceries',
          userId: _userId,
          parentId: 'family',
          name: 'Groceries',
          iconKey: 'utensils',
          description: null,
          sortOrder: 0,
          allocationMethod: ExpenseAllocationMethod.percentage,
          allocationValue: 15,
        ),
      );

      final all = await repository.getAll();
      final family = all.firstWhere((item) => item.id == 'family');
      expect(family.allocationMethod, isNull);
      expect(family.allocationValue, isNull);
    },
  );

  test(
    'delete() cascades to direct children in one transaction (FR-016)',
    () async {
      await repository.create(_leaf('family', value: 30));
      await repository.create(_leaf('child', parentId: 'family', value: 15));

      await repository.delete('family');

      final remaining = await repository.getAll();
      expect(remaining, isEmpty);
    },
  );
}
