import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/l10n/locale_notifier.dart';
import 'package:finance/core/router/app_router.dart';
import 'package:finance/core/storage/app_preferences_storage.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/theme/theme_mode_notifier.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expense_control/domain/transaction_history_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';
import 'package:finance/features/expenses/presentation/overview_providers.dart';

import 'expense_control_fixtures.dart';
import 'pull_complete_override.dart';

/// Renders the real app shell (rail or bottom bar, `appRouterProvider`) with
/// every non-Supabase leaf provider faked, as `app_shell_discard_prompt_test`
/// does (a copy, so that file stays untouched). Used by the adaptive tests of
/// the pop-ups that the shell opens.

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

ProviderContainer shellContainerFor(
  FakeExpenseControlRepository repository, {
  List<Override> extra = const [],
}) {
  return ProviderContainer(
    overrides: [
      authStateChangesProvider.overrideWith((ref) => const Stream.empty()),
      isSignedInProvider.overrideWithValue(true),
      isPasswordRecoveryProvider.overrideWithValue(false),
      currentUserIdProvider.overrideWithValue('u1'),
      accountAuthActionsProvider.overrideWithValue(_FakeAccountAuthActions()),
      overviewAuthActionsProvider.overrideWithValue(_FakeAccountAuthActions()),
      transactionHistoryRepositoryProvider.overrideWithValue(
        _FakeTransactionHistoryRepository(),
      ),
      expenseControlRepositoryProvider.overrideWithValue(repository),
      themeModeProvider.overrideWith(
        (ref) =>
            ThemeModeNotifier(_FakeAppPreferencesStorage(), ThemeMode.system),
      ),
      localeProvider.overrideWith(
        (ref) =>
            LocaleNotifier(_FakeAppPreferencesStorage(), const Locale('vi')),
      ),
      pullCompleteOverride,
      ...extra,
    ],
  );
}

Widget shellApp(ProviderContainer container, {ThemeData? theme}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: container.read(appRouterProvider),
    ),
  );
}

/// Pumps the shell on Tổng quan, opens Kế hoạch, then stages one pending edit
/// (the precondition of the discard prompt).
Future<void> arriveOnExpenseControlWithPendingEdit(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(shellApp(container));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kế hoạch').last);
  await tester.pumpAndSettle();
  container.read(pendingItemEditsProvider.notifier).state = {
    'a': const PendingItemEdit(value: 50),
  };
  await tester.pump();
}
