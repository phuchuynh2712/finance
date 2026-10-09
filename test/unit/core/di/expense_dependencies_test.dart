import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/database/app_database.dart';
import 'package:finance/core/database/app_database_provider.dart';
import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/features/expense_control/data/transaction_correction_repository_impl.dart';
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

  test('correction repository is built for the signed-in user', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('signed-in-user'),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(transactionCorrectionRepositoryProvider),
      isA<TransactionCorrectionRepositoryImpl>(),
    );
  });

  test('correction repository cannot be read while signed out', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith(
          (ref) => throw StateError('Signed out'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(transactionCorrectionRepositoryProvider),
      throwsStateError,
    );
  });

  test('correction clock is injectable', () {
    final fixed = DateTime(2026, 10, 9);
    final container = ProviderContainer(
      overrides: [correctionNowProvider.overrideWithValue(() => fixed)],
    );
    addTearDown(container.dispose);

    expect(container.read(correctionNowProvider)(), fixed);
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
