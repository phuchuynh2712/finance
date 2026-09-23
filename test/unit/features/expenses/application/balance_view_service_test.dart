import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expenses/application/balance_view_service.dart';

void main() {
  test('prepares leaf and group balances outside presentation', () {
    final child = _item('child', balance: 125);
    final group = _item('group', balance: 999);
    final rows = const BalanceViewService(ExpenseControlPlanService()).prepare([
      ExpenseControlNode(item: group, children: [child]),
      ExpenseControlNode(item: child, children: const []),
    ]);

    expect(rows[0].balance, 125);
    expect(rows[1].balance, 125);
  });
}

ExpenseControlItem _item(String id, {required int balance}) {
  return ExpenseControlItem(
    id: id,
    userId: 'user',
    parentId: null,
    name: id,
    iconKey: 'wallet',
    description: null,
    sortOrder: 0,
    allocationMethod: ExpenseAllocationMethod.fixed,
    allocationValue: 100,
    balance: balance,
    isSavingsReceiver: false,
  );
}
