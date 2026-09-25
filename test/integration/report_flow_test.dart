import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/features/expense_control/data/expense_control_repository_impl.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expenses/application/report_summary.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';

void main() {
  test(
    'a recorded income allocation and expense are reflected in this '
    "month's totals and breakdown without a manual refresh (FR-016)",
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

      final now = DateTime.now();
      final monthRangeStart = monthStart(now);
      final monthRangeEnd = nextMonth(now);

      final totalsSnapshots = <ReportTotals>[];
      final breakdownSnapshots = <List<ReportItemEntry>>[];

      final itemsSnapshot = await repository.watchAll().first;
      final tree = [
        for (final item in itemsSnapshot)
          ExpenseControlNode(item: item, children: const []),
      ];

      final subscription = repository
          .watchTransactionHistory(start: monthRangeStart, end: monthRangeEnd)
          .listen((records) {
            totalsSnapshots.add(computeReportTotals(records));
            breakdownSnapshots.add(computeReportBreakdown(records, tree));
          });

      await pumpEventQueue();

      await repository.applyIncomeAllocation({'food': 100000});
      await repository.recordExpense(itemId: 'food', amount: 25000);
      await pumpEventQueue();

      await subscription.cancel();

      expect(
        totalsSnapshots.last.totalIncome,
        100000,
        reason:
            'the income allocation is visible via watchTransactionHistory '
            'without a manual refresh',
      );
      expect(totalsSnapshots.last.totalExpense, 25000);

      final foodEntry = breakdownSnapshots.last.singleWhere(
        (e) => e.itemId == 'food',
      );
      expect(foodEntry.allocated, 100000);
      expect(foodEntry.spent, 25000);
      expect(foodEntry.usageState, ReportItemUsageState.tracked);
    },
  );
}
