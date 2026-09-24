import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expense_control/domain/transaction_history_repository.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';
import 'package:finance/features/expenses/presentation/overview_providers.dart';
import 'package:finance/features/expenses/presentation/overview_screen.dart';
import 'package:finance/features/expenses/presentation/transaction_history_providers.dart';
import 'package:finance/features/expenses/presentation/transaction_history_screen.dart';

class _FakeAccountAuthActions implements AccountAuthActions {
  _FakeAccountAuthActions({this.displayName, this.email});

  final String? displayName;
  final String? email;

  @override
  String? get currentDisplayName => displayName;

  @override
  String? get currentEmail => email;

  @override
  String? get currentAvatarUrl => null;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {}

  @override
  Future<bool> isBiometricLoginEnabled() async => false;

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {}
}

class _FakeExpenseControlRepository implements ExpenseControlRepository {
  _FakeExpenseControlRepository([
    List<ExpenseControlItem> initial = const [],
    this._autoEmit = true,
  ]) : _items = List.of(initial);

  final List<ExpenseControlItem> _items;
  final _controller = StreamController<List<ExpenseControlItem>>.broadcast();
  bool _shouldError = false;
  final bool _autoEmit;

  void emit(List<ExpenseControlItem> items) {
    _items
      ..clear()
      ..addAll(items);
    _controller.add(List.of(_items));
  }

  void emitError() {
    _shouldError = true;
    _controller.addError(Exception('boom'));
  }

  @override
  Stream<List<ExpenseControlItem>> watchAll() {
    if (!_autoEmit) return _controller.stream;
    Future.microtask(() {
      if (_shouldError) {
        _controller.addError(Exception('boom'));
      } else {
        _controller.add(List.of(_items));
      }
    });
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

  @override
  Future<void> recordExpense({
    required String itemId,
    required int amount,
  }) async {}
}

class _FakeHistoryRepository implements TransactionHistoryRepository {
  const _FakeHistoryRepository([this.records = const []]);

  final List<TransactionHistoryRecord> records;

  @override
  Stream<List<TransactionHistoryRecord>> watchTransactionHistory({
    required DateTime start,
    required DateTime end,
  }) {
    return Stream.value(records);
  }

  @override
  Stream<List<TransactionHistoryRecord>> watchRecent({required int limit}) {
    return Stream.value(records.take(limit).toList());
  }
}

ExpenseControlItem _leaf(String id, {int balance = 0, String name = 'Item'}) {
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
    balance: balance,
    isSavingsReceiver: false,
  );
}

Widget _harness(
  _FakeExpenseControlRepository repository, {
  _FakeHistoryRepository? historyRepository,
  AccountAuthActions? authActions,
}) {
  return ProviderScope(
    overrides: [
      expenseControlRepositoryProvider.overrideWithValue(repository),
      transactionHistoryRepositoryProvider.overrideWithValue(
        historyRepository ?? const _FakeHistoryRepository(),
      ),
      overviewAuthActionsProvider.overrideWithValue(
        authActions ?? _FakeAccountAuthActions(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const OverviewScreen(),
    ),
  );
}

void main() {
  group('total balance card', () {
    testWidgets('shows a loading indicator before data arrives', (
      tester,
    ) async {
      // autoEmit: false — the stream never emits during this test, so the
      // provider deterministically stays in AsyncLoading rather than racing
      // against a microtask-scheduled emission.
      final repository = _FakeExpenseControlRepository([_leaf('a')], false);
      await tester.pumpWidget(_harness(repository));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('renders both the compact and full amount once loaded', (
      tester,
    ) async {
      // Two differently-valued accounts, so the total (12,400,000) is
      // distinct from either individual account card's own balance —
      // otherwise a single-account total would coincidentally match its
      // own card's text too, making the assertion ambiguous.
      final repository = _FakeExpenseControlRepository([
        _leaf('a', balance: 9400000),
        _leaf('b', balance: 3000000),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.textContaining('12,4 triệu'), findsOneWidget);
      expect(find.textContaining('12.400.000'), findsOneWidget);
    });

    testWidgets('renders "0 ₫" when there are no accounts', (tester) async {
      final repository = _FakeExpenseControlRepository();
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final zero = CurrencyFormatter('vi').format(0);
      expect(find.text(zero), findsWidgets);
    });

    testWidgets(
      'shows a retryable error state, and retry reloads successfully',
      (tester) async {
        final repository = _FakeExpenseControlRepository([_leaf('a')]);
        repository._shouldError = true;
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        expect(find.text(l10n.overviewLoadError), findsOneWidget);

        repository._shouldError = false;
        await tester.tap(find.text(l10n.overviewRetry));
        await tester.pumpAndSettle();

        expect(find.text(l10n.overviewLoadError), findsNothing);
      },
    );
  });

  testWidgets(
    'has no floating action button or other mutation entry point (FR-013, read-only)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  group('negative-balance banner', () {
    testWidgets('is hidden when no account is negative', (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('a', balance: 100),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.overviewSeeDetailAction), findsNothing);
    });

    testWidgets('is shown and names the negative account', (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('a', balance: -50000, name: 'Điện, nước, rác'),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(
        find.text(l10n.overviewNegativeBalanceWarning('Điện, nước, rác')),
        findsOneWidget,
      );
      expect(find.text(l10n.overviewSeeDetailAction), findsOneWidget);
    });

    testWidgets(
      '"Xem chi tiết →" opens transaction history filtered to that account\'s group',
      (tester) async {
        final repository = _FakeExpenseControlRepository([
          _leaf('a', balance: -50000, name: 'Điện, nước, rác'),
        ]);
        final historyRecord = TransactionHistoryRecord(
          id: 't1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 50000,
          occurredAt: DateTime.now(),
          displayName: 'Tiền điện',
          displayGroupName: 'Điện, nước, rác',
          displayIconKey: 'home',
        );
        await tester.pumpWidget(
          _harness(
            repository,
            historyRepository: _FakeHistoryRepository([historyRecord]),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text(l10n.overviewSeeDetailAction));
        await tester.pumpAndSettle();

        expect(find.byType(TransactionHistoryScreen), findsOneWidget);
        expect(find.text('Tiền điện'), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(TransactionHistoryScreen)),
        );
        expect(
          container.read(selectedTransactionHistoryFilterProvider),
          const TransactionHistoryFilter.group('Điện, nước, rác'),
        );
      },
    );
  });

  group('accounts section', () {
    testWidgets('lists every top-level account with a formatted balance', (
      tester,
    ) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('a', balance: 5150000, name: 'Gia đình'),
        _leaf('b', balance: 1100000, name: 'Cá nhân'),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.text('Gia đình'), findsOneWidget);
      expect(find.textContaining('5.150.000'), findsOneWidget);
      expect(find.text('Cá nhân'), findsOneWidget);
      expect(find.textContaining('1.100.000'), findsOneWidget);
    });

    testWidgets(
      'a negative account balance renders in the danger color, a positive one does not',
      (tester) async {
        final repository = _FakeExpenseControlRepository([
          _leaf('a', balance: -20000, name: 'Negative'),
          _leaf('b', balance: 20000, name: 'Positive'),
        ]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        final theme = AppTheme.light;
        final negativeText = tester.widget<Text>(
          find.textContaining('-20.000'),
        );
        final positiveText = tester.widget<Text>(
          find.textContaining('20.000').last,
        );
        expect(negativeText.style?.color, theme.colorScheme.error);
        expect(positiveText.style?.color, isNot(theme.colorScheme.error));
      },
    );

    testWidgets('shows an empty state when there are no accounts', (
      tester,
    ) async {
      final repository = _FakeExpenseControlRepository();
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.overviewAccountsEmpty), findsOneWidget);
    });

    testWidgets('"Xem tất cả" navigates to the Kế hoạch tab', (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseControlRepositoryProvider.overrideWithValue(repository),
            transactionHistoryRepositoryProvider.overrideWithValue(
              const _FakeHistoryRepository(),
            ),
            overviewAuthActionsProvider.overrideWithValue(
              _FakeAccountAuthActions(),
            ),
            currentUserIdProvider.overrideWithValue('u1'),
            authStateChangesProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
            isSignedInProvider.overrideWithValue(true),
            isPasswordRecoveryProvider.overrideWithValue(false),
          ],
          child: Builder(
            builder: (context) {
              return MaterialApp.router(
                theme: AppTheme.light,
                locale: const Locale('vi'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                routerConfig: GoRouter(
                  initialLocation: '/overview',
                  routes: [
                    GoRoute(
                      path: '/overview',
                      builder: (context, state) => const OverviewScreen(),
                    ),
                    GoRoute(
                      path: '/expense-control',
                      builder: (context, state) =>
                          const Scaffold(body: Text('Kế hoạch screen')),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tester.tap(find.text(l10n.overviewSeeAllAction).first);
      await tester.pumpAndSettle();

      expect(find.text('Kế hoạch screen'), findsOneWidget);
    });
  });

  group('recent-transactions section', () {
    testWidgets('shows rows with relative time and a signed, colored amount', (
      tester,
    ) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      final now = DateTime.now();
      final records = [
        TransactionHistoryRecord(
          id: 't1',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.expense,
          amount: 450000,
          occurredAt: now,
          displayName: 'Siêu thị Coopmart',
          displayGroupName: 'Ăn uống',
          displayIconKey: 'utensils',
        ),
        TransactionHistoryRecord(
          id: 't2',
          sourceItemId: 'a',
          direction: TransactionHistoryDirection.income,
          amount: 25000000,
          occurredAt: now.subtract(const Duration(days: 3)),
          displayName: 'Lương tháng 6',
          displayGroupName: null,
          displayIconKey: 'wallet',
        ),
      ];
      await tester.pumpWidget(
        _harness(
          repository,
          historyRepository: _FakeHistoryRepository(records),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text('Siêu thị Coopmart'), findsOneWidget);
      expect(find.textContaining(l10n.overviewToday), findsOneWidget);
      expect(find.text('Lương tháng 6'), findsOneWidget);
      expect(find.textContaining(l10n.overviewDaysAgo(3)), findsOneWidget);

      final theme = AppTheme.light;
      final expenseText = tester.widget<Text>(find.textContaining('-450.000'));
      final incomeText = tester.widget<Text>(find.textContaining('25.000.000'));
      expect(expenseText.style?.color, theme.colorScheme.error);
      expect(incomeText.style?.color, theme.colorScheme.primary);
    });

    testWidgets('shows an empty state when there are no transactions', (
      tester,
    ) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.overviewTransactionsEmpty), findsOneWidget);
    });

    testWidgets(
      '"Xem tất cả" pushes an unfiltered transaction-history screen',
      (tester) async {
        final repository = _FakeExpenseControlRepository([_leaf('a')]);
        final records = [
          TransactionHistoryRecord(
            id: 't1',
            sourceItemId: 'a',
            direction: TransactionHistoryDirection.expense,
            amount: 1000,
            occurredAt: DateTime.now(),
            displayName: 'Some expense',
            displayGroupName: 'Group',
            displayIconKey: 'home',
          ),
        ];
        await tester.pumpWidget(
          _harness(
            repository,
            historyRepository: _FakeHistoryRepository(records),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text(l10n.overviewSeeAllAction).last);
        await tester.pumpAndSettle();

        expect(find.byType(TransactionHistoryScreen), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TransactionHistoryScreen)),
        );
        expect(
          container.read(selectedTransactionHistoryFilterProvider),
          const TransactionHistoryFilter.all(),
        );
      },
    );
  });

  group('header', () {
    testWidgets('greets the user by their display name when set', (
      tester,
    ) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(
        _harness(
          repository,
          authActions: _FakeAccountAuthActions(displayName: 'Lan'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Lan'), findsOneWidget);
    });

    testWidgets('falls back to the email prefix when no display name is set', (
      tester,
    ) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(
        _harness(
          repository,
          authActions: _FakeAccountAuthActions(email: 'lan.nguyen@example.com'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('lan.nguyen'), findsOneWidget);
    });

    testWidgets('the bell button opens the "not available yet" placeholder', (
      tester,
    ) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.bell));
      await tester.pumpAndSettle();

      expect(find.byType(NotAvailablePlaceholderScreen), findsOneWidget);
    });

    testWidgets(
      'the notification button meets the ≥48dp touch-target minimum (research.md Decision 7)',
      (tester) async {
        final repository = _FakeExpenseControlRepository([_leaf('a')]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        final size = tester.getSize(find.byType(IconButton));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      },
    );
  });

  group(
    'SC-004: renders correctly for every accounts × transactions combination',
    () {
      for (final hasAccounts in [true, false]) {
        for (final hasTransactions in [true, false]) {
          testWidgets('accounts=$hasAccounts, transactions=$hasTransactions', (
            tester,
          ) async {
            final repository = _FakeExpenseControlRepository(
              hasAccounts ? [_leaf('a', balance: 1000)] : const [],
            );
            final records = hasTransactions
                ? [
                    TransactionHistoryRecord(
                      id: 't1',
                      sourceItemId: 'a',
                      direction: TransactionHistoryDirection.expense,
                      amount: 500,
                      occurredAt: DateTime.now(),
                      displayName: 'Item',
                      displayGroupName: 'Group',
                      displayIconKey: 'home',
                    ),
                  ]
                : const <TransactionHistoryRecord>[];

            // No crash and no exception is the assertion itself (SC-004);
            // takeException below makes any thrown error fail the test.
            await tester.pumpWidget(
              _harness(
                repository,
                historyRepository: _FakeHistoryRepository(records),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
          });
        }
      }
    },
  );

  testWidgets('renders without error under the dark theme (FR-011)', (
    tester,
  ) async {
    final repository = _FakeExpenseControlRepository([_leaf('a')]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseControlRepositoryProvider.overrideWithValue(repository),
          transactionHistoryRepositoryProvider.overrideWithValue(
            const _FakeHistoryRepository(),
          ),
          overviewAuthActionsProvider.overrideWithValue(
            _FakeAccountAuthActions(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const OverviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(OverviewScreen), findsOneWidget);
  });
}
