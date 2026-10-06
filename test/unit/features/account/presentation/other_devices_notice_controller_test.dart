import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/account/application/change_password_service.dart';
import 'package:finance/features/account/presentation/other_devices_notice_controller.dart';

class _FakeService extends Fake implements ChangePasswordService {
  int retries = 0;
  Completer<ChangePasswordResult>? gate;
  Object? throwOnRetry;
  ChangePasswordResult result = const ChangePasswordResult(
    ChangePasswordOutcome.changed,
  );

  @override
  Future<ChangePasswordResult> signOutOtherDevices() async {
    retries++;
    if (throwOnRetry != null) throw throwOnRetry!;
    if (gate != null) return gate!.future;
    return result;
  }
}

void main() {
  late _FakeService service;
  late OtherDevicesNoticeController controller;

  setUp(() {
    service = _FakeService();
    controller = OtherDevicesNoticeController(service);
  });

  tearDown(() => controller.dispose());

  test('starts hidden', () {
    expect(controller.state, OtherDevicesNotice.hidden);
  });

  test('show() makes the notice visible', () {
    controller.show();
    expect(controller.state, OtherDevicesNotice.notEnded);
  });

  test('a successful retry hides the notice and returns the result', () async {
    controller.show();

    final result = await controller.retry();

    expect(result?.outcome, ChangePasswordOutcome.changed);
    expect(controller.state, OtherDevicesNotice.hidden);
    expect(service.retries, 1);
  });

  test('retry goes retrying -> hidden while the service runs', () async {
    controller.show();
    service.gate = Completer<ChangePasswordResult>();

    final pending = controller.retry();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, OtherDevicesNotice.retrying);

    service.gate!.complete(
      const ChangePasswordResult(ChangePasswordOutcome.changed),
    );
    await pending;
    expect(controller.state, OtherDevicesNotice.hidden);
  });

  test('a failed retry goes back to notEnded and returns the error', () async {
    controller.show();
    final error = StateError('offline');
    service.result = ChangePasswordResult(
      ChangePasswordOutcome.changedOthersNotEnded,
      error,
    );

    final result = await controller.retry();

    expect(result?.outcome, ChangePasswordOutcome.changedOthersNotEnded);
    expect(result?.error, same(error));
    expect(controller.state, OtherDevicesNotice.notEnded);
  });

  test('an unexpected throw is wrapped as changedOthersNotEnded with that '
      'error and the notice stays', () async {
    controller.show();
    final error = StateError('unexpected');
    service.throwOnRetry = error;

    final result = await controller.retry();

    expect(result?.outcome, ChangePasswordOutcome.changedOthersNotEnded);
    expect(result?.error, same(error));
    expect(controller.state, OtherDevicesNotice.notEnded);
  });

  test('is single-flight: a second retry while retrying is ignored', () async {
    controller.show();
    service.gate = Completer<ChangePasswordResult>();

    final first = controller.retry();
    await Future<void>.delayed(Duration.zero);
    final second = await controller.retry();

    expect(second, isNull);
    expect(service.retries, 1);

    service.gate!.complete(
      const ChangePasswordResult(ChangePasswordOutcome.changed),
    );
    await first;
  });

  test('retry while hidden does nothing', () async {
    final result = await controller.retry();

    expect(result, isNull);
    expect(service.retries, 0);
    expect(controller.state, OtherDevicesNotice.hidden);
  });

  test('show() while a retry runs does not interrupt it', () async {
    controller.show();
    service.gate = Completer<ChangePasswordResult>();
    final pending = controller.retry();
    await Future<void>.delayed(Duration.zero);

    controller.show();
    expect(controller.state, OtherDevicesNotice.retrying);

    service.gate!.complete(
      const ChangePasswordResult(ChangePasswordOutcome.changed),
    );
    await pending;
  });
}
