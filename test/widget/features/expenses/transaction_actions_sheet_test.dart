import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/transaction_correction_repository.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/presentation/transaction_actions_sheet.dart';

import '../../../support/correction_fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 9, 10);
  final record = TransactionHistoryRecord(
    id: 'expense-1',
    sourceItemId: 'food',
    direction: TransactionHistoryDirection.expense,
    amount: 25000,
    occurredAt: now.subtract(const Duration(hours: 1)),
    displayName: 'Groceries',
    displayGroupName: 'Living',
    displayIconKey: 'basket',
  );

  Widget opener(TransactionHistoryRecord record) {
    return Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showTransactionActions(context, record),
            child: const Text('Open transaction'),
          ),
        ),
      ),
    );
  }

  testWidgets('shows transaction details and confirms a recent deletion', (
    tester,
  ) async {
    final repository = FakeTransactionCorrectionRepository()
      ..deletePreview = const CorrectionPreview(
        amount: 25000,
        items: [
          CorrectionPreviewItem(
            itemId: 'food',
            itemName: 'Groceries',
            balanceAfter: 75000,
            itemRemoved: false,
          ),
        ],
      );
    await correctionHarness(
      tester,
      child: opener(record),
      correctionRepository: repository,
      historyRepository: const FakeCorrectionHistoryRepository(),
      now: now,
    );

    await tester.tap(find.text('Open transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Living'), findsOneWidget);
    expect(find.text('-25.000 ₫'), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    await tester.tap(find.text(l10n.correctionActionDelete));
    await tester.pumpAndSettle();
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
    expect(find.text(l10n.correctionDeleteTitle), findsOneWidget);
    expect(
      find.text(l10n.correctionBalanceLine('Groceries', '75.000 ₫')),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.correctionActionDelete).last);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, hasLength(1));
    expect(repository.deleteCalls.single.transactionId, record.id);
    expect(find.text(l10n.correctionDoneDeleted), findsOneWidget);
  });

  testWidgets('negative preview warns but does not disable confirmation', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = FakeTransactionCorrectionRepository()
      ..deleteGate = gate
      ..deletePreview = const CorrectionPreview(
        amount: 25000,
        items: [
          CorrectionPreviewItem(
            itemId: 'food',
            itemName: 'Groceries',
            balanceAfter: -1000,
            itemRemoved: false,
          ),
        ],
      );
    await correctionHarness(
      tester,
      child: opener(record),
      correctionRepository: repository,
      historyRepository: const FakeCorrectionHistoryRepository(),
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    await tester.tap(find.text('Open transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.correctionActionDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.correctionNegativeBalanceWarning), findsOneWidget);

    await tester.tap(find.text(l10n.correctionActionDelete).last);
    await tester.pump();
    expect(
      tester.widgetList<FilledButton>(find.byType(FilledButton)).last.onPressed,
      isNull,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.correctionDoneDeleted), findsOneWidget);
  });

  testWidgets('edits an expense through the action sheet', (tester) async {
    final repository = FakeTransactionCorrectionRepository();
    await correctionHarness(
      tester,
      child: opener(record),
      correctionRepository: repository,
      historyRepository: const FakeCorrectionHistoryRepository(),
      items: [
        ExpenseControlItem(
          id: 'food',
          userId: 'u1',
          parentId: null,
          name: 'Groceries',
          iconKey: 'basket',
          description: null,
          sortOrder: 0,
          allocationMethod: ExpenseAllocationMethod.percentage,
          allocationValue: 10,
          balance: 100000,
          isSavingsReceiver: false,
        ),
      ],
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    await tester.tap(find.text('Open transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.correctionActionEdit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '20000');
    await tester.tap(find.text(l10n.correctionEditSave));
    await tester.pumpAndSettle();

    expect(repository.editCalls, hasLength(1));
    expect(repository.editCalls.single.amount, 20000);
    expect(find.text(l10n.correctionDoneEdited), findsOneWidget);
  });

  testWidgets('deletes an entire income event and previews every share', (
    tester,
  ) async {
    final income = TransactionHistoryRecord(
      id: 'income-1',
      sourceItemId: 'food',
      direction: TransactionHistoryDirection.income,
      amount: 40000,
      occurredAt: now.subtract(const Duration(hours: 1)),
      displayName: 'Groceries',
      displayGroupName: 'Living',
      displayIconKey: 'basket',
    );
    final repository = FakeTransactionCorrectionRepository()
      ..deletePreview = const CorrectionPreview(
        amount: 100000,
        items: [
          CorrectionPreviewItem(
            itemId: 'food',
            itemName: 'Groceries',
            balanceAfter: 120000,
            itemRemoved: false,
          ),
          CorrectionPreviewItem(
            itemId: 'rent',
            itemName: 'Rent',
            balanceAfter: 350000,
            itemRemoved: false,
          ),
          CorrectionPreviewItem(
            itemId: 'archived',
            itemName: 'Archived',
            balanceAfter: 0,
            itemRemoved: true,
          ),
        ],
      );
    await correctionHarness(
      tester,
      child: opener(income),
      correctionRepository: repository,
      historyRepository: const FakeCorrectionHistoryRepository(),
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    await tester.tap(find.text('Open transaction'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.correctionActionEdit), findsNothing);
    expect(find.text(l10n.correctionActionDelete), findsOneWidget);
    await tester.tap(find.text(l10n.correctionActionDelete));
    await tester.pumpAndSettle();

    expect(find.text(l10n.correctionIncomeEventNote(3)), findsOneWidget);
    expect(
      find.text(l10n.correctionBalanceLine('Groceries', '120.000 ₫')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.correctionBalanceLine('Rent', '350.000 ₫')),
      findsOneWidget,
    );
    expect(find.text(l10n.correctionItemRemovedNote), findsOneWidget);

    await tester.tap(find.text(l10n.correctionActionDelete).last);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, hasLength(1));
    expect(repository.deleteCalls.single.transactionId, income.id);
  });

  testWidgets('reverses an entire income event and previews every share', (
    tester,
  ) async {
    final income = TransactionHistoryRecord(
      id: 'old-income-1',
      sourceItemId: 'food',
      direction: TransactionHistoryDirection.income,
      amount: 40000,
      occurredAt: now.subtract(const Duration(hours: 25)),
      displayName: 'Groceries',
      displayGroupName: 'Living',
      displayIconKey: 'basket',
    );
    final repository = FakeTransactionCorrectionRepository()
      ..reversePreview = const CorrectionPreview(
        amount: 100000,
        items: [
          CorrectionPreviewItem(
            itemId: 'food',
            itemName: 'Groceries',
            balanceAfter: 20000,
            itemRemoved: false,
          ),
          CorrectionPreviewItem(
            itemId: 'rent',
            itemName: 'Rent',
            balanceAfter: -50000,
            itemRemoved: false,
          ),
        ],
      );
    await correctionHarness(
      tester,
      child: opener(income),
      correctionRepository: repository,
      historyRepository: const FakeCorrectionHistoryRepository(),
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    await tester.tap(find.text('Open transaction'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.correctionActionEdit), findsNothing);
    expect(find.text(l10n.correctionActionDelete), findsNothing);
    await tester.tap(find.text(l10n.correctionActionReverse));
    await tester.pumpAndSettle();

    expect(find.text(l10n.correctionIncomeEventNote(2)), findsOneWidget);
    expect(
      find.text(l10n.correctionBalanceLine('Groceries', '20.000 ₫')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.correctionBalanceLine('Rent', '-50.000 ₫')),
      findsOneWidget,
    );
    expect(find.text(l10n.correctionNegativeBalanceWarning), findsOneWidget);
    await tester.tap(find.text(l10n.correctionActionReverse).last);
    await tester.pumpAndSettle();
    expect(repository.reverseCalls, hasLength(1));
    expect(repository.reverseCalls.single.transactionId, income.id);
  });

  testWidgets('reverses a past transaction after showing its preview', (
    tester,
  ) async {
    final oldRecord = TransactionHistoryRecord(
      id: 'old-expense',
      sourceItemId: 'food',
      direction: TransactionHistoryDirection.expense,
      amount: 25000,
      occurredAt: now.subtract(const Duration(hours: 25)),
      displayName: 'Groceries',
      displayGroupName: 'Living',
      displayIconKey: 'basket',
    );
    final repository = FakeTransactionCorrectionRepository()
      ..reversePreview = const CorrectionPreview(
        amount: 25000,
        items: [
          CorrectionPreviewItem(
            itemId: 'food',
            itemName: 'Groceries',
            balanceAfter: -1000,
            itemRemoved: false,
          ),
        ],
      );
    await correctionHarness(
      tester,
      child: opener(oldRecord),
      correctionRepository: repository,
      historyRepository: const FakeCorrectionHistoryRepository(),
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    await tester.tap(find.text('Open transaction'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.correctionActionEdit), findsNothing);
    expect(find.text(l10n.correctionActionDelete), findsNothing);
    await tester.tap(find.text(l10n.correctionActionReverse));
    await tester.pumpAndSettle();
    expect(find.text(l10n.correctionReverseTitle), findsOneWidget);
    expect(find.text(l10n.correctionNegativeBalanceWarning), findsOneWidget);

    await tester.tap(find.text(l10n.correctionActionReverse).last);
    await tester.pumpAndSettle();

    expect(repository.reverseCalls, hasLength(1));
    expect(repository.reverseCalls.single.transactionId, oldRecord.id);
    expect(find.text(l10n.correctionDoneReversed), findsOneWidget);
  });

  testWidgets('opens the linked reversal from the original transaction', (
    tester,
  ) async {
    final original = TransactionHistoryRecord(
      id: 'original',
      sourceItemId: 'food',
      direction: TransactionHistoryDirection.expense,
      amount: 25000,
      occurredAt: now.subtract(const Duration(hours: 30)),
      displayName: 'Groceries',
      displayGroupName: 'Living',
      displayIconKey: 'basket',
      isReversed: true,
      reversedById: 'reversal',
    );
    final reversal = TransactionHistoryRecord(
      id: 'reversal',
      sourceItemId: 'food',
      direction: TransactionHistoryDirection.expense,
      amount: 25000,
      occurredAt: now.subtract(const Duration(hours: 1)),
      displayName: 'Groceries',
      displayGroupName: 'Living',
      displayIconKey: 'basket',
      reversesId: 'original',
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    await correctionHarness(
      tester,
      child: opener(original),
      correctionRepository: FakeTransactionCorrectionRepository(),
      historyRepository: FakeCorrectionHistoryRepository([original, reversal]),
      now: now,
    );

    await tester.tap(find.text('Open transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.correctionSheetReversedTag));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.correctionSheetReversalOf('Groceries')),
      findsOneWidget,
    );
    expect(find.text('+25.000 ₫'), findsOneWidget);
  });

  testWidgets('a past-window transaction shows details without delete action', (
    tester,
  ) async {
    final oldRecord = TransactionHistoryRecord(
      id: 'old-expense',
      sourceItemId: 'food',
      direction: TransactionHistoryDirection.expense,
      amount: 25000,
      occurredAt: now.subtract(const Duration(hours: 25)),
      displayName: 'Groceries',
      displayGroupName: 'Living',
      displayIconKey: 'basket',
    );
    await correctionHarness(
      tester,
      child: opener(oldRecord),
      correctionRepository: FakeTransactionCorrectionRepository(),
      historyRepository: const FakeCorrectionHistoryRepository(),
      now: now,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    await tester.tap(find.text('Open transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text(l10n.correctionActionDelete), findsNothing);
    expect(find.text(l10n.correctionActionReverse), findsOneWidget);
  });
}
