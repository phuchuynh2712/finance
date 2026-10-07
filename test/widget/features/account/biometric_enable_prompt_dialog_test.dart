import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/biometric_enable_prompt.dart';

import '../../../support/expense_screen_harness.dart';

class _FakeAuth extends Fake implements AuthRepository {
  final enabledCalls = <bool>[];

  @override
  Future<bool> shouldShowBiometricEnablePrompt() async => true;

  @override
  Future<void> markBiometricPromptShown() async {}

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    enabledCalls.add(enabled);
  }
}

class _FakeBiometric extends Fake implements BiometricLoginRepository {
  @override
  Future<bool> isDeviceCapable() async => true;
}

/// D6 (contracts/plan-screen-ui.md): the biometric offer is bounded like every
/// pop-up, its primary button has the initial focus, Enter accepts and Escape
/// is "not now".
void main() {
  late AppLocalizations l10n;
  late _FakeAuth auth;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Future<void> open(WidgetTester tester, double width, double height) async {
    useView(tester, width, height);
    auth = _FakeAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          biometricLoginRepositoryProvider.overrideWithValue(_FakeBiometric()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => maybeShowBiometricEnablePrompt(context, ref),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  testWidgets('1440×900: centered, at most 560 wide', (tester) async {
    await open(tester, 1440, 900);
    final rect = dialogRect(tester);
    expect(rect.width, lessThanOrEqualTo(560.01));
    expect(rect.center.dx, closeTo(720, 1));
  });

  testWidgets('the primary button has the initial focus; Enter accepts', (
    tester,
  ) async {
    await open(tester, 1440, 900);
    expect(
      focusIsWithin(
        tester,
        find.widgetWithText(
          FilledButton,
          l10n.biometricEnablePromptAcceptAction,
        ),
      ),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(auth.enabledCalls, [true]);
  });

  testWidgets('Escape is "not now": nothing is enabled', (tester) async {
    await open(tester, 1440, 900);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(auth.enabledCalls, isEmpty);
  });

  testWidgets('410×864: fully visible', (tester) async {
    await open(tester, 410, 864);
    final rect = dialogRect(tester);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(410));
  });
}
