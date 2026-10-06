import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/tables/financial_transactions_table.dart';
import 'package:finance/core/sync/remote_row_writer.dart';

const _userId = 'test-user';
const _otherUserId = 'other-user';

ExpenseControlItemRow _itemRow(
  String id, {
  String userId = _userId,
  String name = 'Food',
  required DateTime updatedAt,
  DateTime? deletedAt,
}) {
  return ExpenseControlItemRow(
    id: id,
    userId: userId,
    parentId: null,
    name: name,
    iconKey: 'utensils',
    description: null,
    sortOrder: 0,
    allocationMethod: null,
    allocationValue: null,
    balance: 0,
    isSavingsReceiver: false,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

FinancialTransactionRow _transactionRow(
  String id, {
  String userId = _userId,
  required DateTime updatedAt,
  DateTime? deletedAt,
}) {
  return FinancialTransactionRow(
    id: id,
    userId: userId,
    expenseControlItemId: 'food',
    direction: TransactionDirection.expense,
    amount: 1000,
    occurredAt: DateTime.utc(2026, 1, 1),
    displayName: null,
    displayGroupName: null,
    displayIconKey: null,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('applyRemoteExpenseControlItem', () {
    test('first application of a new row inserts it', () async {
      final row = _itemRow('food', updatedAt: DateTime.utc(2026, 1, 1));
      await applyRemoteExpenseControlItem(db, _userId, row);

      final stored = await (db.select(
        db.expenseControlItems,
      )..where((t) => t.id.equals('food'))).getSingle();
      expect(stored.name, 'Food');
    });

    test('re-applying an unchanged row is a no-op (FR-004)', () async {
      final updatedAt = DateTime.utc(2026, 1, 1);
      final row = _itemRow('food', updatedAt: updatedAt);
      await applyRemoteExpenseControlItem(db, _userId, row);
      await applyRemoteExpenseControlItem(db, _userId, row);

      final all = await db.select(db.expenseControlItems).get();
      expect(all, hasLength(1));
    });

    test(
      'applying a row with updatedAt older-than-or-equal-to the local '
      'value is skipped, not applied (research.md Decision 8 race fix)',
      () async {
        final newer = DateTime.utc(2026, 1, 2);
        final older = DateTime.utc(2026, 1, 1);
        await applyRemoteExpenseControlItem(
          db,
          _userId,
          _itemRow('food', name: 'Newer', updatedAt: newer),
        );

        await applyRemoteExpenseControlItem(
          db,
          _userId,
          _itemRow('food', name: 'Older', updatedAt: older),
        );
        var stored = await (db.select(
          db.expenseControlItems,
        )..where((t) => t.id.equals('food'))).getSingle();
        expect(stored.name, 'Newer');

        await applyRemoteExpenseControlItem(
          db,
          _userId,
          _itemRow('food', name: 'SameTimestamp', updatedAt: newer),
        );
        stored = await (db.select(
          db.expenseControlItems,
        )..where((t) => t.id.equals('food'))).getSingle();
        expect(stored.name, 'Newer');
      },
    );

    test(
      'applying a row with deletedAt set correctly tombstones it (FR-003)',
      () async {
        final deletedAt = DateTime.utc(2026, 1, 2);
        final row = _itemRow(
          'food',
          updatedAt: deletedAt,
          deletedAt: deletedAt,
        );
        await applyRemoteExpenseControlItem(db, _userId, row);

        final stored = await (db.select(
          db.expenseControlItems,
        )..where((t) => t.id.equals('food'))).getSingle();
        expect(stored.deletedAt, deletedAt);
      },
    );

    test(
      'confirms no sync_outbox row is created (research.md Decision 7)',
      () async {
        final row = _itemRow('food', updatedAt: DateTime.utc(2026, 1, 1));
        await applyRemoteExpenseControlItem(db, _userId, row);

        final outbox = await db.select(db.syncOutbox).get();
        expect(outbox, isEmpty);
      },
    );

    test(
      'a row whose userId does not match the passed-in userId is '
      'rejected rather than silently applied (`/speckit-analyze` finding G1)',
      () async {
        final row = _itemRow(
          'food',
          userId: _otherUserId,
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        await applyRemoteExpenseControlItem(db, _userId, row);

        final all = await db.select(db.expenseControlItems).get();
        expect(all, isEmpty);
      },
    );
  });

  group('applyRemoteFinancialTransaction', () {
    test('first application of a new row inserts it', () async {
      final row = _transactionRow('txn', updatedAt: DateTime.utc(2026, 1, 1));
      await applyRemoteFinancialTransaction(db, _userId, row);

      final stored = await (db.select(
        db.financialTransactions,
      )..where((t) => t.id.equals('txn'))).getSingle();
      expect(stored.amount, 1000);
    });

    test('re-applying an unchanged row is a no-op (FR-004)', () async {
      final updatedAt = DateTime.utc(2026, 1, 1);
      final row = _transactionRow('txn', updatedAt: updatedAt);
      await applyRemoteFinancialTransaction(db, _userId, row);
      await applyRemoteFinancialTransaction(db, _userId, row);

      final all = await db.select(db.financialTransactions).get();
      expect(all, hasLength(1));
    });

    test(
      'applying a row with deletedAt set correctly tombstones it (FR-003)',
      () async {
        final deletedAt = DateTime.utc(2026, 1, 2);
        final row = _transactionRow(
          'txn',
          updatedAt: deletedAt,
          deletedAt: deletedAt,
        );
        await applyRemoteFinancialTransaction(db, _userId, row);

        final stored = await (db.select(
          db.financialTransactions,
        )..where((t) => t.id.equals('txn'))).getSingle();
        expect(stored.deletedAt, deletedAt);
      },
    );

    test(
      'confirms no sync_outbox row is created (research.md Decision 7)',
      () async {
        final row = _transactionRow('txn', updatedAt: DateTime.utc(2026, 1, 1));
        await applyRemoteFinancialTransaction(db, _userId, row);

        final outbox = await db.select(db.syncOutbox).get();
        expect(outbox, isEmpty);
      },
    );

    test(
      'a row whose userId does not match the passed-in userId is '
      'rejected rather than silently applied (`/speckit-analyze` finding G1)',
      () async {
        final row = _transactionRow(
          'txn',
          userId: _otherUserId,
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        await applyRemoteFinancialTransaction(db, _userId, row);

        final all = await db.select(db.financialTransactions).get();
        expect(all, isEmpty);
      },
    );
  });
}
