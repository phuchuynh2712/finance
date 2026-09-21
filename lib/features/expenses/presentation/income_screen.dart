import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/formatting/currency_formatter.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../expense_control/presentation/expense_control_providers.dart';
import 'income_providers.dart';

/// Income entry (FR-001–FR-019): lets the user record one or more named
/// income line items, then distributes their sum across every leaf item's
/// saved formula in one save action. Reached only by pushing from "Thu
/// chi" — no bottom-nav tab of its own (spec.md Assumptions).
class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  String? _errorText(AppLocalizations l10n, IncomeSaveError? error) {
    return switch (error) {
      IncomeSaveError.invalidTotal => l10n.incomeErrorInvalidTotal,
      IncomeSaveError.missingRowName => l10n.incomeErrorMissingRowName,
      IncomeSaveError.missingRowAmount => l10n.incomeErrorMissingRowAmount,
      IncomeSaveError.writeFailed => null, // handled separately below
      null => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final state = ref.watch(incomeFormControllerProvider);
    final controller = ref.read(incomeFormControllerProvider.notifier);
    final itemsAsync = ref.watch(expenseControlItemsStreamProvider);
    final hasItems = (itemsAsync.valueOrNull?.isNotEmpty) ?? false;

    ref.listen(incomeFormControllerProvider, (previous, next) {
      if (next.saved && previous?.saved != true) {
        Navigator.of(context).pop();
      }
      if (next.saveError == IncomeSaveError.writeFailed &&
          previous?.saveError != IncomeSaveError.writeFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.incomeErrorWriteFailedPrefix(next.writeErrorDetail ?? ''),
            ),
          ),
        );
      }
    });

    final errorText = _errorText(l10n, state.saveError);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: semantic.successSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                LucideIcons.arrowUpCircle,
                size: 17,
                color: semantic.success,
              ),
            ),
            const SizedBox(width: 12),
            Text(l10n.incomeScreenTitle),
          ],
        ),
      ),
      body: SafeArea(
        child: !hasItems
            ? EmptyStateView(
                icon: LucideIcons.walletCards,
                message: l10n.incomeEmptyStateMessage,
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              children: [
                                Text(
                                  l10n.incomeTotalLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: semantic.fg3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  currency.format(state.totalAmount),
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              l10n.incomeSourcesEyebrow.toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: semantic.fg2,
                              ),
                            ),
                          ),
                          for (final row in state.rows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _IncomeSourceRowWidget(
                                row: row,
                                // FR-002: removing the last row is allowed —
                                // it leaves zero rows, which FR-004 then
                                // blocks only at save time, not here.
                                showDelete: true,
                                isErrored: state.errorRowId == row.id,
                                onNameChanged: (value) =>
                                    controller.setRowName(row.id, value),
                                onAmountChanged: (value) =>
                                    controller.setRowAmount(row.id, value),
                                onDelete: () => controller.removeRow(row.id),
                              ),
                            ),
                          _AddSourceButton(
                            label: l10n.incomeAddSourceAction,
                            onPressed: controller.addRow,
                          ),
                          if (errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                errorText,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: state.isSubmitting
                            ? null
                            : () => controller.save(),
                        icon: state.isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.check),
                        label: Text(l10n.incomeSaveAction),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _IncomeSourceRowWidget extends StatefulWidget {
  const _IncomeSourceRowWidget({
    required this.row,
    required this.showDelete,
    required this.isErrored,
    required this.onNameChanged,
    required this.onAmountChanged,
    required this.onDelete,
  });

  final IncomeSourceRow row;
  final bool showDelete;
  final bool isErrored;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<int?> onAmountChanged;
  final VoidCallback onDelete;

  @override
  State<_IncomeSourceRowWidget> createState() => _IncomeSourceRowWidgetState();
}

class _IncomeSourceRowWidgetState extends State<_IncomeSourceRowWidget> {
  late final TextEditingController _amountController;
  late final FocusNode _amountFocusNode;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.row.amount?.toString() ?? '',
    );
    _amountFocusNode = FocusNode()..addListener(_onAmountFocusChange);
  }

  @override
  void dispose() {
    _amountFocusNode.removeListener(_onAmountFocusChange);
    _amountFocusNode.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// FR-016: the amount field shows raw digits while being actively
  /// edited (a currency-grouped display while typing would fight the
  /// cursor position, and no acceptance scenario requires it — research.md
  /// Decision 8), but reformats via the shared [CurrencyFormatter] the
  /// moment the field loses focus, so it never sits at rest showing an
  /// unformatted number.
  void _onAmountFocusChange() {
    if (_amountFocusNode.hasFocus || widget.row.amount == null) return;
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    _amountController.text = currency.format(widget.row.amount!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isErrored ? theme.colorScheme.error : semantic.border1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: semantic.primarySoft,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              LucideIcons.briefcase,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              initialValue: widget.row.name,
              decoration: InputDecoration(
                hintText: l10n.incomeSourceNameLabel,
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: widget.onNameChanged,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            height: 42,
            child: TextFormField(
              key: ValueKey('income-amount-${widget.row.id}'),
              controller: _amountController,
              focusNode: _amountFocusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: l10n.incomeSourceAmountLabel,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: semantic.border2, width: 1.5),
                ),
              ),
              onChanged: (value) {
                final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                widget.onAmountChanged(
                  digits.isEmpty ? null : int.parse(digits),
                );
              },
            ),
          ),
          if (widget.showDelete)
            Semantics(
              button: true,
              label: l10n.incomeSourceDeleteSemantic(widget.row.name),
              child: IconButton(
                icon: Icon(LucideIcons.trash2, size: 16, color: semantic.fg3),
                onPressed: widget.onDelete,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddSourceButton extends StatelessWidget {
  const _AddSourceButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: theme.colorScheme.primary,
            width: 1.5,
            style: BorderStyle.solid,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(
          LucideIcons.plus,
          size: 15,
          color: theme.colorScheme.primary,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
