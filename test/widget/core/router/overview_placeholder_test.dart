import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/router/app_router.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';

/// FR-017, spec.md US5 Acceptance Scenario 2 — "Tổng quan" no longer shows
/// the retired Envelope-based list; it renders the same shared "not yet
/// available" placeholder pattern as "Báo cáo" and Thu chi's scaffolded
/// entry points (research.md Decision 4), in-place as the tab's own branch
/// content (not pushed — contracts/spending_balance_ui_state.md).
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

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      authStateChangesProvider.overrideWith((ref) => const Stream.empty()),
      isSignedInProvider.overrideWithValue(true),
      isPasswordRecoveryProvider.overrideWithValue(false),
      currentUserIdProvider.overrideWithValue('u1'),
      expenseControlRepositoryProvider.overrideWithValue(
        _FakeExpenseControlRepository(),
      ),
      accountAuthActionsProvider.overrideWithValue(_FakeAccountAuthActions()),
    ],
  );
}

void main() {
  testWidgets(
    'the "Tổng quan" tab renders the shared placeholder, not the old envelope list or a Plan entry point',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_harness(container));
      await tester.pumpAndSettle();

      expect(find.byType(NotAvailablePlaceholderScreen), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Plan'), findsNothing);
    },
  );
}
