import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/balance_ledger.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/sync/remote_row_writer.dart';
import 'package:finance/core/sync/sync_notice.dart';
import 'package:finance/core/sync/sync_outbox_table.dart';

const _userId = 'test-user';

ExpenseControlItemRow _item(
  String id, {
  int balance = 0,
  int base = 0,
  int? serverBalance,
  required DateTime updatedAt,
}) {
  return ExpenseControlItemRow(
    id: id,
    userId: _userId,
    parentId: null,
    name: id,
    iconKey: 'home',
    description: null,
    sortOrder: 0,
    allocationMethod: null,
    allocationValue: null,
    balance: balance,
    balanceBase: base,
    serverBalance: serverBalance,
    isSavingsReceiver: false,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deletedAt: null,
  );
}

FinancialTransactionRow _tx(
  String id, {
  String item = 'food',
  TransactionDirection direction = TransactionDirection.expense,
  int amount = 100,
  required DateTime updatedAt,
  DateTime? deletedAt,
  String? reversesId,
}) {
  return FinancialTransactionRow(
    id: id,
    userId: _userId,
    expenseControlItemId: item,
    direction: direction,
    amount: amount,
    occurredAt: DateTime.utc(2026, 1, 1),
    displayName: null,
    displayGroupName: null,
    displayIconKey: null,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    reversesId: reversesId,
  );
}

void main() {
  late AppDatabase db;
  final t1 = DateTime.utc(2026, 1, 1);
  final t2 = DateTime.utc(2026, 1, 2);
  final t3 = DateTime.utc(2026, 1, 3);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<ExpenseControlItemRow> read(String id) => (db.select(
    db.expenseControlItems,
  )..where((t) => t.id.equals(id))).getSingle();

  group('applying an item row', () {
    test('stores balance_base, keeps the row balance as server_balance and '
        'derives the displayed balance from the local transactions', () async {
      await db
          .into(db.financialTransactions)
          .insert(
            FinancialTransactionsCompanion.insert(
              id: 'local-income',
              userId: _userId,
              expenseControlItemId: 'food',
              direction: TransactionDirection.income,
              amount: 40,
              occurredAt: t1,
            ),
          );

      await applyRemoteExpenseControlItem(
        db,
        _userId,
        _item('food', balance: 500, base: 100, updatedAt: t2),
      );

      final stored = await read('food');
      expect(stored.balanceBase, 100);
      expect(stored.serverBalance, 500);
      expect(stored.balance, 140);
    });

    test('a transaction that arrived before its item is counted when the '
        'item row arrives', () async {
      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', amount: 30, updatedAt: t1),
      );
      expect(await db.select(db.expenseControlItems).get(), isEmpty);

      await applyRemoteExpenseControlItem(
        db,
        _userId,
        _item('food', base: 1000, updatedAt: t2),
      );

      expect((await read('food')).balance, 970);
    });
  });

  group('applying a transaction row', () {
    setUp(() async {
      await applyRemoteExpenseControlItem(
        db,
        _userId,
        _item('food', base: 1000, updatedAt: t1),
      );
      await applyRemoteExpenseControlItem(
        db,
        _userId,
        _item('rent', base: 5000, updatedAt: t1),
      );
    });

    test('insert, amount change and soft delete recompute the item', () async {
      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', amount: 100, updatedAt: t1),
      );
      expect((await read('food')).balance, 900);

      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', amount: 250, updatedAt: t2),
      );
      expect((await read('food')).balance, 750);

      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', amount: 250, updatedAt: t3, deletedAt: t3),
      );
      expect((await read('food')).balance, 1000);
    });

    test('an item change recomputes the old and the new item', () async {
      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', item: 'food', amount: 100, updatedAt: t1),
      );
      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', item: 'rent', amount: 100, updatedAt: t2),
      );

      expect((await read('food')).balance, 1000);
      expect((await read('rent')).balance, 4900);
    });

    test('a reversal row cancels its original', () async {
      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', amount: 100, updatedAt: t1),
      );
      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('r', amount: 100, updatedAt: t2, reversesId: 't'),
      );

      expect((await read('food')).balance, 1000);
    });

    test(
      'a remote reversal replaces an unsynced local reversal collision',
      () async {
        await db
            .into(db.financialTransactions)
            .insert(_tx('original', updatedAt: t1));
        await db
            .into(db.financialTransactions)
            .insert(
              _tx('local-reversal', updatedAt: t2, reversesId: 'original'),
            );
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                id: 'local-reversal-outbox',
                entityTable: 'financial_transactions',
                rowId: 'local-reversal',
                operation: SyncOperation.insert,
                payload: '{}',
              ),
            );
        final notices = SyncNotices(db);
        await notices.loaded;
        final noticeFuture = notices.stream.first;

        await applyRemoteFinancialTransaction(
          db,
          _userId,
          _tx('server-reversal', updatedAt: t3, reversesId: 'original'),
          notices: notices,
        );

        expect(
          await (db.select(
            db.financialTransactions,
          )..where((row) => row.id.equals('local-reversal'))).getSingleOrNull(),
          isNull,
        );
        expect(
          await (db.select(db.financialTransactions)
                ..where((row) => row.id.equals('server-reversal')))
              .getSingleOrNull(),
          isNotNull,
        );
        expect(await db.select(db.syncOutbox).get(), isEmpty);
        expect((await read('food')).balance, 1000);
        expect((await noticeFuture).reason, SyncNoticeReason.alreadyReversed);
        await notices.dispose();
      },
    );

    test(
      'deleting an original remotely cascades to its pending reversal',
      () async {
        await db
            .into(db.financialTransactions)
            .insert(_tx('original', updatedAt: t1));
        await db
            .into(db.financialTransactions)
            .insert(
              _tx('local-reversal', updatedAt: t2, reversesId: 'original'),
            );
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                id: 'local-reversal-outbox',
                entityTable: 'financial_transactions',
                rowId: 'local-reversal',
                operation: SyncOperation.insert,
                payload: '{}',
              ),
            );
        final notices = SyncNotices(db);
        await notices.loaded;
        final noticeFuture = notices.stream.first;

        await applyRemoteFinancialTransaction(
          db,
          _userId,
          _tx('original', updatedAt: t3, deletedAt: t3),
          notices: notices,
        );

        final reversal = await (db.select(
          db.financialTransactions,
        )..where((row) => row.id.equals('local-reversal'))).getSingle();
        expect(reversal.deletedAt, t3);
        expect(await db.select(db.syncOutbox).get(), isEmpty);
        expect((await read('food')).balance, 1000);
        expect((await noticeFuture).reason, SyncNoticeReason.deleted);
        await notices.dispose();
      },
    );

    test(
      'a recent local edit overridden by a pulled row is reported once',
      () async {
        await db
            .into(db.financialTransactions)
            .insert(_tx('t', amount: 250, updatedAt: t2));
        await db
            .into(db.syncOutbox)
            .insert(
              SyncOutboxCompanion.insert(
                id: 'synced-edit',
                entityTable: 'financial_transactions',
                rowId: 't',
                operation: SyncOperation.update,
                payload: '{}',
                syncedAt: Value(t2),
              ),
            );
        final notices = SyncNotices(db);
        await notices.loaded;
        final noticeFuture = notices.stream.first;

        await applyRemoteFinancialTransaction(
          db,
          _userId,
          _tx('t', amount: 300, updatedAt: t3),
          notices: notices,
          now: t3,
        );

        final notice = await noticeFuture;
        expect(notice.reason, SyncNoticeReason.editedElsewhere);
        expect(notice.amount, 250);
        expect(
          (await db.select(db.financialTransactions).getSingle()).amount,
          300,
        );
        await notices.dispose();
      },
    );

    test('applying the same row twice, or two rows in either order, gives the '
        'same balances', () async {
      final older = _tx('t', amount: 100, updatedAt: t1);
      final newer = _tx('t', amount: 300, updatedAt: t2);

      await applyRemoteFinancialTransaction(db, _userId, newer);
      await applyRemoteFinancialTransaction(db, _userId, older);
      await applyRemoteFinancialTransaction(db, _userId, newer);

      expect((await read('food')).balance, 700);
    });

    test('a collector defers the recompute to the caller', () async {
      final touched = <String>{};

      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', amount: 100, updatedAt: t1),
        touchedItemIds: touched,
      );
      expect((await read('food')).balance, 1000); // not recomputed yet
      expect(touched, {'food'});

      await BalanceLedger.recomputeBalances(db, touched);
      expect((await read('food')).balance, 900);
    });

    test(
      'a collector also receives the old item of a moved transaction',
      () async {
        await applyRemoteFinancialTransaction(
          db,
          _userId,
          _tx('t', item: 'food', updatedAt: t1),
        );
        final touched = <String>{};
        await applyRemoteFinancialTransaction(
          db,
          _userId,
          _tx('t', item: 'rent', updatedAt: t2),
          touchedItemIds: touched,
        );
        expect(touched, {'food', 'rent'});
      },
    );

    test('a row that is not newer is a no-op and recomputes nothing', () async {
      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', amount: 100, updatedAt: t2),
      );
      // Distinguishable marker: a recompute would overwrite it.
      await (db.update(db.expenseControlItems)
            ..where((i) => i.id.equals('food')))
          .write(const ExpenseControlItemsCompanion(balance: Value(-1)));

      await applyRemoteFinancialTransaction(
        db,
        _userId,
        _tx('t', amount: 999, updatedAt: t1),
      );

      expect((await read('food')).balance, -1);
    });

    test(
      'overwrite: true applies a row whatever the two updatedAt say',
      () async {
        await applyRemoteFinancialTransaction(
          db,
          _userId,
          _tx('t', amount: 100, updatedAt: t3),
        );

        await applyRemoteFinancialTransaction(
          db,
          _userId,
          _tx('t', amount: 400, updatedAt: t1),
          overwrite: true,
        );

        final stored = await (db.select(
          db.financialTransactions,
        )..where((x) => x.id.equals('t'))).getSingle();
        expect(stored.amount, 400);
        expect(stored.updatedAt, t1);
        expect((await read('food')).balance, 600);
      },
    );

    test(
      'overwrite: true applies an item row whatever the updatedAt say',
      () async {
        await applyRemoteExpenseControlItem(
          db,
          _userId,
          _item('food', base: 7, updatedAt: t1),
          overwrite: true,
        );
        expect((await read('food')).balanceBase, 7);
      },
    );
  });

  group('applyRemoteRowJson', () {
    test('parses balance, balance_base and reverses_id strictly', () async {
      await applyRemoteRowJson(db, 'expense_control_items', {
        'id': 'food',
        'user_id': _userId,
        'name': 'Food',
        'icon_key': 'home',
        'sort_order': 0,
        'balance': 900,
        'balance_base': 1000,
        'is_savings_receiver': false,
        'created_at': t1.toIso8601String(),
        'updated_at': t1.toIso8601String(),
      });
      await applyRemoteRowJson(db, 'financial_transactions', {
        'id': 'r',
        'user_id': _userId,
        'expense_control_item_id': 'food',
        'direction': 'expense',
        'amount': 100,
        'occurred_at': t1.toIso8601String(),
        'created_at': t1.toIso8601String(),
        'updated_at': t2.toIso8601String(),
        'reverses_id': 'o',
      });

      final stored = await read('food');
      expect(stored.serverBalance, 900);
      expect(stored.balanceBase, 1000);
      // The reversal of an expense gives money back.
      expect(stored.balance, 1100);
      final reversal = await (db.select(
        db.financialTransactions,
      )..where((x) => x.id.equals('r'))).getSingle();
      expect(reversal.reversesId, 'o');
    });

    test('an item row without balance_base is refused loudly', () async {
      await expectLater(
        applyRemoteRowJson(db, 'expense_control_items', {
          'id': 'food',
          'user_id': _userId,
          'name': 'Food',
          'icon_key': 'home',
          'sort_order': 0,
          'balance': 900,
          'is_savings_receiver': false,
          'created_at': t1.toIso8601String(),
          'updated_at': t1.toIso8601String(),
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
