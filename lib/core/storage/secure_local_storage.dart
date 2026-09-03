import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase Auth session in platform secure storage
/// (Keychain on iOS, Keystore-backed EncryptedSharedPreferences on Android)
/// instead of the plain `SharedPreferences` supabase_flutter uses by default,
/// per the constitution's Security section.
///
/// iOS builds may additionally need a Keychain Sharing entitlement added via
/// Xcode on first build on macOS — cannot be safely added blind from a
/// Windows dev environment (no `.entitlements` files exist in this project
/// yet).
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  static const _key = 'SUPABASE_PERSIST_SESSION_KEY';
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}
