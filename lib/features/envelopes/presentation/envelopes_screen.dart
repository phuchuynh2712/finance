import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/l10n/app_localizations.dart';
import '../domain/envelope.dart';
import 'envelope_form_screen.dart';
import 'envelopes_providers.dart';

class EnvelopesScreen extends ConsumerWidget {
  const EnvelopesScreen({super.key});

  /// FR-028: deleting the current rounding-remainder receiver requires
  /// designating a new one first, unless it's the user's last envelope.
  /// Returns `false` if the user cancelled (delete should not proceed).
  Future<bool> _reassignReceiverIfNeeded(
    BuildContext context,
    WidgetRef ref,
    Envelope target,
    List<Envelope> allEnvelopes,
  ) async {
    if (!target.isRoundingReceiver) return true;
    final others = allEnvelopes.where((e) => e.id != target.id).toList();
    if (others.isEmpty) return true; // last envelope — flag simply clears

    final l10n = AppLocalizations.of(context);
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final chosenId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.envelopeReassignReceiverTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    if (chosenId == null) return false;

    final newReceiver = others.firstWhere((e) => e.id == chosenId);
    await ref
        .read(envelopeRepositoryProvider)
        .update(newReceiver.copyWith(isRoundingReceiver: true));
    return true;
  }

  /// FR-027: warn before deleting an envelope with a non-zero balance.
  /// Returns `false` if the user cancelled.
  Future<bool> _confirmNonZeroBalanceIfNeeded(
    BuildContext context,
    Envelope target,
  ) async {
    if (target.balance == 0) return true;
    final l10n = AppLocalizations.of(context);
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.envelopeDeleteConfirmTitle(target.name)),
        content: Text(
          l10n.envelopeDeleteNonZeroWarning(currency.format(target.balance)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.envelopeDeleteConfirmAction),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    Envelope target,
    List<Envelope> allEnvelopes,
  ) async {
    final canProceedReceiver = await _reassignReceiverIfNeeded(
      context,
      ref,
      target,
      allEnvelopes,
    );
    if (!canProceedReceiver) return;
    if (!context.mounted) return;

    final canProceedBalance = await _confirmNonZeroBalanceIfNeeded(
      context,
      target,
    );
    if (!canProceedBalance) return;

    await ref.read(envelopeRepositoryProvider).delete(target.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final envelopesAsync = ref.watch(envelopesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.envelopesTitle)),
      body: envelopesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (envelopes) {
          if (envelopes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.envelopesEmptyState,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: envelopes.length,
            itemBuilder: (context, index) {
              final envelope = envelopes[index];
              return ListTile(
                title: Text(envelope.name),
                subtitle: envelope.isRoundingReceiver
                    ? Text(l10n.envelopesReceiverBadge)
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        EnvelopeFormScreen(existingEnvelope: envelope),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currency.format(envelope.balance)),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2),
                      onPressed: () =>
                          _handleDelete(context, ref, envelope, envelopes),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const EnvelopeFormScreen()),
        ),
        icon: const Icon(LucideIcons.plus),
        label: Text(l10n.envelopesAddAction),
      ),
    );
  }
}
