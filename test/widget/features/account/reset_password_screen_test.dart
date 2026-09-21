import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/reset_password_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? confirmedPassword;
  Object? throwOnConfirmPasswordReset;

  @override
  Future<void> confirmPasswordReset(String newPassword) async {
    if (throwOnConfirmPasswordReset != null) throw throwOnConfirmPasswordReset!;
    confirmedPassword = newPassword;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _harness(_FakeAuthRepository fake) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/reset-password',
        routes: [
          GoRoute(
            path: '/reset-password',
            builder: (context, state) => const ResetPasswordScreen(),
          ),
          GoRoute(
            path: '/sign-in',
            builder: (context, state) => const Scaffold(body: Text('sign-in')),
          ),
        ],
      ),
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light,
    ),
  );
}

void main() {
  testWidgets(
    'setting a matching new password calls confirmPasswordReset, shows '
    'success, then navigates back to sign-in without waiting on the router '
    "(FR-016) — regression test for the screen previously stranding users",
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'newPassword123');
      await tester.enterText(find.byType(TextField).last, 'newPassword123');
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pump();
      await tester.pump();

      expect(fake.confirmedPassword, 'newPassword123');
      expect(find.textContaining('Đã đặt lại mật khẩu'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('sign-in'), findsOneWidget);
    },
  );

  testWidgets(
    'a mismatched confirmation shows an inline error and does not submit',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'newPassword123');
      await tester.enterText(find.byType(TextField).last, 'different');
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pumpAndSettle();

      expect(fake.confirmedPassword, isNull);
      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    },
  );

  testWidgets('a failure shows a retryable error message', (tester) async {
    final fake = _FakeAuthRepository()
      ..throwOnConfirmPasswordReset = Exception('Network error');
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'newPassword123');
    await tester.enterText(find.byType(TextField).last, 'newPassword123');
    await tester.tap(find.text('Đặt lại mật khẩu'));
    await tester.pumpAndSettle();

    // Friendly, localized fallback message — not raw exception text.
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(find.text(l10n.errorMapperGeneric), findsOneWidget);
  });
}
