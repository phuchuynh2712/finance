import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';

ExpenseControlItem _leaf(
  String id, {
  String? parentId,
  required ExpenseAllocationMethod method,
  required double value,
  int sortOrder = 0,
  bool isSavingsReceiver = false,
  int balance = 0,
}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: parentId,
    name: id,
    iconKey: 'home',
    description: null,
    sortOrder: sortOrder,
    allocationMethod: method,
    allocationValue: value,
    balance: balance,
    isSavingsReceiver: isSavingsReceiver,
  );
}

ExpenseControlItem _group(String id, {int sortOrder = 0}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: null,
    name: id,
    iconKey: 'home',
    description: null,
    sortOrder: sortOrder,
    allocationMethod: null,
    allocationValue: null,
    balance: 0,
    isSavingsReceiver: false,
  );
}

void main() {
  const service = ExpenseControlPlanService();

  group('computeIncomeAllocation — main sequential pass (FR-005, FR-006)', () {
    test(
      'every leaf fully covered by ample income receives exactly its formula share, in sortOrder including group-children interleaving',
      () {
        final items = [
          _leaf(
            'fixed1',
            method: ExpenseAllocationMethod.fixed,
            value: 300000,
            sortOrder: 0,
          ),
          _group('family', sortOrder: 1),
          _leaf(
            'child1',
            parentId: 'family',
            method: ExpenseAllocationMethod.percentage,
            value: 20,
            sortOrder: 0,
          ),
          _leaf(
            'percent1',
            method: ExpenseAllocationMethod.percentage,
            value: 10,
            sortOrder: 2,
          ),
        ];
        final tree = service.buildTree(items);
        final result = service.computeIncomeAllocation(tree, 10000000);

        expect(result.deltas['fixed1'], 300000);
        expect(result.deltas['child1'], 2000000); // 20% of 10,000,000
        expect(result.deltas['percent1'], 1000000); // 10% of 10,000,000
        expect(result.unallocatedAmount, 10000000 - 300000 - 2000000 - 1000000);
      },
    );

    test(
      'percentage is computed against the original total income, not a shrinking remainder',
      () {
        // If computed against a shrinking remainder, item2's 50% would be
        // 50% of (1,000,000 - 500,000) = 250,000, not 500,000.
        final items = [
          _leaf(
            'item1',
            method: ExpenseAllocationMethod.fixed,
            value: 500000,
            sortOrder: 0,
          ),
          _leaf(
            'item2',
            method: ExpenseAllocationMethod.percentage,
            value: 50,
            sortOrder: 1,
          ),
        ];
        final tree = service.buildTree(items);
        final result = service.computeIncomeAllocation(tree, 1000000);

        expect(result.deltas['item1'], 500000);
        expect(result.deltas['item2'], 500000); // 50% of ORIGINAL 1,000,000
        expect(result.unallocatedAmount, 0);
      },
    );

    test(
      'insufficient income: the underfunded leaf receives only what remains, then the sequence halts — no later leaf receives anything',
      () {
        final items = [
          _leaf(
            'a',
            method: ExpenseAllocationMethod.fixed,
            value: 5000000,
            sortOrder: 0,
          ),
          _leaf(
            'b',
            method: ExpenseAllocationMethod.fixed,
            value: 5000000,
            sortOrder: 1,
          ),
          _leaf(
            'c',
            method: ExpenseAllocationMethod.fixed,
            value: 5000000,
            sortOrder: 2,
          ),
        ];
        final tree = service.buildTree(items);
        final result = service.computeIncomeAllocation(tree, 7000000);

        expect(result.deltas['a'], 5000000);
        expect(result.deltas['b'], 2000000); // all that remained
        expect(result.deltas.containsKey('c'), isFalse);
        expect(result.unallocatedAmount, 0);
      },
    );

    test(
      'fixed and percentage shares round via .round() (round-half-away-from-zero)',
      () {
        final items = [
          _leaf(
            'p',
            method: ExpenseAllocationMethod.percentage,
            value: 33,
            sortOrder: 0,
          ),
        ];
        final tree = service.buildTree(items);
        // 33% of 1,000,001 = 330,000.33 -> rounds to 330,000
        final result = service.computeIncomeAllocation(tree, 1000001);
        expect(result.deltas['p'], 330000);
      },
    );

    test(
      'zero leaves in the tree returns an empty delta map and unallocatedAmount == totalIncome',
      () {
        final result = service.computeIncomeAllocation(const [], 500000);
        expect(result.deltas, isEmpty);
        expect(result.unallocatedAmount, 500000);
      },
    );

    test('formulas summing to exactly the income leave zero leftover', () {
      final items = [
        _leaf(
          'a',
          method: ExpenseAllocationMethod.fixed,
          value: 400000,
          sortOrder: 0,
        ),
        _leaf(
          'b',
          method: ExpenseAllocationMethod.fixed,
          value: 600000,
          sortOrder: 1,
        ),
      ];
      final tree = service.buildTree(items);
      final result = service.computeIncomeAllocation(tree, 1000000);
      expect(result.unallocatedAmount, 0);
    });
  });

  group(
    'computeIncomeAllocation — savings-receiver leftover step (FR-012, FR-013)',
    () {
      test(
        'leftover after full formula coverage lands entirely on the marked leaf, on top of its own formula share',
        () {
          final items = [
            _leaf(
              'regular',
              method: ExpenseAllocationMethod.percentage,
              value: 20,
              sortOrder: 0,
            ),
            _leaf(
              'receiver',
              method: ExpenseAllocationMethod.percentage,
              value: 10,
              sortOrder: 1,
              isSavingsReceiver: true,
            ),
          ];
          final tree = service.buildTree(items);
          final result = service.computeIncomeAllocation(tree, 10000000);

          // regular: 20% = 2,000,000. receiver: 10% = 1,000,000 own share,
          // then leftover = 10,000,000 - 2,000,000 - 1,000,000 = 7,000,000.
          expect(result.deltas['regular'], 2000000);
          expect(result.deltas['receiver'], 1000000 + 7000000);
          expect(result.unallocatedAmount, 0);
        },
      );

      test(
        'no leaf marked: leftover is reported as unallocatedAmount, no delta reflects it',
        () {
          final items = [
            _leaf(
              'a',
              method: ExpenseAllocationMethod.percentage,
              value: 20,
              sortOrder: 0,
            ),
          ];
          final tree = service.buildTree(items);
          final result = service.computeIncomeAllocation(tree, 1000000);

          expect(result.deltas['a'], 200000);
          expect(result.unallocatedAmount, 800000);
        },
      );

      test(
        'allocation halted early by insufficient income: leftover is mechanically 0 even with a receiver marked',
        () {
          final items = [
            _leaf(
              'a',
              method: ExpenseAllocationMethod.fixed,
              value: 5000000,
              sortOrder: 0,
            ),
            _leaf(
              'receiver',
              method: ExpenseAllocationMethod.fixed,
              value: 5000000,
              sortOrder: 1,
              isSavingsReceiver: true,
            ),
          ];
          final tree = service.buildTree(items);
          final result = service.computeIncomeAllocation(tree, 3000000);

          expect(result.deltas['a'], 3000000);
          expect(result.deltas.containsKey('receiver'), isFalse);
          expect(result.unallocatedAmount, 0);
        },
      );

      test(
        'multi-receiver tie-break: if more than one leaf is transiently marked (accepted rare sync race), only the first in sortOrder receives the leftover',
        () {
          final items = [
            _leaf(
              'first',
              method: ExpenseAllocationMethod.percentage,
              value: 10,
              sortOrder: 0,
              isSavingsReceiver: true,
            ),
            _leaf(
              'second',
              method: ExpenseAllocationMethod.percentage,
              value: 10,
              sortOrder: 1,
              isSavingsReceiver: true,
            ),
          ];
          final tree = service.buildTree(items);
          final result = service.computeIncomeAllocation(tree, 1000000);

          // first: 10% = 100,000 + leftover. second: 10% = 100,000 only.
          expect(result.deltas['first'], 100000 + 800000);
          expect(result.deltas['second'], 100000);
          expect(result.unallocatedAmount, 0);
        },
      );
    },
  );
}
