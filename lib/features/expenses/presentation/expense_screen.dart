import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/error/error_mapper.dart';
import 'package:finance/core/formatting/currency_formatter.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_icons.dart';
import 'package:finance/core/theme/app_layout.dart';
import 'package:finance/core/theme/app_semantic_colors.dart';
import 'package:finance/core/widgets/adaptive_gutters.dart';
import 'package:finance/core/widgets/empty_state_view.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expenses/application/expense_control_gateway.dart';
import 'expense_entry_layout.dart';
import 'expense_key_mapping.dart';
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
    final itemsAsync = ref.watch(expenseControlItemsStreamProvider);
    final hasItems = (itemsAsync.valueOrNull?.isNotEmpty) ?? false;
    final layout = ExpenseEntryLayout.of(MediaQuery.sizeOf(context));

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
        leading: Semantics(
          button: true,
          label: l10n.signUpBackSemantic,
          child: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            tooltip: l10n.signUpBackSemantic,
            onPressed: () => Navigator.of(context).pop(),
          ),
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
            // The panel is bounded and centered from 600dp (the entry
            // reading width); the gutter is the only thing that changes
            // across the breakpoint, so no subtree is remounted on resize.
            : AdaptiveGutters(
                maxWidth: AppLayoutTokens.entryContentMaxWidth,
                activatesAt: WindowSizeClass.medium,
                builder: (context, gutter) => Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        layout.tabsTopPadding,
                        gutter,
                        0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabButton(
                              icon: LucideIcons.pencil,
                              label: l10n.expenseTabManual,
                              selected: _isManualTab,
                              height: layout.tabHeight,
                              onTap: () => setState(() => _isManualTab = true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TabButton(
                              icon: LucideIcons.camera,
                              label: l10n.expenseTabScan,
                              selected: !_isManualTab,
                              height: layout.tabHeight,
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
                              errorText: _errorText(l10n, state.saveError),
                              gutter: gutter,
                              layout: layout,
                            )
                          : _ScanTab(gutter: gutter),
                    ),
                  ],
                ),
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
    required this.height,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final double height;
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
          height: height,
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

class _ManualEntryTab extends ConsumerStatefulWidget {
  const _ManualEntryTab({
    required this.state,
    required this.errorText,
    required this.gutter,
    required this.layout,
  });

  final ExpenseFormState state;
  final String? errorText;

  /// Horizontal inset of the bounded entry panel (see [AdaptiveGutters]).
  final double gutter;
  final ExpenseEntryLayout layout;

  @override
  ConsumerState<_ManualEntryTab> createState() => _ManualEntryTabState();
}

class _ManualEntryTabState extends ConsumerState<_ManualEntryTab> {
  /// Holds the keyboard focus while no control is focused, so digits,
  /// Backspace and Enter work as soon as the screen opens. It is not a Tab
  /// stop: typing is the pad's keyboard path, and the Tab order is Back, the
  /// mode tabs, the account chips, Save (contracts/expense-entry-ui.md K10).
  final _panelFocus = FocusNode(
    debugLabel: 'expense-entry-panel',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _panelFocus.dispose();
    super.dispose();
  }

  ExpenseFormController get _controller =>
      ref.read(expenseFormControllerProvider.notifier);

  /// Physical keyboard (FR-007): digits and Backspace do exactly what the
  /// matching pad keys do, Enter saves like the Save control. Everything
  /// else, and any key with Ctrl/Meta/Alt held (browser shortcuts such as
  /// Ctrl+0), is left alone for the rest of the app.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final action = expenseKeyActionFor(
      character: event.character,
      key: event.logicalKey,
      ctrl: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
      alt: keyboard.isAltPressed,
    );
    switch (action) {
      case null:
        return KeyEventResult.ignored;
      case ExpenseDigitAction(:final digit):
        _controller.appendDigit('$digit');
        return KeyEventResult.handled;
      case ExpenseBackspaceAction():
        _controller.backspace();
        return KeyEventResult.handled;
      case ExpenseDecimalAction():
        // The on-screen `.` key is inert (whole-VND amounts).
        return KeyEventResult.handled;
      case ExpenseSaveAction():
        if (!_enterSavesHere()) return KeyEventResult.ignored;
        // A held Enter must not save twice: only the first press does.
        if (event is KeyDownEvent) _controller.save();
        return KeyEventResult.handled;
    }
  }

  /// Enter is decided by the focus target alone (research.md Decision 5): it
  /// saves when focus sits on the panel, on no control, or on the account
  /// that is already chosen (picking it again would do nothing); on any
  /// other control (an unchosen chip, Save) it keeps that control's own
  /// activation, so keyboard navigation stays honest.
  bool _enterSavesHere() {
    final focused = FocusManager.instance.primaryFocus;
    final focusContext = focused?.context;
    if (focused == null ||
        identical(focused, _panelFocus) ||
        focusContext == null) {
      return true;
    }
    final chip = focusContext.findAncestorWidgetOfExactType<_ItemChip>();
    if (chip != null) return chip.selected;
    var isControl =
        focusContext.widget is InkResponse ||
        focusContext.widget is ButtonStyleButton;
    if (!isControl) {
      focusContext.visitAncestorElements((element) {
        final widget = element.widget;
        if (widget is InkResponse || widget is ButtonStyleButton) {
          isControl = true;
          return false;
        }
        return !identical(element, _panelFocus.context);
      });
    }
    return !isControl;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final layout = widget.layout;
    final gutter = widget.gutter;
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

    Widget chipFor(ExpenseControlItem item) {
      final parentName = treeAsync.valueOrNull
          ?.where((node) => node.children.any((c) => c.id == item.id))
          .firstOrNull
          ?.item
          .name;
      return _ItemChip(
        key: ValueKey('expense-item-chip-${item.id}'),
        item: item,
        parentName: parentName,
        selected: state.itemId == item.id,
        onTap: () => _controller.pickItem(item.id),
      );
    }

    final amountBlock = _AmountBlock(
      amount: state.amount ?? 0,
      currency: currency,
      verticalPadding: layout.amountVerticalPadding,
    );

    // Same-shape slots: the Column, the Expanded and the ListView keep their
    // positions whether the amount is pinned or scrolls with the list, so
    // crossing the pin threshold (a resize) neither remounts the list nor
    // loses its scroll offset.
    final pinned = layout.amountPinned;
    return Focus(
      focusNode: _panelFocus,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        // A pointer press anywhere in the panel hands the keyboard focus
        // back to it, so a stale keyboard focus (a chip reached with Tab)
        // never captures a later Enter (K5b).
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _panelFocus.requestFocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pinned
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      layout.contentTopGap,
                      gutter,
                      0,
                    ),
                    child: amountBlock,
                  )
                : const SizedBox.shrink(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: pinned ? 0 : layout.contentTopGap,
                ),
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  children: [
                    pinned ? const SizedBox.shrink() : amountBlock,
                    _Keypad(controller: _controller, layout: layout),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: layout.eyebrowBottomPadding,
                      ),
                      child: Text(
                        l10n.expensePickItemEyebrow,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: semantic.fg2,
                        ),
                      ),
                    ),
                    if (layout.chooserWraps)
                      _WrappingAccountChooser(
                        maxHeight:
                            layout.chooserMaxHeight! * chipTextFactor(context),
                        children: [for (final item in leaves) chipFor(item)],
                      )
                    else
                      SizedBox(
                        height: chipStripHeight(context),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: leaves.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) =>
                              chipFor(leaves[index]),
                        ),
                      ),
                    if (pickedItem != null && (state.amount ?? 0) > 0)
                      _PreviewBanner(
                        item: pickedItem,
                        amount: state.amount!,
                        bottomMargin: layout.bannerBottomMargin,
                      ),
                    if (widget.errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          widget.errorText!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                layout.saveTopPadding,
                gutter,
                layout.saveBottomPadding,
              ),
              child: SizedBox(
                height: layout.saveHeight,
                child: FilledButton.icon(
                  onPressed: state.isSubmitting ? null : _controller.save,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// The amount being typed: label, value and the underline.
class _AmountBlock extends StatelessWidget {
  const _AmountBlock({
    required this.amount,
    required this.currency,
    required this.verticalPadding,
  });

  final int amount;
  final CurrencyFormatter currency;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.expenseAmountLabel,
            style: theme.textTheme.bodySmall?.copyWith(color: semantic.fg3),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            child: Text(
              currency.format(amount),
              key: const ValueKey('expense-amount-display'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wide-window account chooser: chips wrap onto rows inside a bounded
/// two-row area and scroll vertically inside it when there are more, so the
/// amount, the pad and Save never leave the window. It owns its scroll
/// controller: a scroll bar left on the default `PrimaryScrollController`
/// would attach to the tab's own list (research.md Decision 4).
class _WrappingAccountChooser extends StatefulWidget {
  const _WrappingAccountChooser({
    required this.maxHeight,
    required this.children,
  });

  final double maxHeight;
  final List<Widget> children;

  @override
  State<_WrappingAccountChooser> createState() =>
      _WrappingAccountChooserState();
}

class _WrappingAccountChooserState extends State<_WrappingAccountChooser> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Scrollbar(
        controller: _controller,
        child: SingleChildScrollView(
          controller: _controller,
          primary: false,
          child: Wrap(
            spacing: 8,
            runSpacing: ExpenseEntryLayout.chipRunSpacing,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.controller, required this.layout});

  final ExpenseFormController controller;
  final ExpenseEntryLayout layout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: layout.keypadVerticalPadding),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: layout.keyGap,
          crossAxisSpacing: layout.keyGap,
          // Compact: the key height follows the width (aspect ratio) as
          // before. Wide: a fixed, bounded height, so the pad never grows
          // with the window.
          childAspectRatio: ExpenseEntryLayout.compactKeyAspectRatio,
          mainAxisExtent: layout.keyHeight,
        ),
        children: [
          for (final key in _keypadKeys)
            _wrapDeleteKeyLabel(
              l10n,
              key,
              Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  key: ValueKey('expense-keypad-$key'),
                  // Typing is the keyboard path of the pad: 12 more Tab
                  // stops before the chooser would make keyboard
                  // navigation worse. Clicking and semantics are unchanged.
                  canRequestFocus: false,
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
                        ? Semantics(
                            button: true,
                            label: l10n.expenseKeypadDeleteSemantic,
                            child: Icon(
                              LucideIcons.delete,
                              size: 18,
                              color: semantic.fg2,
                            ),
                          )
                        : Text(
                            key,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The delete key is icon-only: it gets a tooltip for the mouse (its
  /// screen-reader label is the [Semantics] above, so the tooltip does not
  /// announce it twice).
  Widget _wrapDeleteKeyLabel(AppLocalizations l10n, String key, Widget child) {
    if (key != '⌫') return child;
    return Tooltip(
      message: l10n.expenseKeypadDeleteSemantic,
      excludeFromSemantics: true,
      child: child,
    );
  }
}

/// How much larger than normal the chips' text is (1.0 at the default size).
/// A chip holds two lines of text, so its height has to follow the text size or
/// the lines overflow it at a larger setting.
double chipTextFactor(BuildContext context) {
  final factor = MediaQuery.textScalerOf(context).scale(10) / 10;
  return factor < 1 ? 1 : factor;
}

/// Height of a horizontal strip of account chips: 54dp at the default text
/// size (unchanged), growing with the text size.
double chipStripHeight(BuildContext context) => 54 * chipTextFactor(context);

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
  const _PreviewBanner({
    required this.item,
    required this.amount,
    required this.bottomMargin,
  });

  final ExpenseControlItem item;
  final int amount;
  final double bottomMargin;

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
      margin: EdgeInsets.only(bottom: bottomMargin),
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
  const _ScanTab({required this.gutter});

  /// Horizontal inset of the bounded entry panel (see [AdaptiveGutters]).
  final double gutter;

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
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: gutter),
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
                            height: chipStripHeight(context),
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
          ),
          if (state.captured)
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 0),
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: state.isSubmitting
                      ? null
                      : () => controller.save(),
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
            ),
        ],
      ),
    );
  }
}
