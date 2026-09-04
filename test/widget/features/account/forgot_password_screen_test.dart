import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/forgot_password_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? requestedEmail;
  Object? throwOnResetPasswordForEmail;

  @override
  Future<void> resetPasswordForEmail(String email) async {
    if (throwOnResetPasswordForEmail != null) {
      requestedEmail = email; // still "requested" even though it will throw
      throw throwOnResetPasswordForEmail!;
    }
    requestedEmail = email;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _harness(_FakeAuthRepository fake) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/forgot-password',
        routes: [
          GoRoute(
            path: '/forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
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
    'submitting a registered email requests a reset and shows the generic confirmation (FR-015)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.tap(find.text('Gửi liên kết đặt lại'));
      await tester.pumpAndSettle();

      expect(fake.requestedEmail, 'user@example.com');
      expect(
        find.text(
          'Nếu email này đã đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu trong ít phút.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'submitting an unregistered email shows the IDENTICAL confirmation (no account-enumeration leak)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnResetPasswordForEmail = const AuthApiException(
          'User not found',
          code: 'user_not_found',
        );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nobody@example.com');
      await tester.tap(find.text('Gửi liên kết đặt lại'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nếu email này đã đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu trong ít phút.',
        ),
        findsOneWidget,
      );
    },
  );
}
