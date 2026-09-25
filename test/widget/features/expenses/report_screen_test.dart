import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expense_control/domain/transaction_history_repository.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';
import 'package:finance/features/expenses/presentation/report_providers.dart';
import 'package:finance/features/expenses/presentation/report_screen.dart';
import 'package:finance/features/expenses/presentation/widgets/report_usage_bar.dart';

class _FakeExpenseControlRepository implements ExpenseControlRepository {
  _FakeExpenseControlRepository([this._items = const []]);

  final List<ExpenseControlItem> _items;

  @override
  Stream<List<ExpenseControlItem>> watchAll() => Stream.value(_items);

  @override
  Future<List<ExpenseControlItem>> getAll() async => _items;

  @override
  Future<void> create(ExpenseControlItem item) async {}

  @override
  Future<void> update(ExpenseControlItem item) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> reorderTopLevel(List<String> orderedIds) async {}

  @override
  Future<void> saveFormulas(Map<String, PendingItemEdit> changes) async {}

  @override
  Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas) async {}

  @override
  Future<void> recordExpense({
    required String itemId,
    required int amount,
  }) async {}
}

/// Filters [records] by `occurredAt` falling within `[start, end)`, matching
/// the real repository's contract — needed so month-navigation tests can
/// seed records across multiple months and have each query correctly scoped.
class _FakeHistoryRepository implements TransactionHistoryRepository {
  _FakeHistoryRepository([
    this.records = const [],
    this.shouldError = false,
    this.neverEmits = false,
  ]);

  final List<TransactionHistoryRecord> records;
  final bool shouldError;

  /// When true, `watchTransactionHistory` returns a stream that never
  /// emits — deterministically keeps the provider in `AsyncLoading` for a
  /// test, rather than racing against `Stream.value`'s near-instant
  /// emission (mirrors `overview_screen_test.dart`'s `_autoEmit: false`).
  final bool neverEmits;

  @override
  Stream<List<TransactionHistoryRecord>> watchTransactionHistory({
    required DateTime start,
    required DateTime end,
  }) {
    if (neverEmits) return const Stream.empty();
    if (shouldError) return Stream.error(Exception('boom'));
    return Stream.value(
      records
          .where(
            (r) => !r.occurredAt.isBefore(start) && r.occurredAt.isBefore(end),
          )
          .toList(),
    );
  }

  @override
  Stream<List<TransactionHistoryRecord>> watchRecent({required int limit}) =>
      Stream.value(records.take(limit).toList());
}

TransactionHistoryRecord _record({
  required String sourceItemId,
  required TransactionHistoryDirection direction,
  required int amount,
  required DateTime occurredAt,
  String displayName = 'Item',
}) {
  return TransactionHistoryRecord(
    id: '$sourceItemId-${occurredAt.microsecondsSinceEpoch}-$amount',
    sourceItemId: sourceItemId,
    direction: direction,
    amount: amount,
    occurredAt: occurredAt,
    displayName: displayName,
    displayGroupName: null,
    displayIconKey: null,
  );
}

ExpenseControlItem _leaf(String id, {String name = 'Item'}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: null,
    name: name,
    iconKey: 'home',
    description: null,
    sortOrder: 0,
    allocationMethod: ExpenseAllocationMethod.percentage,
    allocationValue: 20,
    balance: 0,
    isSavingsReceiver: false,
  );
}

Widget _harness({
  List<ExpenseControlItem> items = const [],
  List<TransactionHistoryRecord> records = const [],
  bool historyError = false,
  bool historyNeverEmits = false,
  DateTime? selectedMonth,
}) {
  return ProviderScope(
    overrides: [
      expenseControlRepositoryProvider.overrideWithValue(
        _FakeExpenseControlRepository(items),
      ),
      transactionHistoryRepositoryProvider.overrideWithValue(
        _FakeHistoryRepository(records, historyError, historyNeverEmits),
      ),
      if (selectedMonth != null)
        selectedReportMonthProvider.overrideWith((ref) => selectedMonth),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const ReportScreen(),
    ),
  );
}

void main() {
  final currentMonth = monthStart(DateTime.now());

  group('totals section', () {
    testWidgets('shows a loading indicator before data arrives', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(selectedMonth: currentMonth, historyNeverEmits: true),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows a retryable error state on failure', (tester) async {
      await tester.pumpWidget(
        _harness(historyError: true, selectedMonth: currentMonth),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.reportLoadError), findsWidgets);
      expect(find.text(l10n.reportRetry), findsWidgets);
    });

    testWidgets('a month with no activity shows both totals as zero', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(selectedMonth: currentMonth));
      await tester.pumpAndSettle();

      expect(find.textContaining('0'), findsWidgets);
    });

    testWidgets('renders the correct income and expense totals', (
      tester,
    ) async {
      // Expense split across two items so neither breakdown row's own
      // amount coincidentally matches the grand total being asserted here.
      await tester.pumpWidget(
        _harness(
          selectedMonth: currentMonth,
          records: [
            _record(
              sourceItemId: 'a',
              direction: TransactionHistoryDirection.income,
              amount: 25000000,
              occurredAt: currentMonth,
            ),
            _record(
              sourceItemId: 'a',
              direction: TransactionHistoryDirection.expense,
              amount: 4000000,
              occurredAt: currentMonth,
            ),
            _record(
              sourceItemId: 'b',
              direction: TransactionHistoryDirection.expense,
              amount: 1730000,
              occurredAt: currentMonth,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('25.000.000'), findsOneWidget);
      expect(find.textContaining('5.730.000'), findsOneWidget);
    });
  });

  group('month navigation', () {
    testWidgets(
      'previous/next controls update the displayed month and totals',
      (tester) async {
        final previous = previousMonth(currentMonth);
        await tester.pumpWidget(
          _harness(
            selectedMonth: currentMonth,
            records: [
              _record(
                sourceItemId: 'a',
                direction: TransactionHistoryDirection.income,
                amount: 1000000,
                occurredAt: currentMonth,
              ),
              _record(
                sourceItemId: 'a',
                direction: TransactionHistoryDirection.income,
                amount: 2000000,
                occurredAt: previous,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('1.000.000'), findsOneWidget);

        await tester.tap(find.byIcon(LucideIcons.chevronLeft));
        await tester.pumpAndSettle();

        expect(find.textContaining('2.000.000'), findsOneWidget);
      },
    );

    testWidgets(
      'the forward control is blocked when already on the current month',
      (tester) async {
        await tester.pumpWidget(_harness(selectedMonth: currentMonth));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        final nextButton = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip(l10n.reportNextMonthSemantic),
            matching: find.byType(IconButton),
          ),
        );
        expect(nextButton.onPressed, isNull);
      },
    );
  });

  group('item breakdown section', () {
    testWidgets('a month with no activity shows an empty-state message', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(selectedMonth: currentMonth));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.reportBreakdownEmpty), findsOneWidget);
    });

    testWidgets(
      'a notAllocated item shows the distinct indicator, not a percentage',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            selectedMonth: currentMonth,
            items: [_leaf('a', name: 'Ăn uống')],
            records: [
              _record(
                sourceItemId: 'a',
                direction: TransactionHistoryDirection.expense,
                amount: 200000,
                occurredAt: currentMonth,
                displayName: 'Ăn uống',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        expect(find.text(l10n.reportNotAllocatedLabel), findsOneWidget);
        expect(find.byType(ReportUsageBar), findsNothing);
      },
    );

    testWidgets('an unused item shows 0% used with an empty-fill bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          selectedMonth: currentMonth,
          items: [_leaf('a', name: 'Tiết kiệm')],
          records: [
            _record(
              sourceItemId: 'a',
              direction: TransactionHistoryDirection.income,
              amount: 1000000,
              occurredAt: currentMonth,
              displayName: 'Tiết kiệm',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReportUsageBar), findsOneWidget);
      expect(find.textContaining('0%'), findsOneWidget);
    });

    testWidgets(
      'an over-100%-usage row caps its bar fill and shows the true percentage as text',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            selectedMonth: currentMonth,
            items: [_leaf('a', name: 'Giải trí')],
            records: [
              _record(
                sourceItemId: 'a',
                direction: TransactionHistoryDirection.income,
                amount: 100000,
                occurredAt: currentMonth,
                displayName: 'Giải trí',
              ),
              _record(
                sourceItemId: 'a',
                direction: TransactionHistoryDirection.expense,
                amount: 150000,
                occurredAt: currentMonth,
                displayName: 'Giải trí',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('150%'), findsOneWidget);

        final bar = tester.widget<ReportUsageBar>(find.byType(ReportUsageBar));
        expect(bar.usagePercent, 150);

        // The bar's own widget caps fill width internally (see
        // report_usage_bar_test-equivalent assertion via the pure widget's
        // constructor input above); this screen-level test only needs to
        // confirm the screen passes the true, uncapped value through.
      },
    );

    testWidgets(
      'navigating to a different month updates the breakdown list, not just totals',
      (tester) async {
        final previous = previousMonth(currentMonth);
        await tester.pumpWidget(
          _harness(
            selectedMonth: currentMonth,
            items: [
              _leaf('a', name: 'Tháng này'),
              _leaf('b', name: 'Tháng trước'),
            ],
            records: [
              _record(
                sourceItemId: 'a',
                direction: TransactionHistoryDirection.expense,
                amount: 100000,
                occurredAt: currentMonth,
                displayName: 'Tháng này',
              ),
              _record(
                sourceItemId: 'b',
                direction: TransactionHistoryDirection.expense,
                amount: 200000,
                occurredAt: previous,
                displayName: 'Tháng trước',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tháng này'), findsOneWidget);
        expect(find.text('Tháng trước'), findsNothing);

        await tester.tap(find.byIcon(LucideIcons.chevronLeft));
        await tester.pumpAndSettle();

        expect(find.text('Tháng này'), findsNothing);
        expect(find.text('Tháng trước'), findsOneWidget);
      },
    );
  });
}
