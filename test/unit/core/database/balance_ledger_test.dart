import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/balance_ledger.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';

const _userId = 'test-user';
final _t0 = DateTime.utc(2026, 1, 1);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> item(
    String id, {
    int base = 0,
    int balance = 0,
    int? serverBalance,
    DateTime? deletedAt,
  }) {
    return db
        .into(db.expenseControlItems)
        .insert(
          ExpenseControlItemsCompanion.insert(
            id: id,
            userId: _userId,
            name: id,
            iconKey: 'home',
            balance: Value(balance),
            balanceBase: Value(base),
            serverBalance: Value(serverBalance),
            updatedAt: Value(_t0),
            deletedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> tx(
    String id,
    String itemId,
    TransactionDirection direction,
    int amount, {
    String? reversesId,
    DateTime? deletedAt,
  }) {
    return db
        .into(db.financialTransactions)
        .insert(
          FinancialTransactionsCompanion.insert(
            id: id,
            userId: _userId,
            expenseControlItemId: itemId,
            direction: direction,
            amount: amount,
            occurredAt: _t0,
            reversesId: Value(reversesId),
            deletedAt: Value(deletedAt),
          ),
        );
  }

  Future<ExpenseControlItemRow> read(String id) => (db.select(
    db.expenseControlItems,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<void> outbox(
    String id,
    String entityTable,
    Map<String, dynamic> payload, {
    DateTime? syncedAt,
    DateTime? rejectedAt,
  }) {
    return db
        .into(db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: id,
            entityTable: entityTable,
            rowId: 'row-$id',
            operation: SyncOperation.insert,
            payload: jsonEncode(payload),
            syncedAt: Value(syncedAt),
            rejectedAt: Value(rejectedAt),
          ),
        );
  }

  group('effectOf', () {
    test('income adds, expense subtracts', () {
      expect(
        BalanceLedger.effectOf(
          TransactionDirection.income,
          500,
          isReversal: false,
        ),
        500,
      );
      expect(
        BalanceLedger.effectOf(
          TransactionDirection.expense,
          500,
          isReversal: false,
        ),
        -500,
      );
    });

    test('a reversal negates the effect of the direction it carries', () {
      expect(
        BalanceLedger.effectOf(
          TransactionDirection.income,
          500,
          isReversal: true,
        ),
        -500,
      );
      expect(
        BalanceLedger.effectOf(
          TransactionDirection.expense,
          500,
          isReversal: true,
        ),
        500,
      );
    });
  });

  group('recomputeBalances', () {
    test('balance is balance_base plus the sum of the live effects', () async {
      await item('a', base: 1000, balance: 99999);
      await tx('t1', 'a', TransactionDirection.income, 300);
      await tx('t2', 'a', TransactionDirection.expense, 120);

      await BalanceLedger.recomputeBalances(db, ['a']);

      expect((await read('a')).balance, 1000 + 300 - 120);
    });

    test('soft-deleted rows are ignored', () async {
      await item('a', base: 0);
      await tx('t1', 'a', TransactionDirection.expense, 100);
      await tx('t2', 'a', TransactionDirection.expense, 50, deletedAt: _t0);

      await BalanceLedger.recomputeBalances(db, ['a']);

      expect((await read('a')).balance, -100);
    });

    test('a reversal row counts negatively (an expense refund)', () async {
      await item('a', base: 500);
      await tx('t1', 'a', TransactionDirection.expense, 200);
      await tx('r1', 'a', TransactionDirection.expense, 200, reversesId: 't1');

      await BalanceLedger.recomputeBalances(db, ['a']);

      expect((await read('a')).balance, 500);
    });

    test('an item without transactions equals its balance_base', () async {
      await item('a', base: 750, balance: 1);
      await BalanceLedger.recomputeBalances(db, ['a']);
      expect((await read('a')).balance, 750);
    });

    test('unknown ids are skipped without error', () async {
      await item('a', base: 5);
      await BalanceLedger.recomputeBalances(db, ['missing', 'a']);
      expect((await read('a')).balance, 5);
    });

    test('applying it twice, or in any order, gives the same value', () async {
      await item('a', base: 10);
      await item('b', base: 20);
      await tx('t1', 'a', TransactionDirection.income, 7);
      await tx('t2', 'b', TransactionDirection.expense, 3);

      await BalanceLedger.recomputeBalances(db, ['a', 'b']);
      final first = [(await read('a')).balance, (await read('b')).balance];
      await BalanceLedger.recomputeBalances(db, ['b', 'a', 'a']);
      await BalanceLedger.recomputeBalances(db, ['a']);

      expect([(await read('a')).balance, (await read('b')).balance], first);
      expect(first, [17, 17]);
    });

    test('updated_at and server_balance are left alone', () async {
      await item('a', base: 0, serverBalance: 42);
      await tx('t1', 'a', TransactionDirection.income, 7);

      await BalanceLedger.recomputeBalances(db, ['a']);

      final row = await read('a');
      expect(row.updatedAt, _t0);
      expect(row.serverBalance, 42);
    });

    test('re-emits a watch() stream of expenseControlItems', () async {
      await item('a', base: 0);
      final emissions = <int>[];
      final subscription = db.select(db.expenseControlItems).watch().listen((
        rows,
      ) {
        emissions.add(rows.single.balance);
      });
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      await tx('t1', 'a', TransactionDirection.income, 7);

      await BalanceLedger.recomputeBalances(db, ['a']);
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, 7);
    });

    test('the sum is served by the expense_control_item_id index', () async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN ${BalanceLedger.recomputeSql}',
            variables: [Variable<String>('a')],
          )
          .get();
      final details = plan.map((r) => r.read<String>('detail')).join('\n');
      expect(details, contains('financial_transactions_item_idx'));
      expect(details, isNot(contains('SCAN financial_transactions')));
    });
  });

  group('backfillBalanceBase', () {
    test('a recompute afterwards returns the stored balance', () async {
      await item('a', balance: 1000);
      await tx('t1', 'a', TransactionDirection.income, 300);
      await tx('t2', 'a', TransactionDirection.expense, 100);
      await tx('t3', 'a', TransactionDirection.expense, 999, deletedAt: _t0);
      await item('neg', balance: -250);
      await tx('t4', 'neg', TransactionDirection.expense, 50);
      await item('legacy', balance: 4000); // allocated before the log existed

      await BalanceLedger.backfillBalanceBase(db);

      expect((await read('a')).balanceBase, 800);
      expect((await read('neg')).balanceBase, -200);
      expect((await read('legacy')).balanceBase, 4000);
      await BalanceLedger.recomputeBalances(db, ['a', 'neg', 'legacy']);
      expect((await read('a')).balance, 1000);
      expect((await read('neg')).balance, -250);
      expect((await read('legacy')).balance, 4000);
    });
  });

  group('findDivergent', () {
    test(
      'returns a live item whose server_balance differs from balance',
      () async {
        await item('a', balance: 100, serverBalance: 90);
        expect(await BalanceLedger.findDivergent(db), ['a']);
      },
    );

    test('ignores equal, null and deleted cases', () async {
      await item('equal', balance: 5, serverBalance: 5);
      await item('unknown', balance: 5);
      await item('gone', balance: 5, serverBalance: 9, deletedAt: _t0);
      expect(await BalanceLedger.findDivergent(db), isEmpty);
    });

    test(
      'an unsynced transaction outbox entry for the item hides it',
      () async {
        await item('a', balance: 100, serverBalance: 90);
        await item('b', balance: 100, serverBalance: 90);
        await outbox('o1', 'financial_transactions', {
          'expense_control_item_id': 'a',
        });

        expect(await BalanceLedger.findDivergent(db), ['b']);
      },
    );

    test('synced, rejected, other-table and other-item entries do not count as '
        'waiting', () async {
      await item('a', balance: 100, serverBalance: 90);
      await outbox('o1', 'financial_transactions', {
        'expense_control_item_id': 'a',
      }, syncedAt: _t0);
      await outbox('o2', 'financial_transactions', {
        'expense_control_item_id': 'a',
      }, rejectedAt: _t0);
      await outbox('o3', 'expense_control_items', {'id': 'a'});
      await outbox('o4', 'financial_transactions', {
        'expense_control_item_id': 'other',
      });

      expect(await BalanceLedger.findDivergent(db), ['a']);
    });
  });
}
