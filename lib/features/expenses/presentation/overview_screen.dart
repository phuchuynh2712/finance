import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_colors.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/adaptive_body.dart';
import 'package:finance/core/widgets/empty_state_view.dart';
import 'package:finance/core/widgets/not_available_placeholder_screen.dart';
import 'package:finance/features/expense_control/domain/transaction_history_record.dart';
import 'package:finance/features/expenses/application/overview_recent_transactions.dart';
import 'package:finance/features/expenses/application/overview_summary_service.dart';
import 'package:finance/features/expenses/application/transaction_history.dart';
import 'package:finance/features/expenses/presentation/overview_providers.dart';
import 'package:finance/features/expenses/presentation/transaction_history_providers.dart';
import 'package:finance/features/expenses/presentation/transaction_history_screen.dart';

/// Home dashboard shown on the "Tổng quan" tab (FR-001). Read-only (FR-013);
/// composes two independent data sources — the shared balance+accounts
/// summary, and recent transactions — each with its own loading/error
/// handling (FR-010, contracts/overview-ui.md).
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(overviewSummaryProvider);
    final recentAsync = ref.watch(overviewRecentTransactionsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: AdaptiveBody(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  children: [
                    summaryAsync.when(
                      loading: () => const _SummaryLoading(),
                      error: (error, stackTrace) => _SummaryError(
                        message: l10n.overviewLoadError,
                        retryLabel: l10n.overviewRetry,
                        // Invalidates the root stream-wrapping provider, not
                        // the derived overviewSummaryProvider — the failure
                        // happened at the source (repository.watchAll()'s
                        // stream), and only re-invoking that source triggers
                        // a fresh attempt.
                        onRetry: () =>
                            ref.invalidate(expenseControlItemsStreamProvider),
                      ),
                      data: (summary) => _SummaryBlock(summary: summary),
                    ),
                    const SizedBox(height: 22),
                    recentAsync.when(
                      loading: () => const _SummaryLoading(),
                      error: (error, stackTrace) => _SummaryError(
                        message: l10n.overviewLoadError,
                        retryLabel: l10n.overviewRetry,
                        onRetry: () =>
                            ref.invalidate(overviewRecentTransactionsProvider),
                      ),
                      data: (records) =>
                          _RecentTransactionsSection(records: records),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(overviewAuthActionsProvider);
    final name =
        auth.currentDisplayName ?? auth.currentEmail?.split('@').first ?? '';

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
              LucideIcons.layoutDashboard,
              size: 17,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.overviewGreeting(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotAvailablePlaceholderScreen(
                  icon: LucideIcons.bell,
                  title: l10n.overviewNotificationSemantic,
                  message: l10n.notAvailablePlaceholderMessage,
                ),
              ),
            ),
            icon: const Icon(LucideIcons.bell),
            tooltip: l10n.overviewNotificationSemantic,
          ),
        ],
      ),
    );
  }
}

class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 140,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({
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

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.summary});

  final OverviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final negativeAccounts = summary.negativeAccounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TotalBalanceCard(totalBalance: summary.totalBalance),
        if (negativeAccounts.isNotEmpty) ...[
          const SizedBox(height: 14),
          _NegativeBalanceBanner(accountName: negativeAccounts.first.name),
        ],
        const SizedBox(height: 22),
        _SectionHeader(
          title: l10n.overviewAccountsSectionTitle(summary.accounts.length),
          seeAllSemanticLabel: l10n.overviewSeeAllAccountsSemantic,
          onSeeAll: () => context.go('/expense-control'),
        ),
        const SizedBox(height: 10),
        if (summary.accounts.isEmpty)
          EmptyStateView(
            icon: LucideIcons.wallet,
            message: l10n.overviewAccountsEmpty,
          )
        else
          _AccountsList(accounts: summary.accounts),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    this.seeAllSemanticLabel,
  });

  final String title;
  final VoidCallback onSeeAll;
  final String? seeAllSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.only(left: 9),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: semantic.border2, width: 3),
              ),
            ),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: semantic.fg2,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: seeAllSemanticLabel,
          child: InkWell(
            onTap: onSeeAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                l10n.overviewSeeAllAction,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountsList extends StatelessWidget {
  const _AccountsList({required this.accounts});

  final List<OverviewAccountSummary> accounts;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final account = accounts[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index == accounts.length - 1 ? 0 : 10,
            ),
            child: _AccountCard(account: account),
          );
        },
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final OverviewAccountSummary account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final locale = Localizations.localeOf(context).toString();
    final currency = CurrencyFormatter(locale);
    final balanceColor = account.isNegative
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Container(
      width: 128,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: semantic.border1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: semantic.primarySoft,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              LucideIcons.wallet,
              size: 15,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            account.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currency.format(account.balance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: balanceColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({required this.records});

  final List<TransactionHistoryRecord> records;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = buildOverviewRecentItems(records, now: DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: l10n.overviewRecentTransactionsSectionTitle,
          seeAllSemanticLabel: l10n.overviewSeeAllTransactionsSemantic,
          onSeeAll: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
          ),
        ),
        const SizedBox(height: 4),
        if (items.isEmpty)
          EmptyStateView(
            icon: LucideIcons.history,
            message: l10n.overviewTransactionsEmpty,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _RecentTransactionRow(item: items[index]),
          ),
      ],
    );
  }
}

class _RecentTransactionRow extends StatelessWidget {
  const _RecentTransactionRow({required this.item});

  final OverviewTransactionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final currency = CurrencyFormatter(locale);
    final isIncome = item.direction == TransactionHistoryDirection.income;
    final amountColor = isIncome
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final amountText = '${isIncome ? '+' : '-'}${currency.format(item.amount)}';
    final relativeLabel = switch (item.relativeDay) {
      OverviewRelativeDayToday() => l10n.overviewToday,
      OverviewRelativeDayYesterday() => l10n.overviewYesterday,
      OverviewRelativeDayDaysAgo(:final days) => l10n.overviewDaysAgo(days),
    };
    final subtitle = item.groupLabel != null
        ? '${item.groupLabel} · $relativeLabel'
        : relativeLabel;

    return Container(
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
              isIncome ? LucideIcons.banknote : LucideIcons.receipt,
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
                  item.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: semantic.fg2, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountText,
            style: TextStyle(
              color: amountColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.totalBalance});

  final int totalBalance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final currency = CurrencyFormatter(locale);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.heroPanel,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.overviewTotalBalanceLabel.toUpperCase(),
            style: const TextStyle(
              color: AppColors.heroPanelGold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currency.formatCompact(totalBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            currency.format(totalBalance),
            style: const TextStyle(color: Color(0x80FFFFFF), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _NegativeBalanceBanner extends StatelessWidget {
  const _NegativeBalanceBanner({required this.accountName});

  final String accountName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: semantic.dangerSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle, size: 18, color: semantic.dangerFg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.overviewNegativeBalanceWarning(accountName),
                  style: TextStyle(
                    color: semantic.dangerFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => _openFilteredHistory(context, accountName),
                  child: Text(
                    l10n.overviewSeeDetailAction,
                    style: TextStyle(color: semantic.dangerFg, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// research.md Decision 9: a negative balance is explained by recorded
  /// spending, not by the allocation plan, so this opens the existing
  /// transaction-history screen filtered to this account's group — not the
  /// Kế hoạch tab — via a nested [ProviderScope] override, reusing
  /// `TransactionHistoryFilter.group` without any change to the history
  /// screen or its providers.
  void _openFilteredHistory(BuildContext context, String accountName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          overrides: [
            selectedTransactionHistoryFilterProvider.overrideWith(
              (ref) => TransactionHistoryFilter.group(accountName),
            ),
          ],
          child: const TransactionHistoryScreen(),
        ),
      ),
    );
  }
}
