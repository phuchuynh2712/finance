import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/l10n/app_localizations.dart';
import 'envelopes_providers.dart';
import 'plan_screen.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final envelopesAsync = ref.watch(envelopesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.overviewTitle)),
      body: envelopesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (envelopes) {
          if (envelopes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.overviewEmptyState,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: envelopes.length,
            itemBuilder: (context, index) {
              final envelope = envelopes[index];
              final isNegative = envelope.balance < 0;
              return ListTile(
                title: Text(envelope.name),
                trailing: Text(
                  currency.format(envelope.balance),
                  style: isNegative
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const PlanScreen())),
        icon: const Icon(Icons.calculate_outlined),
        label: Text(l10n.overviewPlanAction),
      ),
    );
  }
}
