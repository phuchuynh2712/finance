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
    allocationMethod: parentId == null ? ExpenseAllocationMethod.percentage : null,
    allocationValue: parentId == null ? 20 : null,
  );
}

Widget _harness(ExpenseControlNode node, {
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
            onValueChanged: (_, _) {},
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
  testWidgets('a group with children shows a chevron and, when tapped, toggles expand/collapse independently', (
    tester,
  ) async {
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
  });

  testWidgets('tapping "Thêm khoản trong [Tên nhóm]" invokes onAddChild with the group item', (
    tester,
  ) async {
    ExpenseControlItem? addedTo;
    final node = ExpenseControlNode(
      item: _item('family', name: 'Family'),
      children: [_item('groceries', parentId: 'family')],
    );
    await tester.pumpWidget(_harness(node, onAddChild: (item) => addedTo = item));

    await tester.tap(find.text('Thêm khoản trong Family'));
    await tester.pump();

    expect(addedTo?.id, 'family');
  });

  testWidgets('a childless (leaf) node renders its formula row directly, with no chevron', (
    tester,
  ) async {
    final node = ExpenseControlNode(item: _item('rent', name: 'Rent'), children: const []);
    await tester.pumpWidget(_harness(node));

    expect(find.text('Rent'), findsOneWidget);
    // The leaf's own formula field (value input + %/₫ toggle) is present.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('%'), findsOneWidget);
    expect(find.text('₫'), findsOneWidget);
  });

  testWidgets(
    "a group's sub-label shows the live sum of its children's formulas — not its own (cleared) formula",
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

      expect(find.textContaining('35%'), findsOneWidget);
      expect(find.textContaining('1'), findsWidgets);
    },
  );

  testWidgets(
    'a leaf ALSO shows "Thêm khoản trong [Tên nhóm]" — otherwise a leaf could never gain its first child (FR-002)',
    (tester) async {
      ExpenseControlItem? addedTo;
      final node = ExpenseControlNode(item: _item('rent', name: 'Rent'), children: const []);
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
