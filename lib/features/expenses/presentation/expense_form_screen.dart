import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../envelopes/domain/envelope.dart';
import '../../envelopes/presentation/envelopes_providers.dart';
import '../domain/expense_entry.dart';
import 'expense_form_controller.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.existingExpense});

  final ExpenseEntry? existingExpense;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _promptShown = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingExpense;
    if (existing != null) {
      _amountController.text = existing.amount.toString();
      _noteController.text = existing.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _showCoveringPrompt(
    BuildContext context,
    WidgetRef ref,
    List<Envelope> envelopes,
    String targetEnvelopeId,
    int shortfall,
  ) async {
    final l10n = AppLocalizations.of(context);
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final controller = ref.read(
      expenseFormControllerProvider(widget.existingExpense).notifier,
    );
    final others = envelopes.where((e) => e.id != targetEnvelopeId).toList();

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.coveringPromptTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.coveringPromptMessage(currency.format(shortfall))),
            const SizedBox(height: 16),
            for (final envelope in others)
              ListTile(
                title: Text(envelope.name),
                trailing: Text(currency.format(envelope.balance)),
                onTap: () => Navigator.of(context).pop(envelope.id),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancelAction),
          ),
        ],
      ),
    );

    if (chosen != null) {
      await controller.confirmWithCoveringEnvelope(chosen);
    } else {
      controller.cancelCoveringPrompt();
    }
    _promptShown = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.existingExpense != null;
    final envelopesAsync = ref.watch(envelopesStreamProvider);
    final state = ref.watch(
      expenseFormControllerProvider(widget.existingExpense),
    );
    final controller = ref.read(
      expenseFormControllerProvider(widget.existingExpense).notifier,
    );

    ref.listen(expenseFormControllerProvider(widget.existingExpense), (
      previous,
      next,
    ) {
      if (next.saved && (previous?.saved ?? false) == false) {
        Navigator.of(context).pop();
        return;
      }
      if (next.pendingOverspend != null && !_promptShown) {
        _promptShown = true;
        final envelopes = envelopesAsync.valueOrNull ?? [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || next.envelopeId == null) return;
          _showCoveringPrompt(
            context,
            ref,
            envelopes,
            next.envelopeId!,
            next.pendingOverspend!.shortfall,
          );
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l10n.expenseFormTitleEdit : l10n.expenseFormTitleCreate,
        ),
      ),
      body: envelopesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (envelopes) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<String>(
                initialValue: state.envelopeId,
                decoration: InputDecoration(
                  labelText: l10n.expenseFormEnvelopeLabel,
                ),
                items: [
                  for (final envelope in envelopes)
                    DropdownMenuItem(
                      value: envelope.id,
                      child: Text(envelope.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) controller.setEnvelope(value);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.expenseFormAmountLabel,
                ),
                onChanged: (value) {
                  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
                  controller.setAmount(int.tryParse(digitsOnly));
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: l10n.expenseFormNoteLabel,
                ),
                onChanged: controller.setNote,
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.expenseFormErrorPrefix(state.errorMessage!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: state.isSubmitting ? null : controller.save,
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.expenseFormSaveAction),
              ),
            ],
          );
        },
      ),
    );
  }
}
