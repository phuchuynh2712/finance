import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';
import 'package:finance/features/expense_control/presentation/expense_control_screen.dart';

class _FakeExpenseControlRepository implements ExpenseControlRepository {
  _FakeExpenseControlRepository(List<ExpenseControlItem> initial)
    : _items = List.of(initial);

  final List<ExpenseControlItem> _items;
  final _controller = StreamController<List<ExpenseControlItem>>.broadcast();
  final List<Map<String, PendingItemEdit>> savedFormulaBatches = [];
  final List<List<String>> reorderCalls = [];

  void _emit() => _controller.add(List.of(_items));

  @override
  Stream<List<ExpenseControlItem>> watchAll() {
    Future.microtask(_emit);
    return _controller.stream;
  }

  @override
  Future<List<ExpenseControlItem>> getAll() async => List.of(_items);

  @override
  Future<void> create(ExpenseControlItem item) async {
    _items.add(item);
    _emit();
  }

  @override
  Future<void> update(ExpenseControlItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) _items[index] = item;
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((i) => i.id == id || i.parentId == id);
    _emit();
  }

  @override
  Future<void> reorderTopLevel(List<String> orderedIds) async {
    reorderCalls.add(orderedIds);
    for (var i = 0; i < orderedIds.length; i++) {
      final index = _items.indexWhere((item) => item.id == orderedIds[i]);
      if (index != -1) {
        _items[index] = _items[index].copyWith(sortOrder: i);
      }
    }
    _emit();
  }

  @override
  Future<void> saveFormulas(Map<String, PendingItemEdit> changes) async {
    savedFormulaBatches.add(changes);
    for (final entry in changes.entries) {
      final index = _items.indexWhere((item) => item.id == entry.key);
      if (index != -1) {
        _items[index] = _items[index].copyWith(
          name: entry.value.name,
          iconKey: entry.value.iconKey,
          description: entry.value.description,
          allocationMethod: entry.value.method,
          allocationValue: entry.value.value,
        );
      }
    }
    _emit();
  }
}

ExpenseControlItem _leaf(
  String id, {
  ExpenseAllocationMethod method = ExpenseAllocationMethod.percentage,
  double value = 10,
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

Widget _harness(_FakeExpenseControlRepository repository) {
  return ProviderScope(
    overrides: [
      expenseControlRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const ExpenseControlScreen(),
    ),
  );
}

/// Same harness, but backed by a [ProviderContainer] the test keeps a handle
/// to — needed to seed/assert `pendingItemEditsProvider` directly rather
/// than only through UI interaction (T006/T014/T015's staged-edit tests).
Widget _harnessWithContainer(
  _FakeExpenseControlRepository repository,
  ProviderContainer container,
) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const ExpenseControlScreen(),
    ),
  );
}

ProviderContainer _containerFor(_FakeExpenseControlRepository repository) {
  return ProviderContainer(
    overrides: [
      expenseControlRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
}

void main() {
  testWidgets(
    'empty state renders with CTA and no allocation banner (FR-023, US1 Scenario 1)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.text('Thêm khoản mới'), findsOneWidget);
      expect(find.textContaining('Đã phân bổ'), findsNothing);
    },
  );

  testWidgets('create-and-list happy path', (tester) async {
    final repository = _FakeExpenseControlRepository([]);
    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm khoản mới').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Tên khoản'), 'Rent');
    await tester.enterText(find.widgetWithText(TextField, 'Giá trị'), '30');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(repository._items, hasLength(1));
    expect(repository._items.single.name, 'Rent');
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets(
    'save is blocked at 105% total with the offending total flagged',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a', value: 60)]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm khoản mới').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tên khoản'),
        'Extra',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Giá trị'), '45');
      await tester.pump();

      expect(find.textContaining('105'), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu'),
      );
      expect(saveButton.onPressed, isNull);
    },
  );

  testWidgets(
    'save is blocked at exactly 100% when a fixed item exists (FR-008)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('a', value: 70),
        _leaf('b', method: ExpenseAllocationMethod.fixed, value: 200000),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thêm khoản mới').first, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tên khoản'),
        'Extra',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Giá trị'), '30');
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu'),
      );
      expect(saveButton.onPressed, isNull);
    },
  );

  testWidgets('save is blocked on zero/blank value', (tester) async {
    final repository = _FakeExpenseControlRepository([]);
    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm khoản mới').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tên khoản'), 'Rent');
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lưu'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('deleting a leaf removes it immediately (US3 Scenario 4)', (
    tester,
  ) async {
    final repository = _FakeExpenseControlRepository([_leaf('a')]);
    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    expect(find.text('a'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, LucideIcons.trash2).first);
    await tester.pump();

    expect(repository._items, isEmpty);
  });

  testWidgets(
    'editing a leaf via the pencil dialog stages the change — it is not persisted until "Lưu công thức" (research.md Decision 3)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a')]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithIcon(IconButton, LucideIcons.pencil).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tên khoản'),
        'Renamed',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();

      // Nothing written to the repository yet — the rename is only staged.
      expect(repository._items.single.name, 'a');
      expect(repository.savedFormulaBatches, isEmpty);
      // The tree overlays the staged edit, so it's visible immediately.
      expect(find.text('Renamed'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Lưu công thức'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('Lưu công thức'));
      await tester.pumpAndSettle();

      expect(repository._items.single.name, 'Renamed');
      // The edit dialog never touches the formula.
      expect(repository._items.single.allocationValue, 10);
      expect(repository.savedFormulaBatches, hasLength(1));
    },
  );

  testWidgets(
    'deleting a group shows the confirmation dialog and cascades on confirm (US3 Scenario 3)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('family'),
        ExpenseControlItem(
          id: 'child',
          userId: 'u1',
          parentId: 'family',
          name: 'child',
          iconKey: 'home',
          description: null,
          sortOrder: 0,
          allocationMethod: ExpenseAllocationMethod.percentage,
          allocationValue: 5,
        ),
      ]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithIcon(IconButton, LucideIcons.trash2).first,
      );
      await tester.pumpAndSettle();

      // Confirmation dialog is showing; deletion hasn't happened yet.
      expect(find.text('Xoá nhóm "family"?'), findsOneWidget);
      expect(repository._items, hasLength(2));

      await tester.tap(find.text('Xoá').last);
      await tester.pumpAndSettle();

      expect(repository._items, isEmpty);
    },
  );

  testWidgets(
    'with zero staged edits, "Lưu công thức" is not shown (FR-007, US2 Scenario 3)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a', value: 20)]);
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();

      expect(find.text('Lưu công thức'), findsNothing);
    },
  );

  testWidgets(
    'a staged formula change is reflected live, then "Lưu công thức" persists it (T014, research.md §9)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a', value: 20)]);
      final container = _containerFor(repository);
      addTearDown(container.dispose);
      await tester.pumpWidget(_harnessWithContainer(repository, container));
      await tester.pumpAndSettle();

      container.read(pendingItemEditsProvider.notifier).state = {
        'a': const PendingItemEdit(value: 50),
      };
      await tester.pump();

      // Live overlay reflected before saving — nothing persisted yet.
      expect(find.textContaining('50%'), findsWidgets);
      expect(repository._items.single.allocationValue, 20);

      await tester.tap(find.text('Lưu công thức'));
      await tester.pumpAndSettle();

      expect(repository._items.single.allocationValue, 50);
      expect(repository.savedFormulaBatches, hasLength(1));
      expect(container.read(pendingItemEditsProvider), isEmpty);
    },
  );

  testWidgets(
    'a staged name change commits together with the staged formula (FR-004 "together as a single pending edit", T014)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([_leaf('a', value: 20)]);
      final container = _containerFor(repository);
      addTearDown(container.dispose);
      await tester.pumpWidget(_harnessWithContainer(repository, container));
      await tester.pumpAndSettle();

      container.read(pendingItemEditsProvider.notifier).state = {
        'a': const PendingItemEdit(name: 'Renamed', value: 50),
      };
      await tester.pump();

      await tester.tap(find.text('Lưu công thức'));
      await tester.pumpAndSettle();

      expect(repository._items.single.name, 'Renamed');
      expect(repository._items.single.allocationValue, 50);
    },
  );

  testWidgets(
    '"Lưu công thức" stays blocked and flags the total when the pending plan is over budget (FR-012)',
    (tester) async {
      final repository = _FakeExpenseControlRepository([
        _leaf('a', value: 20),
        _leaf('b', value: 30),
      ]);
      final container = _containerFor(repository);
      addTearDown(container.dispose);
      await tester.pumpWidget(_harnessWithContainer(repository, container));
      await tester.pumpAndSettle();

      container.read(pendingItemEditsProvider.notifier).state = {
        'a': const PendingItemEdit(value: 90),
      };
      await tester.pump();
      await tester.dragUntilVisible(
        find.text('Lưu công thức'),
        find.byType(ListView),
        const Offset(0, -200),
      );

      expect(find.textContaining('120'), findsWidgets);
      final saveFormulaButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Lưu công thức'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(saveFormulaButton.onPressed, isNull);
      expect(repository.savedFormulaBatches, isEmpty);
    },
  );

  group('T006: dialog formula-edit behavior', () {
    testWidgets(
      "opening a leaf's edit dialog pre-fills its mode/value as editable fields (FR-003 leaf branch)",
      (tester) async {
        final repository = _FakeExpenseControlRepository([
          _leaf('a', method: ExpenseAllocationMethod.percentage, value: 42),
        ]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithIcon(IconButton, LucideIcons.pencil).first,
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'Giá trị'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Giá trị'))
              .controller
              ?.text,
          '42',
        );
      },
    );

    testWidgets(
      "opening a group's edit dialog shows only name/icon/description, no formula fields (FR-003 group branch, US1 Scenario 6)",
      (tester) async {
        final repository = _FakeExpenseControlRepository([
          ExpenseControlItem(
            id: 'family',
            userId: 'u1',
            parentId: null,
            name: 'family',
            iconKey: 'home',
            description: null,
            sortOrder: 0,
            allocationMethod: null,
            allocationValue: null,
          ),
          ExpenseControlItem(
            id: 'child',
            userId: 'u1',
            parentId: 'family',
            name: 'child',
            iconKey: 'home',
            description: null,
            sortOrder: 0,
            allocationMethod: ExpenseAllocationMethod.percentage,
            allocationValue: 5,
          ),
        ]);
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithIcon(IconButton, LucideIcons.pencil).first,
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'Giá trị'), findsNothing);
      },
    );

    testWidgets(
      "reopening a leaf's dialog before committing shows the previously staged value (FR-008, Scenario 4)",
      (tester) async {
        final repository = _FakeExpenseControlRepository([
          _leaf('a', method: ExpenseAllocationMethod.percentage, value: 20),
        ]);
        final container = _containerFor(repository);
        addTearDown(container.dispose);
        await tester.pumpWidget(_harnessWithContainer(repository, container));
        await tester.pumpAndSettle();

        container.read(pendingItemEditsProvider.notifier).state = {
          'a': const PendingItemEdit(value: 77),
        };
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithIcon(IconButton, LucideIcons.pencil).first,
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Giá trị'))
              .controller
              ?.text,
          '77',
        );
      },
    );

    testWidgets(
      'an over-budget value blocks "Lưu" in the dialog with an inline error and stages nothing (FR-006, Scenario 5)',
      (tester) async {
        final repository = _FakeExpenseControlRepository([
          _leaf('a', method: ExpenseAllocationMethod.percentage, value: 20),
          _leaf('b', method: ExpenseAllocationMethod.percentage, value: 70),
        ]);
        final container = _containerFor(repository);
        addTearDown(container.dispose);
        await tester.pumpWidget(_harnessWithContainer(repository, container));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithIcon(IconButton, LucideIcons.pencil).first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'Giá trị'), '50');
        await tester.pump();

        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Lưu'),
        );
        expect(saveButton.onPressed, isNull);
        expect(container.read(pendingItemEditsProvider), isEmpty);
      },
    );
  });
}
