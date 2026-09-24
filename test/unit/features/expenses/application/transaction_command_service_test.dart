import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expenses/application/expense_control_gateway.dart';
import 'package:finance/features/expenses/application/transaction_command_service.dart';

void main() {
  test('allocates income through the domain plan service', () {
    final item = ExpenseControlItem(
      id: 'food',
      userId: 'user',
      parentId: null,
      name: 'Food',
      iconKey: 'wallet',
      description: null,
      sortOrder: 0,
      allocationMethod: ExpenseAllocationMethod.percentage,
      allocationValue: 20,
      balance: 0,
      isSavingsReceiver: false,
    );
    final gateway = ExpenseControlGateway(
      repository: _FakeRepository(),
      planService: const ExpenseControlPlanService(),
    );
    final service = TransactionCommandService(gateway);

    final result = service.allocateIncome(gateway.buildTree([item]), 1000);

    expect(result.deltas, {'food': 200});
  });
}

class _FakeRepository implements ExpenseControlRepository {
  @override
  Stream<List<ExpenseControlItem>> watchAll() => const Stream.empty();

  @override
  Future<List<ExpenseControlItem>> getAll() async => const [];

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
  Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas) async {}

  @override
  Future<void> recordExpense({
    required String itemId,
    required int amount,
  }) async {}
}
