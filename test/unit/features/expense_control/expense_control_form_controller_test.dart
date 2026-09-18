import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_plan_service.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExpenseControlRepository implements ExpenseControlRepository {
  final List<ExpenseControlItem> created = [];
  final List<ExpenseControlItem> updated = [];

  @override
  Future<void> create(ExpenseControlItem item) async => created.add(item);

  @override
  Future<void> update(ExpenseControlItem item) async => updated.add(item);

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<ExpenseControlItem>> getAll() async => [];

  @override
  Future<void> reorderTopLevel(List<String> orderedIds) async {}

  @override
  Future<void> saveFormulas(Map<String, ExpenseFormulaEdit> changes) async {}

  @override
  Stream<List<ExpenseControlItem>> watchAll() => const Stream.empty();
}

ExpenseControlItem _item({
  required String id,
  ExpenseAllocationMethod? method,
  double? value,
}) {
  return ExpenseControlItem(
    id: id,
    userId: 'u1',
    parentId: null,
    name: id,
    iconKey: 'home',
    description: null,
    sortOrder: 0,
    allocationMethod: method,
    allocationValue: value,
  );
}

void main() {
  late _FakeExpenseControlRepository repository;
  const planService = ExpenseControlPlanService();

  ExpenseControlFormController buildController({
    List<ExpenseControlItem> allItems = const [],
    ExpenseControlItem? existingItem,
    bool isFormulaEditable = true,
  }) {
    return ExpenseControlFormController(
      repository: repository,
      planService: planService,
      userId: 'u1',
      getAllItems: () => allItems,
      existingItem: existingItem,
      isFormulaEditable: isFormulaEditable,
    );
  }

  setUp(() {
    repository = _FakeExpenseControlRepository();
  });

  test('blank name is rejected — canSave is false and save() is a no-op', () async {
    final controller = buildController();
    controller.setValue(10);
    expect(controller.isNameValid, isFalse);
    expect(controller.canSave, isFalse);
    await controller.save();
    expect(repository.created, isEmpty);
  });

  test('zero/blank value is rejected for a leaf', () async {
    final controller = buildController();
    controller.setName('Rent');
    expect(controller.isValueValid, isFalse);
    await controller.save();
    expect(repository.created, isEmpty);
  });

  test('a valid leaf item is accepted and persisted', () async {
    final controller = buildController();
    controller.setName('Rent');
    controller.setValue(30);
    expect(controller.canSave, isTrue);
    await controller.save();
    expect(repository.created, hasLength(1));
    expect(repository.created.single.name, 'Rent');
    expect(repository.created.single.allocationValue, 30);
  });

  test('an over-budget candidate is rejected via the plan service', () async {
    final existing = [
      _item(id: '1', method: ExpenseAllocationMethod.percentage, value: 90),
    ];
    final controller = buildController(allItems: existing);
    controller.setName('Extra');
    controller.setValue(20);
    expect(controller.budgetValidation?.isValid, isFalse);
    expect(controller.canSave, isFalse);
    await controller.save();
    expect(repository.created, isEmpty);
  });

  test(
    'switching formula mode on an existing item replaces — not converts or retains — the stored value (FR-006)',
    () async {
      final existing = _item(
        id: '1',
        method: ExpenseAllocationMethod.fixed,
        value: 500000,
      );
      final controller = buildController(
        allItems: [existing],
        existingItem: existing,
      );
      expect(controller.canSave, isTrue); // pre-filled from existingItem

      controller.setMethod(ExpenseAllocationMethod.percentage);
      controller.setValue(25);
      await controller.save();

      expect(repository.updated, hasLength(1));
      final saved = repository.updated.single;
      expect(saved.allocationMethod, ExpenseAllocationMethod.percentage);
      expect(saved.allocationValue, 25);
    },
  );

  test(
    'the name/icon/description-only edit dialog (isFormulaEditable=false) never touches the formula',
    () async {
      final existing = _item(
        id: '1',
        method: ExpenseAllocationMethod.fixed,
        value: 500000,
      );
      final controller = buildController(
        allItems: [existing],
        existingItem: existing,
        isFormulaEditable: false,
      );
      controller.setName('Renamed');
      await controller.save();

      final saved = repository.updated.single;
      expect(saved.name, 'Renamed');
      expect(saved.allocationMethod, ExpenseAllocationMethod.fixed);
      expect(saved.allocationValue, 500000);
    },
  );
}
