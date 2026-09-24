import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/empty_state_view.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';
import 'package:finance/features/expenses/presentation/transaction_history_providers.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  void _changeMonth(WidgetRef ref, DateTime month) {
    ref.read(selectedTransactionHistoryMonthProvider.notifier).state =
        monthStart(month);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final locale = Localizations.localeOf(context).toString();
    final month = ref.watch(selectedTransactionHistoryMonthProvider);
    final filter = ref.watch(selectedTransactionHistoryFilterProvider);
    final recordsAsync = ref.watch(transactionHistoryRecordsProvider(month));
    final currency = CurrencyFormatter(locale);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _HistoryHeader(
              title: l10n.transactionHistoryTitle,
              backLabel: l10n.transactionHistoryBackSemantic,
              onBack: () => Navigator.of(context).pop(),
              borderColor: semantic.border1,
              iconColor: semantic.fg2,
            ),
            Expanded(
              child: recordsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => EmptyStateView(
                  icon: LucideIcons.history,
                  message: l10n.transactionHistoryLoadError,
                  actionLabel: l10n.transactionHistoryRetry,
                  onAction: () =>
                      ref.invalidate(transactionHistoryRecordsProvider(month)),
                ),
                data: (records) {
                  final view = buildTransactionHistoryView(
                    records: records,
                    filter: filter,
                  );
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                          child: _HistoryControls(
                            month: month,
                            now: DateTime.now(),
                            locale: locale,
                            totalLabel: l10n.transactionHistoryExpenseTotal(
                              currency.format(view.expenseTotal),
                            ),
                            previousLabel:
                                l10n.transactionHistoryPreviousMonthSemantic,
                            nextLabel: l10n.transactionHistoryNextMonthSemantic,
                            onPrevious: () =>
                                _changeMonth(ref, previousMonth(month)),
                            onNext: canAdvanceMonth(month, DateTime.now())
                                ? () => _changeMonth(ref, nextMonth(month))
                                : null,
                            filter: filter,
                            groupFilters: view.groupFilters,
                            allLabel: l10n.transactionHistoryAllFilter,
                            incomeLabel: l10n.transactionHistoryIncomeFilter,
                            onFilterChanged: (value) {
                              ref
                                      .read(
                                        selectedTransactionHistoryFilterProvider
                                            .notifier,
                                      )
                                      .state =
                                  value;
                            },
                            borderColor: semantic.border2,
                            primaryColor: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      if (view.groups.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyStateView(
                            icon: LucideIcons.history,
                            message: l10n.transactionHistoryEmpty,
                          ),
                        )
                      else
                        for (final group in view.groups) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                              child: Text(
                                DateFormat(
                                  'd MMMM',
                                  locale,
                                ).format(group.date).toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                  color: semantic.fg2,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            sliver: SliverList.builder(
                              itemCount: group.items.length,
                              itemBuilder: (context, index) => _TransactionRow(
                                record: group.items[index],
                                currency: currency,
                                incomeLabel:
                                    l10n.transactionHistoryIncomeClassification,
                                archivedLabel:
                                    l10n.transactionHistoryArchivedItem,
                              ),
                            ),
                          ),
                        ],
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.title,
    required this.backLabel,
    required this.onBack,
    required this.borderColor,
    required this.iconColor,
  });

  final String title;
  final String backLabel;
  final VoidCallback onBack;
  final Color borderColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: backLabel,
            child: IconButton(
              tooltip: backLabel,
              onPressed: onBack,
              icon: Icon(LucideIcons.chevronLeft, color: iconColor),
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).extension<AppSemanticColors>()!.primarySoft,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              LucideIcons.history,
              size: 17,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryControls extends StatelessWidget {
  const _HistoryControls({
    required this.month,
    required this.now,
    required this.locale,
    required this.totalLabel,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
    required this.filter,
    required this.groupFilters,
    required this.allLabel,
    required this.incomeLabel,
    required this.onFilterChanged,
    required this.borderColor,
    required this.primaryColor,
  });

  final DateTime month;
  final DateTime now;
  final String locale;
  final String totalLabel;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final TransactionHistoryFilter filter;
  final List<String> groupFilters;
  final String allLabel;
  final String incomeLabel;
  final ValueChanged<TransactionHistoryFilter> onFilterChanged;
  final Color borderColor;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _MonthButton(
              key: const ValueKey('transaction-history-previous-month'),
              icon: LucideIcons.chevronLeft,
              label: previousLabel,
              onPressed: onPrevious,
              borderColor: borderColor,
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM y', locale).format(month),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _MonthButton(
              key: const ValueKey('transaction-history-next-month'),
              icon: LucideIcons.chevronRight,
              label: nextLabel,
              onPressed: onNext,
              borderColor: borderColor,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          totalLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).extension<AppSemanticColors>()!.fg3,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                key: const ValueKey('transaction-history-filter-all'),
                label: allLabel,
                selected: filter.kind == TransactionHistoryFilterKind.all,
                onPressed: () =>
                    onFilterChanged(const TransactionHistoryFilter.all()),
                borderColor: borderColor,
                primaryColor: primaryColor,
              ),
              for (final group in groupFilters)
                _FilterChip(
                  key: ValueKey('transaction-history-filter-$group'),
                  label: group,
                  selected:
                      filter.kind == TransactionHistoryFilterKind.group &&
                      filter.groupName == group,
                  onPressed: () =>
                      onFilterChanged(TransactionHistoryFilter.group(group)),
                  borderColor: borderColor,
                  primaryColor: primaryColor,
                ),
              _FilterChip(
                key: const ValueKey('transaction-history-filter-income'),
                label: incomeLabel,
                selected: filter.kind == TransactionHistoryFilterKind.income,
                onPressed: () =>
                    onFilterChanged(const TransactionHistoryFilter.income()),
                borderColor: borderColor,
                primaryColor: primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          side: BorderSide(color: borderColor),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.borderColor,
    required this.primaryColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final Color borderColor;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? primaryColor : Colors.transparent,
              border: Border.all(color: selected ? primaryColor : borderColor),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).extension<AppSemanticColors>()!.fg2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.record,
    required this.currency,
    required this.incomeLabel,
    required this.archivedLabel,
  });

  final TransactionHistoryRecord record;
  final CurrencyFormatter currency;
  final String incomeLabel;
  final String archivedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final isIncome = record.direction == TransactionHistoryDirection.income;
    final name = record.displayName.isEmpty
        ? archivedLabel
        : record.displayName;
    final classification = isIncome
        ? incomeLabel
        : record.displayGroupName ?? archivedLabel;
    final amountColor = isIncome ? semantic.successFg : theme.colorScheme.error;
    final sign = isIncome ? '+' : '-';
    return Semantics(
      label: '$name, $classification, $sign${currency.format(record.amount)}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: semantic.border1)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: semantic.primarySoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                _iconFor(record.displayIconKey),
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    classification,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: semantic.fg2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$sign${currency.format(record.amount)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String? key) {
  return switch (key) {
    'home' => LucideIcons.home,
    'utensils' => LucideIcons.utensils,
    _ => LucideIcons.walletCards,
  };
}
