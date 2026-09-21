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
    balance: 0,
    isSavingsReceiver: false,
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
          balance: 0,
          isSavingsReceiver: false,
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

  group('applyIncomeAllocation (FR-005–FR-014)', () {
    test(
      'adds each delta to the named item\'s existing balance, leaves others untouched',
      () async {
        await repository.create(_leaf('a'));
        await repository.create(_leaf('b'));
        await repository.create(_leaf('c'));

        await repository.applyIncomeAllocation({'a': 100000, 'b': 250000});

        final all = await repository.getAll();
        expect(all.firstWhere((i) => i.id == 'a').balance, 100000);
        expect(all.firstWhere((i) => i.id == 'b').balance, 250000);
        expect(all.firstWhere((i) => i.id == 'c').balance, 0);
      },
    );

    test(
      'a second call adds on top of the first, rather than overwriting',
      () async {
        await repository.create(_leaf('a'));

        await repository.applyIncomeAllocation({'a': 100000});
        await repository.applyIncomeAllocation({'a': 50000});

        final all = await repository.getAll();
        expect(all.firstWhere((i) => i.id == 'a').balance, 150000);
      },
    );

    test('appends one sync_outbox row per changed item', () async {
      await repository.create(_leaf('a'));
      await repository.create(_leaf('b'));

      final before = await db.select(db.syncOutbox).get();
      await repository.applyIncomeAllocation({'a': 100000, 'b': 200000});
      final after = await db.select(db.syncOutbox).get();

      expect(after.length - before.length, 2);
    });

    test(
      'the balance increment is a single atomic SQL statement, not a read-then-write pair — two concurrent calls to the same item never lose an increment',
      () async {
        await repository.create(_leaf('a'));

        // Simulates a race: if the increment were read-then-write, issuing
        // both concurrently (same starting balance read by both) would
        // apply only one of the two deltas. A single atomic
        // `balance = balance + delta` statement per call makes both land
        // regardless of interleaving.
        await Future.wait([
          repository.applyIncomeAllocation({'a': 100000}),
          repository.applyIncomeAllocation({'a': 200000}),
        ]);

        final all = await repository.getAll();
        expect(all.firstWhere((i) => i.id == 'a').balance, 300000);
      },
    );

    test('an empty delta map is a valid no-op', () async {
      await repository.create(_leaf('a'));
      await repository.applyIncomeAllocation({});
      final all = await repository.getAll();
      expect(all.firstWhere((i) => i.id == 'a').balance, 0);
    });

    test(
      'notifies watchAll() reactive streams of the balance change '
      '(regression: raw customStatement writes are invisible to '
      'Drift\'s stream invalidation — this must use customUpdate)',
      () async {
        await repository.create(_leaf('a'));

        final emissions = <int>[];
        final subscription = repository.watchAll().listen((items) {
          emissions.add(items.firstWhere((i) => i.id == 'a').balance);
        });
        await pumpEventQueue();

        await repository.applyIncomeAllocation({'a': 100000});
        await pumpEventQueue();

        await subscription.cancel();
        expect(emissions, contains(100000));
      },
    );
  });
}
