import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_layout.dart';
import 'package:finance/core/widgets/adaptive_body.dart';

const _contentKey = Key('content');

Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: AdaptiveBody(
          child: ColoredBox(
            key: _contentKey,
            color: Colors.red,
            child: SizedBox(width: double.infinity, height: 50),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'below 840dp, child fills the available width unchanged (FR-006)',
    (tester) async {
      await _pumpAt(tester, 600);
      final size = tester.getSize(find.byKey(_contentKey));
      expect(size.width, 600);
    },
  );

  testWidgets(
    'at 840dp exactly (below the 960dp default max), child still fills the '
    'available width — the cap has not started binding yet',
    (tester) async {
      await _pumpAt(tester, 840);
      final size = tester.getSize(find.byKey(_contentKey));
      expect(size.width, 840);
    },
  );

  testWidgets(
    'well above 960dp, child is capped at contentMaxWidth and centered (FR-005, SC-002)',
    (tester) async {
      await _pumpAt(tester, 1200);
      final size = tester.getSize(find.byKey(_contentKey));
      final topLeft = tester.getTopLeft(find.byKey(_contentKey));
      expect(size.width, AppLayoutTokens.contentMaxWidth);
      expect(topLeft.dx, (1200 - AppLayoutTokens.contentMaxWidth) / 2);
    },
  );

  testWidgets(
    'at an ultra-wide window, the cap still holds — content does not keep '
    'growing (Acceptance Scenario 3)',
    (tester) async {
      await _pumpAt(tester, 2560);
      final size = tester.getSize(find.byKey(_contentKey));
      expect(size.width, AppLayoutTokens.contentMaxWidth);
    },
  );

  testWidgets('a caller-supplied maxWidth overrides the default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveBody(
            maxWidth: 500,
            child: ColoredBox(
              key: _contentKey,
              color: Colors.red,
              child: SizedBox(width: double.infinity, height: 50),
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byKey(_contentKey));
    expect(size.width, 500);
  });
}
