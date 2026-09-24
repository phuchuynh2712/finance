import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expense_control/domain/transaction_history_repository.dart';
import 'package:finance/features/expenses/presentation/transaction_history_screen.dart';

void main() {
  testWidgets(
    'shows current-month rows, expense-only total, and Income filter',
    (tester) async {
      final now = DateTime.now();
      final records = [
        _record(
          'Coffee',
          TransactionHistoryDirection.expense,
          25000,
          now,
          group: 'Food',
        ),
        _record('Salary', TransactionHistoryDirection.income, 1000000, now),
      ];
      await tester.pumpWidget(_harness(records));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(
        find.text(l10n.transactionHistoryExpenseTotal('25.000 ₫')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('transaction-history-filter-income')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsNothing);
      expect(find.text('Salary'), findsOneWidget);
    },
  );

  testWidgets(
    'shows an empty state when the selected previous month has no transactions',
    (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        _harness([
          _record(
            'Coffee',
            TransactionHistoryDirection.expense,
            25000,
            now,
            group: 'Food',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tester.tap(
        find.byKey(const ValueKey('transaction-history-previous-month')),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.transactionHistoryEmpty), findsOneWidget);
    },
  );
}

Widget _harness(List<TransactionHistoryRecord> records) {
  return ProviderScope(
    overrides: [
      transactionHistoryRepositoryProvider.overrideWithValue(
        _HistoryRepository(records),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const TransactionHistoryScreen(),
    ),
  );
}

TransactionHistoryRecord _record(
  String name,
  TransactionHistoryDirection direction,
  int amount,
  DateTime occurredAt, {
  String? group,
}) {
  return TransactionHistoryRecord(
    id: name,
    sourceItemId: name,
    direction: direction,
    amount: amount,
    occurredAt: occurredAt,
    displayName: name,
    displayGroupName: group,
    displayIconKey: 'home',
  );
}

class _HistoryRepository implements TransactionHistoryRepository {
  const _HistoryRepository(this.records);

  final List<TransactionHistoryRecord> records;

  @override
  Stream<List<TransactionHistoryRecord>> watchTransactionHistory({
    required DateTime start,
    required DateTime end,
  }) {
    return Stream.value(
      records
          .where(
            (record) =>
                !record.occurredAt.isBefore(start) &&
                record.occurredAt.isBefore(end),
          )
          .toList(),
    );
  }

  @override
  Stream<List<TransactionHistoryRecord>> watchRecent({required int limit}) {
    return Stream.value(records.take(limit).toList());
  }
}
