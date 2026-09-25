import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/error/error_mapper.dart';
import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/empty_state_view.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expenses/application/expense_control_gateway.dart';
import 'expense_providers.dart';

const _keypadKeys = [
  '1', '2', '3', //
  '4', '5', '6', //
  '7', '8', '9', //
  '.', '0', '⌫', //
];

/// "Chi tiêu" (FR-008–FR-015): records a real expense against a picked leaf
/// budget item, atomically decrementing its balance (FR-009) and allowing
/// it to go negative with a warn-only preview (FR-010). Reached only by
/// pushing from "Thu chi" — no bottom-nav tab of its own, mirroring
/// [IncomeScreen]'s own navigation shape.
class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  var _isManualTab = true;

  String? _errorText(AppLocalizations l10n, ExpenseSaveError? error) {
    return switch (error) {
      ExpenseSaveError.invalidAmount => l10n.expenseErrorInvalidAmount,
      ExpenseSaveError.missingItem => l10n.expenseErrorMissingItem,
      ExpenseSaveError.writeFailed => null, // handled separately below
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final state = ref.watch(expenseFormControllerProvider);
    final controller = ref.read(expenseFormControllerProvider.notifier);
    final itemsAsync = ref.watch(expenseControlItemsStreamProvider);
    final hasItems = (itemsAsync.valueOrNull?.isNotEmpty) ?? false;

    ref.listen(expenseFormControllerProvider, (previous, next) {
      if (next.saved && previous?.saved != true) {
        Navigator.of(context).pop();
      }
      if (next.saveError == ExpenseSaveError.writeFailed &&
          previous?.saveError != ExpenseSaveError.writeFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mapErrorToMessage(next.writeErrorDetail!, l10n)),
          ),
        );
      }
    });
    ref.listen(scanFormControllerProvider, (previous, next) {
      if (next.saved && previous?.saved != true) {
        Navigator.of(context).pop();
      }
      if (next.saveError == ExpenseSaveError.writeFailed &&
          previous?.saveError != ExpenseSaveError.writeFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mapErrorToMessage(next.writeErrorDetail!, l10n)),
          ),
        );
      }
    });

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
                color: semantic.dangerSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                LucideIcons.arrowDownCircle,
                size: 17,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Text(l10n.expenseScreenTitle),
          ],
        ),
      ),
      body: SafeArea(
        child: !hasItems
            ? EmptyStateView(
                icon: LucideIcons.walletCards,
                message: l10n.expenseEmptyStateMessage,
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            icon: LucideIcons.pencil,
                            label: l10n.expenseTabManual,
                            selected: _isManualTab,
                            onTap: () => setState(() => _isManualTab = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TabButton(
                            icon: LucideIcons.camera,
                            label: l10n.expenseTabScan,
                            selected: !_isManualTab,
                            onTap: () => setState(() => _isManualTab = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isManualTab
                        ? _ManualEntryTab(
                            state: state,
                            controller: controller,
                            errorText: _errorText(l10n, state.saveError),
                          )
                        : const _ScanTab(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Material(
      color: selected ? theme.colorScheme.primary : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: selected ? null : Border.all(color: semantic.border1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? theme.colorScheme.onPrimary : semantic.fg2,
              ),
              const SizedBox(width: 7),
              // Flexible (not Expanded): keeps the icon+label centered as
              // a compact pair when it fits (the common case, unchanged);
              // only shrinks/wraps — never truncates — at a compact
              // window width where it doesn't (adaptive-layout-foundation).
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : semantic.fg2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualEntryTab extends ConsumerWidget {
  const _ManualEntryTab({
    required this.state,
    required this.controller,
    required this.errorText,
  });

  final ExpenseFormState state;
  final ExpenseFormController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final treeAsync = ref.watch(expenseControlTreeProvider);
    final gateway = ref.watch(expenseControlGatewayProvider);
    final leaves = treeAsync.valueOrNull == null
        ? const <ExpenseControlItem>[]
        : gateway.flattenLeaves(treeAsync.valueOrNull!);
    final pickedItem = state.itemId == null
        ? null
        : leaves.where((item) => item.id == state.itemId).firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        l10n.expenseAmountLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: semantic.fg3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          currency.format(state.amount ?? 0),
                          key: const ValueKey('expense-amount-display'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _Keypad(controller: controller),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.expensePickItemEyebrow,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: semantic.fg2,
                    ),
                  ),
                ),
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: leaves.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = leaves[index];
                      final parentName = treeAsync.valueOrNull
                          ?.where(
                            (node) => node.children.any((c) => c.id == item.id),
                          )
                          .firstOrNull
                          ?.item
                          .name;
                      return _ItemChip(
                        key: ValueKey('expense-item-chip-${item.id}'),
                        item: item,
                        parentName: parentName,
                        selected: state.itemId == item.id,
                        onTap: () => controller.pickItem(item.id),
                      );
                    },
                  ),
                ),
                if (pickedItem != null && (state.amount ?? 0) > 0)
                  _PreviewBanner(item: pickedItem, amount: state.amount!),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      errorText!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: state.isSubmitting ? null : () => controller.save(),
              icon: state.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.check),
              label: Text(l10n.expenseSaveAction),
            ),
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.controller});

  final ExpenseFormController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.2,
        children: [
          for (final key in _keypadKeys)
            Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                key: ValueKey('expense-keypad-$key'),
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  if (key == '⌫') {
                    controller.backspace();
                  } else if (key == '.') {
                    // FR-011/spec.md: whole-VND amounts only — the decimal
                    // key is part of the static 12-key mockup layout but
                    // has no effect (research.md's keypad-is-static note).
                  } else {
                    controller.appendDigit(key);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: semantic.border1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: key == '⌫'
                      ? Icon(LucideIcons.delete, size: 18, color: semantic.fg2)
                      : Text(
                          key,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({
    super.key,
    required this.item,
    required this.parentName,
    required this.selected,
    required this.onTap,
  });

  final ExpenseControlItem item;
  final String? parentName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Semantics(
      button: true,
      selected: selected,
      label: l10n.expenseItemPickedSemantic(item.name),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minWidth: 84, minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? theme.colorScheme.primary : semantic.border2,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (parentName != null)
                  Text(
                    parentName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: semantic.fg2,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({required this.item, required this.amount});

  final ExpenseControlItem item;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final resultingBalance = item.balance - amount;
    final isNegative = resultingBalance < 0;
    final background = isNegative ? semantic.dangerSoft : semantic.primarySoft;
    final foreground = isNegative
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Container(
      key: const ValueKey('expense-preview-banner'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.cornerDownRight, size: 14, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                children: [
                  TextSpan(text: '"${item.name}" '),
                  TextSpan(
                    text: currency.format(resultingBalance),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanTab extends ConsumerWidget {
  const _ScanTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final state = ref.watch(scanFormControllerProvider);
    final controller = ref.read(scanFormControllerProvider.notifier);
    final treeAsync = ref.watch(expenseControlTreeProvider);
    final gateway = ref.watch(expenseControlGatewayProvider);
    final leaves = treeAsync.valueOrNull == null
        ? const <ExpenseControlItem>[]
        : gateway.flattenLeaves(treeAsync.valueOrNull!);
    final currency = CurrencyFormatter(
      Localizations.localeOf(context).toString(),
    );
    final errorText = state.saveError == ExpenseSaveError.missingItem
        ? l10n.expenseErrorMissingItem
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                Container(
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: semantic.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.camera,
                        size: 34,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.expenseScanFrameHint,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: controller.capture,
                    icon: const Icon(LucideIcons.scanLine),
                    label: Text(l10n.expenseScanCaptureAction),
                  ),
                ),
                if (state.captured) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: semantic.successSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: semantic.success),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.checkCircle2,
                              size: 17,
                              color: semantic.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.expenseScanRecognizedLabel(
                                  currency.format(mockScanAmount),
                                  mockScanMerchantName,
                                ),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: semantic.successFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 54,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: leaves.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final item = leaves[index];
                              final parentName = treeAsync.valueOrNull
                                  ?.where(
                                    (node) => node.children.any(
                                      (c) => c.id == item.id,
                                    ),
                                  )
                                  .firstOrNull
                                  ?.item
                                  .name;
                              return _ItemChip(
                                key: ValueKey(
                                  'expense-scan-item-chip-${item.id}',
                                ),
                                item: item,
                                parentName: parentName,
                                selected: state.itemId == item.id,
                                onTap: () => controller.pickItem(item.id),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      errorText,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          if (state.captured) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: state.isSubmitting ? null : () => controller.save(),
                icon: state.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.check),
                label: Text(l10n.expenseScanConfirmAction),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
