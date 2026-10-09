import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';
import 'package:finance/features/expense_control/data/transaction_correction_repository_impl.dart';
import 'package:finance/features/expense_control/domain/transaction_correction_repository.dart';

import '../../../support/correction_fixtures.dart';

void main() {
  late AppDatabase db;
  late TransactionCorrectionRepositoryImpl repository;

  const userId = 'u1';
  final occurredAt = DateTime(2026, 10, 9, 9);
  final now = DateTime(2026, 10, 9, 10);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionCorrectionRepositoryImpl(db, userId: userId);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'deleting an expense restores its balance and queues only its row',
    () async {
      await seedLedger(
        db,
        items: const [
          CorrectionItemSeed(id: 'food', balanceBase: 5000, balance: 3000),
        ],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 2000,
            occurredAt: occurredAt,
          ),
        ],
      );
      final original = (await db.select(db.financialTransactions).get()).single;

      final result = await repository.delete('expense', now: now);

      expect(result, isA<CorrectionDone>());
      expect(
        (await db.select(db.expenseControlItems).get()).single.balance,
        5000,
      );
      final deleted = (await db.select(db.financialTransactions).get()).single;
      expect(deleted.deletedAt, now);
      expect(deleted.updatedAt.isAfter(original.updatedAt), isTrue);
      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(1));
      expect(outbox.single.entityTable, 'financial_transactions');
      expect(outbox.single.rowId, 'expense');
      expect(outbox.single.operation, SyncOperation.update);
    },
  );

  test(
    'deleting an income entry deletes the complete same-time event only',
    () async {
      await seedLedger(
        db,
        items: const [
          CorrectionItemSeed(id: 'one', balanceBase: 10, balance: 110),
          CorrectionItemSeed(id: 'two', balanceBase: 20, balance: 220),
          CorrectionItemSeed(id: 'three', balanceBase: 30, balance: 330),
          CorrectionItemSeed(id: 'four', balanceBase: 40, balance: 440),
        ],
        transactions: [
          for (final entry in [
            ('income-1', 'one', 100, userId),
            ('income-2', 'two', 200, userId),
            ('income-3', 'three', 300, userId),
            ('different-time', 'four', 400, userId),
            ('different-user', 'four', 500, 'u2'),
          ])
            CorrectionTransactionSeed(
              id: entry.$1,
              itemId: entry.$2,
              direction: TransactionDirection.income,
              amount: entry.$3,
              userId: entry.$4,
              occurredAt: entry.$1 == 'different-time'
                  ? occurredAt.add(const Duration(seconds: 1))
                  : occurredAt,
            ),
        ],
      );

      await repository.delete('income-2', now: now);

      final rows = await db.select(db.financialTransactions).get();
      expect(
        rows.where((row) => row.deletedAt != null).map((row) => row.id).toSet(),
        {'income-1', 'income-2', 'income-3'},
      );
      final balances = {
        for (final item in await db.select(db.expenseControlItems).get())
          item.id: item.balance,
      };
      expect(balances, {'one': 10, 'two': 20, 'three': 30, 'four': 440});
      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(3));
      expect(
        outbox.every(
          (row) =>
              row.entityTable == 'financial_transactions' &&
              row.operation == SyncOperation.update,
        ),
        isTrue,
      );
    },
  );

  test(
    'deleting an expense is allowed to take its balance below zero',
    () async {
      await seedLedger(
        db,
        items: const [CorrectionItemSeed(id: 'food', balanceBase: -100)],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 200,
            occurredAt: occurredAt,
          ),
        ],
      );
      await repository.delete('expense', now: now);
      expect(
        (await db.select(db.expenseControlItems).get()).single.balance,
        -100,
      );
    },
  );

  test(
    'a removed item is reported without inventing a restored balance',
    () async {
      await seedLedger(
        db,
        items: [
          CorrectionItemSeed(
            id: 'removed',
            balanceBase: 900,
            balance: 700,
            deletedAt: now,
          ),
        ],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'removed',
            direction: TransactionDirection.expense,
            amount: 200,
            occurredAt: occurredAt,
          ),
        ],
      );

      final result = await repository.delete('expense', now: now);

      expect(result, isA<CorrectionDone>());
      expect((result as CorrectionDone).itemsWithoutBalance, ['removed']);
      expect(
        (await db.select(db.expenseControlItems).get()).single.balance,
        700,
      );
    },
  );

  test(
    'preview uses the current item name and computes the post-delete balance',
    () async {
      await seedLedger(
        db,
        items: const [
          CorrectionItemSeed(
            id: 'food',
            name: 'Renamed groceries',
            balanceBase: 1000,
            balance: 750,
          ),
        ],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 250,
            occurredAt: occurredAt,
          ),
        ],
      );

      final preview = await repository.previewDelete('expense');

      expect(preview.amount, 250);
      expect(preview.items, hasLength(1));
      expect(preview.items.single.itemId, 'food');
      expect(preview.items.single.itemName, 'Renamed groceries');
      expect(preview.items.single.balanceAfter, 1000);
      expect(preview.items.single.itemRemoved, isFalse);
    },
  );

  test(
    'rolls back the row and balance when appending its outbox entry fails',
    () async {
      await seedLedger(
        db,
        items: const [
          CorrectionItemSeed(id: 'food', balanceBase: 5000, balance: 3000),
        ],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 2000,
            occurredAt: occurredAt,
          ),
        ],
      );
      await db.customStatement('''
        CREATE TRIGGER fail_correction_outbox
        BEFORE INSERT ON sync_outbox
        BEGIN
          SELECT RAISE(ABORT, 'forced outbox failure');
        END
      ''');

      await expectLater(
        repository.delete('expense', now: now),
        throwsA(isA<Exception>()),
      );

      expect(
        (await db.select(db.financialTransactions).get()).single.deletedAt,
        isNull,
      );
      expect(
        (await db.select(db.expenseControlItems).get()).single.balance,
        3000,
      );
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    },
  );

  test('denies a past-window delete without changing the ledger', () async {
    await seedLedger(
      db,
      items: const [
        CorrectionItemSeed(id: 'food', balanceBase: 1000, balance: 750),
      ],
      transactions: [
        CorrectionTransactionSeed(
          id: 'expense',
          itemId: 'food',
          direction: TransactionDirection.expense,
          amount: 250,
          occurredAt: now.subtract(const Duration(hours: 25)),
        ),
      ],
    );

    final result = await repository.delete('expense', now: now);

    expect(result, const CorrectionNotAllowed(CorrectionDenial.windowEnded));
    expect((await db.select(db.syncOutbox).get()), isEmpty);
    expect(
      (await db.select(db.financialTransactions).get()).single.deletedAt,
      isNull,
    );
  });

  test(
    'denies unknown, foreign, already deleted, reversed and reversal rows',
    () async {
      await seedLedger(
        db,
        items: const [CorrectionItemSeed(id: 'food', balanceBase: 1000)],
        transactions: [
          CorrectionTransactionSeed(
            id: 'foreign',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 250,
            userId: 'u2',
            occurredAt: occurredAt,
          ),
          CorrectionTransactionSeed(
            id: 'deleted',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 250,
            occurredAt: occurredAt,
            deletedAt: now,
          ),
          CorrectionTransactionSeed(
            id: 'original',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 250,
            occurredAt: occurredAt,
          ),
          CorrectionTransactionSeed(
            id: 'reversal',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 250,
            occurredAt: occurredAt,
            reversesId: 'other',
          ),
        ],
      );

      expect(
        await repository.delete('missing', now: now),
        const CorrectionNotAllowed(CorrectionDenial.notFound),
      );
      expect(
        await repository.delete('foreign', now: now),
        const CorrectionNotAllowed(CorrectionDenial.notFound),
      );
      expect(
        await repository.delete('deleted', now: now),
        const CorrectionNotAllowed(CorrectionDenial.notFound),
      );
      expect(
        await repository.delete('reversal', now: now),
        const CorrectionNotAllowed(CorrectionDenial.isReversal),
      );
      await db
          .into(db.financialTransactions)
          .insert(
            FinancialTransactionsCompanion.insert(
              id: 'canceller',
              userId: userId,
              expenseControlItemId: 'food',
              direction: TransactionDirection.expense,
              amount: 250,
              occurredAt: now,
              reversesId: const Value('original'),
            ),
          );
      expect(
        await repository.delete('original', now: now),
        const CorrectionNotAllowed(CorrectionDenial.alreadyReversed),
      );
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    },
  );

  test('calls onCommitted after success and never after a denial', () async {
    var committed = 0;
    repository = TransactionCorrectionRepositoryImpl(
      db,
      userId: userId,
      onCommitted: () => committed++,
    );
    await seedLedger(
      db,
      items: const [CorrectionItemSeed(id: 'food', balanceBase: 1000)],
      transactions: [
        CorrectionTransactionSeed(
          id: 'recent',
          itemId: 'food',
          direction: TransactionDirection.expense,
          amount: 250,
          occurredAt: occurredAt,
        ),
        CorrectionTransactionSeed(
          id: 'old',
          itemId: 'food',
          direction: TransactionDirection.expense,
          amount: 250,
          occurredAt: now.subtract(const Duration(hours: 25)),
        ),
      ],
    );
    expect(await repository.delete('recent', now: now), isA<CorrectionDone>());
    expect(committed, 1);
    expect(
      await repository.delete('old', now: now),
      const CorrectionNotAllowed(CorrectionDenial.windowEnded),
    );
    expect(committed, 1);
  });

  test(
    'editing an expense changes its amount without changing its date',
    () async {
      await seedLedger(
        db,
        items: const [CorrectionItemSeed(id: 'food', balanceBase: 1000)],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 200,
            occurredAt: occurredAt,
          ),
        ],
      );
      final savedAt = (await db.select(db.financialTransactions).get()).single;

      final result = await repository.editExpense(
        'expense',
        amount: 300,
        itemId: 'food',
        now: now,
      );

      expect(result, isA<CorrectionDone>());
      final edited = (await db.select(db.financialTransactions).get()).single;
      expect(edited.amount, 300);
      expect(edited.occurredAt, occurredAt);
      expect(edited.updatedAt.isAfter(savedAt.updatedAt), isTrue);
      expect(
        (await db.select(db.expenseControlItems).get()).single.balance,
        700,
      );
      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(1));
      expect(outbox.single.rowId, 'expense');
      expect(outbox.single.entityTable, 'financial_transactions');
      expect(outbox.single.operation, SyncOperation.update);
    },
  );

  test(
    'moving an expense restores the old item and refreshes its snapshot',
    () async {
      await seedLedger(
        db,
        items: const [
          CorrectionItemSeed(
            id: 'group',
            name: 'Essentials',
            allocationMethod: null,
          ),
          CorrectionItemSeed(
            id: 'food',
            parentId: 'group',
            name: 'Groceries',
            iconKey: 'basket',
            balanceBase: 1000,
            balance: 800,
          ),
          CorrectionItemSeed(id: 'travel', name: 'Transit', balanceBase: 500),
        ],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 200,
            occurredAt: occurredAt,
          ),
        ],
      );

      await repository.editExpense(
        'expense',
        amount: 300,
        itemId: 'travel',
        now: now,
      );

      final balances = {
        for (final item in await db.select(db.expenseControlItems).get())
          item.id: item.balance,
      };
      expect(balances['food'], 1000);
      expect(balances['travel'], 200);
      final edited = (await db.select(db.financialTransactions).get()).single;
      expect(edited.expenseControlItemId, 'travel');
      expect(edited.displayName, 'Transit');
      expect(edited.displayGroupName, 'Transit');
      expect(edited.displayIconKey, 'home');
      expect(edited.occurredAt, occurredAt);
      expect(await db.select(db.syncOutbox).get(), hasLength(1));
    },
  );

  test('editing an expense can make the selected item negative', () async {
    await seedLedger(
      db,
      items: const [
        CorrectionItemSeed(id: 'food', balanceBase: 1000),
        CorrectionItemSeed(id: 'travel', balanceBase: 100),
      ],
      transactions: [
        CorrectionTransactionSeed(
          id: 'expense',
          itemId: 'food',
          direction: TransactionDirection.expense,
          amount: 200,
          occurredAt: occurredAt,
        ),
      ],
    );

    final result = await repository.editExpense(
      'expense',
      amount: 500,
      itemId: 'travel',
      now: now,
    );

    expect(result, isA<CorrectionDone>());
    final balances = {
      for (final item in await db.select(db.expenseControlItems).get())
        item.id: item.balance,
    };
    expect(balances['travel'], -400);
  });

  test(
    'denies invalid edits and preserves data for missing, removed, group or income items',
    () async {
      await seedLedger(
        db,
        items: [
          CorrectionItemSeed(
            id: 'group',
            name: 'Group',
            allocationMethod: null,
          ),
          CorrectionItemSeed(
            id: 'child',
            parentId: 'group',
            name: 'Child',
            balanceBase: 100,
          ),
          CorrectionItemSeed(
            id: 'removed',
            name: 'Removed',
            deletedAt: DateTime(2026, 10, 9),
          ),
        ],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'child',
            direction: TransactionDirection.expense,
            amount: 50,
            occurredAt: occurredAt,
          ),
          CorrectionTransactionSeed(
            id: 'income',
            itemId: 'child',
            direction: TransactionDirection.income,
            amount: 50,
            occurredAt: occurredAt,
          ),
        ],
      );

      expect(
        await repository.editExpense(
          'expense',
          amount: 0,
          itemId: 'child',
          now: now,
        ),
        const CorrectionNotAllowed(CorrectionDenial.invalidAmount),
      );
      expect(
        await repository.editExpense(
          'expense',
          amount: 70,
          itemId: 'missing',
          now: now,
        ),
        const CorrectionNotAllowed(CorrectionDenial.itemRemoved),
      );
      expect(
        await repository.editExpense(
          'expense',
          amount: 70,
          itemId: 'removed',
          now: now,
        ),
        const CorrectionNotAllowed(CorrectionDenial.itemRemoved),
      );
      expect(
        await repository.editExpense(
          'expense',
          amount: 70,
          itemId: 'group',
          now: now,
        ),
        const CorrectionNotAllowed(CorrectionDenial.itemRemoved),
      );
      expect(
        await repository.editExpense(
          'income',
          amount: 70,
          itemId: 'child',
          now: now,
        ),
        const CorrectionNotAllowed(CorrectionDenial.notEditable),
      );
      expect(
        await repository.editExpense(
          'missing-row',
          amount: 70,
          itemId: 'child',
          now: now,
        ),
        const CorrectionNotAllowed(CorrectionDenial.notFound),
      );
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    },
  );

  test('editing and then deleting restores the latest amount', () async {
    await seedLedger(
      db,
      items: const [CorrectionItemSeed(id: 'food', balanceBase: 1000)],
      transactions: [
        CorrectionTransactionSeed(
          id: 'expense',
          itemId: 'food',
          direction: TransactionDirection.expense,
          amount: 200,
          occurredAt: occurredAt,
        ),
      ],
    );

    await repository.editExpense(
      'expense',
      amount: 300,
      itemId: 'food',
      now: now,
    );
    await repository.delete('expense', now: now);

    expect(
      (await db.select(db.expenseControlItems).get()).single.balance,
      1000,
    );
  });

  test(
    'reversing an old expense inserts a linked row and restores balance',
    () async {
      final oldTime = now.subtract(const Duration(hours: 25));
      await seedLedger(
        db,
        items: const [
          CorrectionItemSeed(id: 'food', balanceBase: 1000, balance: 750),
        ],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 250,
            occurredAt: oldTime,
            displayName: 'Groceries',
            displayGroupName: 'Living',
            displayIconKey: 'basket',
          ),
        ],
      );
      final original = (await db.select(db.financialTransactions).get()).single;

      final preview = await repository.previewReverse('expense');
      expect(preview.amount, 250);
      expect(preview.items.single.balanceAfter, 1000);
      expect(preview.items.single.itemName, 'Current item name');

      final result = await repository.reverse('expense', now: now);

      expect(result, isA<CorrectionDone>());
      final rows = await db.select(db.financialTransactions).get();
      expect(rows, hasLength(2));
      final reversal = rows.singleWhere((row) => row.reversesId == 'expense');
      expect(reversal.direction, original.direction);
      expect(reversal.amount, original.amount);
      expect(reversal.expenseControlItemId, original.expenseControlItemId);
      expect(reversal.displayName, original.displayName);
      expect(reversal.displayGroupName, original.displayGroupName);
      expect(reversal.displayIconKey, original.displayIconKey);
      expect(reversal.occurredAt, now);
      expect(
        original.updatedAt,
        rows.singleWhere((row) => row.id == 'expense').updatedAt,
      );
      expect(
        (await db.select(db.expenseControlItems).get()).single.balance,
        1000,
      );
      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(1));
      expect(outbox.single.rowId, reversal.id);
      expect(outbox.single.operation, SyncOperation.insert);
    },
  );

  test(
    'reversing an income entry reverses its entire same-time event',
    () async {
      final oldTime = now.subtract(const Duration(hours: 25));
      await seedLedger(
        db,
        items: const [
          CorrectionItemSeed(id: 'one', balanceBase: 100),
          CorrectionItemSeed(id: 'two', balanceBase: 200),
          CorrectionItemSeed(id: 'other', balanceBase: 300, balance: 400),
        ],
        transactions: [
          CorrectionTransactionSeed(
            id: 'income-one',
            itemId: 'one',
            direction: TransactionDirection.income,
            amount: 50,
            occurredAt: oldTime,
          ),
          CorrectionTransactionSeed(
            id: 'income-two',
            itemId: 'two',
            direction: TransactionDirection.income,
            amount: 75,
            occurredAt: oldTime,
          ),
          CorrectionTransactionSeed(
            id: 'different-time',
            itemId: 'other',
            direction: TransactionDirection.income,
            amount: 100,
            occurredAt: oldTime.add(const Duration(seconds: 1)),
          ),
        ],
      );

      await repository.reverse('income-one', now: now);

      final rows = await db.select(db.financialTransactions).get();
      final reversals = rows.where((row) => row.reversesId != null).toList();
      expect(reversals, hasLength(2));
      expect(reversals.map((row) => row.reversesId).toSet(), {
        'income-one',
        'income-two',
      });
      final balances = {
        for (final item in await db.select(db.expenseControlItems).get())
          item.id: item.balance,
      };
      expect(balances, {'one': 100, 'two': 200, 'other': 400});
      expect(await db.select(db.syncOutbox).get(), hasLength(2));
    },
  );

  test(
    'refuses repeat, recent and reversal operations without writes',
    () async {
      final oldTime = now.subtract(const Duration(hours: 25));
      await seedLedger(
        db,
        items: const [CorrectionItemSeed(id: 'food', balanceBase: 1000)],
        transactions: [
          CorrectionTransactionSeed(
            id: 'old',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 250,
            occurredAt: oldTime,
          ),
          CorrectionTransactionSeed(
            id: 'recent',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 100,
            occurredAt: occurredAt,
          ),
          CorrectionTransactionSeed(
            id: 'reversal',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 250,
            occurredAt: now,
            reversesId: 'elsewhere',
          ),
        ],
      );

      expect(
        await repository.reverse('recent', now: now),
        const CorrectionNotAllowed(CorrectionDenial.windowStillOpen),
      );
      expect(
        await repository.reverse('reversal', now: now),
        const CorrectionNotAllowed(CorrectionDenial.isReversal),
      );
      final attempts = await Future.wait([
        repository.reverse('old', now: now),
        repository.reverse('old', now: now),
      ]);
      expect(attempts.whereType<CorrectionDone>(), hasLength(1));
      expect(
        attempts.whereType<CorrectionNotAllowed>().single.denial,
        CorrectionDenial.alreadyReversed,
      );
      final reversalId = (await db.select(db.financialTransactions).get())
          .singleWhere((row) => row.reversesId == 'old')
          .id;
      expect(
        await repository.delete(reversalId, now: now),
        const CorrectionNotAllowed(CorrectionDenial.isReversal),
      );
      expect(
        await repository.editExpense(
          reversalId,
          amount: 100,
          itemId: 'food',
          now: now,
        ),
        const CorrectionNotAllowed(CorrectionDenial.isReversal),
      );
      expect(await db.select(db.syncOutbox).get(), hasLength(1));
    },
  );

  test(
    'reversing after an edit uses the edited amount and permits negatives',
    () async {
      final oldTime = now.subtract(const Duration(hours: 25));
      await seedLedger(
        db,
        items: const [CorrectionItemSeed(id: 'food', balanceBase: 100)],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'food',
            direction: TransactionDirection.expense,
            amount: 250,
            occurredAt: oldTime,
          ),
        ],
      );

      await repository.editExpense(
        'expense',
        amount: 400,
        itemId: 'food',
        now: oldTime.add(const Duration(hours: 23)),
      );
      final result = await repository.reverse('expense', now: now);

      expect(result, isA<CorrectionDone>());
      final rows = await db.select(db.financialTransactions).get();
      expect(
        rows.singleWhere((row) => row.reversesId == 'expense').amount,
        400,
      );
      expect(
        (await db.select(db.expenseControlItems).get()).single.balance,
        100,
      );
      expect(await db.select(db.syncOutbox).get(), hasLength(2));
    },
  );

  test(
    'reversing a removed item reports it without changing its balance',
    () async {
      final oldTime = now.subtract(const Duration(hours: 25));
      await seedLedger(
        db,
        items: [
          CorrectionItemSeed(
            id: 'removed',
            balanceBase: 100,
            balance: -150,
            deletedAt: now,
          ),
        ],
        transactions: [
          CorrectionTransactionSeed(
            id: 'expense',
            itemId: 'removed',
            direction: TransactionDirection.expense,
            amount: 250,
            occurredAt: oldTime,
          ),
        ],
      );

      final result = await repository.reverse('expense', now: now);

      expect(
        result,
        isA<CorrectionDone>().having(
          (done) => done.itemsWithoutBalance,
          'itemsWithoutBalance',
          ['removed'],
        ),
      );
      expect(
        (await db.select(db.expenseControlItems).get()).single.balance,
        -150,
      );
      expect(await db.select(db.syncOutbox).get(), hasLength(1));
    },
  );

  test('reversing an expense can leave its live item negative', () async {
    final oldTime = now.subtract(const Duration(hours: 25));
    await seedLedger(
      db,
      items: const [
        CorrectionItemSeed(id: 'food', balanceBase: -500, balance: -750),
      ],
      transactions: [
        CorrectionTransactionSeed(
          id: 'expense',
          itemId: 'food',
          direction: TransactionDirection.expense,
          amount: 250,
          occurredAt: oldTime,
        ),
      ],
    );

    final result = await repository.reverse('expense', now: now);

    expect(result, isA<CorrectionDone>());
    expect(
      (await db.select(db.expenseControlItems).get()).single.balance,
      -500,
    );
  });
}
