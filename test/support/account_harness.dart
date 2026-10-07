import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/l10n/locale_notifier.dart';
import 'package:finance/core/storage/app_preferences_storage.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/theme/theme_mode_notifier.dart';
import 'package:finance/features/account/application/change_password_service.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/account/presentation/change_password_controller.dart';

import 'expense_control_fixtures.dart' show withRail;
import 'expense_screen_harness.dart' show useView;

/// Harness of the Hồ sơ and Bảo mật adaptive tests (a copy of the providers
/// the existing `account_screen_test` / `security_screen_test` fake, so those
/// files stay untouched).
class FakeAccountActions implements AccountAuthActions {
  var signOutCalls = 0;

  @override
  String? get currentDisplayName => 'QA-Test-User';

  @override
  String? get currentEmail => 'qa@example.com';

  @override
  String? get currentAvatarUrl => null;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutCalls++;
  }

  @override
  Future<bool> isBiometricLoginEnabled() async => false;

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {}
}

class _FakeChangePassword extends Fake implements ChangePasswordService {}

class _FakeBiometric extends Fake implements BiometricLoginRepository {
  @override
  Future<BiometricAvailability> availability() async =>
      BiometricAvailability.available;
}

class _FakePrefs implements AppPreferencesStorage {
  @override
  Future<ThemeMode?> getThemeMode() async => null;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  Future<Locale?> getLocale() async => null;

  @override
  Future<void> setLocale(Locale locale) async {}
}

/// The `ProviderScope` + `MaterialApp` the account screens need, with the
/// account providers faked. [textScale] sets the text size of the whole app.
Widget wrapForAccountTest(
  Widget home, {
  FakeAccountActions? account,
  ThemeData? theme,
  Locale locale = const Locale('vi'),
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      accountAuthActionsProvider.overrideWithValue(
        account ?? FakeAccountActions(),
      ),
      changePasswordServiceProvider.overrideWithValue(_FakeChangePassword()),
      biometricLoginRepositoryProvider.overrideWithValue(_FakeBiometric()),
      themeModeProvider.overrideWith(
        (ref) => ThemeModeNotifier(_FakePrefs(), ThemeMode.light),
      ),
      localeProvider.overrideWith(
        (ref) => LocaleNotifier(_FakePrefs(), locale),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

/// Mounts [screen] with the account providers faked. [rail] mirrors the
/// shell's navigation rail; [locale] is both the app and the stored locale.
Future<FakeAccountActions> pumpAccountScreen(
  WidgetTester tester,
  Widget screen, {
  required double width,
  required double height,
  bool rail = false,
  ThemeData? theme,
  Locale locale = const Locale('vi'),
}) async {
  useView(tester, width, height);
  final account = FakeAccountActions();
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: wrapForAccountTest(
        rail ? withRail(screen) : screen,
        account: account,
        theme: theme,
        locale: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return account;
}
