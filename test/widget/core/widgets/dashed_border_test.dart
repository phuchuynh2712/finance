import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/widgets/dashed_border.dart';

void main() {
  testWidgets('DashedTopBorder preserves child layout and accepts geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 40,
            child: DashedTopBorder(
              color: Colors.black,
              strokeWidth: 2,
              dashWidth: 6,
              gapWidth: 4,
              child: Text('child'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('child'), findsOneWidget);
    expect(tester.getSize(find.byType(DashedTopBorder)), const Size(200, 40));
  });

  testWidgets('DashedRectBorder preserves child layout and radius inputs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 160,
            height: 48,
            child: DashedRectBorder(
              color: Colors.blue,
              borderRadius: 8,
              strokeWidth: 2,
              dashWidth: 5,
              gapWidth: 2,
              child: Text('child'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('child'), findsOneWidget);
    expect(tester.getSize(find.byType(DashedRectBorder)), const Size(160, 48));
  });
}
