import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/features/account/application/change_password_service.dart';
import 'package:finance/features/account/presentation/change_password_controller.dart';

/// State of the "password changed, but other devices were not signed out"
/// notice on the Security screen (data-model.md §3b).
enum OtherDevicesNotice {
  /// Nothing to show: the default, and after the other devices were signed out.
  hidden,

  /// The password changed but ending the other sessions failed. The notice is
  /// visible with a **Thử lại** button.
  notEnded,

  /// The retry is in flight (single-flight): the button shows a spinner.
  retrying,
}

class OtherDevicesNoticeController extends StateNotifier<OtherDevicesNotice> {
  OtherDevicesNoticeController(this._service)
    : super(OtherDevicesNotice.hidden);

  final ChangePasswordService _service;

  /// Called when the change-password screen pops with
  /// [ChangePasswordOutcome.changedOthersNotEnded].
  void show() {
    if (state == OtherDevicesNotice.hidden) {
      state = OtherDevicesNotice.notEnded;
    }
  }

  /// Retries only the "sign out other devices" step. Returns the service's
  /// result so the screen can confirm or show the mapped error, or `null`
  /// when ignored (nothing to retry, or a retry is already running).
  Future<ChangePasswordResult?> retry() async {
    if (state != OtherDevicesNotice.notEnded) return null;
    state = OtherDevicesNotice.retrying;

    ChangePasswordResult result;
    try {
      result = await _service.signOutOtherDevices();
    } catch (error) {
      result = ChangePasswordResult(
        ChangePasswordOutcome.changedOthersNotEnded,
        error,
      );
    }
    if (!mounted) return result;

    state = result.outcome == ChangePasswordOutcome.changed
        ? OtherDevicesNotice.hidden
        : OtherDevicesNotice.notEnded;
    return result;
  }
}

final otherDevicesNoticeControllerProvider =
    StateNotifierProvider.autoDispose<
      OtherDevicesNoticeController,
      OtherDevicesNotice
    >((ref) {
      return OtherDevicesNoticeController(
        ref.watch(changePasswordServiceProvider),
      );
    });
