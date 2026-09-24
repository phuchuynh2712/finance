import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/empty_state_view.dart';
import 'package:finance/features/expenses/application/balance_view_service.dart';
import 'expense_screen.dart';
import 'income_screen.dart';
import 'transaction_history_screen.dart';
import 'widgets/balance_group_card.dart';

/// Read-only balance hub (FR-001–FR-012): shows every Kiểm soát chi tiêu
/// item/group's actual current balance, plus scaffolded entry points for
/// income/expense recording and transaction history (out of scope for this
/// feature — each navigates to a placeholder, per FR-009).
class SpendingScreen extends ConsumerWidget {
  const SpendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final treeAsync = ref.watch(expenseControlTreeProvider);
    final balanceViewService = ref.watch(balanceViewServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSpending)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: LucideIcons.arrowUpCircle,
                          label: l10n.spendingIncomeAction,
                          background: semantic.successSoft,
                          border: semantic.success,
                          foreground: semantic.successFg,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const IncomeScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: LucideIcons.arrowDownCircle,
                          label: l10n.spendingExpenseAction,
                          background: semantic.dangerSoft,
                          border: theme.colorScheme.error,
                          foreground: semantic.dangerFg,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ExpenseScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _HistoryRow(
                    label: l10n.spendingHistoryAction,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TransactionHistoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            Expanded(
              child: treeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(error.toString())),
                data: (tree) {
                  if (tree.isEmpty) {
                    return EmptyStateView(
                      icon: LucideIcons.walletCards,
                      message: l10n.spendingBalanceEmptyState,
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.only(left: 9),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: semantic.border2, width: 3),
                          ),
                        ),
                        child: Text(
                          l10n.spendingBalanceListLabel.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: semantic.fg2,
                          ),
                        ),
                      ),
                      for (final row in balanceViewService.prepare(tree))
                        BalanceGroupCard(
                          node: row.node,
                          balance: row.balance,
                          currency: currency,
                        ),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color border;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: semantic.border1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.history, size: 17, color: semantic.fg2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: semantic.fg3),
            ],
          ),
        ),
      ),
    );
  }
}
