import 'package:finance/features/expense_control/domain/transaction_history_record.dart';

/// How far in the past a transaction's `occurredAt` falls, by calendar date
/// against an injected `now` — *before* localization (data-model.md). The
/// presentation layer, not this pure function, turns this into the
/// localized "Hôm nay" / "Hôm qua" / "{n} ngày trước" label
/// (research.md Decision 4).
sealed class OverviewRelativeDay {
  const factory OverviewRelativeDay.today() = OverviewRelativeDayToday;
  const factory OverviewRelativeDay.yesterday() = OverviewRelativeDayYesterday;
  const factory OverviewRelativeDay.daysAgo(int days) =
      OverviewRelativeDayDaysAgo;
}

class OverviewRelativeDayToday implements OverviewRelativeDay {
  const OverviewRelativeDayToday();

  @override
  bool operator ==(Object other) => other is OverviewRelativeDayToday;

  @override
  int get hashCode => runtimeType.hashCode;
}

class OverviewRelativeDayYesterday implements OverviewRelativeDay {
  const OverviewRelativeDayYesterday();

  @override
  bool operator ==(Object other) => other is OverviewRelativeDayYesterday;

  @override
  int get hashCode => runtimeType.hashCode;
}

class OverviewRelativeDayDaysAgo implements OverviewRelativeDay {
  const OverviewRelativeDayDaysAgo(this.days);

  final int days;

  @override
  bool operator ==(Object other) =>
      other is OverviewRelativeDayDaysAgo && other.days == days;

  @override
  int get hashCode => Object.hash(runtimeType, days);
}

/// Read-only projection of one [TransactionHistoryRecord] for the Overview
/// recent-activity list (data-model.md).
class OverviewTransactionItem {
  const OverviewTransactionItem({
    required this.id,
    required this.displayName,
    required this.groupLabel,
    required this.relativeDay,
    required this.direction,
    required this.amount,
  });

  final String id;
  final String displayName;
  final String? groupLabel;
  final OverviewRelativeDay relativeDay;
  final TransactionHistoryDirection direction;
  final int amount;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

OverviewRelativeDay _relativeDayOf(DateTime occurredAt, DateTime now) {
  final days = _dateOnly(now).difference(_dateOnly(occurredAt)).inDays;
  return switch (days) {
    0 => const OverviewRelativeDay.today(),
    1 => const OverviewRelativeDay.yesterday(),
    _ => OverviewRelativeDay.daysAgo(days),
  };
}

/// Maps [records] (already ordered and capped by the repository query — see
/// `TransactionHistoryRepository.watchRecent`) to display items, adding only
/// relative-day bucketing. Does not re-sort or re-limit.
List<OverviewTransactionItem> buildOverviewRecentItems(
  List<TransactionHistoryRecord> records, {
  required DateTime now,
}) {
  return [
    for (final record in records)
      OverviewTransactionItem(
        id: record.id,
        displayName: record.displayName,
        groupLabel: record.displayGroupName,
        relativeDay: _relativeDayOf(record.occurredAt, now),
        direction: record.direction,
        amount: record.amount,
      ),
  ];
}
