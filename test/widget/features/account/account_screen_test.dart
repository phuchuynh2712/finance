import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/l10n/locale_notifier.dart';
import 'package:finance/core/storage/app_preferences_storage.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/core/theme/theme_mode_notifier.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/account/presentation/account_screen.dart';

class _FakeAccountAuthActions implements AccountAuthActions {
  _FakeAccountAuthActions({
    this.currentDisplayName,
    this.currentEmail,
    this.currentAvatarUrl,
  });

  @override
  String? currentDisplayName;

  @override
  String? currentEmail;

  @override
  String? currentAvatarUrl;

  SignOutScope? signOutScope;
  bool biometricEnabled = false;
  Completer<void>? signOutGate;
  int signOutCallCount = 0;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutScope = scope;
    signOutCallCount++;
    if (signOutGate != null) await signOutGate!.future;
  }

  @override
  Future<bool> isBiometricLoginEnabled() async => biometricEnabled;

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }
}

class _FakeAppPreferencesStorage implements AppPreferencesStorage {
  ThemeMode? storedThemeMode;
  Locale? storedLocale;

  @override
  Future<ThemeMode?> getThemeMode() async => storedThemeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async => storedThemeMode = mode;

  @override
  Future<Locale?> getLocale() async => storedLocale;

  @override
  Future<void> setLocale(Locale locale) async => storedLocale = locale;
}

Widget _harness(
  _FakeAccountAuthActions fake, {
  ThemeMode initialThemeMode = ThemeMode.system,
  Locale initialLocale = const Locale('vi'),
}) {
  return ProviderScope(
    overrides: [
      accountAuthActionsProvider.overrideWithValue(fake),
      themeModeProvider.overrideWith(
        (ref) =>
            ThemeModeNotifier(_FakeAppPreferencesStorage(), initialThemeMode),
      ),
      localeProvider.overrideWith(
        (ref) => LocaleNotifier(_FakeAppPreferencesStorage(), initialLocale),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light,
      home: const AccountScreen(),
    ),
  );
}

void main() {
  group('Appearance toggle (US1)', () {
    testWidgets(
      'tapping "Tối" calls setThemeMode(dark) and reflects the new active state',
      (tester) async {
        final fake = _FakeAccountAuthActions();
        await tester.pumpWidget(
          _harness(fake, initialThemeMode: ThemeMode.light),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tối'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(AccountScreen)),
        );
        expect(container.read(themeModeProvider), ThemeMode.dark);
      },
    );

    testWidgets(
      'tapping "Sáng" calls setThemeMode(light) and reflects the new active state',
      (tester) async {
        final fake = _FakeAccountAuthActions();
        await tester.pumpWidget(
          _harness(fake, initialThemeMode: ThemeMode.dark),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sáng'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(AccountScreen)),
        );
        expect(container.read(themeModeProvider), ThemeMode.light);
      },
    );
  });

  group('Language selector (US2)', () {
    testWidgets(
      'tapping the Ngôn ngữ row opens the selector showing both languages with the current one indicated',
      (tester) async {
        final fake = _FakeAccountAuthActions();
        await tester.pumpWidget(_harness(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ngôn ngữ'));
        await tester.pumpAndSettle();

        expect(find.text('Tiếng Việt'), findsWidgets);
        expect(find.text('English'), findsOneWidget);
      },
    );

    testWidgets('selecting English calls setLocale(en) and closes the dialog', (
      tester,
    ) async {
      final fake = _FakeAccountAuthActions();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ngôn ngữ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccountScreen)),
      );
      expect(container.read(localeProvider), const Locale('en'));
      expect(find.text('Chọn ngôn ngữ'), findsNothing);
    });
  });

  group('Account identity and menu (US3)', () {
    testWidgets('renders display name and email when both are set', (
      tester,
    ) async {
      final fake = _FakeAccountAuthActions(
        currentDisplayName: 'Lan Nguyễn',
        currentEmail: 'lan.nguyen@email.com',
      );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      expect(find.text('Lan Nguyễn'), findsOneWidget);
      expect(find.text('lan.nguyen@email.com'), findsOneWidget);
    });

    testWidgets(
      'renders an initial-letter avatar placeholder when no photo is set',
      (tester) async {
        final fake = _FakeAccountAuthActions(
          currentDisplayName: 'Lan Nguyễn',
          currentEmail: 'lan.nguyen@email.com',
        );
        await tester.pumpWidget(_harness(fake));
        await tester.pumpAndSettle();

        expect(find.text('L'), findsOneWidget);
      },
    );

    testWidgets(
      'renders the avatar photo instead of an initial when currentAvatarUrl is set (FR-010)',
      (tester) async {
        // The test harness has no real network access, so NetworkImage's
        // load will fail — this test only asserts *which provider* the
        // widget wires up, not that the image successfully decodes, so
        // that expected failure is intentionally silenced for this test.
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exception is NetworkImageLoadException) return;
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        final fake = _FakeAccountAuthActions(
          currentDisplayName: 'Lan Nguyễn',
          currentEmail: 'lan.nguyen@email.com',
          currentAvatarUrl: 'https://example.com/avatar.png',
        );
        await tester.pumpWidget(_harness(fake));
        await tester.pump();

        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect(avatar.backgroundImage, isA<NetworkImage>());
        expect(find.text('L'), findsNothing);
      },
    );

    testWidgets(
      'falls back to a name/initial derived from the email when no display name is set',
      (tester) async {
        final fake = _FakeAccountAuthActions(
          currentEmail: 'nobody@example.com',
        );
        await tester.pumpWidget(_harness(fake));
        await tester.pumpAndSettle();

        expect(find.text('nobody'), findsOneWidget);
        expect(find.text('N'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "Thông báo" navigates to a placeholder distinct from "Bảo mật"/"Trợ giúp"',
      (tester) async {
        final fake = _FakeAccountAuthActions();
        await tester.pumpWidget(_harness(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông báo'));
        await tester.pumpAndSettle();

        expect(find.text('Thông báo'), findsOneWidget);
        expect(find.text('Bảo mật'), findsNothing);
      },
    );

    testWidgets(
      'tapping "Bảo mật" navigates to a placeholder distinct from "Thông báo"/"Trợ giúp"',
      (tester) async {
        final fake = _FakeAccountAuthActions();
        await tester.pumpWidget(_harness(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Bảo mật'));
        await tester.pumpAndSettle();

        expect(find.text('Bảo mật'), findsOneWidget);
        expect(find.text('Thông báo'), findsNothing);
      },
    );

    testWidgets(
      'tapping "Trợ giúp" navigates to a placeholder distinct from "Thông báo"/"Bảo mật"',
      (tester) async {
        final fake = _FakeAccountAuthActions();
        await tester.pumpWidget(_harness(fake));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Trợ giúp'));
        await tester.pumpAndSettle();

        expect(find.text('Trợ giúp'), findsOneWidget);
        expect(find.text('Thông báo'), findsNothing);
      },
    );
  });

  testWidgets('tapping sign out calls signOut with the local scope', (
    tester,
  ) async {
    final fake = _FakeAccountAuthActions();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    expect(fake.signOutScope, SignOutScope.local);
  });

  testWidgets(
    'shows a spinner and blocks a second tap while sign-out is in flight',
    (tester) async {
      final fake = _FakeAccountAuthActions()..signOutGate = Completer<void>();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng xuất'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // A second tap while signing out must not call signOut again.
      await tester.tap(find.text('Đăng xuất'));
      await tester.pump();

      expect(fake.signOutCallCount, 1);

      fake.signOutGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
