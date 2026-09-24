import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/features/expense_control/data/expense_control_repository_impl.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';

void main() {
  test(
    'recorded income and expense appear in the current monthly history',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ExpenseControlRepositoryImpl(database, userId: 'user');
      await repository.create(
        const ExpenseControlItem(
          id: 'food',
          userId: 'user',
          parentId: null,
          name: 'Food',
          iconKey: 'utensils',
          description: null,
          sortOrder: 0,
          allocationMethod: ExpenseAllocationMethod.fixed,
          allocationValue: 100,
          balance: 0,
          isSavingsReceiver: false,
        ),
      );

      await repository.applyIncomeAllocation({'food': 100000});
      await repository.recordExpense(itemId: 'food', amount: 25000);

      final now = DateTime.now();
      final records = await repository
          .watchTransactionHistory(start: monthStart(now), end: nextMonth(now))
          .first;
      final view = buildTransactionHistoryView(
        records: records,
        filter: const TransactionHistoryFilter.all(),
      );

      expect(records.map((record) => record.direction).toSet(), {
        TransactionHistoryDirection.income,
        TransactionHistoryDirection.expense,
      });
      expect(view.expenseTotal, 25000);
      expect(view.groups.single.items, hasLength(2));
    },
  );
}
