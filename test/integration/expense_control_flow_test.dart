import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:finance/core/database/app_database.dart';
import 'package:finance/features/expense_control/data/expense_control_repository_impl.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';

const _uuid = Uuid();
const _userId = 'test-user';

void main() {
  late AppDatabase db;
  late ExpenseControlRepositoryImpl repository;
  const planService = ExpenseControlPlanService();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ExpenseControlRepositoryImpl(db, userId: _userId);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'create -> group (add child) -> inline-edit formula -> Lưu công thức -> reorder top-level -> delete, end to end',
    () async {
      // 1. Create two top-level leaf items (per quickstart.md item 1).
      final rentId = _uuid.v4();
      final familyId = _uuid.v4();
      await repository.create(
        ExpenseControlItem(
          id: rentId,
          userId: _userId,
          parentId: null,
          name: 'Rent',
          iconKey: 'home',
          description: null,
          sortOrder: 0,
          allocationMethod: ExpenseAllocationMethod.fixed,
          allocationValue: 5000000,
          balance: 0,
          isSavingsReceiver: false,
        ),
      );
      await repository.create(
        ExpenseControlItem(
          id: familyId,
          userId: _userId,
          parentId: null,
          name: 'Family',
          iconKey: 'family',
          description: null,
          sortOrder: 1,
          allocationMethod: ExpenseAllocationMethod.percentage,
          allocationValue: 30,
          balance: 0,
          isSavingsReceiver: false,
        ),
      );

      // 2. Group: add a child under "Family" — it becomes a group and its
      //    own formula is cleared (per quickstart.md item 4).
      final groceriesId = _uuid.v4();
      await repository.create(
        ExpenseControlItem(
          id: groceriesId,
          userId: _userId,
          parentId: familyId,
          name: 'Groceries',
          iconKey: 'utensils',
          description: null,
          sortOrder: 0,
          allocationMethod: ExpenseAllocationMethod.percentage,
          allocationValue: 15,
          balance: 0,
          isSavingsReceiver: false,
        ),
      );

      var items = await repository.getAll();
      final family = items.firstWhere((i) => i.id == familyId);
      expect(family.allocationMethod, isNull, reason: 'FR-004');
      var totals = planService.computeTotals(items);
      expect(totals.percentAllocated, 15, reason: 'only the child counts');

      // 3. Inline-edit formula -> "Lưu công thức" (per quickstart.md item 7).
      final pending = {
        groceriesId: const PendingItemEdit(
          method: ExpenseAllocationMethod.percentage,
          value: 25,
        ),
      };
      final validation = planService.validateBudget(
        items,
        pendingEdits: pending,
      );
      expect(validation.isValid, isTrue);
      await repository.saveFormulas(pending);

      items = await repository.getAll();
      totals = planService.computeTotals(items);
      expect(totals.percentAllocated, 25);
      expect(totals.fixedItemCount, 1);

      // 4. Reorder top-level items (per quickstart.md item 8).
      await repository.reorderTopLevel([familyId, rentId]);
      items = await repository.getAll();
      final familyAfterReorder = items.firstWhere((i) => i.id == familyId);
      final rentAfterReorder = items.firstWhere((i) => i.id == rentId);
      expect(familyAfterReorder.sortOrder, 0);
      expect(rentAfterReorder.sortOrder, 1);

      // 5. Delete: the group cascades to its child (per quickstart.md item 8).
      await repository.delete(familyId);
      items = await repository.getAll();
      expect(items.map((i) => i.id), [rentId]);

      // 6. Persistence survives a fresh repository instance against the same DB
      //    (simulating an app restart, per quickstart.md items 1/8).
      final repositoryAfterRestart = ExpenseControlRepositoryImpl(
        db,
        userId: _userId,
      );
      final persisted = await repositoryAfterRestart.getAll();
      expect(persisted.single.id, rentId);
      expect(persisted.single.allocationValue, 5000000);
    },
  );
}
