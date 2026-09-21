import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';
import 'package:finance/features/expenses/presentation/income_screen.dart';

class _FakeExpenseControlRepository implements ExpenseControlRepository {
  _FakeExpenseControlRepository([List<ExpenseControlItem> initial = const []])
    : _items = List.of(initial);

  final List<ExpenseControlItem> _items;
  final _controller = StreamController<List<ExpenseControlItem>>.broadcast();
  Map<String, int>? lastAppliedDeltas;

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
  Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas) async {
    lastAppliedDeltas = balanceDeltas;
  }
}

ExpenseControlItem _leaf(
  String id, {
  ExpenseAllocationMethod method = ExpenseAllocationMethod.percentage,
  double value = 20,
  String name = 'Item',
}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: null,
    name: name,
    iconKey: 'home',
    description: null,
    sortOrder: 0,
    allocationMethod: method,
    allocationValue: value,
    balance: 0,
    isSavingsReceiver: false,
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
      home: const IncomeScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'entering an income source displays it as the running total (FR-003)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('income-amount-0')),
        '10000000',
      );
      await tester.pump();

      expect(find.textContaining('10.000.000'), findsWidgets);
    },
  );

  testWidgets(
    'saving with a valid entry navigates back (contracts write-side step 4)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseControlRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const IncomeScreen(),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('income-amount-0')),
        '5000000',
      );
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tester.enterText(find.byType(TextFormField).first, 'Lương chính');
      await tester.tap(find.text(l10n.incomeSaveAction));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(repository.lastAppliedDeltas, isNotNull);
      expect(repository.lastAppliedDeltas!['a'], 1000000); // 20% of 5,000,000
    },
  );

  testWidgets(
    'the amount field reformats via the shared currency formatter once it loses focus (FR-016)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('income-amount-0')),
        '10000000',
      );
      await tester.pump();

      // While focused, the field still shows raw digits (no live-grouping
      // while typing, per research.md Decision 8).
      expect(find.text('10000000'), findsOneWidget);

      // Moving focus elsewhere blurs the amount field.
      await tester.tap(find.byType(TextFormField).first);
      await tester.pumpAndSettle();

      expect(find.text('10000000'), findsNothing);
      expect(find.textContaining('10.000.000'), findsWidgets);
    },
  );

  testWidgets(
    'blank/zero total blocks saving with an inline message and no navigation (FR-004, Scenario 5)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      // Removing the only row (FR-002: zero rows is a valid state) is the
      // one way a totally-empty row list can exist, isolating the "total
      // is 0/blank" failure from the (separately-tested) per-row failures.
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tester.tap(find.byIcon(LucideIcons.trash2));
      await tester.pump();

      await tester.tap(find.text(l10n.incomeSaveAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.incomeErrorInvalidTotal), findsOneWidget);
      expect(repository.lastAppliedDeltas, isNull);
    },
  );

  testWidgets(
    'zero leaf items shows a message directing the user to Kiểm soát chi tiêu (FR-018)',
    (tester) async {
      final repository = _FakeExpenseControlRepository();
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.incomeEmptyStateMessage), findsOneWidget);
    },
  );

  group('multiple income sources (US2)', () {
    testWidgets(
      'tapping "Thêm nguồn thu nhập khác" adds a new, empty income source row (Scenario 1)',
      (tester) async {
        final repository = _FakeExpenseControlRepository([_leaf('a')]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsNWidgets(2)); // name + amount

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text(l10n.incomeAddSourceAction));
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsNWidgets(4));
        expect(find.byKey(const ValueKey('income-amount-1')), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a row\'s delete icon removes it and the total recalculates to exclude it (Scenario 2)',
      (tester) async {
        final repository = _FakeExpenseControlRepository([_leaf('a')]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text(l10n.incomeAddSourceAction));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('income-amount-0')),
          '1000000',
        );
        await tester.enterText(
          find.byKey(const ValueKey('income-amount-1')),
          '2000000',
        );
        await tester.pump();
        expect(find.textContaining('3.000.000'), findsWidgets);

        await tester.tap(find.byIcon(LucideIcons.trash2).first);
        await tester.pump();

        expect(find.byKey(const ValueKey('income-amount-0')), findsNothing);
        expect(find.textContaining('2.000.000'), findsWidgets);
        expect(find.textContaining('3.000.000'), findsNothing);
      },
    );

    testWidgets(
      'leaving one row\'s name blank while its amount is filled blocks saving with a message identifying that row (Scenario 3)',
      (tester) async {
        final repository = _FakeExpenseControlRepository([_leaf('a')]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('income-amount-0')),
          '1000000',
        );
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text(l10n.incomeSaveAction));
        await tester.pumpAndSettle();

        expect(find.text(l10n.incomeErrorMissingRowName), findsOneWidget);
        expect(repository.lastAppliedDeltas, isNull);
      },
    );
  });
}
