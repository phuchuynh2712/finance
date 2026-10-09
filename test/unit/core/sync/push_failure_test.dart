import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/sync/push_failure.dart';
import 'package:finance/core/sync/sync_notice.dart';

void main() {
  PostgrestException exception(String? code) =>
      PostgrestException(message: 'server response', code: code);

  test('classifies transaction guard refusals into notice reasons', () {
    final cases = {
      'TX001': ('invalid_reversal', SyncNoticeReason.deleted),
      'TX002': ('reversal_immutable', SyncNoticeReason.reversed),
      'TX003': ('transaction_reversed', SyncNoticeReason.reversed),
      '23505': ('already_reversed', SyncNoticeReason.alreadyReversed),
    };

    for (final entry in cases.entries) {
      expect(
        PushFailure.classify(
          exception(entry.key),
          entityTable: 'financial_transactions',
        ),
        isA<PushRefused>()
            .having(
              (failure) => failure.rejectReason,
              'rejectReason',
              entry.value.$1,
            )
            .having(
              (failure) => failure.noticeReason,
              'noticeReason',
              entry.value.$2,
            ),
        reason: entry.key,
      );
    }
  });

  test('check violations are permanent but do not produce a notice', () {
    expect(
      PushFailure.classify(
        exception('23514'),
        entityTable: 'financial_transactions',
      ),
      isA<PushRefused>()
          .having(
            (failure) => failure.rejectReason,
            'rejectReason',
            'check_violation',
          )
          .having((failure) => failure.noticeReason, 'noticeReason', isNull),
    );
  });

  test('unique violations are specific to the transaction table', () {
    expect(
      PushFailure.classify(
        exception('23505'),
        entityTable: 'expense_control_items',
      ),
      isA<PushTransient>(),
    );
  });

  test('network, server and unknown errors remain transient', () {
    for (final error in [
      Exception('offline'),
      exception(null),
      exception('40001'),
      exception('50000'),
    ]) {
      expect(
        PushFailure.classify(error, entityTable: 'financial_transactions'),
        isA<PushTransient>(),
      );
    }
  });
}
