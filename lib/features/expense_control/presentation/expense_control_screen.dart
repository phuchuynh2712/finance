import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../domain/expense_control_item.dart';
import '../domain/expense_control_plan_service.dart';
import 'expense_control_form_controller.dart';
import 'expense_control_providers.dart';
import 'formatting.dart';
import 'widgets/allocation_mode_toggle.dart';
import 'widgets/allocation_summary_banner.dart';
import 'widgets/dashed_border.dart';
import 'widgets/expense_group_card.dart';
import 'widgets/icon_picker.dart';

class ExpenseControlScreen extends ConsumerWidget {
  const ExpenseControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final treeAsync = ref.watch(expenseControlTreeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 62,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(bottom: BorderSide(color: semantic.border1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: semantic.primarySoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      LucideIcons.slidersHorizontal,
                      size: 17,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.expenseControlScreenTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: treeAsync.when(
                data: (tree) {
                  if (tree.isEmpty) {
                    return EmptyStateView(
                      icon: LucideIcons.slidersHorizontal,
                      message: l10n.expenseControlEmptyStateMessage,
                      actionLabel: l10n.expenseControlAddItemAction,
                      onAction: () =>
                          _openCreateDialog(context, ref, parentId: null),
                    );
                  }
                  return _ScreenContent(tree: tree);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    Center(child: Text(error.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenContent extends ConsumerWidget {
  const _ScreenContent({required this.tree});

  final List<ExpenseControlNode> tree;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final totalsAsync = ref.watch(expenseControlTotalsProvider);
    final pendingEdits = ref.watch(pendingItemEditsProvider);
    final planService = ref.watch(expenseControlPlanServiceProvider);
    final items =
        ref.watch(expenseControlItemsStreamProvider).valueOrNull ?? [];

    final validation = pendingEdits.isEmpty
        ? null
        : planService.validateBudget(items, pendingEdits: pendingEdits);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: semantic.primarySoft,
            border: Border.all(color: semantic.border1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.info,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.expenseControlBannerHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: tree.length,
          itemBuilder: (context, index) {
            final node = tree[index];
            return ExpenseGroupCard(
              key: ValueKey(node.item.id),
              node: node,
              index: index,
              onEditItem: (item) => _openEditDialog(context, ref, item),
              onDeleteLeaf: (item) =>
                  ref.read(expenseControlRepositoryProvider).delete(item.id),
              onDeleteGroup: (group) =>
                  _confirmDeleteGroup(context, ref, group),
              onAddChild: (parent) =>
                  _openCreateDialog(context, ref, parentId: parent.id),
              // A group carries no formula of its own (FR-003/FR-004) — its
              // *effective* value is the sum of its children's formulas,
              // computed live (including any pending inline edits) rather
              // than stored, so it's always in sync with its children.
              groupSubtotal: node.isGroup
                  ? planService.computeTotals(
                      node.children,
                      pendingEdits: pendingEdits,
                    )
                  : null,
            );
          },
          onReorder: (oldIndex, newIndex) {
            var adjustedNewIndex = newIndex;
            if (oldIndex < newIndex) adjustedNewIndex -= 1;
            final orderedIds = [for (final node in tree) node.item.id];
            final movedId = orderedIds.removeAt(oldIndex);
            orderedIds.insert(adjustedNewIndex, movedId);
            ref
                .read(expenseControlRepositoryProvider)
                .reorderTopLevel(orderedIds);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DashedRectBorder(
            color: theme.colorScheme.primary,
            borderRadius: 6,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openCreateDialog(context, ref, parentId: null),
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.plus,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.expenseControlAddItemAction,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (totalsAsync.hasValue)
          AllocationSummaryBanner(totals: totalsAsync.requireValue),
        if (pendingEdits.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (validation != null && !validation.isValid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.expenseControlSaveFormulaBlockedMessage(
                  formatPercent(validation.violatingTotal ?? 0),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: (validation?.isValid ?? true)
                  ? () async {
                      await ref
                          .read(expenseControlRepositoryProvider)
                          .saveFormulas(pendingEdits);
                      ref.read(pendingItemEditsProvider.notifier).state = {};
                    }
                  : null,
              icon: const Icon(LucideIcons.check, size: 20),
              label: Text(
                l10n.expenseControlSaveFormulaAction,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

void _openCreateDialog(
  BuildContext context,
  WidgetRef ref, {
  required String? parentId,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _ItemFormDialog(
      params: (existingItem: null, parentId: parentId, isFormulaEditable: true),
    ),
  );
}

void _openEditDialog(
  BuildContext context,
  WidgetRef ref,
  ExpenseControlItem item,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _ItemFormDialog(
      params: (
        existingItem: item,
        parentId: null,
        // FR-003: only a leaf (non-null allocationMethod) gets formula
        // fields in its edit dialog — a group has no formula of its own.
        isFormulaEditable: item.allocationMethod != null,
      ),
    ),
  );
}

Future<void> _confirmDeleteGroup(
  BuildContext context,
  WidgetRef ref,
  ExpenseControlItem group,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.expenseControlDeleteGroupTitle(group.name)),
      content: Text(l10n.expenseControlDeleteGroupWarning),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.expenseControlDeleteGroupConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await ref.read(expenseControlRepositoryProvider).delete(group.id);
  }
}

class _ItemFormDialog extends ConsumerStatefulWidget {
  const _ItemFormDialog({required this.params});

  final ExpenseControlFormParams params;

  @override
  ConsumerState<_ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<_ItemFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    final existing = widget.params.existingItem;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _valueController = TextEditingController(
      text: existing?.allocationValue == null
          ? ''
          : formatPercent(existing!.allocationValue!),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = widget.params;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(expenseControlFormControllerProvider(params));
    final controller = ref.read(
      expenseControlFormControllerProvider(params).notifier,
    );

    ref.listen(expenseControlFormControllerProvider(params), (previous, next) {
      if (next.saved && !(previous?.saved ?? false)) {
        Navigator.of(context).pop();
      }
    });

    final title = params.existingItem != null
        ? l10n.expenseControlEditItemTitle
        : l10n.expenseControlAddItemAction;

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: l10n.expenseControlNameLabel,
              ),
              controller: _nameController,
              onChanged: controller.setName,
            ),
            if (controller.showNameError)
              Text(
                l10n.expenseControlNameRequiredError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            Text(l10n.expenseControlIconPickerLabel),
            const SizedBox(height: 6),
            IconPicker(
              selectedKey: state.iconKey,
              onSelected: controller.setIconKey,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: l10n.expenseControlDescriptionLabel,
              ),
              controller: _descriptionController,
              onChanged: controller.setDescription,
            ),
            if (params.isFormulaEditable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.expenseControlValueLabel,
                      ),
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) =>
                          controller.setValue(double.tryParse(value)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AllocationModeToggle(
                    method: state.method,
                    onChanged: controller.setMethod,
                  ),
                ],
              ),
              if (controller.showValueError)
                Text(
                  l10n.expenseControlValueRequiredError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (state.method == ExpenseAllocationMethod.fixed)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.expenseControlFixedNote,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (controller.budgetValidation != null &&
                  !controller.budgetValidation!.isValid)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.expenseControlOverBudgetError(
                      formatPercent(
                        controller.budgetValidation!.violatingTotal ?? 0,
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              // FR-008/FR-010: only ever shown for a leaf (a group has no
              // formula section at all, per the isFormulaEditable gate
              // above it already sits inside).
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.savingsReceiverToggleLabel),
                value: state.isSavingsReceiver,
                onChanged: controller.setIsSavingsReceiver,
              ),
              if (state.savingsReceiverRejected)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.savingsReceiverBlockedError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              // FR-011, per spec.md Clarifications: shown on THIS dialog
              // when it is creating a child under a parent that currently
              // holds the savings-receiver mark — the mark will be cleared
              // the moment this child is saved.
              if (params.existingItem == null &&
                  params.parentId != null &&
                  (ref
                          .watch(expenseControlItemsStreamProvider)
                          .valueOrNull
                          ?.any(
                            (item) =>
                                item.id == params.parentId &&
                                item.isSavingsReceiver,
                          ) ??
                      false))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.savingsReceiverAutoClearWarning,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
            // FR-012: shown inline within the dialog, not via
            // ScaffoldMessenger/SnackBar — a SnackBar triggered from inside
            // an AlertDialog can render behind the dialog's modal barrier
            // and go unseen (research.md/contracts/error_mapper.md Pattern
            // B still applies: the controller keeps the raw error, this
            // widget maps it to a friendly message at display time).
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  mapErrorToMessage(state.errorMessage!, l10n),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(
          onPressed: controller.canSave && !state.isSubmitting
              ? controller.save
              : null,
          child: Text(l10n.expenseControlDialogSaveAction),
        ),
      ],
    );
  }
}
