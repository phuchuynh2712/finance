import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/account/presentation/account_screen.dart';

class _FakeAccountAuthActions implements AccountAuthActions {
  String? updatedAvatarUrl;
  String? changedPassword;
  SignOutScope? signOutScope;
  Object? throwOnUpdateAvatar;
  Object? throwOnChangePassword;
  bool biometricEnabled = false;

  @override
  Future<void> updateAvatar(String avatarUrl) async {
    if (throwOnUpdateAvatar != null) throw throwOnUpdateAvatar!;
    updatedAvatarUrl = avatarUrl;
  }

  @override
  Future<void> changePassword(String newPassword) async {
    if (throwOnChangePassword != null) throw throwOnChangePassword!;
    changedPassword = newPassword;
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutScope = scope;
  }

  @override
  Future<bool> isBiometricLoginEnabled() async => biometricEnabled;

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }
}

Widget _harness(_FakeAccountAuthActions fake) {
  return ProviderScope(
    overrides: [accountAuthActionsProvider.overrideWithValue(fake)],
    child: MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const AccountScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'updating the avatar URL calls updateAvatar and shows confirmation',
    (tester) async {
      final fake = _FakeAccountAuthActions();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'https://example.com/avatar.png',
      );
      await tester.tap(find.text('Cập nhật ảnh đại diện'));
      await tester.pumpAndSettle();

      expect(fake.updatedAvatarUrl, 'https://example.com/avatar.png');
      expect(find.text('Đã cập nhật ảnh đại diện.'), findsOneWidget);
    },
  );

  testWidgets(
    'changing the password calls changePassword and shows confirmation',
    (tester) async {
      final fake = _FakeAccountAuthActions();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'newSecurePass123');
      await tester.tap(find.text('Đổi mật khẩu'));
      await tester.pumpAndSettle();

      expect(fake.changedPassword, 'newSecurePass123');
      expect(find.textContaining('Đã đổi mật khẩu'), findsOneWidget);
    },
  );

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

  testWidgets('no Google-linking section is present anywhere on the screen', (
    tester,
  ) async {
    final fake = _FakeAccountAuthActions();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets(
    'the biometric toggle reflects and updates the stored preference (FR-010)',
    (tester) async {
      final fake = _FakeAccountAuthActions();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      final toggleBefore = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(toggleBefore.value, isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(fake.biometricEnabled, isTrue);
      final toggleAfter = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(toggleAfter.value, isTrue);
    },
  );
}
