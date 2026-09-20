import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expense_control/presentation/widgets/expense_group_card.dart';

ExpenseControlItem _item(String id, {String? parentId, String name = 'Item'}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: parentId,
    name: name,
    iconKey: 'home',
    description: null,
    sortOrder: 0,
    allocationMethod: parentId == null
        ? ExpenseAllocationMethod.percentage
        : null,
    allocationValue: parentId == null ? 20 : null,
    balance: 0,
  );
}

Widget _harness(
  ExpenseControlNode node, {
  void Function(ExpenseControlItem)? onAddChild,
  void Function(ExpenseControlItem)? onDeleteGroup,
  void Function(ExpenseControlItem)? onDeleteLeaf,
  ExpenseControlTotals? groupSubtotal,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: ReorderableListView(
        onReorder: (_, _) {},
        children: [
          ExpenseGroupCard(
            key: const ValueKey('card'),
            node: node,
            index: 0,
            onEditItem: (_) {},
            onDeleteLeaf: onDeleteLeaf ?? (_) {},
            onDeleteGroup: onDeleteGroup ?? (_) {},
            onAddChild: onAddChild ?? (_) {},
            groupSubtotal: groupSubtotal,
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'a group with children shows a chevron and, when tapped, toggles expand/collapse independently',
    (tester) async {
      final node = ExpenseControlNode(
        item: _item('family', name: 'Family'),
        children: [_item('groceries', parentId: 'family', name: 'Groceries')],
      );
      await tester.pumpWidget(_harness(node));

      expect(find.text('Groceries'), findsOneWidget);

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(find.text('Groceries'), findsNothing);

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(find.text('Groceries'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping "Thêm khoản trong [Tên nhóm]" invokes onAddChild with the group item',
    (tester) async {
      ExpenseControlItem? addedTo;
      final node = ExpenseControlNode(
        item: _item('family', name: 'Family'),
        children: [_item('groceries', parentId: 'family')],
      );
      await tester.pumpWidget(
        _harness(node, onAddChild: (item) => addedTo = item),
      );

      await tester.tap(find.text('Thêm khoản trong Family'));
      await tester.pump();

      expect(addedTo?.id, 'family');
    },
  );

  testWidgets(
    'a childless (leaf) node renders its formula row directly, with no chevron',
    (tester) async {
      final node = ExpenseControlNode(
        item: _item('rent', name: 'Rent'),
        children: const [],
      );
      await tester.pumpWidget(_harness(node));

      expect(find.text('Rent'), findsOneWidget);
      // The leaf's formula value is a non-interactive static label (FR-001) —
      // mode conveyed via the label's own %/₫ suffix, not a separate toggle.
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('20%'), findsOneWidget);
    },
  );

  testWidgets(
    "a group's sub-label shows the live sum of its children's formulas — not its own (cleared) formula — only while collapsed (FR-014/FR-015)",
    (tester) async {
      final node = ExpenseControlNode(
        item: _item('family', name: 'Family'),
        children: [
          _item('groceries', parentId: 'family', name: 'Groceries'),
          _item('utilities', parentId: 'family', name: 'Utilities'),
        ],
      );
      const subtotal = ExpenseControlTotals(
        percentAllocated: 35,
        fixedItemCount: 1,
        percentFree: 65,
      );
      await tester.pumpWidget(_harness(node, groupSubtotal: subtotal));

      // A group defaults to expanded (FR-014: the summary duplicates the
      // children list visible below it, so it's hidden while expanded).
      expect(find.textContaining('35%'), findsNothing);

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.textContaining('35%'), findsOneWidget);
      expect(find.textContaining('1'), findsWidgets);
    },
  );

  testWidgets(
    'expanding a collapsed group hides its summary line entirely, leaving only the header row (FR-014, T022 Scenario 2)',
    (tester) async {
      final node = ExpenseControlNode(
        item: _item('family', name: 'Family'),
        children: [_item('groceries', parentId: 'family', name: 'Groceries')],
      );
      const subtotal = ExpenseControlTotals(
        percentAllocated: 20,
        fixedItemCount: 0,
        percentFree: 80,
      );
      await tester.pumpWidget(_harness(node, groupSubtotal: subtotal));

      // Collapse first, so the summary is showing.
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      expect(find.textContaining('20%'), findsOneWidget);

      // Expand again.
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.textContaining('20%'), findsNothing);
      expect(find.text('Groceries'), findsOneWidget);
    },
  );

  testWidgets(
    'a long collapsed summary has no overflow/ellipsis configured, so it wraps instead of truncating (FR-015, SC-005, T022 Scenario 1)',
    (tester) async {
      final node = ExpenseControlNode(
        item: _item('family', name: 'Family'),
        children: [_item('groceries', parentId: 'family', name: 'Groceries')],
      );
      // A high fixedItemCount pushes the rendered summary string long
      // enough that it would previously have needed truncation.
      const subtotal = ExpenseControlTotals(
        percentAllocated: 87,
        fixedItemCount: 12,
        percentFree: 13,
      );
      await tester.pumpWidget(_harness(node, groupSubtotal: subtotal));

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      final summaryText = tester.widget<Text>(find.textContaining('87%').last);
      expect(summaryText.overflow, isNot(TextOverflow.ellipsis));
    },
  );

  testWidgets(
    'a leaf ALSO shows "Thêm khoản trong [Tên nhóm]" — otherwise a leaf could never gain its first child (FR-002)',
    (tester) async {
      ExpenseControlItem? addedTo;
      final node = ExpenseControlNode(
        item: _item('rent', name: 'Rent'),
        children: const [],
      );
      await tester.pumpWidget(
        _harness(node, onAddChild: (item) => addedTo = item),
      );

      expect(find.text('Thêm khoản trong Rent'), findsOneWidget);
      await tester.tap(find.text('Thêm khoản trong Rent'));
      await tester.pump();

      expect(addedTo?.id, 'rent');
    },
  );

  testWidgets('deleting a group invokes onDeleteGroup, not onDeleteLeaf', (
    tester,
  ) async {
    ExpenseControlItem? deletedGroup;
    ExpenseControlItem? deletedLeaf;
    final node = ExpenseControlNode(
      item: _item('family', name: 'Family'),
      children: [_item('groceries', parentId: 'family')],
    );
    await tester.pumpWidget(
      _harness(
        node,
        onDeleteGroup: (item) => deletedGroup = item,
        onDeleteLeaf: (item) => deletedLeaf = item,
      ),
    );

    final trashFinder = find.widgetWithIcon(IconButton, LucideIcons.trash2);
    await tester.tap(trashFinder.first);
    await tester.pump();

    expect(deletedGroup?.id, 'family');
    expect(deletedLeaf, isNull);
  });
}
