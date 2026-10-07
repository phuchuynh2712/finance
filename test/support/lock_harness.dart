import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/account/presentation/sign_in_screen.dart';

import 'expense_screen_harness.dart' show useView;

/// A session for [userId], enough for the lock providers.
Session lockTestSession([String userId = 'user-a']) => Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  ),
);

/// The auth repository the lock screen talks to. It records every call that
/// would leave the device (`networkCalls`), so a test can assert that a PIN
/// unlock made none.
class FakeLockAuthRepository implements AuthRepository {
  /// `signInWithPassword` or `verifySessionAlive`, in the order they were made.
  final networkCalls = <String>[];
  Object? throwOnSignInWithPassword;
  bool biometricEnabled = false;
  bool showBiometricPrompt = false;
  var biometricPromptShown = 0;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    networkCalls.add('signInWithPassword');
    await Future<void>.delayed(Duration.zero);
    if (throwOnSignInWithPassword != null) throw throwOnSignInWithPassword!;
  }

  @override
  Future<void> verifySessionAlive() async {
    networkCalls.add('verifySessionAlive');
  }

  @override
  Future<bool> isBiometricLoginEnabled() async => biometricEnabled;

  @override
  Future<void> setBiometricLoginEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }

  @override
  Future<bool> shouldShowBiometricEnablePrompt() async => showBiometricPrompt;

  @override
  Future<void> markBiometricPromptShown() async {
    biometricPromptShown++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeLockAuthRepository.${invocation.memberName}',
  );
}

/// What the biometric hardware of the device under test can do.
class FakeLockBiometric extends Fake implements BiometricLoginRepository {
  FakeLockBiometric(this.availabilityValue);

  BiometricAvailability availabilityValue;

  /// What `isDeviceCapable` answers; by default whether biometrics are usable.
  /// A test may force `true` next to a `noHardware` availability to make both
  /// the biometric and the PIN offer appear, to check their order.
  bool? deviceCapable;
  var authenticateCalls = 0;

  @override
  Future<BiometricAvailability> availability() async => availabilityValue;

  @override
  Future<bool> isDeviceCapable() async =>
      deviceCapable ?? availabilityValue == BiometricAvailability.available;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCalls++;
    return true;
  }
}

/// A [PinLockRepository] over the in-memory secure storage, for the account
/// [userId], with a clock the test can move.
class LockTestPins {
  LockTestPins({String? userId = 'user-a', DateTime? now})
    : now = now ?? DateTime.utc(2026, 3, 1, 9),
      _userId = userId {
    FlutterSecureStorage.setMockInitialValues({});
    repository = SecurePinLockRepository(
      storage: const FlutterSecureStorage(),
      userId: () => _userId,
      now: () => this.now,
    );
  }

  DateTime now;
  String? _userId;
  late final PinLockRepository repository;
  final storage = const FlutterSecureStorage();

  set userId(String? value) => _userId = value;

  Future<String?> raw(String key) => storage.read(key: '${key}_$_userId');
}

/// The app lock, starting locked (or not) by itself so the harness does not
/// depend on the order of the first auth event and the notifier's creation.
class _TestLock extends AppLockNotifier {
  _TestLock(super.ref, {required bool startLocked}) {
    if (startLocked) lock();
  }
}

/// What [pumpLockGate] built.
class LockGate {
  LockGate({
    required this.container,
    required this.auth,
    required this.biometric,
    required this.pins,
  });

  final ProviderContainer container;
  final FakeLockAuthRepository auth;
  final FakeLockBiometric biometric;
  final LockTestPins pins;

  bool get isLocked => container.read(appLockProvider);
}

/// Mounts a stand-in for the router's lock gate: the lock screen
/// ([SignInScreen] by default) while `appLockProvider` is locked or nobody is
/// signed in, a plain `home` marker otherwise. The auth stream is stubbed so the app
/// starts the way a cold start with a saved session does: signed in and
/// locked (`locked: false` unlocks it right after; `signedIn: false` starts
/// signed out, which shows the ordinary sign-in screen).
///
/// [pinAvailable] overrides are not needed: the real providers read the fake
/// biometric repository, so `BiometricAvailability.noHardware` makes a PIN
/// available and `available` does not.
Future<LockGate> pumpLockGate(
  WidgetTester tester, {
  Widget Function()? lockScreen,
  Locale locale = const Locale('vi'),
  double width = 410,
  double height = 864,
  ThemeData? theme,
  BiometricAvailability availability = BiometricAvailability.noHardware,
  bool? deviceCapable,
  bool locked = true,
  bool signedIn = true,
  LockTestPins? pins,
  FakeLockAuthRepository? auth,
  List<Override> overrides = const [],
}) async {
  useView(tester, width, height);
  final fakeAuth = auth ?? FakeLockAuthRepository();
  final fakeBiometric = FakeLockBiometric(availability)
    ..deviceCapable = deviceCapable;
  final fakePins = pins ?? LockTestPins();
  final events = StreamController<AuthState>();
  addTearDown(events.close);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) =>
              (ref.watch(appLockProvider) || !ref.watch(isSignedInProvider))
              ? (lockScreen?.call() ?? const SignInScreen())
              : const Scaffold(body: Center(child: Text('home'))),
        ),
      ),
      GoRoute(
        path: '/account/security/pin/:mode',
        builder: (context, state) =>
            Scaffold(body: Text('pin-flow-${state.pathParameters['mode']}')),
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
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        authStateChangesProvider.overrideWith((ref) => events.stream),
        appLockProvider.overrideWith(
          (ref) => _TestLock(ref, startLocked: locked && signedIn),
        ),
        biometricLoginRepositoryProvider.overrideWithValue(fakeBiometric),
        pinLockRepositoryProvider.overrideWithValue(fakePins.repository),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme ?? AppTheme.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  // The first auth event: a saved session, or none.
  events.add(
    AuthState(
      AuthChangeEvent.initialSession,
      signedIn ? lockTestSession() : null,
    ),
  );
  await tester.pump();
  await tester.pump();
  if (!locked) container.read(appLockProvider.notifier).unlock();
  await tester.pump();
  return LockGate(
    container: container,
    auth: fakeAuth,
    biometric: fakeBiometric,
    pins: fakePins,
  );
}
