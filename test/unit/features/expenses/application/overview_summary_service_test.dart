import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expenses/application/overview_summary_service.dart';

void main() {
  const service = OverviewSummaryService(ExpenseControlPlanService());

  test('totalBalance is the fold of every root account balance', () {
    final tree = [
      ExpenseControlNode(item: _item('a', balance: 100), children: const []),
      ExpenseControlNode(item: _item('b', balance: 250), children: const []),
      ExpenseControlNode(item: _item('c', balance: -30), children: const []),
    ];

    final summary = service.buildSummary(tree);

    expect(summary.totalBalance, 320);
  });

  test(
    'a group account uses the live sum of its children, never its own stored balance value',
    () {
      final child1 = _item('child1', balance: 40);
      final child2 = _item('child2', balance: 60);
      final group = _item('group', balance: 999); // stale/unused per FR-001
      final tree = [
        ExpenseControlNode(item: group, children: [child1, child2]),
      ];

      final summary = service.buildSummary(tree);

      expect(summary.accounts.single.balance, 100);
      expect(summary.totalBalance, 100);
    },
  );

  test(
    'accounts preserves the tree order and carries name/iconKey through',
    () {
      final tree = [
        ExpenseControlNode(
          item: _item('a', balance: 10, name: 'Gia đình', iconKey: 'home'),
          children: const [],
        ),
        ExpenseControlNode(
          item: _item('b', balance: 20, name: 'Cá nhân', iconKey: 'user'),
          children: const [],
        ),
      ];

      final summary = service.buildSummary(tree);

      expect(summary.accounts.map((a) => a.id), ['a', 'b']);
      expect(summary.accounts[0].name, 'Gia đình');
      expect(summary.accounts[0].iconKey, 'home');
      expect(summary.accounts[1].name, 'Cá nhân');
    },
  );

  group('negativeAccounts / isNegative', () {
    test('an account with a negative balance is flagged isNegative', () {
      final tree = [
        ExpenseControlNode(item: _item('a', balance: -1), children: const []),
      ];

      final summary = service.buildSummary(tree);

      expect(summary.accounts.single.isNegative, isTrue);
      expect(summary.negativeAccounts, hasLength(1));
    });

    test('a zero balance is not negative', () {
      final tree = [
        ExpenseControlNode(item: _item('a', balance: 0), children: const []),
      ];

      final summary = service.buildSummary(tree);

      expect(summary.accounts.single.isNegative, isFalse);
      expect(summary.negativeAccounts, isEmpty);
    });

    test('negativeAccounts contains only the negative accounts, in order', () {
      final tree = [
        ExpenseControlNode(item: _item('a', balance: 10), children: const []),
        ExpenseControlNode(item: _item('b', balance: -5), children: const []),
        ExpenseControlNode(item: _item('c', balance: -15), children: const []),
      ];

      final summary = service.buildSummary(tree);

      expect(summary.negativeAccounts.map((a) => a.id), ['b', 'c']);
    });

    test('no accounts negative yields an empty negativeAccounts list', () {
      final tree = [
        ExpenseControlNode(item: _item('a', balance: 10), children: const []),
        ExpenseControlNode(item: _item('b', balance: 20), children: const []),
      ];

      final summary = service.buildSummary(tree);

      expect(summary.negativeAccounts, isEmpty);
    });
  });

  test('an empty tree yields a zero total and no accounts', () {
    final summary = service.buildSummary(const []);

    expect(summary.totalBalance, 0);
    expect(summary.accounts, isEmpty);
    expect(summary.negativeAccounts, isEmpty);
  });
}

ExpenseControlItem _item(
  String id, {
  required int balance,
  String name = 'item',
  String iconKey = 'wallet',
}) {
  return ExpenseControlItem(
    id: id,
    userId: 'user',
    parentId: null,
    name: name,
    iconKey: iconKey,
    description: null,
    sortOrder: 0,
    allocationMethod: ExpenseAllocationMethod.fixed,
    allocationValue: 100,
    balance: balance,
    isSavingsReceiver: false,
  );
}
