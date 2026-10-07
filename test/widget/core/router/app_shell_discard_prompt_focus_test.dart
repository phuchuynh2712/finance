import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/di/expense_dependencies.dart';
import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/features/expense_control/presentation/expense_control_screen.dart';

import '../../../support/app_shell_harness.dart';
import '../../../support/expense_control_fixtures.dart';
import '../../../support/expense_screen_harness.dart';

/// D7 (contracts/plan-screen-ui.md): the discard-changes prompt is bounded
/// like every pop-up and its safe option ("keep editing") has the initial
/// focus, so Enter and Escape both keep the staged edits.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('vi'));
  });

  Future<_Handle> arrive(WidgetTester tester) async {
    useView(tester, 1440, 900);
    final repository = FakeExpenseControlRepository([leafItem('a')]);
    final container = shellContainerFor(repository);
    addTearDown(container.dispose);
    await arriveOnExpenseControlWithPendingEdit(tester, container);
    // Leaving Kế hoạch with staged edits opens the prompt.
    await tester.tap(find.text('Tổng quan').last);
    await tester.pumpAndSettle();
    expect(find.text(l10n.expenseControlDiscardPromptTitle), findsOneWidget);
    return _Handle(container);
  }

  testWidgets('the prompt is at most 560 wide and centered', (tester) async {
    await arrive(tester);
    final rect = dialogRect(tester);
    expect(rect.width, lessThanOrEqualTo(560.01));
    expect(rect.center.dx, closeTo(83 + (1440 - 83) / 2, 90));
  });

  testWidgets(
    'Cancel (keep editing) has the initial focus; Enter keeps the edits',
    (tester) async {
      final handle = await arrive(tester);
      expect(
        focusIsWithin(
          tester,
          find.widgetWithText(TextButton, l10n.cancelAction),
        ),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ExpenseControlScreen), findsOneWidget);
      expect(handle.container.read(pendingItemEditsProvider), isNotEmpty);
    },
  );

  testWidgets('Escape keeps editing too', (tester) async {
    final handle = await arrive(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(handle.container.read(pendingItemEditsProvider), isNotEmpty);
  });
}

class _Handle {
  _Handle(this.container);

  final ProviderContainer container;
}
