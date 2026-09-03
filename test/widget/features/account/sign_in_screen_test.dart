import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/account/presentation/google_sign_in_feature_flag.dart';
import 'package:finance/features/account/presentation/sign_in_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? signedInEmail;
  Object? throwOnSignInWithPassword;
  Object? throwOnSignInWithGoogle;
  Object? throwOnResendConfirmationEmail;
  bool signInWithGoogleCalled = false;
  String? resentConfirmationEmailFor;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (throwOnSignInWithPassword != null) throw throwOnSignInWithPassword!;
    signedInEmail = email;
  }

  @override
  Future<void> resendConfirmationEmail(String email) async {
    await Future<void>.delayed(Duration.zero);
    if (throwOnResendConfirmationEmail != null) {
      throw throwOnResendConfirmationEmail!;
    }
    resentConfirmationEmailFor = email;
  }

  @override
  Future<void> signInWithGoogle() async {
    await Future<void>.delayed(Duration.zero);
    signInWithGoogleCalled = true;
    if (throwOnSignInWithGoogle != null) throw throwOnSignInWithGoogle!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _harness(_FakeAuthRepository fake) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/sign-in',
        routes: [
          GoRoute(
            path: '/sign-in',
            builder: (context, state) => const SignInScreen(),
          ),
          GoRoute(
            path: '/sign-up',
            builder: (context, state) => const Scaffold(body: Text('sign-up')),
          ),
        ],
      ),
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

void main() {
  testWidgets(
    'tapping "Sign in with Google" calls signInWithGoogle',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng nhập bằng Google'));
      await tester.pumpAndSettle();

      expect(fake.signInWithGoogleCalled, isTrue);
    },
    skip: !kGoogleSignInEnabled,
  );

  testWidgets(
    'cancelling the Google account chooser shows no error and no state change (FR-009)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignInWithGoogle = const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng nhập bằng Google'));
      await tester.pumpAndSettle();

      expect(find.textContaining('thất bại'), findsNothing);
    },
    skip: !kGoogleSignInEnabled,
  );

  testWidgets(
    'a Google sign-in network/server failure shows a retryable error, distinct from cancellation',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignInWithGoogle = const AuthApiException(
          'Network error',
          code: 'unexpected_failure',
        );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng nhập bằng Google'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Đăng nhập bằng Google thất bại'),
        findsOneWidget,
      );
    },
    skip: !kGoogleSignInEnabled,
  );

  testWidgets(
    'Google button is disabled while a request is in flight',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng nhập bằng Google'));
      await tester.pump();

      final button = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(button.onPressed, isNull);

      await tester.pumpAndSettle();
    },
    skip: !kGoogleSignInEnabled,
  );

  testWidgets('successful password sign-in calls signInWithPassword', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(fake.signedInEmail, 'user@example.com');
  });

  testWidgets(
    'email_not_confirmed shows a distinct message with a resend action (FR-022)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignInWithPassword = const AuthApiException(
          'Email not confirmed',
          code: 'email_not_confirmed',
        );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'user@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.textContaining('chưa được xác nhận'), findsOneWidget);
      expect(find.text('Gửi lại email xác nhận'), findsOneWidget);
    },
  );

  testWidgets(
    'a generic wrong-password error does not show the resend action',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignInWithPassword = const AuthApiException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'user@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'wrong-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Gửi lại email xác nhận'), findsNothing);
    },
  );

  testWidgets(
    'tapping resend confirmation email calls resendConfirmationEmail (FR-023)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignInWithPassword = const AuthApiException(
          'Email not confirmed',
          code: 'email_not_confirmed',
        );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'user@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi lại email xác nhận'));
      await tester.pumpAndSettle();

      expect(fake.resentConfirmationEmailFor, 'user@example.com');
      expect(find.text('Đã gửi lại email xác nhận.'), findsOneWidget);
    },
  );

  testWidgets(
    'a resend failure shows a retryable error message (FR-023)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignInWithPassword = const AuthApiException(
          'Email not confirmed',
          code: 'email_not_confirmed',
        )
        ..throwOnResendConfirmationEmail = AuthRetryableFetchException(
          message: 'Network error',
        );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'user@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi lại email xác nhận'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Không thể gửi lại email xác nhận'),
        findsOneWidget,
      );
    },
  );
}
