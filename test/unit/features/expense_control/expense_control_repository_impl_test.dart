import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/features/expense_control/data/expense_control_repository_impl.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';

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

    test(
      'appends one sync_outbox row for the item AND one for its new financial_transactions row, per changed item',
      () async {
        await repository.create(_leaf('a'));
        await repository.create(_leaf('b'));

        final before = await db.select(db.syncOutbox).get();
        await repository.applyIncomeAllocation({'a': 100000, 'b': 200000});
        final after = await db.select(db.syncOutbox).get();

        // 2 items × (1 expense_control_items outbox row + 1
        // financial_transactions outbox row) = 4 (FR-013).
        expect(after.length - before.length, 4);
        final newRows = after.skip(before.length);
        expect(
          newRows.where((r) => r.entityTable == 'expense_control_items'),
          hasLength(2),
        );
        expect(
          newRows.where((r) => r.entityTable == 'financial_transactions'),
          hasLength(2),
        );
      },
    );

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
      'a call with N non-zero deltas inserts exactly N financial_transactions rows, each direction: income, amount matching its delta, all sharing one occurredAt (FR-013)',
      () async {
        await repository.create(_leaf('a'));
        await repository.create(_leaf('b'));
        await repository.create(_leaf('c'));

        await repository.applyIncomeAllocation({
          'a': 100000,
          'b': 250000,
          'c': 0,
        });

        final rows = await db.select(db.financialTransactions).get();
        expect(rows, hasLength(2));
        expect(
          rows.every((r) => r.direction == TransactionDirection.income),
          isTrue,
        );
        expect(rows.map((r) => r.expenseControlItemId).toSet(), {'a', 'b'});
        expect(
          rows.firstWhere((r) => r.expenseControlItemId == 'a').amount,
          100000,
        );
        expect(
          rows.firstWhere((r) => r.expenseControlItemId == 'b').amount,
          250000,
        );
        expect(rows.map((r) => r.occurredAt).toSet(), hasLength(1));
      },
    );

    test(
      'a zero-delta entry produces no financial_transactions row for that item',
      () async {
        await repository.create(_leaf('a'));
        await repository.create(_leaf('b'));

        await repository.applyIncomeAllocation({'a': 0, 'b': 50000});

        final rows = await db.select(db.financialTransactions).get();
        expect(rows, hasLength(1));
        expect(rows.single.expenseControlItemId, 'b');
      },
    );

    test(
      'atomicity guardrail: a failure partway through the allocation loop leaves neither a balance change nor a history row for any item in that call (FR-013, SC-004)',
      () async {
        await repository.create(_leaf('a'));
        // No item 'missing' is created — the update to it succeeds as a
        // no-op (WHERE matches nothing) but the financial_transactions
        // insert's foreign-key-shaped read-back via getSingle() throws,
        // forcing the whole _db.transaction() to roll back.
        await expectLater(
          repository.applyIncomeAllocation({'a': 100000, 'missing': 50000}),
          throwsA(anything),
        );

        final all = await repository.getAll();
        expect(
          all.firstWhere((i) => i.id == 'a').balance,
          0,
          reason:
              'the balance increment for "a" must roll back even though it '
              'was applied before the failure on "missing"',
        );
        final rows = await db.select(db.financialTransactions).get();
        expect(
          rows,
          isEmpty,
          reason:
              'no history row may survive when the same-call balance change '
              'did not',
        );
      },
    );

    test('notifies watchAll() reactive streams of the balance change '
        '(regression: raw customStatement writes are invisible to '
        'Drift\'s stream invalidation — this must use customUpdate)', () async {
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
    });
  });

  group('recordExpense (FR-009, FR-010, SC-002)', () {
    test(
      'decrements the picked item\'s balance by exactly amount, leaves every other item untouched',
      () async {
        await repository.create(_leaf('a'));
        await repository.create(_leaf('b'));
        await repository.applyIncomeAllocation({'a': 500000, 'b': 500000});

        await repository.recordExpense(itemId: 'a', amount: 120000);

        final all = await repository.getAll();
        expect(all.firstWhere((i) => i.id == 'a').balance, 380000);
        expect(all.firstWhere((i) => i.id == 'b').balance, 500000);
      },
    );

    test(
      'creates exactly one new financial_transactions row: direction expense, matching amount, occurredAt at call time',
      () async {
        await repository.create(_leaf('a'));
        final before = DateTime.now();

        await repository.recordExpense(itemId: 'a', amount: 75000);

        final rows = await db.select(db.financialTransactions).get();
        expect(rows, hasLength(1));
        final row = rows.single;
        expect(row.direction, TransactionDirection.expense);
        expect(row.amount, 75000);
        expect(row.expenseControlItemId, 'a');
        expect(
          row.occurredAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
        );
      },
    );

    test(
      'appends one sync_outbox row for the changed expense_control_items row AND one for the new financial_transactions row',
      () async {
        await repository.create(_leaf('a'));
        final before = await db.select(db.syncOutbox).get();

        await repository.recordExpense(itemId: 'a', amount: 50000);

        final after = await db.select(db.syncOutbox).get();
        final newRows = after.skip(before.length);
        expect(
          newRows.where((r) => r.entityTable == 'expense_control_items'),
          hasLength(1),
        );
        expect(
          newRows.where((r) => r.entityTable == 'financial_transactions'),
          hasLength(1),
        );
      },
    );

    test(
      'allows the balance to go negative without throwing or blocking (FR-010)',
      () async {
        await repository.create(_leaf('a'));

        await repository.recordExpense(itemId: 'a', amount: 50000);

        final all = await repository.getAll();
        expect(all.firstWhere((i) => i.id == 'a').balance, -50000);
      },
    );

    test(
      'the balance decrement is a single atomic SQL statement — two concurrent expenses on the same item never lose a decrement',
      () async {
        await repository.create(_leaf('a'));
        await repository.applyIncomeAllocation({'a': 1000000});

        await Future.wait([
          repository.recordExpense(itemId: 'a', amount: 100000),
          repository.recordExpense(itemId: 'a', amount: 200000),
        ]);

        final all = await repository.getAll();
        expect(all.firstWhere((i) => i.id == 'a').balance, 700000);
        final rows = await db.select(db.financialTransactions).get();
        expect(
          rows.where((r) => r.direction == TransactionDirection.expense),
          hasLength(2),
        );
      },
    );

    test(
      'atomicity guardrail: the balance decrement and the history-row insert always land together, never one without the other',
      () async {
        // No item 'missing' exists — mirrors applyIncomeAllocation's own
        // atomicity test: the update is a no-op, but the subsequent
        // read-back inside the same transaction throws, forcing a rollback.
        await expectLater(
          repository.recordExpense(itemId: 'missing', amount: 50000),
          throwsA(anything),
        );

        final rows = await db.select(db.financialTransactions).get();
        expect(rows, isEmpty);
      },
    );
  });

  group('transaction history snapshots', () {
    test(
      'income and expense rows capture immutable display and sync fields',
      () async {
        await repository.create(_leaf('food'));

        await repository.applyIncomeAllocation({'food': 100000});
        await repository.recordExpense(itemId: 'food', amount: 25000);

        final rows = await db.select(db.financialTransactions).get();
        expect(rows, hasLength(2));
        expect(rows.every((row) => row.displayName == 'food'), isTrue);
        expect(rows.every((row) => row.displayIconKey == 'home'), isTrue);
        expect(
          rows.every((row) => row.updatedAt.isAtSameMomentAs(row.occurredAt)),
          isTrue,
        );
        expect(rows.every((row) => row.deletedAt == null), isTrue);
        final expense = rows.firstWhere(
          (row) => row.direction == TransactionDirection.expense,
        );
        expect(expense.displayGroupName, 'food');

        final transactionOutboxRows = (await db.select(db.syncOutbox).get())
            .where((row) => row.entityTable == 'financial_transactions');
        expect(transactionOutboxRows, hasLength(2));
        expect(
          transactionOutboxRows.every(
            (row) => row.payload.contains('display_name'),
          ),
          isTrue,
        );
        expect(
          transactionOutboxRows.every(
            (row) => row.payload.contains('updated_at'),
          ),
          isTrue,
        );
      },
    );

    test(
      'history query is month-bounded, newest-first, and excludes tombstones',
      () async {
        final now = DateTime(2026, 6, 20);
        await repository.create(_leaf('item'));
        await db
            .into(db.financialTransactions)
            .insert(
              FinancialTransactionsCompanion.insert(
                id: 'older',
                userId: _userId,
                expenseControlItemId: 'item',
                direction: TransactionDirection.expense,
                amount: 100,
                occurredAt: DateTime(2026, 6, 1),
                displayName: const Value('Older'),
                updatedAt: Value(now),
              ),
            );
        await db
            .into(db.financialTransactions)
            .insert(
              FinancialTransactionsCompanion.insert(
                id: 'newer',
                userId: _userId,
                expenseControlItemId: 'item',
                direction: TransactionDirection.income,
                amount: 200,
                occurredAt: DateTime(2026, 6, 18),
                displayName: const Value('Newer'),
                updatedAt: Value(now),
              ),
            );
        await db
            .into(db.financialTransactions)
            .insert(
              FinancialTransactionsCompanion.insert(
                id: 'deleted',
                userId: _userId,
                expenseControlItemId: 'item',
                direction: TransactionDirection.expense,
                amount: 300,
                occurredAt: DateTime(2026, 6, 19),
                displayName: const Value('Deleted'),
                updatedAt: Value(now),
                deletedAt: Value(now),
              ),
            );
        await db
            .into(db.financialTransactions)
            .insert(
              FinancialTransactionsCompanion.insert(
                id: 'other-month',
                userId: _userId,
                expenseControlItemId: 'item',
                direction: TransactionDirection.expense,
                amount: 400,
                occurredAt: DateTime(2026, 7, 1),
                displayName: const Value('Other'),
                updatedAt: Value(now),
              ),
            );

        final history = await repository
            .watchTransactionHistory(
              start: DateTime(2026, 6),
              end: DateTime(2026, 7),
            )
            .first;

        expect(history.map((record) => record.id), ['newer', 'older']);
        expect(history.last.direction, TransactionHistoryDirection.expense);
      },
    );
  });

  group('watchRecent', () {
    Future<void> insertAt(
      String id,
      DateTime occurredAt, {
      DateTime? deletedAt,
    }) {
      return db
          .into(db.financialTransactions)
          .insert(
            FinancialTransactionsCompanion.insert(
              id: id,
              userId: _userId,
              expenseControlItemId: 'item',
              direction: TransactionDirection.expense,
              amount: 100,
              occurredAt: occurredAt,
              displayName: Value(id),
              updatedAt: Value(occurredAt),
              deletedAt: Value(deletedAt),
            ),
          );
    }

    test(
      'returns at most limit rows, newest-first, spanning multiple calendar months',
      () async {
        await repository.create(_leaf('item'));
        await insertAt('jan', DateTime(2026, 1, 1));
        await insertAt('mar', DateTime(2026, 3, 1));
        await insertAt('feb', DateTime(2026, 2, 1));

        final recent = await repository.watchRecent(limit: 2).first;

        expect(
          recent.map((r) => r.id),
          ['mar', 'feb'],
          reason:
              'not bounded by any calendar month, and capped at limit even '
              'though a 3rd, older row exists',
        );
      },
    );

    test('excludes soft-deleted rows', () async {
      await repository.create(_leaf('item'));
      await insertAt('visible', DateTime(2026, 6, 1));
      await insertAt(
        'tombstoned',
        DateTime(2026, 6, 2),
        deletedAt: DateTime(2026, 6, 3),
      );

      final recent = await repository.watchRecent(limit: 10).first;

      expect(recent.map((r) => r.id), ['visible']);
    });

    test(
      'returns fewer than limit rows when fewer exist, without error',
      () async {
        await repository.create(_leaf('item'));
        await insertAt('only', DateTime(2026, 6, 1));

        final recent = await repository.watchRecent(limit: 5).first;

        expect(recent.map((r) => r.id), ['only']);
      },
    );
  });
}
