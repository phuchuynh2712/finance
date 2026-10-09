import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/sync/sync_notice.dart';
import 'package:finance/core/sync/sync_notices_provider.dart';

/// Shows each [SyncNotice] of the sync layer to the person exactly once, as a
/// snack bar, one after the other (the `ScaffoldMessenger` queues them), then
/// acknowledges it. Mounted once in the app shell, so the person is told the
/// next time they are on any screen of the app. It adds nothing but [child]
/// to the tree and costs nothing when there is no notice.
class SyncNoticeHost extends ConsumerStatefulWidget {
  const SyncNoticeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncNoticeHost> createState() => _SyncNoticeHostState();
}

class _SyncNoticeHostState extends ConsumerState<SyncNoticeHost> {
  late final SyncNotices _notices;
  StreamSubscription<SyncNotice>? _subscription;

  @override
  void initState() {
    super.initState();
    _notices = ref.read(syncNoticesProvider);
    _subscription = _notices.stream.listen(_show);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _show(SyncNotice notice) {
    if (!mounted) return;
    final message = _messageFor(AppLocalizations.of(context), notice);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (message == null || messenger == null) {
      // Nothing to say (or nowhere to say it): do not keep it open forever.
      unawaited(_notices.acknowledge(notice.id));
      return;
    }
    // A `SnackBar` is a live region, so a screen reader announces it.
    final controller = messenger.showSnackBar(SnackBar(content: Text(message)));
    unawaited(controller.closed.then((_) => _notices.acknowledge(notice.id)));
  }

  /// The sentence for [notice]. The reasons of the refusal and override
  /// notices come with their strings (transaction corrections).
  String? _messageFor(AppLocalizations l10n, SyncNotice notice) {
    if (notice.reason == SyncNoticeReason.balanceMismatch) {
      return l10n.syncBalanceMismatchNotice(notice.itemName);
    }
    final amount = notice.amount;
    if (amount == null) {
      throw StateError(
        'Correction notice ${notice.id} is missing its transaction amount.',
      );
    }
    final amountText = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    ).format(amount);
    return switch (notice.reason) {
      SyncNoticeReason.balanceMismatch => null,
      SyncNoticeReason.deleted => l10n.syncCorrectionDeletedNotice(
        notice.itemName,
        amountText,
      ),
      SyncNoticeReason.reversed => l10n.syncCorrectionReversedNotice(
        notice.itemName,
        amountText,
      ),
      SyncNoticeReason.alreadyReversed =>
        l10n.syncCorrectionAlreadyReversedNotice(notice.itemName, amountText),
      SyncNoticeReason.editedElsewhere =>
        l10n.syncCorrectionEditedElsewhereNotice(notice.itemName, amountText),
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
