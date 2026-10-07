import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// The launch screen of iOS (and Android 11 and older) shows the splash image
/// as it is, so it must have the same rounded corners as the logo on the
/// sign-in screen, not the plain square of the launcher icon (which the
/// operating system rounds by itself). The PNG is generated from the SVG, and
/// the SVG must stay the same drawing as the icon.
void main() {
  String drawing(String svg) => svg
      .replaceAll(RegExp(r'<rect [^>]*></rect>'), '<rect/>')
      .replaceAll(RegExp(r'aria-label="[^"]*"'), '');

  test('the splash SVG is the icon drawing with a rounded background', () {
    final icon = File('assets/icon/appicon.svg').readAsStringSync();
    final splash = File('assets/icon/appicon_splash.svg').readAsStringSync();
    expect(
      splash,
      contains('rx="26.67"'),
    ); // 20/72 of 96, as on the sign-in screen
    expect(icon, isNot(contains('rx=')));
    expect(drawing(splash), drawing(icon));
  });

  test('the native splash is configured with the rounded image', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('image: "assets/icon/appicon_splash.png"'));
  });

  testWidgets('the splash PNG has transparent corners and a solid body', (
    tester,
  ) async {
    final bytes = File('assets/icon/appicon_splash.png').readAsBytesSync();
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      expect([image.width, image.height], [1024, 1024]);
      final data = (await image.toByteData())!;
      int alpha(int x, int y) => data.getUint8((y * image.width + x) * 4 + 3);

      for (final (x, y) in [(0, 0), (1023, 0), (0, 1023), (1023, 1023)]) {
        expect(alpha(x, y), 0, reason: 'corner $x,$y');
      }
      // Along the straight edges and in the middle it is solid.
      for (final (x, y) in [(512, 0), (0, 512), (1023, 512), (512, 1023)]) {
        expect(alpha(x, y), 255, reason: 'edge $x,$y');
      }
      expect(alpha(512, 512), 255);
    });
  });
}
