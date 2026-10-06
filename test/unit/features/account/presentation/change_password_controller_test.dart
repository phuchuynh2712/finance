import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/account/application/change_password_service.dart';
import 'package:finance/features/account/presentation/change_password_controller.dart';

class _FakeService extends Fake implements ChangePasswordService {
  int calls = 0;
  String? lastCurrent;
  String? lastNew;
  Completer<ChangePasswordResult>? gate;
  ChangePasswordResult result = const ChangePasswordResult(
    ChangePasswordOutcome.changed,
  );

  @override
  Future<ChangePasswordResult> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls++;
    lastCurrent = currentPassword;
    lastNew = newPassword;
    if (gate != null) return gate!.future;
    return result;
  }
}

const _current = 'old-password-1';
const _next = 'new-password-2';

void main() {
  late AppLocalizations vi;
  late AppLocalizations en;
  late _FakeService service;
  late ChangePasswordController controller;

  setUpAll(() async {
    vi = await AppLocalizations.delegate.load(const Locale('vi'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    service = _FakeService();
    controller = ChangePasswordController(service);
  });

  tearDown(() => controller.dispose());

  Future<ChangePasswordOutcome?> submit({
    String current = _current,
    String newPassword = _next,
    String? confirm,
  }) => controller.submit(
    current: current,
    newPassword: newPassword,
    confirm: confirm ?? newPassword,
  );

  void expectMessage(
    ChangePasswordIssue? issue,
    ChangePasswordIssueKind kind,
    String Function(AppLocalizations) expected,
  ) {
    expect(issue, isNotNull);
    expect(issue!.kind, kind);
    expect(issue.message(vi), expected(vi));
    expect(issue.message(en), expected(en));
  }

  group('validation (data-model.md §2) — no request is made', () {
    test('an empty current password is required', () async {
      final outcome = await submit(current: '');

      expect(outcome, isNull);
      expect(service.calls, 0);
      expectMessage(
        controller.state.currentIssue,
        ChangePasswordIssueKind.currentRequired,
        (l) => l.changePasswordCurrentRequiredError,
      );
    });

    test('a 7-character new password is too short', () async {
      final outcome = await submit(newPassword: '1234567');

      expect(outcome, isNull);
      expect(service.calls, 0);
      expectMessage(
        controller.state.newIssue,
        ChangePasswordIssueKind.tooShort,
        (l) => l.passwordTooShortError,
      );
    });

    test('a new password equal to the current one is rejected', () async {
      final outcome = await submit(current: _current, newPassword: _current);

      expect(outcome, isNull);
      expect(service.calls, 0);
      expectMessage(
        controller.state.newIssue,
        ChangePasswordIssueKind.sameAsCurrent,
        (l) => l.changePasswordSameAsCurrentError,
      );
    });

    test('a mismatched confirmation is rejected', () async {
      final outcome = await submit(confirm: 'different-password');

      expect(outcome, isNull);
      expect(service.calls, 0);
      expectMessage(
        controller.state.confirmIssue,
        ChangePasswordIssueKind.mismatch,
        (l) => l.resetPasswordMismatchError,
      );
    });

    test('too short wins over same-as-current for the new field', () async {
      await submit(current: 'short', newPassword: 'short');

      expect(controller.state.newIssue?.kind, ChangePasswordIssueKind.tooShort);
    });

    test('independent problems are all shown together', () async {
      await submit(current: '', newPassword: 'short', confirm: 'other');

      expect(
        controller.state.currentIssue?.kind,
        ChangePasswordIssueKind.currentRequired,
      );
      expect(controller.state.newIssue?.kind, ChangePasswordIssueKind.tooShort);
      expect(
        controller.state.confirmIssue?.kind,
        ChangePasswordIssueKind.mismatch,
      );
      expect(service.calls, 0);
      expect(controller.state.isSubmitting, isFalse);
    });
  });

  group('submitting', () {
    test('a valid form calls the service once with the typed values', () async {
      final outcome = await submit();

      expect(outcome, ChangePasswordOutcome.changed);
      expect(service.calls, 1);
      expect(service.lastCurrent, _current);
      expect(service.lastNew, _next);
      expect(controller.state.isSubmitting, isFalse);
      expect(controller.state.hasIssues, isFalse);
    });

    test(
      'changedOthersNotEnded is reported to the screen to pop with',
      () async {
        service.result = const ChangePasswordResult(
          ChangePasswordOutcome.changedOthersNotEnded,
          SocketException('offline'),
        );

        expect(await submit(), ChangePasswordOutcome.changedOthersNotEnded);
        expect(controller.state.hasIssues, isFalse);
      },
    );

    test(
      'is single-flight: a second submit while one runs is ignored',
      () async {
        service.gate = Completer<ChangePasswordResult>();

        final first = submit();
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.isSubmitting, isTrue);

        final second = await submit();
        expect(second, isNull);
        expect(service.calls, 1);

        service.gate!.complete(
          const ChangePasswordResult(ChangePasswordOutcome.changed),
        );
        expect(await first, ChangePasswordOutcome.changed);
        expect(controller.state.isSubmitting, isFalse);
      },
    );

    test('clearIssues is ignored while a request is in flight', () async {
      service.gate = Completer<ChangePasswordResult>();
      final pending = submit();
      await Future<void>.delayed(Duration.zero);

      controller.clearIssues();
      expect(controller.state.isSubmitting, isTrue);

      service.gate!.complete(
        const ChangePasswordResult(ChangePasswordOutcome.changed),
      );
      await pending;
    });
  });

  group(
    'failure results (data-model.md §3) — text comes from the shared mapper',
    () {
      Future<void> failWith(ChangePasswordOutcome outcome, Object error) async {
        service.result = ChangePasswordResult(outcome, error);
        expect(await submit(), isNull);
        expect(controller.state.isSubmitting, isFalse);
      }

      test(
        'wrongCurrentPassword is a field error on the current password',
        () async {
          await failWith(
            ChangePasswordOutcome.wrongCurrentPassword,
            const AuthApiException(
              'Invalid login credentials',
              statusCode: '400',
              code: 'invalid_credentials',
            ),
          );

          expectMessage(
            controller.state.currentIssue,
            ChangePasswordIssueKind.wrongCurrent,
            (l) => l.changePasswordWrongCurrentError,
          );
          expect(controller.state.bannerIssue, isNull);
        },
      );

      test('sameAsCurrent is a field error on the new password', () async {
        await failWith(
          ChangePasswordOutcome.sameAsCurrent,
          const AuthApiException(
            'same',
            statusCode: '422',
            code: 'same_password',
          ),
        );

        expect(
          controller.state.newIssue?.message(vi),
          vi.changePasswordSameAsCurrentError,
        );
        expect(controller.state.bannerIssue, isNull);
      });

      test('weakPassword is a field error with the 8-character copy', () async {
        await failWith(
          ChangePasswordOutcome.weakPassword,
          const AuthApiException(
            'weak',
            statusCode: '422',
            code: 'weak_password',
          ),
        );

        expect(
          controller.state.newIssue?.message(vi),
          vi.errorMapperWeakPassword,
        );
        expect(
          controller.state.newIssue?.message(en),
          en.errorMapperWeakPassword,
        );
      });

      final bannerCases =
          <(ChangePasswordOutcome, Object, String Function(AppLocalizations))>[
            (
              ChangePasswordOutcome.rateLimited,
              const AuthApiException(
                'slow down',
                statusCode: '429',
                code: 'over_request_rate_limit',
              ),
              (l) => l.errorMapperRateLimited,
            ),
            (
              ChangePasswordOutcome.offline,
              const SocketException('down'),
              (l) => l.errorMapperNetworkFailure,
            ),
            (
              ChangePasswordOutcome.sessionExpired,
              const AuthApiException(
                'gone',
                statusCode: '400',
                code: 'refresh_token_not_found',
              ),
              (l) => l.errorMapperSessionExpired,
            ),
            (
              ChangePasswordOutcome.failed,
              StateError('boom'),
              (l) => l.errorMapperGeneric,
            ),
          ];
      for (final (outcome, error, message) in bannerCases) {
        test('$outcome is a banner', () async {
          await failWith(outcome, error);

          expect(controller.state.bannerIssue?.message(vi), message(vi));
          expect(controller.state.bannerIssue?.message(en), message(en));
          expect(controller.state.currentIssue, isNull);
          expect(controller.state.newIssue, isNull);
        });
      }

      test('editing a field clears the shown issues', () async {
        await failWith(
          ChangePasswordOutcome.offline,
          const SocketException('x'),
        );
        expect(controller.state.hasIssues, isTrue);

        controller.clearIssues();

        expect(controller.state.hasIssues, isFalse);
      });

      test('a second attempt starts from a clean slate', () async {
        await failWith(
          ChangePasswordOutcome.offline,
          const SocketException('x'),
        );
        service.result = const ChangePasswordResult(
          ChangePasswordOutcome.changed,
        );

        expect(await submit(), ChangePasswordOutcome.changed);
        expect(controller.state.hasIssues, isFalse);
      });
    },
  );
}
