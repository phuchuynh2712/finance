import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/l10n/locale_notifier.dart';
import 'package:finance/core/router/app_router.dart';
import 'package:finance/core/storage/app_preferences_storage.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/theme/theme_mode_notifier.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expense_control/domain/transaction_history_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';
import 'package:finance/features/expenses/presentation/overview_providers.dart';
import 'package:finance/features/expenses/presentation/overview_screen.dart';
import 'package:finance/features/expenses/presentation/report_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// FR-016–FR-018, SC-006 — visual correctness of the shared bottom
/// [NavigationBar], verified via the real [_AppShell] (through
/// [appRouterProvider], the only way to reach it — see
/// app_shell_discard_prompt_test.dart's header comment for why this needs a
/// fully rendered shell rather than a decision-only unit test).
class _FakeExpenseControlRepository implements ExpenseControlRepository {
  @override
  Stream<List<ExpenseControlItem>> watchAll() => Stream.value(const []);

  @override
  Future<List<ExpenseControlItem>> getAll() async => [];

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

class _FakeAccountAuthActions implements AccountAuthActions {
  @override
  String? get currentDisplayName => null;

  @override
  String? get currentEmail => null;

  @override
  String? get currentAvatarUrl => null;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {}

  @override
  Future<bool> isBiometricLoginEnabled() async => false;

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {}
}

class _FakeTransactionHistoryRepository
    implements TransactionHistoryRepository {
  @override
  Stream<List<TransactionHistoryRecord>> watchTransactionHistory({
    required DateTime start,
    required DateTime end,
  }) => Stream.value(const []);

  @override
  Stream<List<TransactionHistoryRecord>> watchRecent({required int limit}) =>
      Stream.value(const []);
}

class _FakeAppPreferencesStorage implements AppPreferencesStorage {
  @override
  Future<ThemeMode?> getThemeMode() async => null;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  Future<Locale?> getLocale() async => null;

  @override
  Future<void> setLocale(Locale locale) async {}
}

Widget _harness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: container.read(appRouterProvider),
    ),
  );
}

ProviderContainer _container({List<Override> extra = const []}) {
  return ProviderContainer(
    overrides: [
      ...extra,
      authStateChangesProvider.overrideWith((ref) => const Stream.empty()),
      isSignedInProvider.overrideWithValue(true),
      isPasswordRecoveryProvider.overrideWithValue(false),
      currentUserIdProvider.overrideWithValue('u1'),
      expenseControlRepositoryProvider.overrideWithValue(
        _FakeExpenseControlRepository(),
      ),
      accountAuthActionsProvider.overrideWithValue(_FakeAccountAuthActions()),
      overviewAuthActionsProvider.overrideWithValue(_FakeAccountAuthActions()),
      transactionHistoryRepositoryProvider.overrideWithValue(
        _FakeTransactionHistoryRepository(),
      ),
      themeModeProvider.overrideWith(
        (ref) =>
            ThemeModeNotifier(_FakeAppPreferencesStorage(), ThemeMode.system),
      ),
      localeProvider.overrideWith(
        (ref) =>
            LocaleNotifier(_FakeAppPreferencesStorage(), const Locale('vi')),
      ),
    ],
  );
}

const _tabLabels = ['Tổng quan', 'Kế hoạch', 'Thu chi', 'Báo cáo', 'Hồ sơ'];

void main() {
  testWidgets(
    'selection is indicated by icon/label color alone, with no pill background, and a top border separates the bar from content above (FR-013, FR-014, FR-018)',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(NavigationBar));
      final theme = Theme.of(context);

      expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);

      final selectedIcon = theme.navigationBarTheme.iconTheme!.resolve({
        WidgetState.selected,
      })!;
      final unselectedIcon = theme.navigationBarTheme.iconTheme!.resolve({});
      expect(selectedIcon.color, theme.colorScheme.primary);
      expect(unselectedIcon!.color, theme.colorScheme.onSurfaceVariant);

      final selectedLabel = theme.navigationBarTheme.labelTextStyle!.resolve({
        WidgetState.selected,
      })!;
      final unselectedLabel = theme.navigationBarTheme.labelTextStyle!.resolve(
        {},
      );
      expect(selectedLabel.color, theme.colorScheme.primary);
      expect(unselectedLabel!.color, theme.colorScheme.onSurfaceVariant);

      // T027 names its top-border wrapper with this key so the test
      // doesn't have to guess which widget/decoration shape implements it.
      final borderBox = tester.widget<DecoratedBox>(
        find.byKey(const Key('bottomNavTopBorder')),
      );
      final decoration = borderBox.decoration as BoxDecoration;
      final semantic = theme.extension<AppSemanticColors>()!;
      expect(decoration.border?.top.color, semantic.border1);
    },
  );

  testWidgets(
    'switching tabs moves the selected color without leaving a residual indicator shape (FR-013, SC-005)',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      for (final label in _tabLabels) {
        if (label != _tabLabels.first) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
        }

        final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        final context = tester.element(find.byType(NavigationBar));
        final theme = Theme.of(context);
        expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);
        expect(navBar.selectedIndex, _tabLabels.indexOf(label));
      }
    },
  );

  // FR-017/SC-006 originally required every destination label to render on
  // a single line. adaptive-layout-foundation's compact-width test default
  // (the app's own 410-logical-pixel design reference — flutter_test's
  // prior unpinned 800px default had silently masked this) found that
  // requirement unachievable for "Tổng quan" (the longest label) at any
  // realistic phone width without shrinking every label to ~8sp — smaller
  // than is reasonable to read. Product decision: FR-017/SC-006 is relaxed
  // to allow a label to wrap onto two lines; NavigationBar's own default
  // layout already accommodates this within its fixed height without
  // clipping or overflowing (confirmed empirically), so no widget change
  // was needed — only this test's expectation.
  for (var i = 0; i < _tabLabels.length; i++) {
    final label = _tabLabels[i];
    testWidgets(
      'on the "$label" tab, every destination label renders fully — no overflow, no truncation, wrapping onto a second line is acceptable (FR-017/SC-006, relaxed by adaptive-layout-foundation)',
      (tester) async {
        final container = _container();
        addTearDown(container.dispose);
        await tester.pumpWidget(_harness(container));
        await tester.pumpAndSettle();

        if (i != 0) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
        }

        // No RenderFlex overflow, no clipping exception, etc.
        expect(tester.takeException(), isNull);

        for (final l in _tabLabels) {
          // Every label's full text is present and un-ellipsized — Text
          // itself would render a "…" glyph if it had been truncated.
          final textWidget = tester.widget<Text>(find.text(l).last);
          expect(textWidget.data, l);
          expect(textWidget.overflow, isNot(TextOverflow.ellipsis));
        }
      },
    );
  }

  testWidgets(
    'the fourth destination ("Báo cáo") uses the pie-chart icon, not the old history icon (FR-001)',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      final fourthDestination = navBar.destinations[3] as NavigationDestination;
      final fourthIcon = fourthDestination.icon as Icon;
      expect(fourthIcon.icon, LucideIcons.pieChart);
      expect(fourthIcon.icon, isNot(LucideIcons.history));
    },
  );

  testWidgets(
    'the Báo cáo tab\'s selected month survives switching to a different tab '
    'and back (research.md Decision 3 — requires the real StatefulShellRoute '
    'shell, since a bare ReportScreen in isolation has no second tab to '
    'switch to and cannot exercise IndexedStack\'s mount-preservation at all)',
    (tester) async {
      final pastMonth = DateTime(2026, 3);
      final container = _container(
        extra: [selectedReportMonthProvider.overrideWith((ref) => pastMonth)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Báo cáo').last);
      await tester.pumpAndSettle();
      expect(container.read(selectedReportMonthProvider), pastMonth);

      // Switch away, then back.
      await tester.tap(find.text('Hồ sơ').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Báo cáo').last);
      await tester.pumpAndSettle();

      expect(container.read(selectedReportMonthProvider), pastMonth);
    },
  );

  // --- adaptive-layout-foundation (User Story 1) ---

  testWidgets(
    'at a compact window width, navigation is still a bottom NavigationBar, not a rail (regression)',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      // The pinned compact default from flutter_test_config.dart already
      // applies; set it explicitly anyway so this test's intent reads
      // clearly on its own.
      tester.view.physicalSize = const Size(410, 864);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    },
  );

  testWidgets(
    'at an expanded window width (>=600dp), navigation is a rail with every destination'
    " icon+label always visible, at the correct selected index (Clarification Q1, FR-001)",
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(900, 864);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 0);
      expect(rail.labelType, NavigationRailLabelType.all);
      for (final label in _tabLabels) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('Hồ sơ').last);
      await tester.pumpAndSettle();
      final railAfterTap = tester.widget<NavigationRail>(
        find.byType(NavigationRail),
      );
      expect(railAfterTap.selectedIndex, _tabLabels.indexOf('Hồ sơ'));
    },
  );

  testWidgets(
    'the currently-viewed screen is reparented, not disposed and recreated,'
    ' when the window crosses the compact/expanded breakpoint'
    ' (Clarification Q2, research.md Decision 2)',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(410, 864);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      final elementBefore = tester.element(find.byType(OverviewScreen));

      // Cross the 600dp threshold in the other direction.
      tester.view.physicalSize = const Size(900, 864);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);

      final elementAfter = tester.element(find.byType(OverviewScreen));
      expect(
        identical(elementBefore, elementAfter),
        isTrue,
        reason:
            'OverviewScreen was disposed and recreated across the '
            'breakpoint crossing instead of being reparented — this is '
            'exactly what the GlobalKey on navigationShell exists to '
            'prevent, since a fresh Element means any local widget state '
            "(scroll position, an in-progress text field) would have "
            'been lost too.',
      );
    },
  );
}
