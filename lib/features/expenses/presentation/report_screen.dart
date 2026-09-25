import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/formatting/percent_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/empty_state_view.dart';
import 'package:finance/features/expenses/application/report_summary.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';
import 'package:finance/features/expenses/presentation/report_providers.dart';
import 'package:finance/features/expenses/presentation/widgets/report_usage_bar.dart';

/// The Báo cáo tab (FR-002): a selected month's income/expense totals plus
/// a flat, per-item spending breakdown — read-only, no outbound navigation
/// (contracts/report-ui.md). Composes two independent data sources so a
/// slow/failed one never blocks the other's render (research.md
/// Decision 4).
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedReportMonthProvider);
    final totalsAsync = ref.watch(reportTotalsProvider(selectedMonth));
    final breakdownAsync = ref.watch(reportBreakdownProvider(selectedMonth));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                children: [
                  const _MonthSelector(),
                  const SizedBox(height: 16),
                  totalsAsync.when(
                    loading: () => const _SectionLoading(),
                    error: (error, stackTrace) => _SectionError(
                      message: l10n.reportLoadError,
                      retryLabel: l10n.reportRetry,
                      onRetry: () =>
                          ref.invalidate(reportTotalsProvider(selectedMonth)),
                    ),
                    data: (totals) => _TotalsCards(totals: totals),
                  ),
                  const SizedBox(height: 20),
                  breakdownAsync.when(
                    loading: () => const _SectionLoading(),
                    error: (error, stackTrace) => _SectionError(
                      message: l10n.reportLoadError,
                      retryLabel: l10n.reportRetry,
                      onRetry: () => ref.invalidate(
                        reportBreakdownProvider(selectedMonth),
                      ),
                    ),
                    data: (entries) => _BreakdownSection(entries: entries),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: semantic.border1)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: semantic.primarySoft,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              LucideIcons.pieChart,
              size: 17,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.tabHistory,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends ConsumerWidget {
  const _MonthSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final selectedMonth = ref.watch(selectedReportMonthProvider);
    final now = DateTime.now();
    final canAdvance = canAdvanceMonth(selectedMonth, now);
    final monthLabel = DateFormat.yMMMM(locale).format(selectedMonth);

    return Row(
      children: [
        _MonthNavButton(
          icon: LucideIcons.chevronLeft,
          semanticLabel: l10n.reportPreviousMonthSemantic,
          onPressed: () =>
              ref.read(selectedReportMonthProvider.notifier).state =
                  previousMonth(selectedMonth),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            monthLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _MonthNavButton(
          icon: LucideIcons.chevronRight,
          semanticLabel: l10n.reportNextMonthSemantic,
          onPressed: canAdvance
              ? () => ref.read(selectedReportMonthProvider.notifier).state =
                    nextMonth(selectedMonth)
              : null,
        ),
      ],
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: semantic.border2),
      ),
      // A stock IconButton's default 48dp minimum interactive dimension
      // already meets the constitution's touch-target minimum, even though
      // the design's own circular border renders at a visually smaller
      // 44px — no custom hit-area technique needed (research.md,
      // Constitution touch-target reconciliation).
      child: IconButton(
        icon: Icon(icon, size: 18, color: semantic.fg2),
        onPressed: onPressed,
        tooltip: semanticLabel,
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: EmptyStateView(
        icon: LucideIcons.alertTriangle,
        message: message,
        actionLabel: retryLabel,
        onAction: onRetry,
      ),
    );
  }
}

class _TotalsCards extends StatelessWidget {
  const _TotalsCards({required this.totals});

  final ReportTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final locale = Localizations.localeOf(context).toString();
    final currency = CurrencyFormatter(locale);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TotalCard(
            label: l10n.reportIncomeLabel,
            amountText: currency.format(totals.totalIncome),
            background: semantic.successSoft,
            foreground: semantic.successFg,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TotalCard(
            label: l10n.reportExpenseLabel,
            amountText: currency.format(totals.totalExpense),
            background: semantic.dangerSoft,
            foreground: semantic.dangerFg,
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amountText,
    required this.background,
    required this.foreground,
  });

  final String label;
  final String amountText;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amountText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.entries});

  final List<ReportItemEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 9),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: semantic.border2, width: 3)),
          ),
          child: Text(
            l10n.reportBreakdownSectionTitle,
            style: TextStyle(
              color: semantic.fg2,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          EmptyStateView(
            icon: LucideIcons.pieChart,
            message: l10n.reportBreakdownEmpty,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) =>
                _BreakdownRow(entry: entries[index]),
          ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.entry});

  final ReportItemEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final currency = CurrencyFormatter(locale);
    final title = entry.groupName != null
        ? '${entry.name} · ${entry.groupName}'
        : entry.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currency.format(entry.spent),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          switch (entry.usageState) {
            ReportItemUsageState.notAllocated => Text(
              l10n.reportNotAllocatedLabel,
              style: TextStyle(color: semantic.fg2, fontSize: 12),
            ),
            ReportItemUsageState.unused || ReportItemUsageState.tracked => Row(
              children: [
                Expanded(
                  child: ReportUsageBar(usagePercent: entry.usagePercent!),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.reportUsagePercentValue(
                    formatPercent(entry.usagePercent!),
                  ),
                  style: TextStyle(
                    color: entry.usagePercent! > 100
                        ? semantic.dangerFg
                        : semantic.fg2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          },
        ],
      ),
    );
  }
}
