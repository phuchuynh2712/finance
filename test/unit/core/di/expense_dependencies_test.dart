import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expenses/application/expense_control_gateway.dart';

void main() {
  test('expense gateway keeps repository construction overrideable', () {
    final fake = _FakeRepository();
    final container = ProviderContainer(
      overrides: [expenseControlRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final gateway = container.read(expenseControlGatewayProvider);
    expect(gateway.repository, same(fake));
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
