import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expenses/presentation/expense_screen.dart';

import 'expense_control_fixtures.dart';

/// Shared helpers of the Chi tiêu adaptive tests (tasks T011–T013).

void useView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Mounts [ExpenseScreen] directly as the app's home (enough for layout
/// checks; a successful save would pop the only route, so save tests use
/// [pumpExpenseScreenPushed]).
Future<FakeExpenseControlRepository> pumpExpenseScreen(
  WidgetTester tester, {
  required double width,
  required double height,
  List<ExpenseControlItem>? items,
  ThemeData? theme,
  bool rail = false,
  double textScale = 1.0,
}) async {
  useView(tester, width, height);
  final repository = FakeExpenseControlRepository(items ?? accounts(7));
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: wrapForTest(
        const ExpenseScreen(),
        repository: repository,
        theme: theme ?? AppTheme.light,
        rail: rail,
        textScale: textScale,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// Same, but the screen is pushed from a home with an `Open` button so that a
/// successful save can pop back to it.
Future<FakeExpenseControlRepository> pumpExpenseScreenPushed(
  WidgetTester tester, {
  required double width,
  required double height,
  List<ExpenseControlItem>? items,
  ThemeData? theme,
}) async {
  useView(tester, width, height);
  final repository = FakeExpenseControlRepository(items ?? accounts(7));
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: wrapForTest(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const ExpenseScreen(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        repository: repository,
        theme: theme ?? AppTheme.light,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return repository;
}

Finder keypadKey(String key) => find.byKey(ValueKey('expense-keypad-$key'));
Finder chip(String id) => find.byKey(ValueKey('expense-item-chip-$id'));
Finder amountDisplay() => find.byKey(const ValueKey('expense-amount-display'));
Finder previewBanner() => find.byKey(const ValueKey('expense-preview-banner'));

/// The banner renders through `RichText`; this reads its full sentence.
String bannerText(WidgetTester tester) {
  final texts = tester
      .widgetList<RichText>(
        find.descendant(of: previewBanner(), matching: find.byType(RichText)),
      )
      .map((r) => r.text.toPlainText());
  return texts.reduce((a, b) => a.length >= b.length ? a : b);
}

Finder saveButton() => find.bySubtype<FilledButton>().last;

String amountText(WidgetTester tester) =>
    tester.widget<Text>(amountDisplay()).data!;

Future<void> tapDigits(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(keypadKey(digit));
    await tester.pump();
  }
}

/// The manual tab's main vertical scroll position (the first `ListView`).
ScrollPosition mainScrollPosition(WidgetTester tester) {
  final scrollable = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  return tester.state<ScrollableState>(scrollable).position;
}

/// Whether the primary focus sits on, or inside, the widget found by [finder].
bool focusIsWithin(WidgetTester tester, Finder finder) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  final target = tester.element(finder);
  if (identical(context, target)) return true;
  var found = false;
  context.visitAncestorElements((element) {
    if (identical(element, target)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Whether [finder] is (or contains) an enabled `InkWell` — the framework
/// paints its hover and focus overlays from the theme's `hoverColor` and
/// `focusColor` — and the theme's hover colour is visible. (The pointer cursor
/// `InkWell` shows is web-only, so it is checked in the browser pass.)
bool offersHoverFeedback(WidgetTester tester, Finder finder) {
  final inkWells = tester.widgetList<InkWell>(
    find.descendant(
      of: finder,
      matching: find.byType(InkWell),
      matchRoot: true,
    ),
  );
  final context = tester.element(finder);
  return inkWells.any((ink) => ink.onTap != null) &&
      Theme.of(context).hoverColor.a > 0;
}

/// The visible surface of the open dialog (its `Material`), not the full-window
/// layout box `AlertDialog` itself reports.
Rect dialogRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(Material))
      .first,
);
