import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/sync/sync_notice.dart';

/// Classifies permanent server refusals separately from retryable push
/// failures. The database stores [PushRefused.rejectReason] until the person
/// has acknowledged any associated [PushRefused.noticeReason].
sealed class PushFailure {
  const PushFailure();

  factory PushFailure.classify(Object error, {required String entityTable}) {
    if (error is! PostgrestException) return const PushTransient();

    return switch (error.code) {
      'TX001' => const PushRefused(
        rejectReason: 'invalid_reversal',
        noticeReason: SyncNoticeReason.deleted,
      ),
      'TX002' => const PushRefused(
        rejectReason: 'reversal_immutable',
        noticeReason: SyncNoticeReason.reversed,
      ),
      'TX003' => const PushRefused(
        rejectReason: 'transaction_reversed',
        noticeReason: SyncNoticeReason.reversed,
      ),
      '23505' when entityTable == 'financial_transactions' => const PushRefused(
        rejectReason: 'already_reversed',
        noticeReason: SyncNoticeReason.alreadyReversed,
      ),
      '23514' => const PushRefused(
        rejectReason: 'check_violation',
        noticeReason: null,
      ),
      _ => const PushTransient(),
    };
  }
}

final class PushTransient extends PushFailure {
  const PushTransient();
}

final class PushRefused extends PushFailure {
  const PushRefused({required this.rejectReason, required this.noticeReason});

  final String rejectReason;
  final SyncNoticeReason? noticeReason;
}
