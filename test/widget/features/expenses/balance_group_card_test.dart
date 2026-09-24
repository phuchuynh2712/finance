import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expenses/presentation/widgets/balance_group_card.dart';

void main() {
  testWidgets('group expands and renders read-only child rows', (tester) async {
    final group = _item('group', name: 'Group');
    final child = _item('child', name: 'Child', balance: 120);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BalanceGroupCard(
            node: ExpenseControlNode(item: group, children: [child]),
            balance: 120,
            currency: CurrencyFormatter('vi'),
          ),
        ),
      ),
    );

    expect(find.text('Child'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('Group'));
    await tester.pumpAndSettle();
    expect(find.text('Child'), findsNothing);
  });
}

ExpenseControlItem _item(String id, {required String name, int balance = 0}) {
  return ExpenseControlItem(
    id: id,
    userId: 'user',
    parentId: null,
    name: name,
    iconKey: 'wallet',
    description: null,
    sortOrder: 0,
    allocationMethod: ExpenseAllocationMethod.fixed,
    allocationValue: 100,
    balance: balance,
    isSavingsReceiver: false,
  );
}
