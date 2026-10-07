import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finance/core/auth/auth_state_provider.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/domain/expense_control_repository.dart';
import 'package:finance/features/expense_control/presentation/expense_control_providers.dart';

import 'pull_complete_override.dart';

/// Shared fixtures for the adaptive-web tests (specs/20261007-100751-adaptive-
/// web-remaining-screens, tasks T008). A public copy of the behavior of the
/// private fakes in the existing Chi tiêu, Thu nhập and Kế hoạch tests, so the
/// new tests share one fake while those files stay untouched.
class FakeExpenseControlRepository implements ExpenseControlRepository {
  FakeExpenseControlRepository([List<ExpenseControlItem> initial = const []])
    : _items = List.of(initial);

  final List<ExpenseControlItem> _items;
  final _controller = StreamController<List<ExpenseControlItem>>.broadcast();

  var recordExpenseCallCount = 0;
  String? lastItemId;
  int? lastAmount;
  Map<String, int>? lastAppliedDeltas;
  final List<Map<String, PendingItemEdit>> savedFormulaBatches = [];
  final List<List<String>> reorderCalls = [];

  /// When set, [recordExpense] awaits this before resolving — simulates an
  /// in-flight save (double-press prevention).
  Completer<void>? recordExpenseGate;
  Object? throwOnRecordExpense;
  Object? throwOnApplyIncomeAllocation;
  Object? throwOnCreate;
  Object? throwOnSaveFormulas;

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
    if (throwOnCreate != null) throw throwOnCreate!;
    final parentId = item.parentId;
    if (parentId != null && !_items.any((i) => i.parentId == parentId)) {
      final parentIndex = _items.indexWhere((i) => i.id == parentId);
      if (parentIndex != -1) {
        _items[parentIndex] = _items[parentIndex].clearFormula();
      }
    }
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
    if (throwOnSaveFormulas != null) throw throwOnSaveFormulas!;
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
          isSavingsReceiver: entry.value.isSavingsReceiver,
        );
      }
    }
    _emit();
  }

  @override
  Future<void> applyIncomeAllocation(Map<String, int> balanceDeltas) async {
    if (throwOnApplyIncomeAllocation != null) {
      throw throwOnApplyIncomeAllocation!;
    }
    lastAppliedDeltas = balanceDeltas;
  }

  @override
  Future<void> recordExpense({
    required String itemId,
    required int amount,
  }) async {
    recordExpenseCallCount++;
    lastItemId = itemId;
    lastAmount = amount;
    if (recordExpenseGate != null) await recordExpenseGate!.future;
    if (throwOnRecordExpense != null) throw throwOnRecordExpense!;
  }
}

/// A top-level leaf item (an account the person can spend from).
ExpenseControlItem leafItem(
  String id, {
  String? parentId,
  String name = 'Item',
  int balance = 0,
  int sortOrder = 0,
  ExpenseAllocationMethod method = ExpenseAllocationMethod.percentage,
  double value = 10,
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
    balance: balance,
    isSavingsReceiver: false,
  );
}

/// A group item (no formula of its own) followed by its children.
List<ExpenseControlItem> groupWithChildren(
  String groupId, {
  String groupName = 'Nhóm',
  int childCount = 2,
  int sortOrder = 0,
}) {
  return [
    ExpenseControlItem(
      id: groupId,
      userId: 'u1',
      parentId: null,
      name: groupName,
      iconKey: 'home',
      description: null,
      sortOrder: sortOrder,
      allocationMethod: null,
      allocationValue: null,
      balance: 0,
      isSavingsReceiver: false,
    ),
    for (var i = 1; i <= childCount; i++)
      leafItem('$groupId-$i', parentId: groupId, name: 'Khoản $i', value: 10),
  ];
}

/// [count] chip-worthy leaf accounts under one shared group `g` (a chip shows
/// its group name as a second line, like the real data).
///
/// Widget tests do not load the Lexend font, so every glyph is a full em wide
/// (`Khoản 1` measures 98.7dp at 14dp instead of about 55dp). The default
/// 4-character names (`Ví 1`) are therefore about as wide as the 9-character
/// real names the spec's FR-005 talks about, which keeps "two rows hold at
/// least eight accounts" meaningful. `nameLength: 14` builds the long-name
/// case (names padded to 14 characters, so three or more rows are needed).
List<ExpenseControlItem> accounts(int count, {int nameLength = 4}) {
  String nameFor(int i) {
    final base = 'Ví $i';
    return base.length >= nameLength ? base : base.padRight(nameLength, 'x');
  }

  return [
    ExpenseControlItem(
      id: 'g',
      userId: 'u1',
      parentId: null,
      name: 'Nhóm',
      iconKey: 'home',
      description: null,
      sortOrder: 0,
      allocationMethod: null,
      allocationValue: null,
      balance: 0,
      isSavingsReceiver: false,
    ),
    for (var i = 1; i <= count; i++)
      leafItem(
        'a$i',
        parentId: 'g',
        name: nameFor(i),
        balance: 1000000 * i,
        sortOrder: i,
        value: 1,
      ),
  ];
}

/// Mirrors the shell: the navigation rail takes 83 dp from the screen while
/// `MediaQuery` keeps reporting the window width.
Widget withRail(Widget child) {
  return Row(
    children: [
      const SizedBox(width: 83),
      Expanded(child: child),
    ],
  );
}

/// Builds the `ProviderScope` + `MaterialApp` used by the existing harnesses,
/// with the providers every expense/plan screen needs (`pullCompleteOverride`,
/// a fixed current user).
Widget wrapForTest(
  Widget home, {
  FakeExpenseControlRepository? repository,
  ThemeData? theme,
  Locale locale = const Locale('vi'),
  List<Override> overrides = const [],
  bool rail = false,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      pullCompleteOverride,
      if (repository != null)
        expenseControlRepositoryProvider.overrideWithValue(repository),
      ...overrides,
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: rail ? withRail(home) : home,
    ),
  );
}
