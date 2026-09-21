import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';
import 'package:finance/features/expenses/presentation/spending_screen.dart';
import 'package:finance/features/expenses/presentation/widgets/balance_group_card.dart';

class _FakeExpenseControlRepository implements ExpenseControlRepository {
  _FakeExpenseControlRepository([List<ExpenseControlItem> initial = const []])
    : _items = List.of(initial);

  final List<ExpenseControlItem> _items;
  final _controller = StreamController<List<ExpenseControlItem>>.broadcast();

  void emit(List<ExpenseControlItem> items) {
    _items
      ..clear()
      ..addAll(items);
    _controller.add(List.of(_items));
  }

  @override
  Stream<List<ExpenseControlItem>> watchAll() {
    Future.microtask(() => _controller.add(List.of(_items)));
    return _controller.stream;
  }

  @override
  Future<List<ExpenseControlItem>> getAll() async => List.of(_items);

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
}

ExpenseControlItem _leaf(
  String id, {
  String? parentId,
  int balance = 0,
  String name = 'Item',
  bool isSavingsReceiver = false,
}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: parentId,
    name: name,
    iconKey: 'home',
    description: null,
    sortOrder: 0,
    allocationMethod: parentId == null
        ? ExpenseAllocationMethod.percentage
        : null,
    allocationValue: parentId == null ? 20 : null,
    balance: balance,
    isSavingsReceiver: isSavingsReceiver,
  );
}

Widget _harness(_FakeExpenseControlRepository repository) {
  return ProviderScope(
    overrides: [expenseControlRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SpendingScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'every top-level item/group renders with a formatted balance (FR-001, FR-003)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('rent', balance: 5150000, name: 'Rent'),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.text('Rent'), findsOneWidget);
      expect(find.textContaining('5.150.000'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a group row expands it to show children, tapping again collapses (FR-002)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('family', name: 'Family'),
        _leaf(
          'groceries',
          parentId: 'family',
          balance: 100000,
          name: 'Groceries',
        ),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      // Starts expanded by default.
      expect(find.text('Groceries'), findsOneWidget);

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(find.text('Groceries'), findsNothing);

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(find.text('Groceries'), findsOneWidget);
    },
  );

  testWidgets(
    'a childless group renders with no chevron and cannot be expanded (Edge Case)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('solo', name: 'Solo'),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final card = find.byType(BalanceGroupCard);
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(LucideIcons.chevronDown),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(LucideIcons.chevronRight),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a positive balance renders in the informational (primary blue) color, a negative balance in the danger color with a minus sign (FR-004)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('positive', balance: 100000, name: 'Positive'),
        _leaf('negative', balance: -50000, name: 'Negative'),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.textContaining('-50.000'), findsOneWidget);

      final theme = AppTheme.light;
      final positiveText = tester.widget<Text>(find.textContaining('100.000'));
      final negativeText = tester.widget<Text>(find.textContaining('-50.000'));
      expect(positiveText.style?.color, theme.colorScheme.primary);
      expect(negativeText.style?.color, theme.colorScheme.error);
    },
  );

  testWidgets(
    'the tree updates live when the underlying stream emits a changed item list (FR-012)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('a', name: 'Alpha'),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);

      repository.emit([_leaf('a', name: 'Alpha'), _leaf('b', name: 'Beta')]);
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsOneWidget);
    },
  );

  testWidgets(
    'with zero items, an empty-state message directs the user to Kiểm soát chi tiêu (FR-010)',
    (tester) async {
      final repository = _FakeExpenseControlRepository();
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.spendingBalanceEmptyState), findsOneWidget);
    },
  );

  testWidgets(
    'a newly-added leaf item appears automatically with a balance of 0 (FR-011a)',
    (tester) async {
      final repository = _FakeExpenseControlRepository();
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      repository.emit([_leaf('new', balance: 0, name: 'New Item')]);
      await tester.pumpAndSettle();

      expect(find.text('New Item'), findsOneWidget);
      expect(find.textContaining('0'), findsWidgets);
    },
  );

  testWidgets(
    'the balance-list section is labeled with actual-balance wording, not formula wording (FR-006, US2 Scenario 1)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(
        find.text(l10n.spendingBalanceListLabel.toUpperCase()),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'no formula-editing control (percentage/fixed toggle) appears anywhere (FR-005, US2 Scenario 2)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('family', name: 'Family'),
        _leaf('child', parentId: 'family', name: 'Child'),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(BalanceGroupCard), findsWidgets);
    },
  );

  testWidgets(
    'Chi tiêu button and the history row each navigate to a distinct placeholder (FR-007, FR-008, FR-009, US3)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

      expect(find.text(l10n.spendingIncomeAction), findsOneWidget);
      expect(find.text(l10n.spendingExpenseAction), findsOneWidget);
      expect(find.text(l10n.spendingHistoryAction), findsOneWidget);

      await tester.tap(find.text(l10n.spendingExpenseAction));
      await tester.pumpAndSettle();
      expect(find.byType(NotAvailablePlaceholderScreen), findsOneWidget);
      expect(find.text(l10n.expensePlaceholderTitle), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.spendingHistoryAction));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.transactionHistoryPlaceholderTitle),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Thu nhập button navigates to the real income-entry screen, not a placeholder (FR-017)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));

      await tester.tap(find.text(l10n.spendingIncomeAction));
      await tester.pumpAndSettle();

      expect(find.byType(NotAvailablePlaceholderScreen), findsNothing);
      expect(find.text(l10n.incomeScreenTitle), findsOneWidget);
    },
  );
}
