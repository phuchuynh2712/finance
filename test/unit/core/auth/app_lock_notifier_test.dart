import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_state_provider.dart';

/// Pins FR-003's cold-start rule, which nothing tested before the inactivity
/// lock started to interact with lock transitions: a session already present
/// at the first auth event locks the app; nothing after that locks it again.
void main() {
  final session = Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: const User(
      id: 'u1',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );

  late StreamController<AuthState> events;
  late ProviderContainer container;

  setUp(() {
    events = StreamController<AuthState>();
    container = ProviderContainer(
      overrides: [
        authStateChangesProvider.overrideWith((ref) => events.stream),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    events.close();
  });

  /// Delivers [state] and waits until the provider holds it.
  Future<void> emit(AuthState state) async {
    events.add(state);
    await pumpEventQueue();
  }

  /// Delivers [first] and reads the lock once it has arrived.
  Future<bool> firstEvent(AuthState first) async {
    await emit(first);
    await container.read(authStateChangesProvider.future);
    return container.read(appLockProvider);
  }

  test('a session already present at the first event locks the app', () async {
    expect(
      await firstEvent(AuthState(AuthChangeEvent.initialSession, session)),
      isTrue,
    );
  });

  test('no session at the first event leaves it unlocked, and a sign-in '
      'afterwards does not lock it', () async {
    expect(
      await firstEvent(const AuthState(AuthChangeEvent.initialSession, null)),
      isFalse,
    );
    await emit(AuthState(AuthChangeEvent.signedIn, session));
    expect(container.read(appLockProvider), isFalse);
  });

  test('a later event never locks again, even with a session', () async {
    await firstEvent(const AuthState(AuthChangeEvent.initialSession, null));
    await emit(AuthState(AuthChangeEvent.signedIn, session));
    await emit(AuthState(AuthChangeEvent.tokenRefreshed, session));
    expect(container.read(appLockProvider), isFalse);
  });

  // The activity tracker listens to the lock from the first frame, so the
  // notifier exists before the first auth event has arrived (a page reload
  // with a saved session must still land on the lock screen).
  group('created before the first auth event arrives', () {
    test('a restored session then locks the app', () async {
      expect(container.read(appLockProvider), isFalse);
      await emit(AuthState(AuthChangeEvent.initialSession, session));
      expect(container.read(appLockProvider), isTrue);
    });

    test('no session then leaves it unlocked, and a later sign-in does not '
        'lock it', () async {
      expect(container.read(appLockProvider), isFalse);
      await emit(const AuthState(AuthChangeEvent.initialSession, null));
      await emit(AuthState(AuthChangeEvent.signedIn, session));
      expect(container.read(appLockProvider), isFalse);
    });
  });

  test('lock() and unlock() flip the state', () async {
    await firstEvent(const AuthState(AuthChangeEvent.initialSession, null));
    final notifier = container.read(appLockProvider.notifier);
    notifier.lock();
    expect(container.read(appLockProvider), isTrue);
    notifier.unlock();
    expect(container.read(appLockProvider), isFalse);
  });
}
