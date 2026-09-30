import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance/core/theme/app_layout.dart';
import 'package:finance/core/widgets/adaptive_body.dart';

const _contentKey = Key('content');

Future<void> _pumpAt(
  WidgetTester tester,
  double width, {
  WindowSizeClass activatesAt = WindowSizeClass.expanded,
  double maxWidth = AppLayoutTokens.contentMaxWidth,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdaptiveBody(
          activatesAt: activatesAt,
          maxWidth: maxWidth,
          child: const ColoredBox(
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

  group('activatesAt: WindowSizeClass.medium (600dp)', () {
    testWidgets('below 600dp, child fills the available width unchanged', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        599,
        activatesAt: WindowSizeClass.medium,
        maxWidth: 450,
      );
      final size = tester.getSize(find.byKey(_contentKey));
      expect(size.width, 599);
    });

    testWidgets('at exactly 600dp, child is capped and centered', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        600,
        activatesAt: WindowSizeClass.medium,
        maxWidth: 450,
      );
      final size = tester.getSize(find.byKey(_contentKey));
      final topLeft = tester.getTopLeft(find.byKey(_contentKey));
      expect(size.width, 450);
      expect(topLeft.dx, (600 - 450) / 2);
    });

    testWidgets('well above 600dp, child stays capped and centered', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        1200,
        activatesAt: WindowSizeClass.medium,
        maxWidth: 450,
      );
      final size = tester.getSize(find.byKey(_contentKey));
      final topLeft = tester.getTopLeft(find.byKey(_contentKey));
      expect(size.width, 450);
      expect(topLeft.dx, (1200 - 450) / 2);
    });
  });

  testWidgets(
    'the default activatesAt is unchanged: at 600dp (medium), child still '
    'fills the available width — the cap only starts at expanded (840dp)',
    (tester) async {
      await _pumpAt(tester, 600);
      final size = tester.getSize(find.byKey(_contentKey));
      expect(size.width, 600);
    },
  );

  group('state preservation across a live threshold crossing (research.md '
      'Decision 1a — regression coverage for the scroll/state-loss bug)', () {
    testWidgets(
      'a ListView.controller scroll offset survives a resize crossing the '
      'activatesAt threshold from above to below',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdaptiveBody(
                child: ListView.builder(
                  controller: controller,
                  itemCount: 100,
                  itemBuilder: (context, index) =>
                      SizedBox(height: 50, child: Text('Item $index')),
                ),
              ),
            ),
          ),
        );

        controller.jumpTo(500);
        await tester.pump();
        expect(controller.offset, 500.0);

        tester.view.physicalSize = const Size(410, 800);
        await tester.pump();

        expect(controller.offset, 500.0);
      },
    );

    testWidgets(
      'a ListView.controller scroll offset survives a resize crossing the '
      'activatesAt threshold from below to above',
      (tester) async {
        tester.view.physicalSize = const Size(410, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdaptiveBody(
                child: ListView.builder(
                  controller: controller,
                  itemCount: 100,
                  itemBuilder: (context, index) =>
                      SizedBox(height: 50, child: Text('Item $index')),
                ),
              ),
            ),
          ),
        );

        controller.jumpTo(500);
        await tester.pump();
        expect(controller.offset, 500.0);

        tester.view.physicalSize = const Size(1024, 800);
        await tester.pump();

        expect(controller.offset, 500.0);
      },
    );
  });
}
