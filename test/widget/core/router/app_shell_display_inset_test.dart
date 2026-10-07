import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/features/account/presentation/account_screen.dart';

import '../../../support/app_shell_harness.dart';
import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';

/// A phone held sideways has a camera cutout on one side: the display reports
/// a left inset. The side rail pads itself by it, so the content beside the
/// rail must not apply it again (it would indent each screen's header and
/// `SafeArea` by it, and a screen without a `SafeArea` would not line up with
/// its own header).
void main() {
  Future<void> pumpOnProfile(WidgetTester tester) async {
    final container = shellContainerFor(FakeExpenseControlRepository([]));
    addTearDown(container.dispose);
    await tester.pumpWidget(shellApp(container));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ').last);
    await tester.pumpAndSettle();
  }

  void useInset(WidgetTester tester, double left) {
    tester.view.padding = FakeViewPadding(left: left);
    tester.view.viewPadding = FakeViewPadding(left: left);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
  }

  double leftInsetOf(WidgetTester tester) =>
      MediaQuery.paddingOf(tester.element(find.byType(AccountScreen))).left;

  testWidgets('923×411 with a 54dp cutout: the content beside the rail has no '
      'left inset, the rail still clears the cutout', (tester) async {
    useView(tester, 923, 411);
    useInset(tester, 54);
    await pumpOnProfile(tester);

    expect(leftInsetOf(tester), 0);

    final rail = tester.getRect(find.byType(NavigationRail));
    expect(rail.width, greaterThan(54));
    // The header starts one title spacing (16) after the app bar's own left
    // edge, not 54dp further.
    final appBar = tester.getRect(find.byType(AppBar));
    final titleRow = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(Row),
    );
    expect(tester.getTopLeft(titleRow.first).dx - appBar.left, lessThan(20));
  });

  testWidgets('410×864 with a left inset: no rail, the inset is kept', (
    tester,
  ) async {
    useView(tester, 410, 864);
    useInset(tester, 24);
    await pumpOnProfile(tester);

    expect(find.byType(NavigationRail), findsNothing);
    expect(leftInsetOf(tester), 24);
  });
}
