import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expenses/application/expense_control_gateway.dart';

void main() {
  test('forwards expense writes through the application contract', () async {
    final repository = _FakeExpenseControlRepository();
    final gateway = ExpenseControlGateway(
      repository: repository,
      planService: const ExpenseControlPlanService(),
    );

    await gateway.recordExpense(itemId: 'food', amount: 1200);
    await gateway.applyIncomeAllocation({'food': 500});

    expect(repository.recordedExpense, ('food', 1200));
    expect(repository.incomeDeltas, {'food': 500});
  });

  test(
    'exposes repository reads without exposing provider composition',
    () async {
      final item = _item('food');
      final repository = _FakeExpenseControlRepository(items: [item]);
      final gateway = ExpenseControlGateway(
        repository: repository,
        planService: const ExpenseControlPlanService(),
      );

      expect(await gateway.getItems(), [item]);
      expect(await gateway.watchItems().first, [item]);
    },
  );
}

class _FakeExpenseControlRepository implements ExpenseControlRepository {
  _FakeExpenseControlRepository({List<ExpenseControlItem>? items})
    : items = items ?? const [];

  final List<ExpenseControlItem> items;
  (String, int)? recordedExpense;
  Map<String, int>? incomeDeltas;

  @override
  Stream<List<ExpenseControlItem>> watchAll() => Stream.value(items);

  @override
  Future<List<ExpenseControlItem>> getAll() async => items;

  @override
  Future<void> create(ExpenseControlItem item) async {}

  @override
  Future<void> update(ExpenseControlItem item) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> reorderTopLevel(List<String> orderedIds) async {}

  @override
  Future<void> saveFormulas(Map<String, PendingItemEdit> changes) async {}

  @override
  Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas) async {
    incomeDeltas = balanceDeltas;
  }

  @override
  Future<void> recordExpense({
    required String itemId,
    required int amount,
  }) async {
    recordedExpense = (itemId, amount);
  }
}

ExpenseControlItem _item(String id) {
  return ExpenseControlItem(
    id: id,
    userId: 'user',
    parentId: null,
    name: 'Food',
    iconKey: 'wallet',
    description: null,
    sortOrder: 0,
    allocationMethod: ExpenseAllocationMethod.fixed,
    allocationValue: 100,
    balance: 0,
    isSavingsReceiver: false,
  );
}
