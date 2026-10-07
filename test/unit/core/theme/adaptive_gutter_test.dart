import 'package:finance/core/theme/app_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('adaptiveGutterFor (contracts/adaptive-layout-primitives.md)', () {
    test('compact windows get exactly the minimum gutter', () {
      expect(adaptiveGutterFor(windowWidth: 412, viewportWidth: 412), 18);
    });

    test('below the activation class the minimum gutter is kept', () {
      expect(adaptiveGutterFor(windowWidth: 839.9, viewportWidth: 757), 18);
    });

    test(
      'at the activation class a viewport narrower than the max keeps 18',
      () {
        // (757 - 960) / 2 is negative, so the minimum gutter wins.
        expect(adaptiveGutterFor(windowWidth: 840, viewportWidth: 757), 18);
      },
    );

    test('a wide viewport is centered: (viewport - max) / 2', () {
      expect(adaptiveGutterFor(windowWidth: 1440, viewportWidth: 1357), 198.5);
      expect(adaptiveGutterFor(windowWidth: 2560, viewportWidth: 2477), 758.5);
    });

    test('entry width activates at medium', () {
      const entry = AppLayoutTokens.entryContentMaxWidth;
      expect(
        adaptiveGutterFor(
          windowWidth: 600,
          viewportWidth: 517,
          maxWidth: entry,
          activatesAt: WindowSizeClass.medium,
        ),
        18,
      );
      expect(
        adaptiveGutterFor(
          windowWidth: 1000,
          viewportWidth: 917,
          maxWidth: entry,
          activatesAt: WindowSizeClass.medium,
        ),
        198.5,
      );
      expect(
        adaptiveGutterFor(
          windowWidth: 599.9,
          viewportWidth: 599.9,
          maxWidth: entry,
          activatesAt: WindowSizeClass.medium,
        ),
        18,
      );
    });

    test('tokens carry the planned values', () {
      expect(AppLayoutTokens.entryContentMaxWidth, 520);
      expect(AppLayoutTokens.screenGutter, 18);
      expect(AppLayoutTokens.contentMaxWidth, 960);
    });

    test('never below minGutter and non-decreasing in the viewport width', () {
      var previous = 0.0;
      for (var viewport = 300.0; viewport <= 3000; viewport += 37) {
        final gutter = adaptiveGutterFor(
          windowWidth: viewport + 83,
          viewportWidth: viewport,
        );
        expect(gutter, greaterThanOrEqualTo(AppLayoutTokens.screenGutter));
        expect(gutter, greaterThanOrEqualTo(previous));
        previous = gutter;
      }
    });

    test('a custom minGutter is honoured below activation', () {
      expect(
        adaptiveGutterFor(windowWidth: 400, viewportWidth: 400, minGutter: 24),
        24,
      );
    });
  });
}
