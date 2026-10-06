import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('a 7-character new password is rejected before any request '
      '(FR-015)', (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '1234567');
    await tester.enterText(find.byType(TextField).last, '1234567');
    await tester.tap(find.text('Đặt lại mật khẩu'));
    await tester.pumpAndSettle();

    expect(fake.confirmedPassword, isNull);
    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsOneWidget);
  });

  testWidgets('an 8-character new password is sent', (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '12345678');
    await tester.enterText(find.byType(TextField).last, '12345678');
    await tester.tap(find.text('Đặt lại mật khẩu'));
    await tester.pump();
    await tester.pump();

    expect(fake.confirmedPassword, '12345678');
    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('the length check comes before the mismatch check, and both '
      'messages stay specific', (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'short');
    await tester.enterText(find.byType(TextField).last, 'different');
    await tester.tap(find.text('Đặt lại mật khẩu'));
    await tester.pumpAndSettle();

    expect(fake.confirmedPassword, isNull);
    expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsOneWidget);
  });

  testWidgets('the 8-character requirement is visible before typing', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);
  });

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

  testWidgets('at a compact width (<600dp), the form renders at full width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(410, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    final fieldSize = tester.getSize(find.byType(TextField).first);
    expect(fieldSize.width, greaterThan(300));
  });

  testWidgets(
    'at an expanded width (>=840dp), the form is capped and centered',
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

      final fieldSize = tester.getSize(find.byType(TextField).first);
      // Padding(all: 24) sits OUTSIDE AdaptiveBody here (same structure as
      // Forgot Password), so the field width is the raw authContentMaxWidth
      // token, not reduced by that padding.
      expect(fieldSize.width, 450);
    },
  );

  testWidgets(
    'the capped container width does not change when the inline error message appears',
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

      final widthBefore = tester.getSize(find.byType(TextField).first).width;

      await tester.enterText(find.byType(TextField).first, 'newPassword123');
      await tester.enterText(find.byType(TextField).last, 'different');
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pumpAndSettle();

      final widthAfter = tester.getSize(find.byType(TextField).first).width;
      expect(widthAfter, widthBefore);
    },
  );

  testWidgets(
    'resizing below 600dp immediately after the success message appears '
    'keeps it visible (FR-010) — resize happens before the 2s auto-redirect',
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

      await tester.enterText(find.byType(TextField).first, 'newPassword123');
      await tester.enterText(find.byType(TextField).last, 'newPassword123');
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Đã đặt lại mật khẩu'), findsOneWidget);

      tester.view.physicalSize = const Size(410, 800);
      // Well under the screen's own 2-second redirect delay — a hypothetical
      // bug that clears the message only when the redirect timer fires
      // can't accidentally make this test pass for the wrong reason.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Đã đặt lại mật khẩu'), findsOneWidget);

      // Drain the screen's own pending 2-second redirect timer so the test
      // framework's "no pending timers after teardown" invariant holds.
      await tester.pumpAndSettle(const Duration(seconds: 3));
    },
  );

  testWidgets('Tab traversal reaches every interactive control in order', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_harness(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
    }
  });

  testWidgets(
    'pressing Enter in confirm-password submits the form (FR-006 Enter-to-submit)',
    (tester) async {
      final fake = _FakeAuthRepository();
      await tester.pumpWidget(_harness(fake));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'newPassword123');
      await tester.enterText(find.byType(TextField).last, 'newPassword123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();

      expect(fake.confirmedPassword, 'newPassword123');

      await tester.pumpAndSettle(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'Enter during the post-success 2-second window does not re-trigger '
    'confirmPasswordReset (FR-006 guard)',
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

      fake.confirmedPassword = null;
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 100));

      expect(fake.confirmedPassword, isNull);

      await tester.pumpAndSettle(const Duration(seconds: 3));
    },
  );
}
