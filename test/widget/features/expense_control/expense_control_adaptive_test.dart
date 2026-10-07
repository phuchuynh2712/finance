import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/presentation/expense_control_screen.dart';
import 'package:finance/features/expense_control/presentation/widgets/allocation_summary_banner.dart';
import 'package:finance/features/expense_control/presentation/widgets/expense_group_card.dart';
import 'package:finance/features/expense_control/presentation/widgets/expense_item_row.dart';

import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';
import '../../../support/load_app_fonts.dart';

List<ExpenseControlItem> _plan({int groupChildren = 2}) => [
  ...groupWithChildren('g1', groupName: 'Nhà', childCount: groupChildren),
  leafItem('solo', name: 'Tiết kiệm', sortOrder: 1, value: 20),
];

Future<FakeExpenseControlRepository> _pump(
  WidgetTester tester, {
  required double width,
  required double height,
  List<ExpenseControlItem>? items,
  bool rail = false,
  ThemeData? theme,
}) async {
  useView(tester, width, height);
  final repository = FakeExpenseControlRepository(items ?? _plan());
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: wrapForTest(
        const ExpenseControlScreen(),
        repository: repository,
        theme: theme ?? AppTheme.light,
        rail: rail,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ExpenseControlScreen)),
);

ScrollPosition _listPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    await loadAppFonts();
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  group('P1: one bounded, centered column', () {
    for (final entry in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      for (final w in [1440.0, 2560.0]) {
        testWidgets('${entry.key} ${w.toInt()}: cards, add button and banner '
            'stay inside 960 and are centered', (tester) async {
          await _pump(
            tester,
            width: w,
            height: 1000,
            rail: true,
            theme: entry.value,
          );
          _container(tester).read(pendingItemEditsProvider.notifier).state = {
            'g1-1': const PendingItemEdit(value: 15),
          };
          await tester.pumpAndSettle();

          final center = 83 + (w - 83) / 2;
          final left = center - 480;
          final right = center + 480;
          final card = tester.getRect(find.byType(ExpenseGroupCard).first);
          expect(card.width, closeTo(960, 0.01));
          expect(card.center.dx, closeTo(center, 1));
          final add = tester.getRect(
            find
                .ancestor(
                  of: find.text(l10n.expenseControlAddItemAction),
                  matching: find.byType(InkWell),
                )
                .first,
          );
          expect(add.left, greaterThanOrEqualTo(left - 0.5));
          expect(add.right, lessThanOrEqualTo(right + 0.5));
          final banner = tester.getRect(find.byType(AllocationSummaryBanner));
          expect(banner.left, greaterThanOrEqualTo(left - 0.5));
          expect(banner.right, lessThanOrEqualTo(right + 0.5));
        });
      }
    }
  });

  group('P2/P3: the allocation box sits next to the name on wide windows', () {
    testWidgets('1440: inline, at most 200 wide, 40 high, right edges align', (
      tester,
    ) async {
      await _pump(tester, width: 1440, height: 900, rail: true);
      final labels = find.byType(ExpenseFormulaLabel);
      // Two children of the group + the top-level leaf.
      expect(labels, findsNWidgets(3));
      final rects = [for (var i = 0; i < 3; i++) tester.getRect(labels.at(i))];
      for (final rect in rects) {
        expect(rect.width, lessThanOrEqualTo(200.01));
        expect(rect.width, greaterThanOrEqualTo(96));
        expect(rect.height, 40);
      }
      // Inline: same row as the name, to its right.
      final childName = tester.getRect(find.text('Khoản 1'));
      expect(rects[0].left, greaterThanOrEqualTo(childName.right));
      expect((rects[0].center.dy - childName.center.dy).abs(), lessThan(14));
      // A column of values: every right edge is the same.
      expect(rects[1].right, closeTo(rects[0].right, 0.5));
      expect(rects[2].right, closeTo(rects[0].right, 0.5));
    });

    testWidgets('410: the box stays below the name as before', (tester) async {
      await _pump(tester, width: 410, height: 900);
      final childName = tester.getRect(find.text('Khoản 1'));
      final label = tester.getRect(find.byType(ExpenseFormulaLabel).first);
      expect(label.top, greaterThanOrEqualTo(childName.bottom));
      expect(label.width, greaterThan(200)); // the full row, as today
    });
  });

  group('P4: the pending-changes Save button', () {
    testWidgets('1440: at most 360 wide and centered; 410: full width', (
      tester,
    ) async {
      await _pump(tester, width: 1440, height: 1000, rail: true);
      _container(tester).read(pendingItemEditsProvider.notifier).state = {
        'g1-1': const PendingItemEdit(value: 15),
      };
      await tester.pumpAndSettle();
      Finder save() => find.ancestor(
        of: find.text(l10n.expenseControlSaveFormulaAction),
        matching: find.bySubtype<FilledButton>(),
      );
      await tester.ensureVisible(save());
      await tester.pump();
      final wide = tester.getRect(save());
      expect(wide.width, closeTo(360, 0.01));
      expect(wide.height, 52);
      expect(wide.center.dx, closeTo(83 + (1440 - 83) / 2, 1));

      // Compact (a fresh tree: no rail): the button spans the row, as before.
      await _pump(tester, width: 410, height: 900);
      _container(tester).read(pendingItemEditsProvider.notifier).state = {
        'g1-1': const PendingItemEdit(value: 15),
      };
      await tester.pumpAndSettle();
      await tester.ensureVisible(save());
      await tester.pump();
      expect(tester.getRect(save()).width, closeTo(410 - 36, 0.01));
    });
  });

  group('P5: actions keep working at every width', () {
    for (final (w, h) in [(410.0, 900.0), (840.0, 900.0), (1440.0, 900.0)]) {
      testWidgets('${w.toInt()}: collapse, add child, reorder', (tester) async {
        final repository = await _pump(tester, width: w, height: h);
        expect(find.text('Khoản 1'), findsOneWidget);
        await tester.tap(find.text('Nhà'));
        await tester.pumpAndSettle();
        expect(find.text('Khoản 1'), findsNothing);
        await tester.tap(find.text('Nhà'));
        await tester.pumpAndSettle();
        expect(find.text('Khoản 1'), findsOneWidget);

        await tester.tap(find.text(l10n.expenseControlAddChildAction('Nhà')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text(l10n.cancelAction));
        await tester.pumpAndSettle();

        await tester.timedDrag(
          find.byType(ReorderableDragStartListener).at(1),
          const Offset(0, -300),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        expect(repository.reorderCalls, isNotEmpty);
      });
    }
  });

  group('P6: scrolling from the margin', () {
    testWidgets('the wheel works over the left margin at 1440×500', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 1440,
        height: 500,
        items: _plan(groupChildren: 25),
      );
      final position = _listPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      final before = position.pixels;
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(50, 300)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(position.pixels, greaterThan(before));
    });
  });

  group('P7: hover, focus and tooltips', () {
    testWidgets('the group header offers hover feedback; icon buttons and the '
        'reorder handle have tooltips', (tester) async {
      await _pump(tester, width: 1440, height: 900);
      final header = find
          .ancestor(of: find.text('Nhà'), matching: find.byType(InkWell))
          .first;
      expect(offersHoverFeedback(tester, header), isTrue);
      expect(
        find.byTooltip(l10n.expenseControlEditSemantic('Nhà')),
        findsOneWidget,
      );
      expect(
        find.byTooltip(l10n.expenseControlDeleteSemantic('Nhà')),
        findsOneWidget,
      );
      expect(
        find.byTooltip(l10n.expenseControlReorderSemantic('Nhà')),
        findsOneWidget,
      );
    });
  });

  group('P8: long names and large amounts', () {
    for (final w in [320.0, 1440.0]) {
      testWidgets('${w.toInt()}: nothing overflows and the box stays bounded', (
        tester,
      ) async {
        final longName = 'Tên rất dài ' * 5;
        await _pump(
          tester,
          width: w,
          height: 900,
          items: [
            leafItem(
              'big',
              name: longName.trim(),
              method: ExpenseAllocationMethod.fixed,
              value: 999999999999,
            ),
          ],
        );
        expect(tester.takeException(), isNull);
        if (w >= 600) {
          final label = tester.getRect(find.byType(ExpenseFormulaLabel).first);
          expect(label.width, lessThanOrEqualTo(200.01));
        }
      });
    }
  });

  group('P9: resizing keeps the screen state', () {
    testWidgets(
      'a collapsed group and pending edits survive 1440 → 410 → 1440',
      (tester) async {
        await _pump(tester, width: 1440, height: 1000, rail: true);
        await tester.tap(find.text('Nhà'));
        await tester.pumpAndSettle();
        expect(find.text('Khoản 1'), findsNothing);
        _container(tester).read(pendingItemEditsProvider.notifier).state = {
          'solo': const PendingItemEdit(value: 25),
        };
        await tester.pumpAndSettle();

        for (final (w, h) in [(410.0, 900.0), (1440.0, 1000.0)]) {
          useView(tester, w, h);
          await tester.pumpAndSettle();
          expect(find.text('Khoản 1'), findsNothing, reason: 'still collapsed');
          expect(
            _container(tester).read(pendingItemEditsProvider),
            isNotEmpty,
            reason: 'pending edits kept',
          );
          expect(
            find.text(l10n.expenseControlSaveFormulaAction),
            findsOneWidget,
          );
        }
      },
    );
  });

  group('P10: compact is unchanged', () {
    testWidgets('410: 18dp side padding', (tester) async {
      await _pump(tester, width: 410, height: 900);
      final card = tester.getRect(find.byType(ExpenseGroupCard).first);
      expect(card.left, 18);
      expect(card.right, 410 - 18);
    });
  });
}
