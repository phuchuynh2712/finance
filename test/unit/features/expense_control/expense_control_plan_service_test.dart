import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';

ExpenseControlItem _item({
  required String id,
  String? parentId,
  ExpenseAllocationMethod? method,
  double? value,
  int sortOrder = 0,
  String name = 'Item',
}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: parentId,
    name: name,
    iconKey: 'home',
    description: null,
    sortOrder: sortOrder,
    allocationMethod: method,
    allocationValue: value,
  );
}

void main() {
  final service = const ExpenseControlPlanService();

  group('computeTotals', () {
    test('sums percentage leaves and counts fixed leaves', () {
      final items = [
        _item(id: '1', method: ExpenseAllocationMethod.percentage, value: 60),
        _item(id: '2', method: ExpenseAllocationMethod.fixed, value: 500000),
      ];
      final totals = service.computeTotals(items);
      expect(totals.percentAllocated, 60);
      expect(totals.fixedItemCount, 1);
      expect(totals.percentFree, 40);
    });

    test('a group with children does not count its own (null) formula, only children do', () {
      final items = [
        _item(id: 'group', method: null, value: null),
        _item(
          id: 'child1',
          parentId: 'group',
          method: ExpenseAllocationMethod.percentage,
          value: 25,
        ),
      ];
      final totals = service.computeTotals(items);
      expect(totals.percentAllocated, 25);
    });

    test('applies a pending-edit overlay without mutating persisted values', () {
      final items = [
        _item(id: '1', method: ExpenseAllocationMethod.percentage, value: 20),
      ];
      final totals = service.computeTotals(
        items,
        pendingEdits: {
          '1': const PendingItemEdit(
            method: ExpenseAllocationMethod.percentage,
            value: 50,
          ),
        },
      );
      expect(totals.percentAllocated, 50);
    });
  });

  group('validateBudget', () {
    test('blocks when percentage sum exceeds 100%', () {
      final items = [
        _item(id: '1', method: ExpenseAllocationMethod.percentage, value: 60),
        _item(id: '2', method: ExpenseAllocationMethod.percentage, value: 45),
      ];
      final result = service.validateBudget(items);
      expect(result.isValid, isFalse);
      expect(result.violatingTotal, 105);
    });

    test('blocks at exactly 100% when a fixed item exists (strict <100%, FR-008)', () {
      final items = [
        _item(id: '1', method: ExpenseAllocationMethod.percentage, value: 100),
        _item(id: '2', method: ExpenseAllocationMethod.fixed, value: 200000),
      ];
      final result = service.validateBudget(items);
      expect(result.isValid, isFalse);
      expect(result.violatingTotal, 100);
    });

    test('allows exactly 100% when no fixed item exists', () {
      final items = [
        _item(id: '1', method: ExpenseAllocationMethod.percentage, value: 100),
      ];
      final result = service.validateBudget(items);
      expect(result.isValid, isTrue);
    });

    test('validates a candidate via the pending-edit overlay before persisting', () {
      final items = [
        _item(id: '1', method: ExpenseAllocationMethod.percentage, value: 70),
        _item(id: '2', method: ExpenseAllocationMethod.fixed, value: 100000),
      ];
      final result = service.validateBudget(
        items,
        pendingEdits: {
          '1': const PendingItemEdit(
            method: ExpenseAllocationMethod.percentage,
            value: 100,
          ),
        },
      );
      expect(result.isValid, isFalse);
      expect(result.violatingTotal, 100);
    });
  });

  group('buildTree', () {
    test('groups children under their parent, ordered by sortOrder', () {
      final items = [
        _item(id: 'a', sortOrder: 1),
        _item(id: 'b', sortOrder: 0),
        _item(id: 'a2', parentId: 'a', sortOrder: 1),
        _item(id: 'a1', parentId: 'a', sortOrder: 0),
      ];
      final tree = service.buildTree(items);
      expect(tree.map((n) => n.item.id), ['b', 'a']);
      final groupA = tree.firstWhere((n) => n.item.id == 'a');
      expect(groupA.children.map((c) => c.id), ['a1', 'a2']);
      expect(groupA.isGroup, isTrue);
    });

    test('a leaf with no children is not a group', () {
      final tree = service.buildTree([_item(id: 'leaf')]);
      expect(tree.single.isGroup, isFalse);
    });
  });

  group('leaf⇄group transitions (US2)', () {
    test(
      'leaf→group: once an item has a child, its own (now-null) formula is excluded from totals — only the child counts',
      () {
        final items = [
          _item(id: 'family', method: null, value: null, name: 'Family'),
          _item(
            id: 'groceries',
            parentId: 'family',
            method: ExpenseAllocationMethod.percentage,
            value: 15,
          ),
        ];
        final tree = service.buildTree(items);
        final familyNode = tree.single;
        expect(familyNode.isGroup, isTrue);
        expect(service.computeTotals(items).percentAllocated, 15);
      },
    );

    test(
      'group→leaf: once a group has zero children again, it is a leaf and its formula slot is eligible (not auto-restored) rather than counting a stale value',
      () {
        // The last child has already been removed by the caller (repository
        // delete()); the former group row itself is untouched (still null
        // formula, data-model.md's state-transition table).
        final items = [
          _item(id: 'family', method: null, value: null, name: 'Family'),
        ];
        final tree = service.buildTree(items);
        expect(tree.single.isGroup, isFalse);
        expect(service.computeTotals(items).percentAllocated, 0);
      },
    );
  });

  group('isNestingAllowed (FR-002)', () {
    test('allows nesting under a top-level item', () {
      final items = [_item(id: 'top')];
      expect(service.isNestingAllowed(items, 'top'), isTrue);
    });

    test('rejects nesting under an item that is itself a child (no grandchildren)', () {
      final items = [
        _item(id: 'top'),
        _item(id: 'child', parentId: 'top'),
      ];
      expect(service.isNestingAllowed(items, 'child'), isFalse);
    });
  });
}
