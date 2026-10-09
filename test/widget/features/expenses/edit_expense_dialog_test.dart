import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/presentation/edit_expense_dialog.dart';

import '../../../support/correction_fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 9, 10);
  final record = TransactionHistoryRecord(
    id: 'expense',
    sourceItemId: 'food',
    direction: TransactionHistoryDirection.expense,
    amount: 250,
    occurredAt: now.subtract(const Duration(hours: 1)),
    displayName: 'Old name',
    displayGroupName: 'Old group',
    displayIconKey: 'home',
  );
  final items = [
    _leaf('food', 'Groceries', 750),
    _leaf('travel', 'Transit', 500),
  ];

  Widget opener() => Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => EditExpenseDialog(record: record, items: items),
          ),
          child: const Text('Edit expense'),
        ),
      ),
    ),
  );

  testWidgets('shows the amount, leaf chooser and balance previews', (
    tester,
  ) async {
    final repository = FakeTransactionCorrectionRepository();
    await correctionHarness(
      tester,
      child: opener(),
      correctionRepository: repository,
      historyRepository: const FakeCorrectionHistoryRepository(),
      items: items,
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    await tester.tap(find.text('Edit expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '500');
    await tester.pumpAndSettle();

    expect(find.text(l10n.correctionEditTitle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DropdownButtonFormField<String>),
        matching: find.text('Groceries'),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.correctionEditItemLabel), findsOneWidget);
    expect(find.text(l10n.correctionEditBalanceTitle), findsOneWidget);
    expect(find.text('750 ₫'), findsOneWidget);
    expect(find.text('500 ₫'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .height,
      lessThan(600),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      TextInputType.number,
    );
  });

  testWidgets('saves the changed amount and chosen item once', (tester) async {
    final repository = FakeTransactionCorrectionRepository();
    await correctionHarness(
      tester,
      child: opener(),
      correctionRepository: repository,
      historyRepository: const FakeCorrectionHistoryRepository(),
      items: items,
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    await tester.tap(find.text('Edit expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.correctionEditSave));
    await tester.pumpAndSettle();

    expect(repository.editCalls, hasLength(1));
    expect(repository.editCalls.single.transactionId, record.id);
    expect(repository.editCalls.single.amount, 500);
    expect(repository.editCalls.single.itemId, 'travel');
    expect(repository.editCalls.single.now, now);
  });

  testWidgets('empty or zero amount disables save and shows validation', (
    tester,
  ) async {
    await correctionHarness(
      tester,
      child: opener(),
      correctionRepository: FakeTransactionCorrectionRepository(),
      historyRepository: const FakeCorrectionHistoryRepository(),
      items: items,
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    await tester.tap(find.text('Edit expense'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0');
    await tester.pumpAndSettle();
    expect(find.text(l10n.correctionErrorAmount), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text(l10n.correctionEditSave),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });
}

ExpenseControlItem _leaf(String id, String name, int balance) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: null,
    name: name,
    iconKey: 'home',
    description: null,
    sortOrder: 0,
    allocationMethod: ExpenseAllocationMethod.percentage,
    allocationValue: 10,
    balance: balance,
    isSavingsReceiver: false,
  );
}
