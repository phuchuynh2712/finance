import 'package:finance/features/expense_control/domain/transaction_history_record.dart';

enum TransactionHistoryFilterKind { all, income, group }

class TransactionHistoryFilter {
  const TransactionHistoryFilter.all()
    : kind = TransactionHistoryFilterKind.all,
      groupName = null;

  const TransactionHistoryFilter.income()
    : kind = TransactionHistoryFilterKind.income,
      groupName = null;

  const TransactionHistoryFilter.group(String this.groupName)
    : kind = TransactionHistoryFilterKind.group;

  final TransactionHistoryFilterKind kind;
  final String? groupName;

  @override
  bool operator ==(Object other) {
    return other is TransactionHistoryFilter &&
        other.kind == kind &&
        other.groupName == groupName;
  }

  @override
  int get hashCode => Object.hash(kind, groupName);
}

class TransactionHistoryDayGroup {
  const TransactionHistoryDayGroup({required this.date, required this.items});

  final DateTime date;
  final List<TransactionHistoryRecord> items;
}

class TransactionHistoryView {
  const TransactionHistoryView({
    required this.expenseTotal,
    required this.groupFilters,
    required this.groups,
  });

  final int expenseTotal;
  final List<String> groupFilters;
  final List<TransactionHistoryDayGroup> groups;
}

DateTime monthStart(DateTime value) => DateTime(value.year, value.month);

DateTime nextMonth(DateTime month) => DateTime(month.year, month.month + 1);

DateTime previousMonth(DateTime month) => DateTime(month.year, month.month - 1);

bool canAdvanceMonth(DateTime month, DateTime now) {
  return !nextMonth(month).isAfter(monthStart(now));
}

TransactionHistoryView buildTransactionHistoryView({
  required List<TransactionHistoryRecord> records,
  required TransactionHistoryFilter filter,
}) {
  final groupFilters =
      records
          .where(
            (record) => record.direction == TransactionHistoryDirection.expense,
          )
          .map((record) => record.displayGroupName)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
  final visible = records.where((record) {
    return switch (filter.kind) {
      TransactionHistoryFilterKind.all => true,
      TransactionHistoryFilterKind.income =>
        record.direction == TransactionHistoryDirection.income,
      TransactionHistoryFilterKind.group =>
        record.direction == TransactionHistoryDirection.expense &&
            record.displayGroupName == filter.groupName,
    };
  }).toList();
  final grouped = <DateTime, List<TransactionHistoryRecord>>{};
  for (final record in visible) {
    final day = DateTime(
      record.occurredAt.year,
      record.occurredAt.month,
      record.occurredAt.day,
    );
    (grouped[day] ??= []).add(record);
  }
  final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return TransactionHistoryView(
    expenseTotal: records
        .where(
          (record) => record.direction == TransactionHistoryDirection.expense,
        )
        .fold(0, (sum, record) => sum + record.amount),
    groupFilters: groupFilters,
    groups: [
      for (final date in dates)
        TransactionHistoryDayGroup(date: date, items: grouped[date]!),
    ],
  );
}
