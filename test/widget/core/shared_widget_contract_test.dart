import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/widgets/empty_state_view.dart';

void main() {
  testWidgets('shared empty state exposes feature-neutral content and action', (
    tester,
  ) async {
    var actionPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: EmptyStateView(
          icon: Icons.inbox_outlined,
          message: 'Nothing here',
          actionLabel: 'Add item',
          actionSemanticsLabel: 'Add a new item',
          onAction: () => actionPressed = true,
        ),
      ),
    );

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Add item'), findsOneWidget);
    expect(find.bySemanticsLabel('Add a new item'), findsOneWidget);

    await tester.tap(find.text('Add item'));
    expect(actionPressed, isTrue);
  });
}
