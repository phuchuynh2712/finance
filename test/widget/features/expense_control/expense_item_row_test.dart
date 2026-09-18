import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/l10n/app_localizations.dart';
import 'package:finance/core/theme/app_theme.dart';
import 'package:finance/features/expense_control/domain/expense_control_item.dart';
import 'package:finance/features/expense_control/presentation/widgets/expense_item_row.dart';

ExpenseControlItem _leaf(double value) => ExpenseControlItem(
  id: 'a',
  userId: 'u1',
  parentId: null,
  name: 'Rent',
  iconKey: 'home',
  description: null,
  sortOrder: 0,
  allocationMethod: ExpenseAllocationMethod.percentage,
  allocationValue: value,
);

Widget _harness(ExpenseControlItem item, bool hasPendingEdit) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: ExpenseItemRow(
        item: item,
        showHeader: false,
        hasPendingEdit: hasPendingEdit,
        onValueChanged: (_, _) {},
      ),
    ),
  );
}

void main() {
  testWidgets(
    'when a pending edit is discarded (hasPendingEdit flips false), the field resyncs to the persisted value rather than keeping the discarded typed text',
    (tester) async {
      // Simulates the discard flow: the widget starts mid-edit (persisted
      // value 20, user typed 99, hasPendingEdit=true), then research.md
      // §9's discard trigger clears the pending-edits map, the tree
      // provider re-emits with the ORIGINAL persisted value, and
      // hasPendingEdit flips back to false.
      await tester.pumpWidget(_harness(_leaf(20), true));
      await tester.enterText(find.byType(TextField), '99');
      await tester.pump();
      expect(find.text('99'), findsOneWidget);

      // Discard: item reverts to its original persisted value, pending
      // flag flips off.
      await tester.pumpWidget(_harness(_leaf(20), false));
      await tester.pump();

      expect(find.text('99'), findsNothing);
      expect(find.text('20'), findsOneWidget);
    },
  );

  testWidgets(
    'while a pending edit is still active, the field does not fight the user\'s typing on subsequent rebuilds',
    (tester) async {
      await tester.pumpWidget(_harness(_leaf(20), true));
      await tester.enterText(find.byType(TextField), '35');
      await tester.pump();

      // A rebuild with the SAME hasPendingEdit=true (as would happen from
      // an unrelated provider change) must not clobber the user's typing.
      await tester.pumpWidget(_harness(_leaf(35), true));
      await tester.pump();

      expect(find.text('35'), findsOneWidget);
    },
  );
}
