import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/sign_up_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? signedUpEmail;
  String? signedUpPassword;
  String? signedUpDisplayName;
  String? signedUpPhoneNumber;
  Object? throwOnSignUp;

  @override
  Future<void> signUp({
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
  }

  @override
  Future<bool> shouldShowBiometricEnablePrompt() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeBiometricLoginRepository extends BiometricLoginRepository {
  _FakeBiometricLoginRepository() : super(LocalAuthentication());

  @override
  Future<bool> isDeviceCapable() async => false;
}

Widget _harness(_FakeAuthRepository fake) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fake),
      biometricLoginRepositoryProvider.overrideWithValue(
        _FakeBiometricLoginRepository(),
      ),
    ],
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
      theme: AppTheme.light,
    ),
  );
}

/// Field order in the rebuilt [SignUpScreen] (reference/login-signup-spec.md
/// §2): Full name, Phone, Email, Password, Confirm Password.
final _nameField = find.byType(TextField).at(0);
final _phoneField = find.byType(TextField).at(1);
final _emailField = find.byType(TextField).at(2);
final _passwordField = find.byType(TextField).at(3);
final _confirmPasswordField = find.byType(TextField).at(4);

Future<void> _fillValidForm(
  WidgetTester tester, {
  String email = 'user@example.com',
  String password = 'password123',
  String? confirmPassword,
  String name = '',
  String phone = '',
  bool acceptTerms = true,
}) async {
  if (name.isNotEmpty) await tester.enterText(_nameField, name);
  if (phone.isNotEmpty) await tester.enterText(_phoneField, phone);
  await tester.enterText(_emailField, email);
  await tester.enterText(_passwordField, password);
  await tester.enterText(_confirmPasswordField, confirmPassword ?? password);
  if (acceptTerms) {
    await tester.ensureVisible(find.textContaining('Tôi đồng ý với'));
    await tester.tap(find.textContaining('Tôi đồng ý với'));
    await tester.pump();
  }
}

void main() {
  testWidgets('successful registration calls signUp with the entered values', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpEmail, 'user@example.com');
    expect(fake.signedUpPassword, 'password123');
  });

  testWidgets(
    'the primary button is disabled until the Terms checkbox is checked (FR-007)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester, acceptTerms: false);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      await tester.ensureVisible(find.textContaining('Tôi đồng ý với'));
      await tester.tap(find.textContaining('Tôi đồng ý với'));
      await tester.pumpAndSettle();

      final buttonAfter = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(buttonAfter.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a successful registration signs in immediately, no confirmation step of any kind (FR-019)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, 'user@example.com');
      expect(find.textContaining('kiểm tra hộp thư'), findsNothing);
      expect(find.text('Gửi lại email xác nhận'), findsNothing);
    },
  );

  testWidgets('leaving name and phone number blank still succeeds', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpEmail, 'user@example.com');
    expect(fake.signedUpDisplayName, isEmpty);
    expect(fake.signedUpPhoneNumber, isEmpty);
  });

  testWidgets('filling in name and phone number passes them to signUp', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester, name: 'Nguyen Van A', phone: '0912345678');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpDisplayName, 'Nguyen Van A');
    expect(fake.signedUpPhoneNumber, '0912345678');
  });

  testWidgets(
    'confirm-password mismatch shows an inline error and does not submit',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester, confirmPassword: 'different-password');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, isNull);
      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    },
  );

  testWidgets(
    'an empty email is rejected the same as an invalid one, since email is always required (FR-006)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester, email: '');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, isNull);
      expect(find.text('Email không hợp lệ.'), findsOneWidget);
    },
  );

  testWidgets(
    'duplicate email shows an inline error, no account created, no Google mention',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignUp = const AuthApiException(
          'A user with this email address has already been registered',
          code: 'email_exists',
        );
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Email này đã được đăng ký'), findsOneWidget);
      expect(find.textContaining('Google'), findsNothing);
    },
  );

  testWidgets('weak password shows an inline field error, no submission', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester, password: '123', confirmPassword: '123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpEmail, isNull);
    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsOneWidget);
  });

  testWidgets('a 7-character password is rejected with the 8-character '
      'message and no account is created (FR-015)', (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(
      tester,
      password: '1234567',
      confirmPassword: '1234567',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpEmail, isNull);
    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsOneWidget);
  });

  testWidgets('an 8-character password is accepted and sign-up proceeds', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(
      tester,
      password: '12345678',
      confirmPassword: '12345678',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpPassword, '12345678');
    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsNothing);
  });

  testWidgets('the 8-character requirement is visible before typing, in '
      'Vietnamese', (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);
  });

  testWidgets('invalid email shows an inline field error, no submission', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await _fillValidForm(tester, email: 'not-an-email');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(fake.signedUpEmail, isNull);
    expect(find.text('Email không hợp lệ.'), findsOneWidget);
  });

  testWidgets(
    'a network/server failure preserves the email, clears the password, '
    'and a retry with the same email succeeds',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignUp = AuthRetryableFetchException(message: 'Network error');
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
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

      // Friendly, localized network-failure message — not raw exception
      // text — via the shared mapper's fallback branch (FR-011).
      final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
      expect(find.text(l10n.errorMapperNetworkFailure), findsOneWidget);

      fake.throwOnSignUp = null;
      await tester.enterText(_passwordField, 'password123');
      await tester.enterText(_confirmPasswordField, 'password123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
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
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets('the screen renders no Google sign-in button anywhere', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets(
    'at a compact width (<600dp), the form renders at full width and the '
    'header spans the full viewport width',
    (tester) async {
      // 410dp, not 375dp — this project's own verified pinned reference
      // width (test/flutter_test_config.dart); 375dp overflows _Header's
      // Row and is not a width this app has been validated against.
      tester.view.physicalSize = const Size(410, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      final fieldSize = tester.getSize(_nameField);
      expect(fieldSize.width, greaterThan(300));
    },
  );

  testWidgets(
    'at an expanded width (>=840dp), the scrollable body is capped at '
    '450dp while the header stays full-width (FR-004)',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      final fieldSize = tester.getSize(_nameField);
      // Padding.fromLTRB(24,...,24,...) is OUTSIDE AdaptiveBody here (the
      // AdaptiveBody wraps the Column directly, same as Sign In).
      expect(fieldSize.width, 450);

      final headerFinder = find.byType(Container).first;
      final headerSize = tester.getSize(headerFinder);
      expect(headerSize.width, 1024);
    },
  );

  testWidgets('Tab traversal reaches every interactive control in order', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await tester.tap(_nameField);
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
    }
  });

  testWidgets(
    'pressing Enter on confirm-password submits when terms are accepted (FR-006 Enter-to-submit)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, 'user@example.com');
    },
  );

  testWidgets(
    'pressing Enter on confirm-password does NOT submit while terms are unchecked (FR-006/FR-007)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await _fillValidForm(tester, acceptTerms: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(fake.signedUpEmail, isNull);
    },
  );
}
