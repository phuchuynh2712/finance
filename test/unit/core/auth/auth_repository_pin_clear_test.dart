import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';

class _FakeAuth extends Fake implements GoTrueClient {
  _FakeAuth(this.user);

  User? user;
  final signOutScopes = <SignOutScope>[];

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    signOutScopes.add(scope);
    // The session goes away: the account can no longer be resolved.
    user = null;
  }
}

class _FakeClient extends Fake implements SupabaseClient {
  _FakeClient(this._auth);

  final _FakeAuth _auth;

  @override
  GoTrueClient get auth => _auth;
}

User _user(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

/// FR-018: a local sign-out takes the PIN of the account off this device.
void main() {
  const storage = FlutterSecureStorage();
  late _FakeAuth auth;
  late AuthRepository repository;
  late PinLockRepository pins;
  late String? currentId;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    auth = _FakeAuth(_user('user-a'));
    currentId = 'user-a';
    pins = SecurePinLockRepository(
      storage: storage,
      userId: () => currentId,
      now: () => DateTime.utc(2026, 3, 1, 9),
    );
    // The repository resolves the account from the client at the time of the
    // call (before the session goes away), exactly as it does for biometrics.
    repository = AuthRepository(_FakeClient(auth), pinLock: pins);

    await storage.write(key: 'BIOMETRIC_ENABLED_user-a', value: 'true');
    await storage.write(key: 'BIOMETRIC_PROMPT_SHOWN_user-a', value: 'true');
    await pins.set('483920');
    await pins.verify('000001');
    await pins.markOfferShown();
  });

  test('a local sign-out clears the PIN record and the count', () async {
    await repository.signOut();
    expect(await storage.read(key: 'PIN_RECORD_user-a'), isNull);
    expect(await storage.read(key: 'PIN_FAILS_user-a'), isNull);
    expect(auth.signOutScopes, [SignOutScope.local]);
  });

  test('it keeps the one-time offer marker', () async {
    await repository.signOut();
    expect(await storage.read(key: 'PIN_OFFER_SHOWN_user-a'), 'true');
  });

  test('the biometric clearing still happens', () async {
    await repository.signOut();
    expect(await storage.read(key: 'BIOMETRIC_ENABLED_user-a'), isNull);
    expect(await storage.read(key: 'BIOMETRIC_PROMPT_SHOWN_user-a'), isNull);
  });

  test('another account\'s PIN, count and marker are untouched', () async {
    currentId = 'user-b';
    await pins.set('594031');
    await pins.verify('000001');
    await pins.markOfferShown();
    currentId = 'user-a';

    await repository.signOut();

    expect(await storage.read(key: 'PIN_RECORD_user-b'), isNotNull);
    expect(await storage.read(key: 'PIN_FAILS_user-b'), '1');
    expect(await storage.read(key: 'PIN_OFFER_SHOWN_user-b'), 'true');
  });

  test(
    'signing out of other sessions leaves this device\'s PIN alone',
    () async {
      await repository.signOut(scope: SignOutScope.others);
      expect(await storage.read(key: 'PIN_RECORD_user-a'), isNotNull);
      expect(await storage.read(key: 'PIN_FAILS_user-a'), '1');
    },
  );

  test('a failing PIN clear never stops the sign-out', () async {
    final repo = AuthRepository(_FakeClient(auth), pinLock: _ThrowingPins());
    await repo.signOut();
    expect(auth.signOutScopes, [SignOutScope.local]);
  });

  test('without a PIN repository (the web) sign-out still works', () async {
    final repo = AuthRepository(_FakeClient(auth));
    await repo.signOut();
    expect(auth.signOutScopes, [SignOutScope.local]);
    expect(await storage.read(key: 'BIOMETRIC_ENABLED_user-a'), isNull);
  });
}

class _ThrowingPins implements PinLockRepository {
  @override
  Future<void> clear() async => throw StateError('storage unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
