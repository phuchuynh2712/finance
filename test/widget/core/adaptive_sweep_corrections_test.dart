import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/transaction_correction_repository.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/presentation/edit_expense_dialog.dart';
import 'package:finance/features/expenses/presentation/transaction_actions_sheet.dart';

import '../../support/adaptive_sweep.dart';
import '../../support/correction_fixtures.dart';
import '../../support/load_app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  final now = DateTime(2026, 10, 9, 12);
  final expense = TransactionHistoryRecord(
    id: 'recent-expense',
    sourceItemId: 'food',
    direction: TransactionHistoryDirection.expense,
    amount: 250,
    occurredAt: now.subtract(const Duration(hours: 1)),
    displayName: 'Groceries',
    displayGroupName: 'Living',
    displayIconKey: 'basket',
  );
  final income = TransactionHistoryRecord(
    id: 'income-share',
    sourceItemId: 'food',
    direction: TransactionHistoryDirection.income,
    amount: 500,
    occurredAt: now.subtract(const Duration(hours: 1)),
    displayName: 'Salary',
    displayGroupName: 'Income',
    displayIconKey: 'banknote',
  );
  final item = ExpenseControlItem(
    id: 'food',
    userId: 'u1',
    parentId: null,
    name: 'Groceries',
    iconKey: 'basket',
    description: null,
    sortOrder: 0,
    allocationMethod: ExpenseAllocationMethod.percentage,
    allocationValue: 10,
    balance: 1000,
    isSavingsReceiver: false,
  );

  Widget appFor(
    Widget child,
    SweepCase c, {
    List<ExpenseControlItem> items = const [],
    FakeTransactionCorrectionRepository? repository,
  }) {
    return ProviderScope(
      overrides: [
        transactionCorrectionRepositoryProvider.overrideWithValue(
          repository ?? FakeTransactionCorrectionRepository(),
        ),
        expenseControlRepositoryProvider.overrideWithValue(
          FakeCorrectionExpenseControlRepository(items, const []),
        ),
        correctionNowProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        theme: c.theme,
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(c.textScale)),
          child: app!,
        ),
        home: child,
      ),
    );
  }

  Widget opener(TransactionHistoryRecord record) => Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          onPressed: () => showTransactionActions(context, record),
          child: const Text('Open transaction'),
        ),
      ),
    ),
  );

  group('transaction actions sheet — recent expense', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await pumpSweepCase(
          tester,
          c,
          (_) => opener(expense),
          wrap: (app) => appFor(app, c, items: [item]),
          rail: false,
        );
        await tester.tap(find.text('Open transaction'));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        expect(find.text(l10n.correctionActionEdit), findsOneWidget);
        expect(find.text(l10n.correctionActionDelete), findsOneWidget);
        final sheetSize = tester.getSize(find.byType(TransactionActionsSheet));
        expect(sheetSize.width, lessThanOrEqualTo(c.width));
        expect(
          tester
              .getSize(
                find.ancestor(
                  of: find.text(l10n.correctionActionEdit),
                  matching: find.byType(FilledButton),
                ),
              )
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester
              .getSize(
                find.ancestor(
                  of: find.text(l10n.correctionActionDelete),
                  matching: find.byType(FilledButton),
                ),
              )
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('income confirmation — event note and deletion preview', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        final repository = FakeTransactionCorrectionRepository()
          ..deletePreview = const CorrectionPreview(
            amount: 500,
            items: [
              CorrectionPreviewItem(
                itemId: 'food',
                itemName: 'Groceries',
                balanceAfter: 500,
                itemRemoved: false,
              ),
            ],
          );
        await pumpSweepCase(
          tester,
          c,
          (_) => opener(income),
          wrap: (app) => appFor(app, c, repository: repository),
          rail: false,
        );
        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text('Open transaction'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.correctionActionEdit), findsNothing);
        await tester.tap(find.text(l10n.correctionActionDelete));
        await tester.pumpAndSettle();

        expect(find.text(l10n.correctionIncomeEventNote(1)), findsOneWidget);
        expect(
          find.text(l10n.correctionBalanceLine('Groceries', '500 ₫')),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byType(FilledButton).last).height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('edit expense dialog', () {
    for (final c in sweepCases) {
      testWidgets(c.name, (tester) async {
        await pumpSweepCase(
          tester,
          c,
          (_) => Scaffold(
            body: Center(
              child: EditExpenseDialog(record: expense, items: [item]),
            ),
          ),
          wrap: (app) => appFor(app, c, items: [item]),
          rail: false,
        );

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        expect(find.text(l10n.correctionEditTitle), findsOneWidget);
        expect(find.text(l10n.correctionEditSave), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          tester.getSize(find.byType(AlertDialog)).width,
          lessThanOrEqualTo(c.width),
        );
        final saveButton = tester
            .widgetList<FilledButton>(find.byType(FilledButton))
            .last;
        expect(
          saveButton.style?.minimumSize?.resolve({})?.height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
