import 'package:flutter/material.dart';
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
import 'package:finance/features/account/presentation/sign_in_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? signedInEmail;
  Object? throwOnSignInWithPassword;
  Object? throwOnVerifySessionAlive;
  bool verifySessionAliveCalled = false;
  bool markBiometricPromptShownCalled = false;
  bool shouldShowPrompt = false;

  /// Simulates per-account, per-device scoping (FR-013) without touching
  /// real secure storage: keyed by [currentUserId], mirroring the real
  /// `AuthRepository`'s `BIOMETRIC_ENABLED_<userId>` key scheme.
  final Map<String, bool> biometricEnabledByUser = {};
  String currentUserId = 'user-a';
  final List<String> setBiometricEnabledCalls = [];

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
  Future<void> verifySessionAlive() async {
    verifySessionAliveCalled = true;
    if (throwOnVerifySessionAlive != null) throw throwOnVerifySessionAlive!;
  }

  @override
  Future<bool> isBiometricLoginEnabled() async =>
      biometricEnabledByUser[currentUserId] ?? false;

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    biometricEnabledByUser[currentUserId] = enabled;
    setBiometricEnabledCalls.add(currentUserId);
  }

  @override
  Future<bool> shouldShowBiometricEnablePrompt() async => shouldShowPrompt;

  @override
  Future<void> markBiometricPromptShown() async {
    markBiometricPromptShownCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeBiometricLoginRepository extends BiometricLoginRepository {
  _FakeBiometricLoginRepository() : super(LocalAuthentication());

  bool deviceCapable = true;
  bool authenticateResult = true;
  Object? throwOnAuthenticate;
  bool authenticateCalled = false;

  @override
  Future<bool> isDeviceCapable() async => deviceCapable;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCalled = true;
    if (throwOnAuthenticate != null) throw throwOnAuthenticate!;
    return authenticateResult;
  }
}

Widget _harness(_FakeAuthRepository fake, _FakeBiometricLoginRepository bio) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fake),
      biometricLoginRepositoryProvider.overrideWithValue(bio),
    ],
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
          GoRoute(
            path: '/forgot-password',
            builder: (context, state) =>
                const Scaffold(body: Text('forgot-password')),
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
  testWidgets('successful password sign-in calls signInWithPassword', (
    tester,
  ) async {
    final fake = _FakeAuthRepository();
    final bio = _FakeBiometricLoginRepository()..deviceCapable = false;
    await tester.pumpWidget(_harness(fake, bio));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(fake.signedInEmail, 'user@example.com');
  });

  testWidgets(
    'a phone-number-shaped identifier fails with the same generic message as any invalid credential (FR-005)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..throwOnSignInWithPassword = const AuthApiException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        );
      final bio = _FakeBiometricLoginRepository()..deviceCapable = false;
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '0901234567');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      // Same generic "Đăng nhập thất bại: ..." message as any other failed
      // credential — no special-cased "that looks like a phone number"
      // branch anywhere in the sign-in path.
      expect(find.textContaining('Đăng nhập thất bại'), findsOneWidget);
    },
  );

  testWidgets(
    'fingerprint button is shown only when the device is capable AND biometric is enabled (FR-008)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..biometricEnabledByUser['user-a'] = true;
      final bio = _FakeBiometricLoginRepository()..deviceCapable = true;
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập bằng vân tay'), findsOneWidget);
    },
  );

  testWidgets(
    'fingerprint button is hidden when biometric is not enabled for this account',
    (tester) async {
      final fake = _FakeAuthRepository(); // enabled defaults to false
      final bio = _FakeBiometricLoginRepository()..deviceCapable = true;
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập bằng vân tay'), findsNothing);
    },
  );

  testWidgets(
    'fingerprint button is hidden when the device is not capable, even if enabled for this account',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..biometricEnabledByUser['user-a'] = true;
      final bio = _FakeBiometricLoginRepository()..deviceCapable = false;
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập bằng vân tay'), findsNothing);
    },
  );

  testWidgets(
    'biometric enabled for Account A does not unlock Account B on the same device (FR-013)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..biometricEnabledByUser['user-a'] = true
        ..currentUserId = 'user-b';
      final bio = _FakeBiometricLoginRepository()..deviceCapable = true;
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      // Account B has never enabled it, even though Account A did.
      expect(find.text('Đăng nhập bằng vân tay'), findsNothing);
    },
  );

  testWidgets(
    'tapping the fingerprint button, on success, verifies the session and unlocks (FR-011)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..biometricEnabledByUser['user-a'] = true;
      final bio = _FakeBiometricLoginRepository()
        ..deviceCapable = true
        ..authenticateResult = true;
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng nhập bằng vân tay'));
      await tester.pumpAndSettle();

      expect(bio.authenticateCalled, isTrue);
      expect(fake.verifySessionAliveCalled, isTrue);
    },
  );

  testWidgets(
    'a cancelled/failed biometric check falls back to the password fields with typed data intact (FR-012)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..biometricEnabledByUser['user-a'] = true;
      final bio = _FakeBiometricLoginRepository()
        ..deviceCapable = true
        ..authenticateResult = false; // user cancelled
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.enterText(find.byType(TextField).last, 'typed-password');
      await tester.tap(find.text('Đăng nhập bằng vân tay'));
      await tester.pumpAndSettle();

      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('typed-password'), findsOneWidget);
      expect(fake.signedInEmail, isNull);
    },
  );

  testWidgets(
    'noBiometricsEnrolled hides the button going forward and clears the preference (FR-014)',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..biometricEnabledByUser['user-a'] = true;
      final bio = _FakeBiometricLoginRepository()
        ..deviceCapable = true
        ..throwOnAuthenticate = const LocalAuthException(
          code: LocalAuthExceptionCode.noBiometricsEnrolled,
        );
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng nhập bằng vân tay'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập bằng vân tay'), findsNothing);
      expect(fake.setBiometricEnabledCalls, contains('user-a'));
      expect(fake.biometricEnabledByUser['user-a'], isFalse);
    },
  );

  testWidgets(
    'the one-time enable-biometric prompt appears after a successful password sign-in when never shown before (FR-009)',
    (tester) async {
      final fake = _FakeAuthRepository()..shouldShowPrompt = true;
      final bio = _FakeBiometricLoginRepository()..deviceCapable = true;
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Bật đăng nhập vân tay?'), findsOneWidget);
      expect(fake.markBiometricPromptShownCalled, isTrue);
    },
  );

  testWidgets(
    'the prompt does not appear again once shouldShowBiometricEnablePrompt reports false (already asked before)',
    (tester) async {
      final fake = _FakeAuthRepository()..shouldShowPrompt = false;
      final bio = _FakeBiometricLoginRepository()..deviceCapable = true;
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'user@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Bật đăng nhập vân tay?'), findsNothing);
      expect(fake.markBiometricPromptShownCalled, isFalse);
    },
  );

  testWidgets(
    'biometric succeeds locally but the session is actually dead — falls back to password, not a false signed-in state',
    (tester) async {
      final fake = _FakeAuthRepository()
        ..biometricEnabledByUser['user-a'] = true
        ..throwOnVerifySessionAlive = const AuthException('Session expired');
      final bio = _FakeBiometricLoginRepository()
        ..deviceCapable = true
        ..authenticateResult = true;
      await tester.pumpWidget(_harness(fake, bio));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng nhập bằng vân tay'));
      await tester.pumpAndSettle();

      expect(fake.verifySessionAliveCalled, isTrue);
      expect(find.text('Đăng nhập bằng vân tay'), findsNothing);
      expect(fake.biometricEnabledByUser['user-a'], isFalse);
    },
  );
}
