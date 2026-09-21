import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/widgets/empty_state_view.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';
import 'package:finance/features/expenses/presentation/expense_screen.dart';

class _FakeExpenseControlRepository implements ExpenseControlRepository {
  _FakeExpenseControlRepository([List<ExpenseControlItem> initial = const []])
    : _items = List.of(initial);

  final List<ExpenseControlItem> _items;
  final _controller = StreamController<List<ExpenseControlItem>>.broadcast();
  var recordExpenseCallCount = 0;
  String? lastItemId;
  int? lastAmount;

  /// When set, [recordExpense] awaits this before resolving — lets a test
  /// simulate an in-flight save to assert double-tap prevention.
  Completer<void>? recordExpenseGate;

  Object? throwOnRecordExpense;

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

  @override
  Future<void> recordExpense({
    required String itemId,
    required int amount,
  }) async {
    recordExpenseCallCount++;
    lastItemId = itemId;
    lastAmount = amount;
    if (recordExpenseGate != null) await recordExpenseGate!.future;
    if (throwOnRecordExpense != null) throw throwOnRecordExpense!;
  }
}

ExpenseControlItem _leaf(
  String id, {
  String? parentId,
  String name = 'Item',
  int balance = 0,
}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: parentId,
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

Widget _harness(_FakeExpenseControlRepository repository) {
  return ProviderScope(
    overrides: [expenseControlRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const ExpenseScreen(),
    ),
  );
}

/// The keypad + item picker + preview banner together exceed the default
/// 800×600 test surface, pushing the item picker off-screen. Widened here
/// (torn down after each test) rather than shrinking the screen's own
/// layout to fit an artificial test constraint.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _tapKeypadDigits(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('expense-keypad-$digit')));
    await tester.pump();
  }
}

/// The preview banner renders via `RichText`/`TextSpan` (bolding only the
/// amount within one sentence), which `find.textContaining` cannot see —
/// that finder only matches plain `Text` widgets. This reads the banner's
/// full rendered string instead.
String _previewBannerText(WidgetTester tester) {
  final texts = tester
      .widgetList<RichText>(
        find.descendant(
          of: find.byKey(const ValueKey('expense-preview-banner')),
          matching: find.byType(RichText),
        ),
      )
      .map((r) => r.text.toPlainText());
  // The banner's own RichText carries the full sentence; any other
  // RichText found nested under the same key (e.g. a selection/semantics
  // proxy) renders a short/blank placeholder — picking the longest text
  // reliably selects the real one regardless of internal widget ordering.
  return texts.reduce((a, b) => a.length >= b.length ? a : b);
}

void main() {
  testWidgets(
    'entering an amount and picking a leaf item enables "Lưu giao dịch"; tapping it calls recordExpense and pops',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeExpenseControlRepository([
        _leaf('a', name: 'Ăn uống'),
      ]);
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
                        builder: (context) => const ExpenseScreen(),
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

      await _tapKeypadDigits(tester, '50000');
      await tester.tap(find.text('Ăn uống'));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tester.tap(find.text(l10n.expenseSaveAction));
      await tester.pumpAndSettle();

      expect(repository.recordExpenseCallCount, 1);
      expect(repository.lastItemId, 'a');
      expect(repository.lastAmount, 50000);
      expect(find.text('Open'), findsOneWidget);
    },
  );

  testWidgets(
    'a manual-entry save failure shows the friendly network-failure message, not raw exception text',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeExpenseControlRepository([
        _leaf('a', name: 'Ăn uống'),
      ])..throwOnRecordExpense = const SocketException('Connection refused');
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await _tapKeypadDigits(tester, '50000');
      await tester.tap(find.text('Ăn uống'));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tester.tap(find.text(l10n.expenseSaveAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.errorMapperNetworkFailure), findsOneWidget);
    },
  );

  testWidgets(
    'leaving the amount blank/zero blocks save with an inline message (FR-008 Scenario 3)',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Item'));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tester.tap(find.text(l10n.expenseSaveAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.expenseErrorInvalidAmount), findsOneWidget);
      expect(repository.recordExpenseCallCount, 0);
    },
  );

  testWidgets(
    'a valid amount with no item picked blocks save with an inline message identifying the missing pick (FR-008 Scenario 4)',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await _tapKeypadDigits(tester, '50000');

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      await tester.tap(find.text(l10n.expenseSaveAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.expenseErrorMissingItem), findsOneWidget);
      expect(repository.recordExpenseCallCount, 0);
    },
  );

  testWidgets(
    'only leaf items appear in the picker, group items never do (FR-011)',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeExpenseControlRepository([
        _leaf('group', name: 'Nhóm'),
        _leaf('child', parentId: 'group', name: 'Con'),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      // "Nhóm" is expected to appear once, as the parent-group subtitle
      // under the "Con" chip (per chi-tieu-spec.md's picker layout) — but
      // the picker offers exactly one tappable chip total (for the one
      // leaf "Con"), never a separate chip for the group itself (FR-011).
      expect(find.text('Con'), findsOneWidget);
      expect(find.text('Nhóm'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('expense-item-chip-child')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('expense-item-chip-group')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a brand-new user with zero leaf items sees the EmptyStateView instead of an empty scrollable list (Edge Cases)',
    (tester) async {
      final repository = _FakeExpenseControlRepository();
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
    },
  );

  testWidgets(
    'rapidly tapping "Lưu giao dịch" twice calls recordExpense at most once (Edge Cases, double-tap)',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeExpenseControlRepository([_leaf('a')])
        ..recordExpenseGate = Completer<void>();
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await _tapKeypadDigits(tester, '50000');
      await tester.tap(find.text('Item'));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      final saveButtonFinder = find.text(l10n.expenseSaveAction);
      await tester.tap(saveButtonFinder);
      await tester.pump();
      // Second tap while the first save is still in flight (button now
      // shows a progress indicator, no longer the text) — must be a no-op.
      await tester.tap(saveButtonFinder, warnIfMissed: false);
      await tester.pump();

      expect(repository.recordExpenseCallCount, 1);

      repository.recordExpenseGate!.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'entering digits via the keypad renders the amount display grouped/formatted, not raw unformatted digits (Edge Cases, live formatting)',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await _tapKeypadDigits(tester, '50000');

      expect(find.textContaining('50.000'), findsWidgets);
      expect(find.text('50000'), findsNothing);
    },
  );

  testWidgets(
    'entering an amount and picking an item, then navigating back without saving, calls recordExpense zero times (Edge Cases, navigate-away discards)',
    (tester) async {
      _useTallSurface(tester);
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await _tapKeypadDigits(tester, '50000');
      await tester.tap(find.text('Item'));
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await tester.pumpAndSettle();

      expect(repository.recordExpenseCallCount, 0);
    },
  );

  group('live preview banner (US2, FR-005–FR-007)', () {
    testWidgets(
      'with an item picked and a valid amount entered, the banner shows the item name and its balance minus the amount, using neutral styling when the result is >= 0',
      (tester) async {
        _useTallSurface(tester);
        final repository = _FakeExpenseControlRepository([
          _leaf('a', name: 'Ăn uống', balance: 200000),
        ]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        await _tapKeypadDigits(tester, '50000');
        await tester.tap(find.text('Ăn uống'));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('expense-preview-banner')),
          findsOneWidget,
        );
        final bannerText = _previewBannerText(tester);
        expect(bannerText, contains('Ăn uống'));
        expect(bannerText, contains('150.000'));

        final banner = tester.widget<Container>(
          find.byKey(const ValueKey('expense-preview-banner')),
        );
        final theme = AppTheme.light;
        expect(banner.decoration, isA<BoxDecoration>());
        final decoration = banner.decoration as BoxDecoration;
        // Must be AppSemanticColors.primarySoft, NOT
        // theme.colorScheme.primaryContainer — that Material 3 slot is
        // never set in AppTheme.light (app_theme.dart's own comment warns
        // it falls back to Flutter's default purple-gray seed), so it
        // renders visually indistinguishable from the primary-colored text
        // on top of it. Caught via manual emulator walkthrough (T025):
        // the banner text was literally invisible before this fix.
        expect(
          decoration.color,
          theme.extension<AppSemanticColors>()!.primarySoft,
        );
      },
    );

    testWidgets(
      'the banner uses danger styling when the resulting balance would be negative',
      (tester) async {
        _useTallSurface(tester);
        final repository = _FakeExpenseControlRepository([
          _leaf('a', name: 'Ăn uống', balance: 30000),
        ]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        await _tapKeypadDigits(tester, '50000');
        await tester.tap(find.text('Ăn uống'));
        await tester.pump();

        expect(_previewBannerText(tester), contains('-20.000'));

        final banner = tester.widget<Container>(
          find.byKey(const ValueKey('expense-preview-banner')),
        );
        final theme = AppTheme.light;
        final decoration = banner.decoration as BoxDecoration;
        expect(
          decoration.color,
          theme.extension<AppSemanticColors>()!.dangerSoft,
        );
      },
    );

    testWidgets(
      'changing the amount updates the banner immediately, without saving',
      (tester) async {
        _useTallSurface(tester);
        final repository = _FakeExpenseControlRepository([
          _leaf('a', name: 'Ăn uống', balance: 200000),
        ]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        await _tapKeypadDigits(tester, '50000');
        await tester.tap(find.text('Ăn uống'));
        await tester.pump();
        expect(_previewBannerText(tester), contains('150.000'));

        await _tapKeypadDigits(tester, '0');
        expect(_previewBannerText(tester), isNot(contains('150.000')));
        expect(_previewBannerText(tester), contains('-300.000'));
        expect(repository.recordExpenseCallCount, 0);
      },
    );

    testWidgets('changing the picked item updates the banner immediately', (
      tester,
    ) async {
      _useTallSurface(tester);
      final repository = _FakeExpenseControlRepository([
        _leaf('a', name: 'Ăn uống', balance: 200000),
        _leaf('b', name: 'Di chuyển', balance: 40000),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await _tapKeypadDigits(tester, '50000');
      await tester.tap(find.text('Ăn uống'));
      await tester.pump();
      expect(_previewBannerText(tester), contains('150.000'));

      await tester.tap(find.text('Di chuyển'));
      await tester.pump();
      expect(_previewBannerText(tester), isNot(contains('150.000')));
      expect(_previewBannerText(tester), contains('-10.000'));
    });

    testWidgets(
      'no banner is shown when the amount is blank/zero or no item is picked',
      (tester) async {
        _useTallSurface(tester);
        final repository = _FakeExpenseControlRepository([
          _leaf('a', name: 'Ăn uống', balance: 200000),
        ]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        // No amount, no item picked at all.
        expect(
          find.byKey(const ValueKey('expense-preview-banner')),
          findsNothing,
        );

        // Item picked, but amount still blank/zero.
        await tester.tap(find.text('Ăn uống'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('expense-preview-banner')),
          findsNothing,
        );
      },
    );
  });

  group('Quét hoá đơn tab (US3, scaffold only)', () {
    testWidgets(
      'tapping the tab replaces the manual-entry content with the camera-frame placeholder and capture button (Scenario 1)',
      (tester) async {
        _useTallSurface(tester);
        final repository = _FakeExpenseControlRepository([_leaf('a')]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text(l10n.expenseTabScan));
        await tester.pumpAndSettle();

        expect(find.text(l10n.expenseScanFrameHint), findsOneWidget);
        expect(find.text(l10n.expenseScanCaptureAction), findsOneWidget);
        expect(find.byKey(const ValueKey('expense-keypad-1')), findsNothing);
      },
    );

    testWidgets(
      'tapping "Chụp hoá đơn" shows the static mock recognized card, no real capture occurs (Scenario 2)',
      (tester) async {
        _useTallSurface(tester);
        final repository = _FakeExpenseControlRepository([_leaf('a')]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text(l10n.expenseTabScan));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.expenseScanCaptureAction));
        await tester.pumpAndSettle();

        expect(find.textContaining('450.000'), findsWidgets);
        expect(find.textContaining('Coopmart'), findsOneWidget);
        expect(find.text(l10n.expenseScanConfirmAction), findsOneWidget);
        expect(repository.recordExpenseCallCount, 0);
      },
    );

    testWidgets(
      'picking an item and tapping "Xác nhận & lưu" calls recordExpense with the mock amount and picked item id, never the merchant text (Scenario 3, Clarifications)',
      (tester) async {
        _useTallSurface(tester);
        final repository = _FakeExpenseControlRepository([
          _leaf('a', name: 'Ăn uống'),
        ]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text(l10n.expenseTabScan));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.expenseScanCaptureAction));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ăn uống'));
        await tester.pump();
        await tester.tap(find.text(l10n.expenseScanConfirmAction));
        await tester.pumpAndSettle();

        expect(repository.recordExpenseCallCount, 1);
        expect(repository.lastItemId, 'a');
        expect(repository.lastAmount, 450000);
      },
    );

    testWidgets(
      'a save failure shows the friendly network-failure message, not raw exception text',
      (tester) async {
        _useTallSurface(tester);
        final repository = _FakeExpenseControlRepository([
          _leaf('a', name: 'Ăn uống'),
        ])..throwOnRecordExpense = const SocketException('Connection refused');
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
        await tester.tap(find.text(l10n.expenseTabScan));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.expenseScanCaptureAction));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ăn uống'));
        await tester.pump();
        await tester.tap(find.text(l10n.expenseScanConfirmAction));
        await tester.pumpAndSettle();

        expect(find.text(l10n.errorMapperNetworkFailure), findsOneWidget);
      },
    );
  });
}
