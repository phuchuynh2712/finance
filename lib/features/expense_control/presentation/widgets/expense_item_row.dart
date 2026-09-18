import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/expense_control_item.dart';
import '../formatting.dart';
import 'icon_picker.dart';

/// One leaf item's row: icon/name/edit/delete header, plus its formula
/// (value input + percentage/fixed toggle) and — for fixed mode — an
/// informational note (FR-010). Used both for child rows inside a group
/// (T025) and for a top-level leaf's own formula row.
///
/// [onValueChanged] is the single hook the caller uses to decide what an
/// edit means: the create dialog wires it to in-memory form state (T021);
/// the live list wires it to the pending-formula-edits provider (T041) —
/// this widget never persists anything itself.
class ExpenseItemRow extends StatelessWidget {
  const ExpenseItemRow({
    super.key,
    required this.item,
    required this.onValueChanged,
    this.showHeader = true,
    this.hasPendingEdit = false,
    this.onEdit,
    this.onDelete,
  });

  final ExpenseControlItem item;
  final void Function(String itemId, ExpenseFormulaEdit edit) onValueChanged;

  /// False when the caller (e.g. [ExpenseGroupCard] for a top-level leaf)
  /// already renders its own icon/name/edit/delete header — this widget
  /// then renders only the formula section.
  final bool showHeader;

  /// Whether [item.id] currently has a staged formula edit (research.md
  /// §9). [item]'s own fields already reflect that edit (the tree provider
  /// overlays it) — this flag exists purely so [_FormulaField] can detect
  /// the moment the edit is committed or discarded (this flips back to
  /// `false`) and resync its text field to the now-authoritative value,
  /// without fighting the user's own typing on every keystroke.
  final bool hasPendingEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    if (!showHeader) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _FormulaField(
          item: item,
          onValueChanged: onValueChanged,
          hasPendingEdit: hasPendingEdit,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  resolveExpenseControlIcon(item.iconKey),
                  size: 11,
                  color: semantic.fg2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onEdit != null)
                Semantics(
                  button: true,
                  label: l10n.expenseControlEditSemantic(item.name),
                  child: IconButton(
                    onPressed: onEdit,
                    icon: Icon(LucideIcons.pencil, size: 14, color: semantic.fg3),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
              if (onDelete != null)
                Semantics(
                  button: true,
                  label: l10n.expenseControlDeleteSemantic(item.name),
                  child: IconButton(
                    onPressed: onDelete,
                    icon: Icon(LucideIcons.trash2, size: 15, color: semantic.fg3),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 8),
            child: _FormulaField(
              item: item,
              onValueChanged: onValueChanged,
              hasPendingEdit: hasPendingEdit,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaField extends StatefulWidget {
  const _FormulaField({
    required this.item,
    required this.onValueChanged,
    required this.hasPendingEdit,
  });

  final ExpenseControlItem item;
  final void Function(String itemId, ExpenseFormulaEdit edit) onValueChanged;
  final bool hasPendingEdit;

  @override
  State<_FormulaField> createState() => _FormulaFieldState();
}

class _FormulaFieldState extends State<_FormulaField> {
  late ExpenseAllocationMethod _method;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _method = widget.item.allocationMethod ?? ExpenseAllocationMethod.percentage;
    _controller = TextEditingController(text: _textFor(widget.item));
  }

  String _textFor(ExpenseControlItem item) {
    final value = item.allocationValue;
    return value == null ? '' : formatPercent(value);
  }

  @override
  void didUpdateWidget(_FormulaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The pending edit was just committed ("Lưu công thức") or discarded
    // (navigated away without saving — research.md §9): either way,
    // `widget.item` is now the sole source of truth again, so resync the
    // field. Skipped while a pending edit is still active so this doesn't
    // fight the user's own typing on every keystroke (the tree provider
    // overlays pending edits onto `item`, so `item` itself changes as they
    // type).
    if (oldWidget.hasPendingEdit && !widget.hasPendingEdit) {
      _method =
          widget.item.allocationMethod ?? ExpenseAllocationMethod.percentage;
      _controller.text = _textFor(widget.item);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) return;
    widget.onValueChanged(
      widget.item.id,
      ExpenseFormulaEdit(method: _method, value: parsed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    // Row, matching the mockup: a compact value field + a compact %/₫ pill
    // toggle fit side by side. The toggle previously used full-word labels
    // ("Phần trăm"/"Số tiền cố định"), which both overflowed on-device AND
    // didn't match the mockup's compact symbol chips — using the symbols
    // fixes both at once.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 96,
              height: 40,
              child: TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: theme.textTheme.titleSmall,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: semantic.border2, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: semantic.border2, width: 1.5),
                  ),
                ),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 8),
            _CompactModeToggle(
              method: _method,
              onChanged: (method) {
                setState(() => _method = method);
                _emit();
              },
            ),
          ],
        ),
        if (_method == ExpenseAllocationMethod.fixed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.expenseControlFixedNote,
              style: theme.textTheme.bodySmall?.copyWith(color: semantic.fg2),
            ),
          ),
      ],
    );
  }
}

/// Compact %/₫ pill toggle (mockup: pill bg, active chip blue-500/white,
/// inactive transparent/fg2) — replaces the verbose `SegmentedButton` with
/// full-word labels.
class _CompactModeToggle extends StatelessWidget {
  const _CompactModeToggle({required this.method, required this.onChanged});

  final ExpenseAllocationMethod method;
  final ValueChanged<ExpenseAllocationMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: semantic.border1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(
            context,
            label: '%',
            semanticLabel: l10n.expenseControlModePercentage,
            selected: method == ExpenseAllocationMethod.percentage,
            onTap: () => onChanged(ExpenseAllocationMethod.percentage),
          ),
          const SizedBox(width: 2),
          _chip(
            context,
            label: '₫',
            semanticLabel: l10n.expenseControlModeFixed,
            selected: method == ExpenseAllocationMethod.fixed,
            onTap: () => onChanged(ExpenseAllocationMethod.fixed),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required String semanticLabel,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    // 32px tall per the design reference — the user explicitly chose to
    // match the design pixel-for-pixel here over Constitution Principle
    // III's ≥48dp touch target minimum for this control.
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 32,
          constraints: const BoxConstraints(minWidth: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: selected ? theme.colorScheme.onPrimary : semantic.fg2,
            ),
          ),
        ),
      ),
    );
  }
}
