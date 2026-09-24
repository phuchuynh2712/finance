import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps `local_auth` for device biometric (fingerprint/Face ID) quick login
/// (FR-008/FR-011/FR-012/FR-014). Kept separate from [AuthRepository] since
/// it wraps a different SDK (device hardware, not Supabase) — mirrors the
/// constitution's one-repository-per-external-dependency layering.
///
/// This never performs authentication against Supabase itself: a successful
/// [authenticate] call only unlocks a session [AuthRepository] already holds
/// (spec.md Assumptions — biometric is a local convenience layer, not a new
/// identity provider).
class BiometricLoginRepository {
  BiometricLoginRepository(this._localAuth);

  final LocalAuthentication _localAuth;

  /// True only when the device has biometric hardware AND at least one
  /// fingerprint/face is enrolled at the OS level (FR-008's device-capable
  /// half of the AND condition).
  Future<bool> isDeviceCapable() async {
    if (kIsWeb) return false;
    final canCheck = await _localAuth.canCheckBiometrics;
    final supported = await _localAuth.isDeviceSupported();
    return canCheck && supported;
  }

  /// Triggers the native biometric prompt. Returns `true` on success,
  /// `false` if the user cancels; rethrows [LocalAuthException] for the
  /// caller to map per the error table in
  /// contracts/auth_repository_interface.md (FR-012/FR-014).
  Future<bool> authenticate({required String localizedReason}) {
    if (kIsWeb) return Future.value(false);
    return _localAuth.authenticate(
      localizedReason: localizedReason,
      biometricOnly: true,
    );
  }
}
