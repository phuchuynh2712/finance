import 'package:finance/core/theme/app_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windowSizeClassFor', () {
    test('below 600 is compact', () {
      expect(windowSizeClassFor(0), WindowSizeClass.compact);
      expect(windowSizeClassFor(599), WindowSizeClass.compact);
    });

    test('600 is medium, the compact/medium boundary belongs to medium', () {
      expect(windowSizeClassFor(600), WindowSizeClass.medium);
    });

    test('below 840 stays medium', () {
      expect(windowSizeClassFor(839), WindowSizeClass.medium);
    });

    test(
      '840 is expanded, the medium/expanded boundary belongs to expanded',
      () {
        expect(windowSizeClassFor(840), WindowSizeClass.expanded);
      },
    );

    test('below 1200 stays expanded', () {
      expect(windowSizeClassFor(1199), WindowSizeClass.expanded);
    });

    test('1200 is large, the expanded/large boundary belongs to large', () {
      expect(windowSizeClassFor(1200), WindowSizeClass.large);
    });

    test('below 1600 stays large', () {
      expect(windowSizeClassFor(1599), WindowSizeClass.large);
    });

    test(
      '1600 is extraLarge, the large/extraLarge boundary belongs to extraLarge',
      () {
        expect(windowSizeClassFor(1600), WindowSizeClass.extraLarge);
      },
    );

    test('well above 1600 stays extraLarge', () {
      expect(windowSizeClassFor(2560), WindowSizeClass.extraLarge);
    });
  });

  group('AppLayoutTokens', () {
    test('contentMaxWidth is 960', () {
      expect(AppLayoutTokens.contentMaxWidth, 960);
    });
  });
}
