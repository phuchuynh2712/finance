import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/balance_ledger.dart';
import 'sync_notice.dart';

/// Checks that the balance a device derives from its transactions agrees with
/// the balance the server reports for the same item (constitution,
/// Offline-First: a locally computed balance is never trusted as final; FR-018,
/// SC-008, research.md Decision 10).
///
/// [check] runs at settled points (after a catch-up pull completes and after a
/// drain that leaves nothing waiting). A difference only counts once it has
/// been seen twice, at least [settleDelay] apart, because an item row and its
/// transaction rows can legitimately arrive a moment apart. The first
/// confirmed difference triggers one [resync]; if it remains afterwards the
/// person is told once. Neither figure is ever overwritten here. A [resync]
/// that cannot run (nobody is signed in, so there is no pull service) answers
/// `false`: nothing is reported then, because the data was not synchronised
/// again, and the next settled point looks again.
class ReconciliationMonitor {
  ReconciliationMonitor({
    required Future<List<String>> Function() findDivergent,
    required Future<String> Function(String itemId) itemName,
    required void Function(SyncNotice notice) report,
    required Future<bool> Function() resync,
    this.settleDelay = const Duration(seconds: 10),
    DateTime Function() now = DateTime.now,
  }) : _findDivergent = findDivergent,
       _itemName = itemName,
       _report = report,
       _resync = resync,
       _now = now;

  /// The monitor of the app: reads the divergence from [db] and reports to
  /// [notices].
  factory ReconciliationMonitor.forDatabase(
    AppDatabase db,
    SyncNotices notices, {
    required Future<bool> Function() resync,
    Duration settleDelay = const Duration(seconds: 10),
  }) {
    return ReconciliationMonitor(
      findDivergent: () => BalanceLedger.findDivergent(db),
      itemName: (id) async {
        final row = await (db.select(
          db.expenseControlItems,
        )..where((i) => i.id.equals(id))).getSingleOrNull();
        return row?.name ?? '';
      },
      report: notices.report,
      resync: resync,
      settleDelay: settleDelay,
    );
  }

  final Future<List<String>> Function() _findDivergent;
  final Future<String> Function(String itemId) _itemName;
  final void Function(SyncNotice notice) _report;
  final Future<bool> Function() _resync;
  final DateTime Function() _now;

  /// How long a difference must persist before it counts.
  final Duration settleDelay;

  final Map<String, DateTime> _firstSeen = {};
  final Set<String> _resynced = {};
  final Set<String> _reported = {};
  Timer? _timer;
  Future<void>? _running;

  /// Looks for differences now. Overlapping calls share one run.
  Future<void> check() => _running ??= _check().whenComplete(() {
    _running = null;
  });

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    var divergent = (await _findDivergent()).toSet();
    _forgetConverged(divergent);

    final now = _now();
    for (final id in divergent) {
      _firstSeen.putIfAbsent(id, () => now);
    }
    bool settled(String id) =>
        !_reported.contains(id) &&
        now.difference(_firstSeen[id]!) >= settleDelay;
    final ready = divergent.where(settled).toList();

    var resyncFailed = false;
    var resyncUnavailable = false;
    if (ready.isNotEmpty) {
      final needsResync = ready.where((id) => !_resynced.contains(id)).toList();
      if (needsResync.isNotEmpty) {
        try {
          if (await _resync()) {
            _resynced.addAll(needsResync);
            divergent = (await _findDivergent()).toSet();
            _forgetConverged(divergent);
          } else {
            resyncUnavailable = true;
          }
        } catch (_) {
          // Offline, most likely: try again after another settle delay.
          resyncFailed = true;
        }
      }
      if (!resyncFailed && !resyncUnavailable) {
        for (final id in ready) {
          if (!divergent.contains(id) || _reported.contains(id)) continue;
          _reported.add(id);
          debugPrint(
            'Balance of item $id still differs from the server after a '
            're-synchronisation',
          );
          _report(
            SyncNotice(
              id: 'mismatch:$id',
              reason: SyncNoticeReason.balanceMismatch,
              itemName: await _itemName(id),
            ),
          );
        }
      }
    }

    _scheduleNext(resyncFailed: resyncFailed);
  }

  void _forgetConverged(Set<String> divergent) {
    _firstSeen.removeWhere((id, _) => !divergent.contains(id));
    _resynced.removeWhere((id) => !divergent.contains(id));
    _reported.removeWhere((id) => !divergent.contains(id));
  }

  /// One timer at most: for the earliest difference still settling, or after a
  /// settle delay when the re-synchronisation could not run.
  void _scheduleNext({required bool resyncFailed}) {
    _timer?.cancel();
    _timer = null;
    Duration? wait;
    if (resyncFailed) {
      wait = settleDelay;
    } else {
      final now = _now();
      for (final entry in _firstSeen.entries) {
        if (_reported.contains(entry.key)) continue;
        final remaining = settleDelay - now.difference(entry.value);
        if (remaining > Duration.zero && (wait == null || remaining < wait)) {
          wait = remaining;
        }
      }
    }
    if (wait != null) _timer = Timer(wait, () => unawaited(check()));
  }
}
