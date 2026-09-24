import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expenses/presentation/widgets/balance_item_row.dart';

void main() {
  testWidgets('renders a negative balance with a visible amount', (
    tester,
  ) async {
    final item = ExpenseControlItem(
      id: 'item',
      userId: 'user',
      parentId: 'group',
      name: 'Over budget',
      iconKey: 'wallet',
      description: null,
      sortOrder: 0,
      allocationMethod: null,
      allocationValue: null,
      balance: -500,
      isSavingsReceiver: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BalanceItemRow(item: item, currency: CurrencyFormatter('vi')),
        ),
      ),
    );

    expect(find.textContaining('500'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
