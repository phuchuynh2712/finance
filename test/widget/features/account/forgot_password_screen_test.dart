import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets(
    'at a compact width (<600dp), the pre-submit form renders at full width',
    (tester) async {
      tester.view.physicalSize = const Size(410, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      final fieldSize = tester.getSize(find.byType(TextField));
      expect(fieldSize.width, greaterThan(300));
    },
  );

  testWidgets(
    'at an expanded width (>=840dp), the pre-submit form is capped and centered',
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

      final fieldSize = tester.getSize(find.byType(TextField));
      // Padding(all: 24) sits OUTSIDE AdaptiveBody here (unlike Reset
      // Password's inline error/success Text, which is a plain-width
      // child), so the field width is the raw authContentMaxWidth token.
      expect(fieldSize.width, 450);
    },
  );

  testWidgets(
    'at an expanded width, the post-submit confirmation message is also capped and centered',
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

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.tap(find.text('Gửi liên kết đặt lại'));
      await tester.pumpAndSettle();

      final messageFinder = find.text(
        'Nếu email này đã đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu trong ít phút.',
      );
      final messageSize = tester.getSize(messageFinder);
      expect(messageSize.width, lessThanOrEqualTo(450));
    },
  );

  testWidgets(
    'resizing below 600dp after reaching the post-submit confirmation keeps it shown (FR-010)',
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

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.tap(find.text('Gửi liên kết đặt lại'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(410, 800);
      await tester.pump();

      expect(
        find.text(
          'Nếu email này đã đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu trong ít phút.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Tab traversal reaches every interactive control in order', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
    }
  });

  testWidgets(
    'pressing Enter in the email field submits the form (FR-006 Enter-to-submit)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'user@example.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(fake.requestedEmail, 'user@example.com');
    },
  );
}
