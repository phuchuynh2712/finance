import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/report_summary.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionHistoryRecord _record({
  required String id,
  required String sourceItemId,
  required TransactionHistoryDirection direction,
  required int amount,
  String displayName = 'Item',
  String? displayGroupName,
}) {
  return TransactionHistoryRecord(
    id: id,
    sourceItemId: sourceItemId,
    direction: direction,
    amount: amount,
    occurredAt: DateTime(2026, 6, 15),
    displayName: displayName,
    displayGroupName: displayGroupName,
    displayIconKey: null,
  );
}

ExpenseControlItem _item({
  required String id,
  String? parentId,
  String name = 'Item',
}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: parentId,
    name: name,
    iconKey: 'home',
    description: null,
    sortOrder: 0,
    allocationMethod: null,
    allocationValue: null,
    balance: 0,
    isSavingsReceiver: false,
  );
}

void main() {
  group('computeReportTotals', () {
    test('folds only income records into totalIncome', () {
      final totals = computeReportTotals([
        _record(
          id: '1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.income,
          amount: 1000,
        ),
        _record(
          id: '2',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.income,
          amount: 2000,
        ),
      ]);
      expect(totals.totalIncome, 3000);
      expect(totals.totalExpense, 0);
    });

    test('folds only expense records into totalExpense', () {
      final totals = computeReportTotals([
        _record(
          id: '1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 500,
        ),
        _record(
          id: '2',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 700,
        ),
      ]);
      expect(totals.totalIncome, 0);
      expect(totals.totalExpense, 1200);
    });

    test('sums mixed-direction records into their respective totals', () {
      final totals = computeReportTotals([
        _record(
          id: '1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.income,
          amount: 10000,
        ),
        _record(
          id: '2',
          sourceItemId: 'b',
          direction: TransactionHistoryDirection.expense,
          amount: 4000,
        ),
      ]);
      expect(totals.totalIncome, 10000);
      expect(totals.totalExpense, 4000);
    });

    test('an empty list yields both totals as zero', () {
      final totals = computeReportTotals(const []);
      expect(totals.totalIncome, 0);
      expect(totals.totalExpense, 0);
    });
  });

  group('computeReportBreakdown', () {
    test('aggregates spent and allocated per item by sourceItemId', () {
      final tree = [
        ExpenseControlNode(
          item: _item(id: 'a', name: 'Ăn uống'),
          children: [],
        ),
      ];
      final entries = computeReportBreakdown([
        _record(
          id: '1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.income,
          amount: 5000000,
        ),
        _record(
          id: '2',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 1200000,
        ),
        _record(
          id: '3',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 300000,
        ),
      ], tree);

      expect(entries, hasLength(1));
      expect(entries.single.allocated, 5000000);
      expect(entries.single.spent, 1500000);
    });

    test(
      'notAllocated: expense activity with zero allocation this month shows no percentage',
      () {
        final tree = [
          ExpenseControlNode(
            item: _item(id: 'a'),
            children: [],
          ),
        ];
        final entries = computeReportBreakdown([
          _record(
            id: '1',
            sourceItemId: 'a',
            direction: TransactionHistoryDirection.expense,
            amount: 200000,
          ),
        ], tree);

        expect(entries.single.usageState, ReportItemUsageState.notAllocated);
        expect(entries.single.usagePercent, isNull);
      },
    );

    test('unused: allocated but not yet spent shows 0% used', () {
      final tree = [
        ExpenseControlNode(
          item: _item(id: 'a'),
          children: [],
        ),
      ];
      final entries = computeReportBreakdown([
        _record(
          id: '1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.income,
          amount: 1000000,
        ),
      ], tree);

      expect(entries.single.usageState, ReportItemUsageState.unused);
      expect(entries.single.usagePercent, 0);
    });

    test(
      'tracked: usagePercent can exceed 100 when spent outpaces allocated',
      () {
        final tree = [
          ExpenseControlNode(
            item: _item(id: 'a'),
            children: [],
          ),
        ];
        final entries = computeReportBreakdown([
          _record(
            id: '1',
            sourceItemId: 'a',
            direction: TransactionHistoryDirection.income,
            amount: 100000,
          ),
          _record(
            id: '2',
            sourceItemId: 'a',
            direction: TransactionHistoryDirection.expense,
            amount: 150000,
          ),
        ], tree);

        expect(entries.single.usageState, ReportItemUsageState.tracked);
        expect(entries.single.usagePercent, 150);
      },
    );

    test('an item with no activity in either direction is excluded', () {
      final tree = [
        ExpenseControlNode(
          item: _item(id: 'a'),
          children: [],
        ),
        ExpenseControlNode(
          item: _item(id: 'b'),
          children: [],
        ),
      ];
      final entries = computeReportBreakdown([
        _record(
          id: '1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 100,
        ),
      ], tree);

      expect(entries.map((e) => e.itemId), ['a']);
    });

    test('results are sorted by spent descending', () {
      final tree = [
        ExpenseControlNode(
          item: _item(id: 'a'),
          children: [],
        ),
        ExpenseControlNode(
          item: _item(id: 'b'),
          children: [],
        ),
        ExpenseControlNode(
          item: _item(id: 'c'),
          children: [],
        ),
      ];
      final entries = computeReportBreakdown([
        _record(
          id: '1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 300,
        ),
        _record(
          id: '2',
          sourceItemId: 'b',
          direction: TransactionHistoryDirection.expense,
          amount: 900,
        ),
        _record(
          id: '3',
          sourceItemId: 'c',
          direction: TransactionHistoryDirection.expense,
          amount: 600,
        ),
      ], tree);

      expect(entries.map((e) => e.itemId), ['b', 'c', 'a']);
    });

    test('a nested leaf resolves its parent group name', () {
      final tree = [
        ExpenseControlNode(
          item: _item(id: 'group', name: 'Ăn uống'),
          children: [_item(id: 'leaf', parentId: 'group', name: 'Ăn trưa')],
        ),
      ];
      final entries = computeReportBreakdown([
        _record(
          id: '1',
          sourceItemId: 'leaf',
          direction: TransactionHistoryDirection.expense,
          amount: 100,
        ),
      ], tree);

      expect(entries.single.name, 'Ăn trưa');
      expect(entries.single.groupName, 'Ăn uống');
    });

    test('a standalone top-level item has no group name', () {
      final tree = [
        ExpenseControlNode(
          item: _item(id: 'a', name: 'Tiết kiệm'),
          children: [],
        ),
      ];
      final entries = computeReportBreakdown([
        _record(
          id: '1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 100,
        ),
      ], tree);

      expect(entries.single.groupName, isNull);
    });

    test('an item since removed from the tree falls back to the transaction\'s '
        'own snapshotted displayName, with no group label', () {
      final entries = computeReportBreakdown([
        _record(
          id: '1',
          sourceItemId: 'removed',
          direction: TransactionHistoryDirection.expense,
          amount: 100,
          displayName: 'Archived Item',
        ),
      ], const []);

      expect(entries.single.name, 'Archived Item');
      expect(entries.single.groupName, isNull);
    });

    test('sum of breakdown spent/allocated matches computeReportTotals for the '
        'same record set (SC-005 — the two folds must never disagree)', () {
      final tree = [
        ExpenseControlNode(
          item: _item(id: 'a'),
          children: [],
        ),
        ExpenseControlNode(
          item: _item(id: 'b'),
          children: [],
        ),
      ];
      final records = [
        _record(
          id: '1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.income,
          amount: 5000000,
        ),
        _record(
          id: '2',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 1200000,
        ),
        _record(
          id: '3',
          sourceItemId: 'b',
          direction: TransactionHistoryDirection.expense,
          amount: 800000,
        ),
      ];

      final totals = computeReportTotals(records);
      final entries = computeReportBreakdown(records, tree);

      expect(
        entries.fold<int>(0, (sum, e) => sum + e.spent),
        totals.totalExpense,
      );
      expect(
        entries.fold<int>(0, (sum, e) => sum + e.allocated),
        totals.totalIncome,
      );
    });
  });
}
