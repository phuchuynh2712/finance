import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:finance/core/auth/auth_repository.dart';
import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/auth/biometric_login_repository.dart';
import 'package:finance/core/auth/pin_lock_repository.dart';
import 'package:finance/features/account/presentation/account_controller.dart';

/// What the biometric switch shows (data-model.md §4): the stored preference
/// for this account on this device, and whether the device can use it at all.
class SecuritySettings {
  const SecuritySettings({
    required this.availability,
    required this.preferenceEnabled,
  });

  final BiometricAvailability availability;

  /// The stored per-account, per-device preference (unchanged by this screen
  /// unless the person flips the switch).
  final bool preferenceEnabled;

  /// On only when the preference is stored *and* it can actually be used, so
  /// the switch never claims a feature that no longer works (for instance after
  /// the person removed their enrolled fingerprints).
  bool get switchOn =>
      preferenceEnabled && availability == BiometricAvailability.available;

  /// Off the switch when biometrics are unavailable; the screen then explains
  /// why instead of failing silently.
  bool get switchEnabled => availability == BiometricAvailability.available;
}

/// One-shot messages for the screen to show once and then clear.
enum SecurityNotice {
  /// Turning the switch on was cancelled or failed, so it stayed off.
  enableFailed,
}

class SecurityState {
  const SecurityState({this.settings, this.isChanging = false, this.notice});

  /// `null` until availability and the stored preference have been read, so the
  /// screen shows the switch disabled instead of flashing a wrong state.
  final SecuritySettings? settings;

  /// A biometric check or a preference write is running (single-flight).
  final bool isChanging;

  final SecurityNotice? notice;

  bool get isLoaded => settings != null;

  SecurityState copyWith({
    SecuritySettings? settings,
    bool? isChanging,
    SecurityNotice? notice,
    bool clearNotice = false,
  }) => SecurityState(
    settings: settings ?? this.settings,
    isChanging: isChanging ?? this.isChanging,
    notice: clearNotice ? null : (notice ?? this.notice),
  );
}

class SecurityController extends StateNotifier<SecurityState> {
  SecurityController({
    required BiometricLoginRepository biometric,
    required AccountAuthActions account,
  }) : _biometric = biometric,
       _account = account,
       super(const SecurityState()) {
    refresh();
  }

  final BiometricLoginRepository _biometric;
  final AccountAuthActions _account;

  /// Re-reads availability and the stored preference. Called on open and when
  /// the app resumes, so removing enrollment in system settings shows up as
  /// soon as the person comes back.
  Future<void> refresh() async {
    // A platform failure must not leave the switch loading forever: treat an
    // unreadable device as one that cannot do biometrics (the switch stays off
    // and says so) and an unreadable preference as "not enabled".
    final BiometricAvailability availability;
    try {
      availability = await _biometric.availability();
    } catch (_) {
      return _setSettings(BiometricAvailability.noHardware, false);
    }
    bool preference;
    try {
      preference = await _account.isBiometricLoginEnabled();
    } catch (_) {
      preference = false;
    }
    _setSettings(availability, preference);
  }

  void _setSettings(BiometricAvailability availability, bool preference) {
    if (!mounted) return;
    state = state.copyWith(
      settings: SecuritySettings(
        availability: availability,
        preferenceEnabled: preference,
      ),
    );
  }

  /// Turning it **on** needs one successful biometric check so a person cannot
  /// switch on something that cannot work; a cancelled or failed check leaves
  /// it off. Turning it **off** is immediate with no check. [localizedReason]
  /// is the text of the system prompt (the controller has no `BuildContext`).
  Future<void> setEnabled(
    bool enabled, {
    required String localizedReason,
  }) async {
    final settings = state.settings;
    if (state.isChanging || settings == null) return;
    if (enabled && !settings.switchEnabled) return;

    state = state.copyWith(isChanging: true, clearNotice: true);
    try {
      if (enabled) {
        final confirmed = await _confirmBiometric(localizedReason);
        if (!mounted) return;
        if (!confirmed) {
          state = state.copyWith(notice: SecurityNotice.enableFailed);
          return;
        }
      }
      await _account.setBiometricLoginEnabled(enabled);
      if (!mounted) return;
      state = state.copyWith(
        settings: SecuritySettings(
          availability: settings.availability,
          preferenceEnabled: enabled,
        ),
      );
    } finally {
      if (mounted) state = state.copyWith(isChanging: false);
    }
  }

  Future<bool> _confirmBiometric(String localizedReason) async {
    try {
      return await _biometric.authenticate(localizedReason: localizedReason);
    } on LocalAuthException {
      return false;
    }
  }

  void clearNotice() {
    if (state.notice == null) return;
    state = state.copyWith(clearNotice: true);
  }
}

final securityControllerProvider =
    StateNotifierProvider.autoDispose<SecurityController, SecurityState>((ref) {
      return SecurityController(
        biometric: ref.watch(biometricLoginRepositoryProvider),
        account: ref.watch(accountAuthActionsProvider),
      );
    });

/// What the PIN row of the Security screen shows (`contracts/pin-ui.md` §4).
enum PinRowState {
  /// No row: the web, or biometrics work and no PIN exists.
  hidden,

  /// A PIN may be created and none is set.
  off,

  /// A PIN is set and still counts.
  active,

  /// A PIN is set but older than 12 months.
  expired,
}

/// The row's state from the PIN status and whether a PIN may be created. A row
/// is shown whenever a PIN exists, even on a device that has since gained
/// biometrics, so the person can still turn it off.
final pinRowStateProvider = Provider.autoDispose<PinRowState>((ref) {
  final status = ref.watch(pinStatusProvider).valueOrNull ?? PinStatus.none;
  final available = ref.watch(pinAvailableProvider).valueOrNull ?? false;
  return switch (status) {
    PinStatus.active => PinRowState.active,
    PinStatus.expired => PinRowState.expired,
    PinStatus.none => available ? PinRowState.off : PinRowState.hidden,
  };
});
