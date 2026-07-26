import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../envelopes/presentation/envelopes_providers.dart';
import '../domain/expense_entry.dart';
import 'expense_form_screen.dart';
import 'expenses_providers.dart';

class SpendingScreen extends ConsumerWidget {
  const SpendingScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ExpenseEntry expense,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.spendingDeleteConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.spendingDeleteConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(expenseRepositoryProvider).delete(expense.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final expensesAsync = ref.watch(expensesStreamProvider);
    final envelopesAsync = ref.watch(envelopesStreamProvider);
    final hasEnvelopes = (envelopesAsync.valueOrNull?.isNotEmpty) ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.spendingTitle)),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.spendingEmptyState,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return ListTile(
                title: Text(currency.format(expense.amount)),
                subtitle: expense.note != null ? Text(expense.note!) : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        ExpenseFormScreen(existingExpense: expense),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, expense),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: hasEnvelopes
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ExpenseFormScreen(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.spendingAddAction),
            )
          : null,
      bottomNavigationBar: hasEnvelopes
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.spendingNoEnvelopesWarning,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
    );
  }
}
