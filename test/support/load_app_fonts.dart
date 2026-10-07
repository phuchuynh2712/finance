import 'package:flutter/services.dart';

/// Loads the bundled Lexend UI font into the test engine.
///
/// Widget tests otherwise render every glyph as a full-em Ahem square, which
/// makes text about twice as wide as in the app and produces overflows that do
/// not exist on a device (a 134dp-wide entry button at 320dp holds "Thu nhập"
/// in Lexend but not in Ahem). Call once in `setUpAll` of a test that checks
/// horizontal fit. Vertical metrics are unaffected (they come from the theme's
/// line-height multipliers either way).
Future<void> loadAppFonts() async {
  final loader = FontLoader('Lexend')
    ..addFont(rootBundle.load('assets/fonts/Lexend-VariableFont_wght.ttf'));
  await loader.load();
}
