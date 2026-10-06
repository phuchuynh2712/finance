import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Why biometric sign-in can or cannot be used on this device right now. The
/// Security screen turns each unavailable value into its own explanation
/// (`local_auth.canCheckBiometrics` alone cannot tell "no hardware" from
/// "nothing enrolled").
enum BiometricAvailability {
  /// Hardware present and at least one biometric enrolled.
  available,

  /// Running in a browser: there is no biometric API to use.
  webUnsupported,

  /// The device cannot check biometrics at all.
  noHardware,

  /// The device can, but no fingerprint or face is enrolled in system settings.
  notEnrolled,
}

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
  /// [isWeb] only feeds [availability] and exists so a VM test can exercise
  /// the web branch; it defaults to the real [kIsWeb].
  BiometricLoginRepository(this._localAuth, {bool? isWeb})
    : _isWeb = isWeb ?? kIsWeb;

  final LocalAuthentication _localAuth;
  final bool _isWeb;

  /// The detailed answer behind the Security screen's switch: whether
  /// biometric sign-in can be used, and if not, why. Detected at runtime, never
  /// assumed from the platform (constitution: capability detection).
  Future<BiometricAvailability> availability() async {
    if (_isWeb) return BiometricAvailability.webUnsupported;
    if (!await _localAuth.isDeviceSupported()) {
      return BiometricAvailability.noHardware;
    }
    final enrolled = await _localAuth.getAvailableBiometrics();
    return enrolled.isEmpty
        ? BiometricAvailability.notEnrolled
        : BiometricAvailability.available;
  }

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
