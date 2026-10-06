import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/application/change_password_service.dart';
import 'package:finance/features/account/presentation/account_controller.dart';
import 'package:finance/features/account/presentation/change_password_controller.dart';
import 'package:finance/features/account/presentation/change_password_screen.dart';
import 'package:finance/features/account/presentation/security_screen.dart';

class _FakeService extends Fake implements ChangePasswordService {
  int retries = 0;
  Completer<ChangePasswordResult>? gate;
  ChangePasswordResult retryResult = const ChangePasswordResult(
    ChangePasswordOutcome.changed,
  );
  ChangePasswordResult changeResult = const ChangePasswordResult(
    ChangePasswordOutcome.changed,
  );

  @override
  Future<ChangePasswordResult> signOutOtherDevices() async {
    retries++;
    if (gate != null) return gate!.future;
    return retryResult;
  }

  @override
  Future<ChangePasswordResult> change({
    required String currentPassword,
    required String newPassword,
  }) async => changeResult;
}

class _FakeBiometric extends Fake implements BiometricLoginRepository {
  BiometricAvailability availabilityResult = BiometricAvailability.available;
  Completer<BiometricAvailability>? availabilityGate;
  bool authenticateResult = true;
  Object? authenticateError;
  final authenticateReasons = <String>[];

  @override
  Future<BiometricAvailability> availability() async {
    if (availabilityGate != null) return availabilityGate!.future;
    return availabilityResult;
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateReasons.add(localizedReason);
    if (authenticateError != null) throw authenticateError!;
    return authenticateResult;
  }
}

class _FakeAccount extends Fake implements AccountAuthActions {
  bool stored = false;
  final writes = <bool>[];

  @override
  Future<bool> isBiometricLoginEnabled() async => stored;

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    writes.add(enabled);
    stored = enabled;
  }
}

/// Stands in for the real change-password screen: two buttons pop with the
/// outcome the Security screen has to react to.
class _FakeChangePasswordPage extends StatelessWidget {
  const _FakeChangePasswordPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('fake-change-password')),
      body: Column(
        children: [
          TextButton(
            key: const ValueKey('pop-changed'),
            onPressed: () => context.pop(ChangePasswordOutcome.changed),
            child: const Text('pop changed'),
          ),
          TextButton(
            key: const ValueKey('pop-others-not-ended'),
            onPressed: () =>
                context.pop(ChangePasswordOutcome.changedOthersNotEnded),
            child: const Text('pop others not ended'),
          ),
        ],
      ),
    );
  }
}

const _row = ValueKey('security-change-password-row');
const _notice = ValueKey('security-others-notice');
const _retry = ValueKey('security-others-retry');
const _switchKey = ValueKey('security-biometric-switch');
const _caption = ValueKey('security-biometric-caption');

void main() {
  late _FakeService service;
  late _FakeBiometric biometric;
  late _FakeAccount account;

  setUp(() {
    service = _FakeService();
    biometric = _FakeBiometric();
    account = _FakeAccount();
  });

  Widget harness({
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('vi'),
    bool realChangePassword = false,
  }) {
    return ProviderScope(
      overrides: [
        changePasswordServiceProvider.overrideWithValue(service),
        biometricLoginRepositoryProvider.overrideWithValue(biometric),
        accountAuthActionsProvider.overrideWithValue(account),
      ],
      child: MaterialApp.router(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: GoRouter(
          initialLocation: '/account/security',
          routes: [
            GoRoute(
              path: '/account/security',
              builder: (context, state) => const SecurityScreen(),
              routes: [
                GoRoute(
                  path: 'change-password',
                  builder: (context, state) => realChangePassword
                      ? const ChangePasswordScreen()
                      : const _FakeChangePasswordPage(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('vi'),
    bool realChangePassword = false,
  }) async {
    await tester.pumpWidget(
      harness(
        themeMode: themeMode,
        locale: locale,
        realChangePassword: realChangePassword,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goToChangePasswordAndPop(
    WidgetTester tester,
    String popButtonKey,
  ) async {
    await tester.tap(find.byKey(_row));
    await tester.pumpAndSettle();
    expect(find.text('fake-change-password'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey(popButtonKey)));
    await tester.pumpAndSettle();
  }

  Switch switchWidget(WidgetTester tester) =>
      tester.widget<Switch>(find.byKey(_switchKey));

  group('content and navigation', () {
    testWidgets('shows the title with its badge and the change-password row', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Bảo mật'), findsOneWidget);
      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      expect(find.byKey(_row), findsOneWidget);
      expect(find.text('Đổi mật khẩu'), findsOneWidget);
      expect(find.byIcon(LucideIcons.keyRound), findsOneWidget);
      expect(find.byKey(_notice), findsNothing);
    });

    testWidgets('is translated (en)', (tester) async {
      await pumpScreen(tester, locale: const Locale('en'));

      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Fingerprint sign-in'), findsOneWidget);
    });

    testWidgets('the row is at least 48 dp tall', (tester) async {
      await pumpScreen(tester);

      expect(tester.getSize(find.byKey(_row)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('tapping the row opens change password and Back returns here', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(_row));
      await tester.pumpAndSettle();
      expect(find.text('fake-change-password'), findsOneWidget);

      // `pageBack` looks for the English "Back" tooltip; this app runs in
      // Vietnamese.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SecurityScreen), findsOneWidget);
    });
  });

  group('after changing the password', () {
    testWidgets('changed shows the confirmation and no persistent notice', (
      tester,
    ) async {
      await pumpScreen(tester);
      await goToChangePasswordAndPop(tester, 'pop-changed');

      expect(find.text('Đã đổi mật khẩu.'), findsOneWidget);
      expect(find.byKey(_notice), findsNothing);
    });

    testWidgets('changedOthersNotEnded shows the notice with a retry button', (
      tester,
    ) async {
      await pumpScreen(tester);
      await goToChangePasswordAndPop(tester, 'pop-others-not-ended');

      expect(find.byKey(_notice), findsOneWidget);
      expect(
        find.text(
          'Đã đổi mật khẩu, nhưng chưa đăng xuất được các thiết bị khác.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(_retry)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('retrying the other-devices step', () {
    Future<void> showNotice(WidgetTester tester) async {
      await pumpScreen(tester);
      await goToChangePasswordAndPop(tester, 'pop-others-not-ended');
      expect(find.byKey(_notice), findsOneWidget);
    }

    testWidgets('success hides the notice and confirms in a snackbar', (
      tester,
    ) async {
      await showNotice(tester);

      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();

      expect(service.retries, 1);
      expect(find.byKey(_notice), findsNothing);
      expect(find.text('Đã đăng xuất các thiết bị khác.'), findsOneWidget);
    });

    testWidgets('an offline failure keeps the notice and says why', (
      tester,
    ) async {
      service.retryResult = const ChangePasswordResult(
        ChangePasswordOutcome.changedOthersNotEnded,
        SocketException('down'),
      );
      await showNotice(tester);

      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();

      expect(find.byKey(_notice), findsOneWidget);
      expect(
        find.text(
          'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('any other failure keeps the notice with the generic message', (
      tester,
    ) async {
      service.retryResult = ChangePasswordResult(
        ChangePasswordOutcome.changedOthersNotEnded,
        StateError('boom'),
      );
      await showNotice(tester);

      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();

      expect(find.byKey(_notice), findsOneWidget);
      expect(find.text('Đã có lỗi xảy ra. Vui lòng thử lại.'), findsOneWidget);
    });

    testWidgets('shows a spinner and ignores a second tap while retrying', (
      tester,
    ) async {
      service.gate = Completer<ChangePasswordResult>();
      await showNotice(tester);

      await tester.tap(find.byKey(_retry));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(_notice),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(_retry), warnIfMissed: false);
      await tester.pump();
      expect(service.retries, 1);

      service.gate!.complete(
        const ChangePasswordResult(ChangePasswordOutcome.changed),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_notice), findsNothing);
    });
  });

  group('biometric switch (US2)', () {
    testWidgets('is off and enabled on a capable device with no preference', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Đăng nhập bằng vân tay'), findsOneWidget);
      expect(find.byIcon(LucideIcons.fingerprint), findsOneWidget);
      expect(switchWidget(tester).value, isFalse);
      expect(switchWidget(tester).onChanged, isNotNull);
      expect(find.byKey(_caption), findsNothing);
    });

    testWidgets('shows the stored preference as on', (tester) async {
      account.stored = true;
      await pumpScreen(tester);

      expect(switchWidget(tester).value, isTrue);
      expect(switchWidget(tester).onChanged, isNotNull);
    });

    testWidgets('is disabled while availability is still being read, then '
        'settles (no flash of a wrong state)', (tester) async {
      biometric.availabilityGate = Completer<BiometricAvailability>();
      await tester.pumpWidget(harness());
      await tester.pump();

      expect(switchWidget(tester).onChanged, isNull);
      expect(switchWidget(tester).value, isFalse);

      biometric.availabilityGate!.complete(BiometricAvailability.available);
      await tester.pumpAndSettle();

      expect(switchWidget(tester).onChanged, isNotNull);
    });

    final reasons = <(BiometricAvailability, String)>[
      (
        BiometricAvailability.webUnsupported,
        'Đăng nhập bằng vân tay chưa hỗ trợ trên web.',
      ),
      (
        BiometricAvailability.noHardware,
        'Thiết bị này không hỗ trợ đăng nhập bằng vân tay.',
      ),
      (
        BiometricAvailability.notEnrolled,
        'Hãy thêm vân tay hoặc khuôn mặt trong cài đặt thiết bị để bật tính năng này.',
      ),
    ];
    for (final (availability, text) in reasons) {
      testWidgets('$availability disables the switch and explains why', (
        tester,
      ) async {
        biometric.availabilityResult = availability;
        await pumpScreen(tester);

        expect(switchWidget(tester).onChanged, isNull);
        expect(switchWidget(tester).value, isFalse);
        expect(find.byKey(_caption), findsOneWidget);
        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('a stored preference that can no longer be used shows off and '
        'disabled with the reason, leaving the stored value alone', (
      tester,
    ) async {
      account.stored = true;
      biometric.availabilityResult = BiometricAvailability.notEnrolled;
      await pumpScreen(tester);

      expect(switchWidget(tester).value, isFalse);
      expect(switchWidget(tester).onChanged, isNull);
      expect(account.stored, isTrue);
      expect(account.writes, isEmpty);
    });

    testWidgets('turning it on asks for one check and then shows on', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();

      expect(biometric.authenticateReasons, [
        'Xác nhận để bật đăng nhập bằng vân tay',
      ]);
      expect(account.writes, [true]);
      expect(switchWidget(tester).value, isTrue);
    });

    testWidgets('tapping the row also toggles it', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Đăng nhập bằng vân tay'));
      await tester.pumpAndSettle();

      expect(account.writes, [true]);
      expect(switchWidget(tester).value, isTrue);
    });

    testWidgets('a cancelled check leaves it off and says so', (tester) async {
      biometric.authenticateResult = false;
      await pumpScreen(tester);

      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();

      expect(account.writes, isEmpty);
      expect(switchWidget(tester).value, isFalse);
      expect(
        find.text('Chưa bật được đăng nhập bằng vân tay.'),
        findsOneWidget,
      );
    });

    testWidgets('a failing check leaves it off and says so', (tester) async {
      biometric.authenticateError = const LocalAuthException(
        code: LocalAuthExceptionCode.userCanceled,
      );
      await pumpScreen(tester);

      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();

      expect(account.writes, isEmpty);
      expect(switchWidget(tester).value, isFalse);
      expect(
        find.text('Chưa bật được đăng nhập bằng vân tay.'),
        findsOneWidget,
      );
    });

    testWidgets('turning it off takes effect at once with no check', (
      tester,
    ) async {
      account.stored = true;
      await pumpScreen(tester);

      await tester.tap(find.byKey(_switchKey));
      await tester.pumpAndSettle();

      expect(biometric.authenticateReasons, isEmpty);
      expect(account.writes, [false]);
      expect(switchWidget(tester).value, isFalse);
    });

    testWidgets('returning from system settings re-reads availability', (
      tester,
    ) async {
      biometric.availabilityResult = BiometricAvailability.notEnrolled;
      await pumpScreen(tester);
      expect(switchWidget(tester).onChanged, isNull);

      biometric.availabilityResult = BiometricAvailability.available;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(switchWidget(tester).onChanged, isNotNull);
      expect(find.byKey(_caption), findsNothing);
    });

    testWidgets('FR-009: changing the password leaves the biometric setting '
        'unchanged', (tester) async {
      account.stored = true;
      service.changeResult = const ChangePasswordResult(
        ChangePasswordOutcome.changed,
      );
      await pumpScreen(tester, realChangePassword: true);
      expect(switchWidget(tester).value, isTrue);

      await tester.tap(find.byKey(_row));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('change-password-current')),
        'old-password-1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('change-password-new')),
        'new-password-2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('change-password-confirm')),
        'new-password-2',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('change-password-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('change-password-submit')));
      await tester.pumpAndSettle();

      expect(find.byType(SecurityScreen), findsOneWidget);
      expect(find.text('Đã đổi mật khẩu.'), findsOneWidget);
      expect(switchWidget(tester).value, isTrue);
      expect(account.writes, isEmpty);
      expect(account.stored, isTrue);
    });
  });

  group('accessibility', () {
    // Found while verifying on web: with one tappable row and one merged
    // (Switch) row in the same card, the first row's semantics used to be
    // merged UP into an ancestor node covering the whole card, so a screen
    // reader saw one huge "Đổi mật khẩu" target with the biometric row nested
    // inside it. Every row must be its own, row-sized node.
    testWidgets('each row is its own semantics node sized like the row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      final passwordNode = tester.getSemantics(find.byKey(_row));
      final biometricNode = tester.getSemantics(find.byKey(_switchKey));
      final rowHeight = tester.getSize(find.byKey(_row)).height;

      expect(passwordNode.label, 'Đổi mật khẩu');
      expect(
        passwordNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        passwordNode.rect.height,
        lessThan(rowHeight + 2),
        reason: 'the tap target must not swallow the biometric row too',
      );
      expect(passwordNode.id, isNot(biometricNode.id));
      expect(biometricNode.parent?.id, isNot(passwordNode.id));
      handle.dispose();
    });

    testWidgets('the biometric row reads as one item: label, reason and the '
        'switch state', (tester) async {
      final handle = tester.ensureSemantics();
      biometric.availabilityResult = BiometricAvailability.notEnrolled;
      await pumpScreen(tester);

      final node = tester.getSemantics(find.byKey(_switchKey));
      final data = node.getSemanticsData();
      expect(node.label, contains('Đăng nhập bằng vân tay'));
      expect(
        node.label,
        contains('Hãy thêm vân tay hoặc khuôn mặt'),
        reason: 'the reason it is disabled is announced with the switch',
      );
      expect(
        data.flagsCollection.isToggled,
        Tristate.isFalse,
        reason: 'announced as a switch that is off',
      );
      handle.dispose();
    });
  });

  group('adaptive layout and appearance', () {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (label, size) in [
        ('compact 410', const Size(410, 864)),
        ('expanded 1000', const Size(1000, 800)),
      ]) {
        for (final availability in [
          BiometricAvailability.available,
          BiometricAvailability.notEnrolled,
        ]) {
          testWidgets('renders without overflow at $label in $themeMode '
              '($availability), with the notice visible and a capped content '
              'width', (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);
            biometric.availabilityResult = availability;

            await pumpScreen(tester, themeMode: themeMode);
            await goToChangePasswordAndPop(tester, 'pop-others-not-ended');

            expect(tester.takeException(), isNull);
            expect(find.byKey(_notice), findsOneWidget);
            expect(find.byKey(_switchKey), findsOneWidget);
            final rowWidth = tester.getSize(find.byKey(_row)).width;
            if (size.width >= 840) {
              expect(
                rowWidth,
                lessThan(size.width),
                reason: 'content must not stretch edge to edge',
              );
            } else {
              expect(rowWidth, greaterThan(300));
            }
            expect(
              tester.getSize(find.byKey(_switchKey)).height,
              greaterThanOrEqualTo(40),
            );
          });
        }
      }
    }
  });
}
