import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/widgets/empty_state_view.dart';

void main() {
  testWidgets(
    'renders message without an action when no callback is supplied',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmptyStateView(icon: Icons.inbox, message: 'Nothing here'),
        ),
      );

      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets('renders and invokes an accessible action', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EmptyStateView(
          icon: Icons.inbox,
          message: 'Nothing here',
          actionLabel: 'Add item',
          actionSemanticsLabel: 'Add a new item',
          onAction: () => pressed = true,
        ),
      ),
    );

    expect(find.bySemanticsLabel('Add a new item'), findsOneWidget);
    await tester.tap(find.text('Add item'));
    expect(pressed, isTrue);
  });
}
