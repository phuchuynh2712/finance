import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/l10n/app_localizations.dart';
import 'plan_controller.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  final _incomeController = TextEditingController();

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final state = ref.watch(planControllerProvider);
    final controller = ref.read(planControllerProvider.notifier);

    ref.listen(planControllerProvider, (previous, next) {
      if (next.confirmed && (previous?.confirmed ?? false) == false) {
        Navigator.of(context).pop();
      }
    });

    final preview = state.preview;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.planTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _incomeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.planIncomeLabel),
            onChanged: controller.updateIncome,
          ),
          if (preview != null) ...[
            const SizedBox(height: 24),
            Text(
              l10n.planPreviewHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final line in preview.lines)
              ListTile(
                title: Text(line.envelope.name),
                trailing: Text(currency.format(line.allocatedAmount)),
                subtitle: line.wouldBeNegative
                    ? Text(
                        currency.format(line.resultingBalance),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
              ),
            if (preview.hasOverAllocation) ...[
              const SizedBox(height: 16),
              Text(
                l10n.planOverAllocationWarning(
                  currency.format(preview.overAllocationExcess),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (preview.missingRoundingReceiver) ...[
              const SizedBox(height: 16),
              Text(
                l10n.planMissingReceiverWarning,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (preview.hasNegativeBalance) ...[
              const SizedBox(height: 16),
              Text(
                l10n.planNegativeBalanceWarning,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.planErrorPrefix(state.errorMessage!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: preview.canConfirm && !state.isSubmitting
                  ? controller.confirm
                  : null,
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.planConfirmAction),
            ),
          ],
        ],
      ),
    );
  }
}
