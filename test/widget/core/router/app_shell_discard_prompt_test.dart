import 'dart:async';

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
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/theme/theme_mode_notifier.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';

/// FR-009–FR-012, spec.md US3 — renders the *real* [_AppShell] (via
/// [appRouterProvider], since `_AppShell` is private to app_router.dart and
/// only reachable through the shell route it builds) with every
/// non-Supabase leaf provider overridden by a fake, and auth/lock state
/// overridden directly (narrower than faking a full Supabase `AuthState`).
/// This is the only way to verify the actual tap → dialog → navigate chain,
/// not just its decision logic in isolation.
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

class _FakeExpenseControlRepository implements ExpenseControlRepository {
  _FakeExpenseControlRepository(List<ExpenseControlItem> initial)
    : _items = List.of(initial);

  final List<ExpenseControlItem> _items;
  final _controller = StreamController<List<ExpenseControlItem>>.broadcast();
  final List<Map<String, PendingItemEdit>> savedFormulaBatches = [];

  void _emit() => _controller.add(List.of(_items));

  @override
  Stream<List<ExpenseControlItem>> watchAll() {
    Future.microtask(_emit);
    return _controller.stream;
  }

  @override
  Future<List<ExpenseControlItem>> getAll() async => List.of(_items);

  @override
  Future<void> create(ExpenseControlItem item) async {
    _items.add(item);
    _emit();
  }

  @override
  Future<void> update(ExpenseControlItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) _items[index] = item;
    _emit();
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> reorderTopLevel(List<String> orderedIds) async {}

  @override
  Future<void> saveFormulas(Map<String, PendingItemEdit> changes) async {
    savedFormulaBatches.add(changes);
    for (final entry in changes.entries) {
      final index = _items.indexWhere((item) => item.id == entry.key);
      if (index != -1) {
        _items[index] = _items[index].copyWith(
          allocationMethod: entry.value.method,
          allocationValue: entry.value.value,
        );
      }
    }
    _emit();
  }

  @override
  Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas) async {}

  @override
  Future<void> recordExpense({
    required String itemId,
    required int amount,
  }) async {}
}

ExpenseControlItem _leaf(String id, {double value = 10}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: null,
    name: id,
    iconKey: 'home',
    description: null,
    sortOrder: 0,
    allocationMethod: ExpenseAllocationMethod.percentage,
    allocationValue: value,
    balance: 0,
    isSavingsReceiver: false,
  );
}

Widget _harness({
  required _FakeExpenseControlRepository expenseControlRepository,
  required ProviderContainer container,
}) {
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

ProviderContainer _containerFor(
  _FakeExpenseControlRepository expenseControlRepository,
) {
  return ProviderContainer(
    overrides: [
      // Avoids constructing a real Supabase AuthState — AppLockNotifier
      // (behind appLockProvider) only reacts to stream events and never
      // resolves `signed in` on an empty stream, so `state` stays `false`
      // (unlocked) without needing to fake it directly.
      authStateChangesProvider.overrideWith((ref) => const Stream.empty()),
      isSignedInProvider.overrideWithValue(true),
      isPasswordRecoveryProvider.overrideWithValue(false),
      currentUserIdProvider.overrideWithValue('u1'),
      accountAuthActionsProvider.overrideWithValue(_FakeAccountAuthActions()),
      expenseControlRepositoryProvider.overrideWithValue(
        expenseControlRepository,
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

/// Pumps the shell (starting on Tổng quan, per `initialLocation`), navigates
/// into Kiểm soát, then optionally seeds a pending edit — the shared
/// preamble every test below needs before it can exercise the tab-switch
/// interception, since that only fires while *on* Kiểm soát.
Future<void> _arriveOnExpenseControl(
  WidgetTester tester, {
  required _FakeExpenseControlRepository repository,
  required ProviderContainer container,
  bool seedPendingEdit = true,
}) async {
  await tester.pumpWidget(
    _harness(expenseControlRepository: repository, container: container),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Kiểm soát').last);
  await tester.pumpAndSettle();

  if (seedPendingEdit) {
    container.read(pendingItemEditsProvider.notifier).state = {
      'a': const PendingItemEdit(value: 50),
    };
    await tester.pump();
  }
}

/// [StatefulShellRoute.indexedStack] keeps every branch mounted, so
/// `find.text(...)` for another branch's content can't distinguish "we
/// navigated there" from "it was mounted-but-hidden all along." The
/// `NavigationBar`'s `selectedIndex` (bound to
/// `navigationShell.currentIndex`, the actual value `goBranch` updates) is
/// the discriminating signal for whether navigation actually happened.
int _selectedTabIndex(WidgetTester tester) {
  return tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;
}

void main() {
  testWidgets(
    'with staged edits present, switching tabs shows the three-button prompt and does not navigate immediately (FR-009, SC-003, Scenario 1)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      final container = _containerFor(repository);
      addTearDown(container.dispose);
      await _arriveOnExpenseControl(
        tester,
        repository: repository,
        container: container,
      );

      await tester.tap(find.text('Tổng quan').last);
      await tester.pumpAndSettle();

      expect(find.text('Lưu thay đổi?'), findsOneWidget);
      // Still on Kiểm soát — navigation hasn't happened.
      expect(find.text('Lưu công thức'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping "Lưu" persists staged edits then navigates (FR-010, Scenario 2)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      final container = _containerFor(repository);
      addTearDown(container.dispose);
      await _arriveOnExpenseControl(
        tester,
        repository: repository,
        container: container,
      );

      await tester.tap(find.text('Tổng quan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(repository._items.single.allocationValue, 50);
      expect(repository.savedFormulaBatches, hasLength(1));
      expect(container.read(pendingItemEditsProvider), isEmpty);
      // Navigation proceeded — the shell's selected index moved off
      // Kiểm soát (index 1) to Tổng quan (index 0). `find.text('Lưu công
      // thức')` alone can't prove this: IndexedStack keeps every branch
      // mounted, so the button's absence could equally mean "still on
      // Kiểm soát, but the (now-empty) map just hides the button."
      expect(_selectedTabIndex(tester), 0);
    },
  );

  testWidgets(
    'tapping "Không lưu" clears the map without persisting then navigates immediately (FR-011, Scenario 3)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      final container = _containerFor(repository);
      addTearDown(container.dispose);
      await _arriveOnExpenseControl(
        tester,
        repository: repository,
        container: container,
      );

      await tester.tap(find.text('Tổng quan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không lưu'));
      await tester.pumpAndSettle();

      expect(repository._items.single.allocationValue, 10);
      expect(repository.savedFormulaBatches, isEmpty);
      expect(container.read(pendingItemEditsProvider), isEmpty);
      expect(_selectedTabIndex(tester), 0);
    },
  );

  testWidgets(
    'tapping "Hủy" navigates nowhere and leaves the map intact (Scenario 4 in Edge Cases)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      final container = _containerFor(repository);
      addTearDown(container.dispose);
      await _arriveOnExpenseControl(
        tester,
        repository: repository,
        container: container,
      );

      await tester.tap(find.text('Tổng quan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(container.read(pendingItemEditsProvider), hasLength(1));
      expect(find.text('Lưu công thức'), findsOneWidget);
      expect(_selectedTabIndex(tester), 1); // still on Kiểm soát
    },
  );

  testWidgets(
    'an over-budget staged combination blocked via the prompt\'s "Lưu" keeps the prompt open with an error and does not navigate (Edge Cases §3)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('a', value: 20),
        _leaf('b', value: 70),
      ]);
      final container = _containerFor(repository);
      addTearDown(container.dispose);
      await _arriveOnExpenseControl(
        tester,
        repository: repository,
        container: container,
      );

      await tester.tap(find.text('Tổng quan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      // Prompt still showing, nothing committed, still on Kiểm soát.
      expect(find.text('Lưu thay đổi?'), findsOneWidget);
      expect(repository.savedFormulaBatches, isEmpty);
      expect(container.read(pendingItemEditsProvider), hasLength(1));
      expect(_selectedTabIndex(tester), 1);
    },
  );

  testWidgets(
    'with zero staged edits, tapping another tab navigates immediately with no prompt (FR-012, Scenario 4)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      final container = _containerFor(repository);
      addTearDown(container.dispose);
      await _arriveOnExpenseControl(
        tester,
        repository: repository,
        container: container,
        seedPendingEdit: false,
      );

      await tester.tap(find.text('Tổng quan').last);
      await tester.pumpAndSettle();

      expect(find.text('Lưu thay đổi?'), findsNothing);
      expect(_selectedTabIndex(tester), 0);
    },
  );

  testWidgets(
    'the prompt fires when switching to each of the four other destinations, not just one (SC-003)',
    (tester) async {
      for (final label in ['Thu chi', 'Báo cáo', 'Hồ sơ', 'Tổng quan']) {
        final repository = _FakeExpenseControlRepository([_leaf('a')]);
        final container = _containerFor(repository);
        addTearDown(container.dispose);
        await _arriveOnExpenseControl(
          tester,
          repository: repository,
          container: container,
        );

        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();

        expect(
          find.text('Lưu thay đổi?'),
          findsOneWidget,
          reason: 'expected the prompt when switching to "$label"',
        );

        // Dismiss so the next iteration starts clean.
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
      }
    },
  );
}
