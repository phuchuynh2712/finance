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
import 'package:finance/features/account/presentation/sign_up_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? signedUpEmail;
  String? signedUpPassword;
  String? signedUpDisplayName;
  String? signedUpPhoneNumber;
  Object? throwOnSignUp;
  Object? throwOnSignInWithGoogle;
  Object? throwOnResendConfirmationEmail;
  bool signInWithGoogleCalled = false;
  String? resentConfirmationEmailFor;
  bool needsEmailConfirmation = true;

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    await Future<void>.delayed(Duration.zero);
    if (throwOnSignUp != null) throw throwOnSignUp!;
    signedUpEmail = email;
    signedUpPassword = password;
    signedUpDisplayName = displayName;
    signedUpPhoneNumber = phoneNumber;
    return needsEmailConfirmation;
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
        initialLocation: '/sign-up',
        routes: [
          GoRoute(
            path: '/sign-up',
            builder: (context, state) => const SignUpScreen(),
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
    ),
  );
}

/// Field order in [SignUpScreen]: Email, Password, Confirm Password, Name,
/// Phone Number.
final _emailField = find.byType(TextField).at(0);
final _passwordField = find.byType(TextField).at(1);
final _confirmPasswordField = find.byType(TextField).at(2);
final _nameField = find.byType(TextField).at(3);
final _phoneField = find.byType(TextField).at(4);

Future<void> _fillValidForm(
  WidgetTester tester, {
  String email = 'user@example.com',
  String password = 'password123',
  String? confirmPassword,
  String name = '',
  String phone = '',
}) async {
  await tester.enterText(_emailField, email);
  await tester.enterText(_passwordField, password);
  await tester.enterText(_confirmPasswordField, confirmPassword ?? password);
  if (name.isNotEmpty) await tester.enterText(_nameField, name);
  if (phone.isNotEmpty) await tester.enterText(_phoneField, phone);
}

void main() {
  testWidgets('successful registration calls signUp with the entered values', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpEmail, 'user@example.com');
    expect(fake.signedUpPassword, 'password123');
  });

  testWidgets(
    'successful registration needing confirmation shows the check-your-email '
    'message instead of navigating away (FR-015, FR-021)',
    (tester) async {
      final fake = _FakeAuthRepository()..needsEmailConfirmation = true;
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.textContaining('user@example.com'), findsOneWidget);
      expect(find.text('Gửi lại email xác nhận'), findsOneWidget);
    },
  );

  testWidgets(
    'successful registration with an immediate session shows the form '
    'submitted without a check-your-email message',
    (tester) async {
      final fake = _FakeAuthRepository()..needsEmailConfirmation = false;
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, 'user@example.com');
      expect(find.text('Gửi lại email xác nhận'), findsNothing);
    },
  );

  testWidgets(
    'tapping resend confirmation email calls resendConfirmationEmail (FR-023)',
    (tester) async {
      final fake = _FakeAuthRepository()..needsEmailConfirmation = true;
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi lại email xác nhận'));
      await tester.pumpAndSettle();

      expect(fake.resentConfirmationEmailFor, 'user@example.com');
      expect(find.text('Đã gửi lại email xác nhận.'), findsOneWidget);
    },
  );

  testWidgets(
    'leaving name and phone number blank still succeeds (FR-019)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, 'user@example.com');
      expect(fake.signedUpDisplayName, isEmpty);
      expect(fake.signedUpPhoneNumber, isEmpty);
    },
  );

  testWidgets(
    'filling in name and phone number passes them to signUp (FR-001, FR-019)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester, name: 'Nguyen Van A', phone: '0912345678');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.signedUpDisplayName, 'Nguyen Van A');
      expect(fake.signedUpPhoneNumber, '0912345678');
    },
  );

  testWidgets(
    'confirm-password mismatch shows an inline error and does not submit (FR-002)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester, confirmPassword: 'different-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, isNull);
      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    },
  );

  testWidgets('duplicate email shows an inline error, no account created', (
    tester,
  ) async {
    final fake = _FakeAuthRepository()
      ..throwOnSignUp = const AuthApiException(
        'A user with this email address has already been registered',
        code: 'email_exists',
      );
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Email này đã được đăng ký'),
      findsOneWidget,
    );
  });

  testWidgets('weak password shows an inline field error, no submission', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester, password: '123', confirmPassword: '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpEmail, isNull);
    expect(
      find.text('Mật khẩu phải có ít nhất 6 ký tự.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid email shows an inline field error, no submission', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester, email: 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpEmail, isNull);
    expect(find.text('Email không hợp lệ.'), findsOneWidget);
  });

  testWidgets(
    'a network/server failure preserves the email, clears the password, '
    'and a retry with the same email succeeds (US5, FR-011)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignUp = AuthRetryableFetchException(
          message: 'Network error',
        );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, isNull);
      final emailField = tester.widget<TextField>(_emailField);
      final passwordField = tester.widget<TextField>(_passwordField);
      final confirmPasswordField = tester.widget<TextField>(
        _confirmPasswordField,
      );
      expect(emailField.controller!.text, 'user@example.com');
      expect(passwordField.controller!.text, isEmpty);
      expect(confirmPasswordField.controller!.text, isEmpty);

      fake.throwOnSignUp = null;
      await tester.enterText(_passwordField, 'password123');
      await tester.enterText(_confirmPasswordField, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, 'user@example.com');
    },
  );

  testWidgets('submit button is disabled while a request is in flight', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

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
    'cancelling the Google account chooser shows no error and no state change',
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
    'a Google sign-in network/server failure shows a retryable error',
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
}
