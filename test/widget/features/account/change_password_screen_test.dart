import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/application/change_password_service.dart';
import 'package:finance/features/account/presentation/change_password_controller.dart';
import 'package:finance/features/account/presentation/change_password_screen.dart';

const _current = 'old-password-1';
const _next = 'new-password-2';

class _FakeService extends Fake implements ChangePasswordService {
  int calls = 0;
  String? lastCurrent;
  String? lastNew;
  Completer<ChangePasswordResult>? gate;
  ChangePasswordResult result = const ChangePasswordResult(
    ChangePasswordOutcome.changed,
  );

  @override
  Future<ChangePasswordResult> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls++;
    lastCurrent = currentPassword;
    lastNew = newPassword;
    if (gate != null) return gate!.future;
    return result;
  }
}

/// A start page that opens the change-password screen like the Security
/// screen does and shows what the screen popped with.
class _StartPage extends StatefulWidget {
  const _StartPage();

  @override
  State<_StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<_StartPage> {
  String popped = 'nothing';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            key: const ValueKey('open'),
            onPressed: () async {
              final outcome = await context.push<ChangePasswordOutcome>(
                '/change',
              );
              setState(() => popped = '$outcome');
            },
            child: const Text('open'),
          ),
          Text(popped, key: const ValueKey('popped')),
        ],
      ),
    );
  }
}

Widget _harness(
  _FakeService service, {
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('vi'),
}) {
  return ProviderScope(
    overrides: [changePasswordServiceProvider.overrideWithValue(service)],
    child: MaterialApp.router(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const _StartPage()),
          GoRoute(
            path: '/change',
            builder: (context, state) => const ChangePasswordScreen(),
          ),
        ],
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

Future<void> _type(
  WidgetTester tester, {
  String current = _current,
  String newPassword = _next,
  String? confirm,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('change-password-current')),
    current,
  );
  await tester.enterText(
    find.byKey(const ValueKey('change-password-new')),
    newPassword,
  );
  await tester.enterText(
    find.byKey(const ValueKey('change-password-confirm')),
    confirm ?? newPassword,
  );
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('change-password-submit')),
  );
  await tester.tap(find.byKey(const ValueKey('change-password-submit')));
  await tester.pumpAndSettle();
}

TextField _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key)));

void main() {
  late _FakeService service;

  setUp(() => service = _FakeService());

  Future<void> pumpScreen(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('vi'),
  }) async {
    await tester.pumpWidget(
      _harness(service, themeMode: themeMode, locale: locale),
    );
    await tester.pumpAndSettle();
    await _open(tester);
  }

  group('content', () {
    testWidgets('shows the three labelled fields and the 8-character hint '
        'before anything is typed (vi)', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Mật khẩu hiện tại'), findsOneWidget);
      expect(find.text('Mật khẩu mới'), findsOneWidget);
      expect(find.text('Nhập lại mật khẩu mới'), findsOneWidget);
      expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);
      expect(find.byKey(const ValueKey('change-password-submit')), findsOne);
      expect(find.text('Đổi mật khẩu'), findsWidgets);
    });

    testWidgets('is fully translated (en)', (tester) async {
      await pumpScreen(tester, locale: const Locale('en'));

      expect(find.text('Current password'), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('Change password'), findsWidgets);
    });

    testWidgets('password fields are hidden by default and use the right '
        'autofill roles and keyboard settings', (tester) async {
      await pumpScreen(tester);

      for (final key in [
        'change-password-current',
        'change-password-new',
        'change-password-confirm',
      ]) {
        final field = _field(tester, key);
        expect(field.obscureText, isTrue, reason: key);
        expect(field.autocorrect, isFalse, reason: key);
        expect(field.enableSuggestions, isFalse, reason: key);
      }
      expect(_field(tester, 'change-password-current').autofillHints, [
        AutofillHints.password,
      ]);
      expect(_field(tester, 'change-password-new').autofillHints, [
        AutofillHints.newPassword,
      ]);
      expect(_field(tester, 'change-password-confirm').autofillHints, [
        AutofillHints.newPassword,
      ]);
    });

    testWidgets('each show/hide toggle reveals its own field with a labelled '
        'tooltip', (tester) async {
      await pumpScreen(tester);

      Finder toggleOf(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(IconButton),
      );

      expect(
        tester.widget<IconButton>(toggleOf('change-password-new')).tooltip,
        'Hiện mật khẩu',
      );

      await tester.tap(toggleOf('change-password-new'));
      await tester.pump();

      expect(_field(tester, 'change-password-new').obscureText, isFalse);
      expect(_field(tester, 'change-password-current').obscureText, isTrue);
      expect(_field(tester, 'change-password-confirm').obscureText, isTrue);
      expect(
        tester.widget<IconButton>(toggleOf('change-password-new')).tooltip,
        'Ẩn mật khẩu',
      );
    });

    testWidgets('touch targets are at least 48 dp', (tester) async {
      await pumpScreen(tester);

      for (final key in [
        'change-password-current',
        'change-password-new',
        'change-password-confirm',
      ]) {
        final toggle = find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(IconButton),
        );
        final size = tester.getSize(toggle);
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
      final submit = tester.getSize(
        find.byKey(const ValueKey('change-password-submit')),
      );
      expect(submit.height, greaterThanOrEqualTo(48));
    });
  });

  group('validation (no request is made)', () {
    testWidgets('an empty current password shows its message', (tester) async {
      await pumpScreen(tester);
      await _type(tester, current: '');
      await _submit(tester);

      expect(find.text('Nhập mật khẩu hiện tại.'), findsOneWidget);
      expect(service.calls, 0);
    });

    testWidgets('a 7-character new password shows the 8-character message', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _type(tester, newPassword: '1234567');
      await _submit(tester);

      expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsOneWidget);
      expect(service.calls, 0);
    });

    testWidgets('a new password equal to the current one is rejected', (
      tester,
    ) async {
      await pumpScreen(tester);
      await _type(tester, current: _current, newPassword: _current);
      await _submit(tester);

      expect(
        find.text('Mật khẩu mới phải khác mật khẩu hiện tại.'),
        findsOneWidget,
      );
      expect(service.calls, 0);
    });

    testWidgets('a mismatched confirmation is rejected', (tester) async {
      await pumpScreen(tester);
      await _type(tester, confirm: 'different-password');
      await _submit(tester);

      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
      expect(service.calls, 0);
    });

    testWidgets('editing a field clears the shown errors', (tester) async {
      await pumpScreen(tester);
      await _type(tester, newPassword: '1234567');
      await _submit(tester);
      expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('change-password-new')),
        '12345678',
      );
      // The error cross-fades out, so let the animation finish.
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu phải có ít nhất 8 ký tự.'), findsNothing);
    });
  });

  group('submitting', () {
    testWidgets('shows a spinner, disables the button and sends one request '
        'even if tapped again', (tester) async {
      service.gate = Completer<ChangePasswordResult>();
      await pumpScreen(tester);
      await _type(tester);

      final submit = find.byKey(const ValueKey('change-password-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);

      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      expect(service.calls, 1);
      expect(service.lastCurrent, _current);
      expect(service.lastNew, _next);

      service.gate!.complete(
        const ChangePasswordResult(ChangePasswordOutcome.changed),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Enter on the last field submits', (tester) async {
      await pumpScreen(tester);
      await _type(tester);
      await tester.showKeyboard(
        find.byKey(const ValueKey('change-password-confirm')),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(service.calls, 1);
    });

    testWidgets('success pops back with changed', (tester) async {
      await pumpScreen(tester);
      await _type(tester);
      await _submit(tester);

      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('popped'))).data,
        '${ChangePasswordOutcome.changed}',
      );
    });

    testWidgets('success with the other devices not ended pops back with '
        'changedOthersNotEnded', (tester) async {
      service.result = const ChangePasswordResult(
        ChangePasswordOutcome.changedOthersNotEnded,
        SocketException('offline'),
      );
      await pumpScreen(tester);
      await _type(tester);
      await _submit(tester);

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('popped'))).data,
        '${ChangePasswordOutcome.changedOthersNotEnded}',
      );
    });
  });

  group('failures', () {
    testWidgets('a wrong current password is shown under that field', (
      tester,
    ) async {
      service.result = const ChangePasswordResult(
        ChangePasswordOutcome.wrongCurrentPassword,
        AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );
      await pumpScreen(tester);
      await _type(tester);
      await _submit(tester);

      expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('an offline failure shows a banner and keeps the typed values', (
      tester,
    ) async {
      service.result = const ChangePasswordResult(
        ChangePasswordOutcome.offline,
        SocketException('down'),
      );
      await pumpScreen(tester);
      await _type(tester);
      await _submit(tester);

      expect(
        find.text(
          'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.',
        ),
        findsOneWidget,
      );
      expect(
        _field(tester, 'change-password-current').controller!.text,
        _current,
      );
      expect(_field(tester, 'change-password-new').controller!.text, _next);
      expect(_field(tester, 'change-password-confirm').controller!.text, _next);
    });

    testWidgets('a session that ended shows its banner and does not navigate '
        'by itself', (tester) async {
      service.result = const ChangePasswordResult(
        ChangePasswordOutcome.sessionExpired,
        AuthApiException(
          'gone',
          statusCode: '400',
          code: 'refresh_token_not_found',
        ),
      );
      await pumpScreen(tester);
      await _type(tester);
      await _submit(tester);

      expect(
        find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
        findsOneWidget,
      );
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('a weak password from the service is shown under the new '
        'password field', (tester) async {
      service.result = const ChangePasswordResult(
        ChangePasswordOutcome.weakPassword,
        AuthApiException('weak', statusCode: '422', code: 'weak_password'),
      );
      await pumpScreen(tester);
      await _type(tester);
      await _submit(tester);

      expect(
        find.text('Mật khẩu chưa đủ mạnh. Hãy dùng ít nhất 8 ký tự.'),
        findsOneWidget,
      );
    });
  });

  group('leaving', () {
    testWidgets('re-opening the screen shows three empty fields (nothing is '
        'retained)', (tester) async {
      await pumpScreen(tester);
      await _type(tester);

      // Leave without submitting. (`pageBack` looks for the English "Back"
      // tooltip, but this app runs in Vietnamese.)
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsNothing);

      await _open(tester);

      for (final key in [
        'change-password-current',
        'change-password-new',
        'change-password-confirm',
      ]) {
        expect(_field(tester, key).controller!.text, isEmpty, reason: key);
      }
    });
  });

  group('adaptive layout and appearance', () {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (label, size) in [
        ('compact 410', const Size(410, 864)),
        ('expanded 1000', const Size(1000, 800)),
      ]) {
        testWidgets('renders without overflow at $label in $themeMode '
            'with a capped content width', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await pumpScreen(tester, themeMode: themeMode);
          await _type(tester, newPassword: '1234567');
          await _submit(tester);

          expect(tester.takeException(), isNull);
          final width = tester
              .getSize(find.byKey(const ValueKey('change-password-new')))
              .width;
          if (size.width >= 840) {
            expect(
              width,
              lessThanOrEqualTo(450),
              reason: 'content must not stretch edge to edge',
            );
          } else {
            expect(width, greaterThan(300));
          }
        });
      }
    }
  });
}
