import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/presentation/report_providers.dart';
import 'package:finance/features/expenses/presentation/report_screen.dart';

import '../../../support/expense_control_fixtures.dart';
import '../../../support/history_fixtures.dart';
import '../../../support/pull_complete_override.dart';

void main() {
  final month = DateTime(2026, 10);
  final records = [
    _record(
      id: 'expense',
      direction: TransactionHistoryDirection.expense,
      amount: 500,
      occurredAt: DateTime(2026, 10, 2),
    ),
    _record(
      id: 'refund',
      direction: TransactionHistoryDirection.expense,
      amount: 200,
      occurredAt: DateTime(2026, 10, 3),
      reversesId: 'expense',
    ),
    _record(
      id: 'income',
      direction: TransactionHistoryDirection.income,
      amount: 1000,
      occurredAt: DateTime(2026, 10, 4),
    ),
    _record(
      id: 'withdrawal',
      direction: TransactionHistoryDirection.income,
      amount: 300,
      occurredAt: DateTime(2026, 10, 5),
      reversesId: 'income',
    ),
  ];

  Future<void> pumpReport(
    WidgetTester tester, {
    required Locale locale,
    required List<TransactionHistoryRecord> history,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseControlRepositoryProvider.overrideWithValue(
            FakeExpenseControlRepository(),
          ),
          transactionHistoryRepositoryProvider.overrideWithValue(
            FakeHistoryRepository(history),
          ),
          selectedReportMonthProvider.overrideWith((ref) => month),
          pullCompleteOverride,
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ReportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in const [Locale('vi'), Locale('en')]) {
    testWidgets(
      'shows positive monthly reversal totals in ${locale.languageCode}',
      (tester) async {
        await pumpReport(tester, locale: locale, history: records);
        final l10n = await AppLocalizations.delegate.load(locale);
        final semantic = AppTheme.light.extension<AppSemanticColors>()!;
        final currency = CurrencyFormatter(locale.toString());

        expect(find.text(l10n.reportRefundedExpense), findsOneWidget);
        expect(find.text(l10n.reportWithdrawnIncome), findsOneWidget);
        expect(find.text(currency.format(200)), findsOneWidget);
        expect(find.text(currency.format(300)), findsOneWidget);
        expect(find.textContaining('-200'), findsNothing);
        expect(
          tester
              .widget<Text>(find.text(l10n.reportRefundedExpense))
              .style
              ?.color,
          semantic.fg2,
        );
      },
    );
  }

  testWidgets('hides both reversal totals when they are zero', (tester) async {
    await pumpReport(tester, locale: const Locale('vi'), history: const []);
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

    expect(find.text(l10n.reportRefundedExpense), findsNothing);
    expect(find.text(l10n.reportWithdrawnIncome), findsNothing);
  });
}

TransactionHistoryRecord _record({
  required String id,
  required TransactionHistoryDirection direction,
  required int amount,
  required DateTime occurredAt,
  String? reversesId,
}) {
  return TransactionHistoryRecord(
    id: id,
    sourceItemId: 'food',
    direction: direction,
    amount: amount,
    occurredAt: occurredAt,
    displayName: 'Groceries',
    displayGroupName: 'Living',
    displayIconKey: 'basket',
    reversesId: reversesId,
  );
}
