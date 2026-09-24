import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/features/expense_control/data/expense_control_repository_impl.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expenses/application/overview_recent_transactions.dart';
import 'package:finance/features/expenses/application/overview_summary_service.dart';

void main() {
  test(
    'a recorded expense is reflected in both the total balance and the recent-transactions list, without a manual refresh (FR-014)',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = ExpenseControlRepositoryImpl(database, userId: 'user');
      const summaryService = OverviewSummaryService(
        ExpenseControlPlanService(),
      );

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

      final treeSummaries = <int>[];
      final treeSubscription = repository.watchAll().listen((items) {
        final tree = [
          for (final item in items)
            ExpenseControlNode(item: item, children: const []),
        ];
        treeSummaries.add(summaryService.buildSummary(tree).totalBalance);
      });

      final recentCounts = <int>[];
      final recentSubscription = repository.watchRecent(limit: 5).listen((
        records,
      ) {
        recentCounts.add(records.length);
      });

      await pumpEventQueue();

      await repository.applyIncomeAllocation({'food': 100000});
      await repository.recordExpense(itemId: 'food', amount: 25000);
      await pumpEventQueue();

      await treeSubscription.cancel();
      await recentSubscription.cancel();

      expect(
        treeSummaries.last,
        75000,
        reason:
            'total balance reflects the recorded income minus expense '
            'via the same watchAll() stream the Overview provider chain '
            'watches — no manual refresh call was made',
      );
      expect(
        recentCounts.last,
        2,
        reason:
            'both the income and expense rows are visible via '
            'watchRecent without a manual refresh',
      );

      final recentRecords = await repository.watchRecent(limit: 5).first;
      final recentItems = buildOverviewRecentItems(
        recentRecords,
        now: DateTime.now(),
      );
      expect(recentItems.map((i) => i.relativeDay).toSet(), {
        const OverviewRelativeDay.today(),
      });
    },
  );
}
