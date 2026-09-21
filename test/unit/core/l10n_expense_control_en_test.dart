import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';

void main() {
  testWidgets('English ARB strings resolve for Expense Control (no raw keys)', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(l10n.tabExpenseControl, 'Control');
    expect(l10n.tabHistory, 'History');
    expect(l10n.tabSpending, 'My Wallet');
    expect(l10n.tabAccount, 'Profile');
    expect(l10n.expenseControlScreenTitle, 'Expense Control');
    expect(
      l10n.expenseControlEmptyStateMessage,
      isNot(contains('expenseControl')),
    );
    expect(l10n.expenseControlAddItemAction, 'Add new item');
    expect(l10n.expenseControlSaveFormulaAction, 'Save formula');
    expect(l10n.expenseControlOverBudgetError('105'), contains('105'));
    expect(l10n.allocationSummaryAllocatedLine('90', 1), contains('90'));
    expect(l10n.historyPlaceholderMessage, 'Coming soon.');
  });
}
